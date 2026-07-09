package h2odin

import "core:fmt"
import vmem "core:mem/virtual"
import "core:os"
import "core:path/filepath"
import "core:strings"

// H2Odin is a pipeline: Extraction → Analysis → Transformation → Emission.
// main owns the generation arena and the stage order; the stages own
// everything else.
main :: proc() {
	mode := Type_Mode.ABI
	mode_from_cli := false
	cli_header: string
	config_path: string
	for arg in os.args[1:] {
		if strings.has_prefix(arg, "-mode:") {
			switch arg[len("-mode:"):] {
			case "abi":
				mode = .ABI
			case "idiomatic":
				mode = .Idiomatic
			case:
				usage()
			}
			mode_from_cli = true
		} else if strings.has_prefix(arg, "-config:") {
			config_path = arg[len("-config:"):]
		} else if cli_header == "" {
			cli_header = arg
		} else {
			usage()
		}
	}

	// One named generation arena owns the IR and every long-lived string for
	// this run, and is freed once when the run ends. context.allocator is a
	// convenience pointing at it, not the owner.
	arena: vmem.Arena
	if err := vmem.arena_init_growing(&arena); err != nil {
		fmt.eprintln("h2odin: failed to initialise generation arena:", err)
		os.exit(1)
	}
	defer vmem.arena_destroy(&arena)
	context.allocator = vmem.arena_allocator(&arena)

	policy, policy_ok := policy_load(config_path)
	if !policy_ok {
		os.exit(1)
	}
	defer policy_destroy(&policy)

	// An explicit CLI mode wins; otherwise the config decides; otherwise ABI.
	if !mode_from_cli && policy.type_mode_is_set {
		mode = policy.type_mode
	}

	headers, headers_ok := resolve_input_headers(cli_header, &policy)
	if !headers_ok {
		os.exit(1)
	}

	preprocess := Extract_Preprocess {
		include_paths = resolve_path_list(policy.include_paths, policy.config_dir),
		defines       = policy.defines,
	}

	ir: IR
	ir_init(&ir)

	if !extract(headers, &ir, preprocess) {
		os.exit(1)
	}
	analyze(&ir)
	transform(&ir, mode, &policy)

	// Package and foreign library default to the first header's stem.
	stem := filepath.stem(filepath.base(headers[0]))
	opts := Emit_Options {
		package_name      = policy.package_name if policy.package_name != "" else stem,
		foreign_lib       = policy.foreign_lib if policy.foreign_lib != "" else stem,
		link_prefix       = policy.foreign_link_prefix,
		procedures_at_end = policy.procedures_at_end,
		emit_comments     = policy.emit_comments,
		imports_file      = policy.imports_file,
	}
	result := emit(&ir, opts)

	if !write_emit_result(result, &policy, stem) {
		os.exit(1)
	}
	report_diagnostics(&ir)
}

// Prefer config.inputs when set; otherwise the CLI header is required.
// Relative config.inputs paths resolve against the config directory.
resolve_input_headers :: proc(cli_header: string, policy: ^Policy) -> (headers: []string, ok: bool) {
	if len(policy.inputs) > 0 {
		out := make([]string, len(policy.inputs))
		for path, i in policy.inputs {
			out[i] = resolve_path(path, policy.config_dir)
		}
		return out, true
	}
	if cli_header == "" {
		fmt.eprintln("h2odin: no input headers (pass a header path or set config.inputs)")
		usage()
	}
	out := make([]string, 1)
	out[0] = cli_header
	return out, true
}

resolve_path_list :: proc(paths: []string, base_dir: string) -> []string {
	if len(paths) == 0 {
		return nil
	}
	out := make([]string, len(paths))
	for path, i in paths {
		out[i] = resolve_path(path, base_dir)
	}
	return out
}

// Absolute paths stay as-is; relative paths join base_dir when non-empty.
resolve_path :: proc(path: string, base_dir: string) -> string {
	if path == "" || filepath.is_abs(path) || base_dir == "" {
		return path
	}
	joined, err := filepath.join({base_dir, path})
	if err != nil {
		return path
	}
	return joined
}

write_emit_result :: proc(result: Emit_Result, policy: ^Policy, stem: string) -> bool {
	main_text := result.main
	if policy.footer_per_header {
		footer := load_footer(policy, stem)
		if footer != "" {
			main_text = strings.concatenate({main_text, footer})
		}
	}

	if policy.output_folder == "" && policy.imports_file == "" {
		fmt.print(main_text)
		return true
	}

	if policy.output_folder != "" {
		if err := os.make_directory_all(policy.output_folder); err != nil {
			if !os.is_dir(policy.output_folder) {
				fmt.eprintfln("h2odin: cannot create output_folder %q: %v", policy.output_folder, err)
				return false
			}
		}
	}

	if policy.imports_file != "" {
		imports_path := policy.imports_file
		if policy.output_folder != "" && !filepath.is_abs(imports_path) {
			joined, jerr := filepath.join({policy.output_folder, imports_path})
			if jerr != nil {
				fmt.eprintfln("h2odin: cannot join imports path: %v", jerr)
				return false
			}
			imports_path = joined
		}
		if werr := os.write_entire_file(imports_path, result.imports); werr != nil {
			fmt.eprintfln("h2odin: failed to write imports file %q: %v", imports_path, werr)
			return false
		}
	}

	if policy.output_folder != "" {
		out_path, jerr := filepath.join({policy.output_folder, fmt.tprintf("%s.odin", stem)})
		if jerr != nil {
			fmt.eprintfln("h2odin: cannot join output path: %v", jerr)
			return false
		}
		if werr := os.write_entire_file(out_path, main_text); werr != nil {
			fmt.eprintfln("h2odin: failed to write %q: %v", out_path, werr)
			return false
		}
		return true
	}

	// imports_file without output_folder: imports on disk, main on stdout.
	fmt.print(main_text)
	return true
}

// footer_per_header: look for {stem}_footer.odin next to the output (or CWD
// when writing to stdout) and append its contents unchanged.
load_footer :: proc(policy: ^Policy, stem: string) -> string {
	name := fmt.tprintf("%s_footer.odin", stem)
	try_read :: proc(path: string) -> string {
		data, err := os.read_entire_file(path, context.temp_allocator)
		if err != nil {
			return ""
		}
		return string(data)
	}
	if policy.output_folder != "" {
		if p, err := filepath.join({policy.output_folder, name}); err == nil {
			if s := try_read(p); s != "" {
				return s
			}
		}
	}
	if policy.config_dir != "" {
		if p, err := filepath.join({policy.config_dir, name}); err == nil {
			if s := try_read(p); s != "" {
				return s
			}
		}
	}
	return try_read(name)
}

usage :: proc() -> ! {
	fmt.eprintln("usage: h2odin [-mode:abi|idiomatic] [-config:file.lua] [header.h]")
	fmt.eprintln("  header.h is required unless config.inputs is set")
	os.exit(2)
}
