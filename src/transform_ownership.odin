package h2odin

import "core:path/filepath"

// Derive declaration homes from configured roots and the raw inclusion
// provenance copied by Extraction. Roots keep their own units. Unlisted
// non-system headers fold to the nearest root on their inclusion chain when
// they lie beneath any configured root directory. First root in inputs order
// wins a diamond; later competing reaches produce one diagnostic.
assign_header_ownership :: proc(ir: ^IR) {
	if len(ir.header_reaches) == 0 {
		return // synthetic unit tests may provide homes directly
	}

	root_files := make(map[string]Input_Header_Handle, context.temp_allocator)
	root_dirs := make([]string, len(ir.input_headers), context.temp_allocator)
	owners := make(map[string]Input_Header_Handle, context.temp_allocator)
	for i in 1 ..< len(ir.input_headers) {
		home := Input_Header_Handle(i)
		path := normalize_source_path(ir.input_headers[i], context.temp_allocator)
		root_files[path] = home
		root_dirs[i] = filepath.dir(path)
		owners[path] = home
	}

	conflicts := make(map[string]bool, context.temp_allocator)
	for reach in ir.header_reaches {
		if root_home, is_root := root_files[reach.path]; is_root {
			owners[reach.path] = root_home
			continue
		}

		candidate: Input_Header_Handle
		for including_path in reach.inclusion_chain {
			if root_home, is_root := root_files[including_path]; is_root {
				candidate = root_home
				break
			}
		}
		if candidate == 0 || !header_is_under_any_root(reach.path, root_dirs) {
			continue
		}

		if existing, claimed := owners[reach.path]; claimed {
			if existing != candidate && !conflicts[reach.path] {
				conflicts[reach.path] = true
			}
			if int(candidate) < int(existing) {
				owners[reach.path] = candidate
			}
			continue
		}
		owners[reach.path] = candidate
	}

	reported := make(map[string]bool, context.temp_allocator)
	for reach in ir.header_reaches {
		if conflicts[reach.path] && !reported[reach.path] {
			reported[reach.path] = true
			winner := owners[reach.path]
			ir_diag(
				ir,
				.Header_Ownership_Conflict,
				"project header %q is reachable from multiple roots; assigned to first input root %q",
				reach.path,
				ir_input_header_path(ir, winner),
			)
		}
	}

	for &decl in ir.funcs {
		decl.home = owners[decl.source_path]
	}
	for &decl in ir.vars {
		decl.home = owners[decl.source_path]
	}
	for &decl in ir.macros {
		decl.home = owners[decl.source_path]
	}
	for &decl in ir.records {
		if decl.is_foreign {
			continue
		}
		decl.home = owners[decl.source_path]
	}
	for &decl in ir.enums {
		if decl.is_foreign {
			continue
		}
		decl.home = owners[decl.source_path]
	}
	for &decl in ir.typedefs {
		if decl.is_foreign {
			continue
		}
		decl.home = owners[decl.source_path]
	}

	for occurrence in ir.decl_occurrences {
		candidate := owners[occurrence.path]
		if candidate == 0 {
			continue
		}
		existing := ir_decl_home(ir, occurrence.decl)
		if existing == 0 || int(candidate) < int(existing) {
			ir_set_decl_home(ir, occurrence.decl, candidate)
		}
	}

	for &decl in ir.records {
		decl.is_unowned = !decl.is_foreign && decl.source_path != "" && decl.home == 0
	}
	for &decl in ir.enums {
		decl.is_unowned = !decl.is_foreign && decl.source_path != "" && decl.home == 0
	}
	for &decl in ir.typedefs {
		decl.is_unowned = !decl.is_foreign && decl.source_path != "" && decl.home == 0
	}

	for &ref in ir.order {
		if ref.kind != .Invalid && ir_decl_home(ir, ref) == 0 {
			ref.kind = .Invalid
		}
	}
}

header_is_under_any_root :: proc(path: string, root_dirs: []string) -> bool {
	for i in 1 ..< len(root_dirs) {
		if path_is_under(path, root_dirs[i]) {
			return true
		}
	}
	return false
}
