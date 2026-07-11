package h2odin

import "core:fmt"
import vmem "core:mem/virtual"
import "core:os"
import "core:path/filepath"
import "core:strings"

// Default config filename looked up inside a project directory.
DEFAULT_CONFIG_NAME :: "H2Odin.lua"

// Where generated bindings are written.
Output_Destination :: enum {
	Config, // use config.output_folder (default)
	Stdout, // write a single merged unit to stdout
}

// H2Odin is a pipeline: Extraction → Analysis → Transformation → Emission.
// main owns the generation arena and the stage order; the stages own
// everything else. Generation is steered by a Lua config — the CLI selects
// that config (directory/H2Odin.lua or -config:) and process-level knobs.
main :: proc() {
	cli, cli_ok := parse_cli(os.args[1:])
	if !cli_ok {
		usage()
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

	policy, policy_ok := policy_load(cli.config_path)
	if !policy_ok {
		os.exit(1)
	}
	defer policy_destroy(&policy)

	mode := Type_Mode.ABI
	if policy.type_mode_is_set {
		mode = policy.type_mode
	}

	headers, headers_ok := resolve_input_headers(&policy)
	if !headers_ok {
		os.exit(1)
	}

	include_paths, includes_ok := resolve_path_list(policy.include_paths, policy.config_dir)
	if !includes_ok {
		os.exit(1)
	}
	preprocess := Extract_Preprocess {
		include_paths = include_paths,
		defines       = policy.defines,
	}

	ir: IR
	ir_init(&ir)

	if !extract(headers, &ir, preprocess) {
		os.exit(1)
	}
	analyze(&ir)
	transform(&ir, mode, &policy)

	plan, plan_ok := plan_outputs(&ir, &policy)
	if !plan_ok {
		os.exit(1)
	}

	// Package and foreign library default to the first header's stem
	// (sanitized / validated — see resolve_emit_names).
	stem := filepath.stem(filepath.base(headers[0]))
	package_name, foreign_lib, names_ok := resolve_emit_names(&policy, stem)
	if !names_ok {
		os.exit(1)
	}
	opts := Emit_Options {
		package_name      = package_name,
		foreign_lib       = foreign_lib,
		link_prefix       = policy.foreign_link_prefix,
		procedures_at_end = policy.procedures_at_end,
		emit_comments     = policy.emit_comments,
	}
	bit_field_plan := plan_bit_field_emission(&ir, context.temp_allocator)
	for diagnostic in bit_field_plan.diagnostics {
		append(&ir.diagnostics, diagnostic)
	}
	report_pointer_lowering_guesses(&ir, bit_field_plan.opaque_records)
	result := emit(&ir, plan, opts)

	if !write_emit_result(result, &policy, cli.destination) {
		os.exit(1)
	}
	// Emit first, then report: errors still leave usable output on disk /
	// stdout when requested, but a non-zero exit marks the run as failed.
	if !report_diagnostics(&ir, &policy, cli.quiet, cli.verbose) {
		os.exit(1)
	}
}

CLI :: struct {
	config_path: string,
	destination: Output_Destination,
	quiet:       bool,
	verbose:     bool,
}

// Parse process-level flags and resolve the config path. Returns false on
// usage errors (caller should print usage and exit 2).
parse_cli :: proc(args: []string) -> (cli: CLI, ok: bool) {
	config_path: string
	project_dir: string
	destination := Output_Destination.Config
	destination_set := false
	quiet := false
	verbose := false

	for arg in args {
		switch {
		case arg == "-h" || arg == "-help" || arg == "--help":
			usage()
		case arg == "-q" || arg == "-quiet" || arg == "--quiet":
			quiet = true
		case arg == "-v" || arg == "-verbose" || arg == "--verbose":
			verbose = true
		case strings.has_prefix(arg, "-config:"), strings.has_prefix(arg, "--config:"):
			if config_path != "" {
				fmt.eprintln("h2odin: -config: specified more than once")
				return {}, false
			}
			prefix_len := 8 // "-config:"
			if strings.has_prefix(arg, "--config:") {
				prefix_len = 9
			}
			config_path = arg[prefix_len:]
			if config_path == "" {
				fmt.eprintln("h2odin: -config: requires a path")
				return {}, false
			}
		case strings.has_prefix(arg, "-destination:"), strings.has_prefix(arg, "--destination:"), strings.has_prefix(arg, "-d:"):
			if destination_set {
				fmt.eprintln("h2odin: -destination: specified more than once")
				return {}, false
			}
			value: string
			switch {
			case strings.has_prefix(arg, "--destination:"):
				value = arg[len("--destination:"):]
			case strings.has_prefix(arg, "-destination:"):
				value = arg[len("-destination:"):]
			case:
				value = arg[len("-d:"):]
			}
			dest, dest_ok := parse_destination(value)
			if !dest_ok {
				fmt.eprintfln("h2odin: -destination: unknown value %q (want config or stdout)", value)
				return {}, false
			}
			destination = dest
			destination_set = true
		case strings.has_prefix(arg, "-"):
			fmt.eprintfln("h2odin: unknown argument %q", arg)
			return {}, false
		case:
			// Positional: project directory containing H2Odin.lua.
			if project_dir != "" {
				fmt.eprintfln("h2odin: unexpected argument %q (only one project directory is accepted)", arg)
				return {}, false
			}
			project_dir = arg
		}
	}

	if quiet && verbose {
		fmt.eprintln("h2odin: -quiet and -verbose are mutually exclusive")
		return {}, false
	}

	resolved, resolved_ok := resolve_config_path(config_path, project_dir)
	if !resolved_ok {
		return {}, false
	}

	return CLI{config_path = resolved, destination = destination, quiet = quiet, verbose = verbose}, true
}

parse_destination :: proc(value: string) -> (Output_Destination, bool) {
	switch value {
	case "config":
		return .Config, true
	case "stdout":
		return .Stdout, true
	}
	return {}, false
}

// Resolve the Lua config path from -config: and/or a project directory.
// -config: is explicit; a directory implies directory/H2Odin.lua.
resolve_config_path :: proc(config_path: string, project_dir: string) -> (path: string, ok: bool) {
	if config_path != "" && project_dir != "" {
		fmt.eprintln("h2odin: pass either a project directory or -config:, not both")
		return "", false
	}
	if config_path != "" {
		return config_path, true
	}
	if project_dir == "" {
		fmt.eprintln("h2odin: pass a project directory (containing H2Odin.lua) or -config:path")
		return "", false
	}
	if !os.exists(project_dir) {
		fmt.eprintfln("h2odin: project directory %q does not exist", project_dir)
		return "", false
	}
	if !os.is_dir(project_dir) {
		fmt.eprintfln("h2odin: %q is not a directory (use -config: for a Lua file path)", project_dir)
		return "", false
	}
	joined, jerr := filepath.join({project_dir, DEFAULT_CONFIG_NAME})
	if jerr != nil {
		fmt.eprintfln("h2odin: cannot join config path under %q: %v", project_dir, jerr)
		return "", false
	}
	if !os.exists(joined) {
		fmt.eprintfln("h2odin: no %s in %q (create one or pass -config:path)", DEFAULT_CONFIG_NAME, project_dir)
		return "", false
	}
	if !os.is_file(joined) {
		fmt.eprintfln("h2odin: %q is not a file", joined)
		return "", false
	}
	return joined, true
}

// config.inputs is the sole source of headers (paths relative to the config dir).
resolve_input_headers :: proc(policy: ^Policy) -> (headers: []string, ok: bool) {
	if len(policy.inputs) == 0 {
		fmt.eprintln("h2odin: config.inputs is empty (list at least one header path)")
		return nil, false
	}
	out := make([]string, len(policy.inputs))
	for path, i in policy.inputs {
		resolved, path_ok := resolve_path(path, policy.config_dir)
		if !path_ok {
			return nil, false
		}
		out[i] = resolved
	}
	return out, true
}

resolve_path_list :: proc(paths: []string, base_dir: string) -> (out: []string, ok: bool) {
	if len(paths) == 0 {
		return nil, true
	}
	out = make([]string, len(paths))
	for path, i in paths {
		resolved, path_ok := resolve_path(path, base_dir)
		if !path_ok {
			return nil, false
		}
		out[i] = resolved
	}
	return out, true
}

// Resolve package and foreign-lib names for emission. Explicit config values
// fail closed when invalid; stem defaults are sanitized into legal forms.
resolve_emit_names :: proc(policy: ^Policy, stem: string) -> (package_name, foreign_lib: string, ok: bool) {
	if policy.package_name != "" {
		if !is_odin_identifier(policy.package_name) {
			fmt.eprintfln(
				"h2odin: config.package %q is not a valid Odin package identifier (letter/underscore then alphanumerics/underscores, not a keyword)",
				policy.package_name,
			)
			return "", "", false
		}
		package_name = policy.package_name
	} else {
		package_name = sanitize_package_stem(stem)
		if package_name == "" {
			package_name = "bindings"
		}
	}

	if policy.foreign_lib != "" {
		if !is_safe_foreign_lib(policy.foreign_lib) {
			fmt.eprintfln("h2odin: config.foreign.import_lib %q is empty or contains a quote, backslash, or control character", policy.foreign_lib)
			return "", "", false
		}
		foreign_lib = policy.foreign_lib
	} else {
		// system: path is a string, not an identifier — keep the stem as-is
		// when non-empty (hyphens are fine); fall back to a generic name.
		foreign_lib = stem if is_safe_foreign_lib(stem) else "lib"
	}
	return package_name, foreign_lib, true
}

// Absolute paths stay as-is; relative paths join base_dir when non-empty.
// Join failure is fatal — a silent cwd-relative fallback can pick the wrong
// header or output dir (see ROADMAP Code health).
resolve_path :: proc(path: string, base_dir: string) -> (resolved: string, ok: bool) {
	if path == "" || filepath.is_abs(path) || base_dir == "" {
		return path, true
	}
	joined, err := filepath.join({base_dir, path})
	if err != nil {
		fmt.eprintfln("h2odin: cannot join path %q with base %q: %v", path, base_dir, err)
		return "", false
	}
	return joined, true
}

write_emit_result :: proc(result: Emit_Result, policy: ^Policy, destination: Output_Destination) -> bool {
	switch destination {
	case .Stdout:
		return write_emit_to_stdout(result, policy)
	case .Config:
		return write_emit_to_config_folder(result, policy)
	}
	return false
}

write_emit_to_stdout :: proc(result: Emit_Result, policy: ^Policy) -> bool {
	// Stdout only makes sense for a single merged unit.
	if len(result.files) != 1 {
		fmt.eprintln("h2odin: -destination:stdout requires a single output unit (use output.layout = \"merged\")")
		return false
	}
	text := result.files[0].content
	if policy.footer_per_header {
		footer := load_footer(policy, result.files[0].stem)
		if footer != "" {
			text = strings.concatenate({text, footer})
		}
	}
	fmt.print(text)
	return true
}

write_emit_to_config_folder :: proc(result: Emit_Result, policy: ^Policy) -> bool {
	// Relative output_folder resolves against the config directory (same as inputs).
	output_folder, folder_ok := resolve_path(policy.output_folder, policy.config_dir)
	if !folder_ok {
		return false
	}

	if output_folder == "" {
		fmt.eprintln("h2odin: no config.output_folder set; set it in the Lua config or use -destination:stdout")
		return false
	}

	if err := os.make_directory_all(output_folder); err != nil {
		if !os.is_dir(output_folder) {
			fmt.eprintfln("h2odin: cannot create output_folder %q: %v", output_folder, err)
			return false
		}
	}

	for file in result.files {
		text := file.content
		if policy.footer_per_header {
			footer := load_footer(policy, file.stem)
			if footer != "" {
				text = strings.concatenate({text, footer})
			}
		}
		out_path, jerr := filepath.join({output_folder, file.filename})
		if jerr != nil {
			fmt.eprintfln("h2odin: cannot join output path: %v", jerr)
			return false
		}
		if werr := os.write_entire_file(out_path, text); werr != nil {
			fmt.eprintfln("h2odin: failed to write %q: %v", out_path, werr)
			return false
		}
	}
	return true
}

// footer_per_header: look for {stem}_footer.odin next to the output (or next
// to the config / CWD when writing to stdout) and append its contents unchanged.
load_footer :: proc(policy: ^Policy, stem: string) -> string {
	name := fmt.tprintf("%s_footer.odin", stem)
	try_read :: proc(path: string) -> string {
		data, err := os.read_entire_file(path, context.temp_allocator)
		if err != nil {
			return ""
		}
		return string(data)
	}
	if output_folder, folder_ok := resolve_path(policy.output_folder, policy.config_dir); folder_ok && output_folder != "" {
		if p, err := filepath.join({output_folder, name}); err == nil {
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
	fmt.eprintln("usage: h2odin <project-dir> [options]")
	fmt.eprintln("       h2odin -config:file.lua [options]")
	fmt.eprintln("")
	fmt.eprintln("  <project-dir>         directory containing H2Odin.lua (common case)")
	fmt.eprintln("  -config:path          explicit Lua config path (when not using H2Odin.lua)")
	fmt.eprintln("  -destination:dest     where to write bindings: config (default) or stdout")
	fmt.eprintln("  -d:dest               short for -destination")
	fmt.eprintln("  -quiet, -q            suppress warnings and errors on stderr")
	fmt.eprintln("  -verbose, -v          detailed diagnostic reports (cause + config fixes)")
	fmt.eprintln("  -help, -h             show this help")
	fmt.eprintln("")
	fmt.eprintln("By default, bindings are written under config.output_folder.")
	fmt.eprintln("Use -destination:stdout to print a single merged unit to stdout.")
	os.exit(2)
}
