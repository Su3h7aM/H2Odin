package h2odin

import "core:fmt"
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

Command_Line_Options :: struct {
	config_path:  string,
	destination:  Output_Destination,
	quiet:        bool,
	verbose:      bool,
	resource_dir: string, // -resource-dir:; empty = use config / clang driver
}

// Parse process-level flags and resolve the config path. Returns false on
// usage errors (caller should print usage and exit 2).
parse_command_line :: proc(args: []string) -> (options: Command_Line_Options, ok: bool) {
	config_path: string
	project_dir: string
	destination := Output_Destination.Config
	destination_set := false
	quiet := false
	verbose := false
	resource_dir: string

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
				user_error("h2odin: -config: specified more than once")
				return {}, false
			}
			prefix_len := 8 // "-config:"
			if strings.has_prefix(arg, "--config:") {
				prefix_len = 9
			}
			config_path = arg[prefix_len:]
			if config_path == "" {
				user_error("h2odin: -config: requires a path")
				return {}, false
			}
		case strings.has_prefix(arg, "-destination:"), strings.has_prefix(arg, "--destination:"), strings.has_prefix(arg, "-d:"):
			if destination_set {
				user_error("h2odin: -destination: specified more than once")
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
			parsed_destination, destination_ok := parse_output_destination(value)
			if !destination_ok {
				user_errorf("h2odin: -destination: unknown value %q (want config or stdout)", value)
				return {}, false
			}
			destination = parsed_destination
			destination_set = true
		case strings.has_prefix(arg, "-resource-dir:"), strings.has_prefix(arg, "--resource-dir:"):
			if resource_dir != "" {
				user_error("h2odin: -resource-dir: specified more than once")
				return {}, false
			}
			prefix_len := len("-resource-dir:")
			if strings.has_prefix(arg, "--resource-dir:") {
				prefix_len = len("--resource-dir:")
			}
			resource_dir = arg[prefix_len:]
			if resource_dir == "" {
				user_error("h2odin: -resource-dir: requires a path")
				return {}, false
			}
		case strings.has_prefix(arg, "-"):
			user_errorf("h2odin: unknown argument %q", arg)
			return {}, false
		case:
			// Positional: project directory containing H2Odin.lua.
			if project_dir != "" {
				user_errorf("h2odin: unexpected argument %q (only one project directory is accepted)", arg)
				return {}, false
			}
			project_dir = arg
		}
	}

	if quiet && verbose {
		user_error("h2odin: -quiet and -verbose are mutually exclusive")
		return {}, false
	}

	resolved_config_path, config_path_ok := resolve_config_path(config_path, project_dir)
	if !config_path_ok {
		return {}, false
	}

	return Command_Line_Options{config_path = resolved_config_path, destination = destination, quiet = quiet, verbose = verbose, resource_dir = resource_dir},
		true
}

parse_output_destination :: proc(value: string) -> (Output_Destination, bool) {
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
		user_error("h2odin: pass either a project directory or -config:, not both")
		return "", false
	}
	if config_path != "" {
		return config_path, true
	}
	if project_dir == "" {
		user_error("h2odin: pass a project directory (containing H2Odin.lua) or -config:path")
		return "", false
	}
	if !os.exists(project_dir) {
		user_errorf("h2odin: project directory %q does not exist", project_dir)
		return "", false
	}
	if !os.is_dir(project_dir) {
		user_errorf("h2odin: %q is not a directory (use -config: for a Lua file path)", project_dir)
		return "", false
	}
	joined_path, join_error := filepath.join({project_dir, DEFAULT_CONFIG_NAME})
	if join_error != nil {
		user_errorf("h2odin: cannot join config path under %q: %v", project_dir, join_error)
		return "", false
	}
	if !os.exists(joined_path) {
		user_errorf("h2odin: no %s in %q (create one or pass -config:path)", DEFAULT_CONFIG_NAME, project_dir)
		return "", false
	}
	if !os.is_file(joined_path) {
		user_errorf("h2odin: %q is not a file", joined_path)
		return "", false
	}
	return joined_path, true
}

usage :: proc() -> ! {
	fmt.eprintln("usage: h2odin <project-dir> [options]")
	fmt.eprintln("       h2odin -config:file.lua [options]")
	fmt.eprintln("")
	fmt.eprintln("  <project-dir>         directory containing H2Odin.lua (common case)")
	fmt.eprintln("  -config:path          explicit Lua config path (when not using H2Odin.lua)")
	fmt.eprintln("  -destination:dest     where to write bindings: config (default) or stdout")
	fmt.eprintln("  -d:dest               short for -destination")
	fmt.eprintln("  -quiet, -q            stderr: errors only (default: summary of hints/warnings/errors)")
	fmt.eprintln("  -verbose, -v          provenance + info diags + every diagnostic site + guidance")
	fmt.eprintln("  -resource-dir:path    override clang builtin-header resource directory")
	fmt.eprintln("  -help, -h             show this help")
	fmt.eprintln("")
	fmt.eprintln("By default, bindings are written under config.output_folder.")
	fmt.eprintln("Use -destination:stdout to print a single merged unit to stdout.")
	os.exit(2)
}
