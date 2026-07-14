-- Validation example: ggml (https://github.com/ggml-org/ggml).
--
-- Exercises: tensor/ML C API, multi-header (ggml + alloc + backend + cpu + gguf),
-- dual ggml_/gguf_ prefixes, opaque contexts, large enums, function pointers.
--
-- Honest dual-prefix strategy: strip ggml_/GGML_ as usual; keep gguf_/GGUF_
-- Odin names so the two libraries do not collide after strip. Procs that share
-- a C tag/type name (e.g. ggml_backend_dev_type enum + function) get kind-aware
-- renames. Incomplete tag spellings that survive without a typedef alias are
-- mapped onto the corresponding *_t handles.

local h2o = require "h2odin"

local config = h2o.config()
config.package = "ggml"
config.type_mode = "idiomatic"

config.inputs = {
	"include/ggml.h",
	"include/ggml-alloc.h",
	"include/ggml-backend.h",
	"include/ggml-cpu.h",
	"include/gguf.h",
}
config.preprocess.include_paths = { "include" }
config.output_folder = "."

config.foreign.import_lib = "ggml"
-- Primary C prefix; gguf_* keep @(link_name) when their Odin name differs.
config.foreign.link_prefix = "ggml_"

config.naming = {
	strip_prefixes = {
		-- Only ggml_ is stripped automatically. gguf_ is retained via override
		-- so dual-prefix short names do not collide (type, free, context, …).
		proc = { "ggml_" },
		type = { "ggml_" },
		const = { "GGML_" },
		enum_value = { "GGML_", "GGUF_" },
	},
	overrides = {
		-- Incomplete tags referenced without the *_t typedef spelling.
		ggml_backend_buffer = "backend_buffer_t",
		ggml_threadpool = "threadpool_t",
	},
	override = function(sym)
		-- Keep gguf API under its full C names (minus const/enum_value strips above).
		if h2o.str.has_prefix(sym.name, "gguf_") then
			return sym.name
		end
		if h2o.str.has_prefix(sym.name, "GGUF_") and sym.kind ~= "enum_value" then
			return sym.name
		end

		-- C tag/function share one spelling; disambiguate the procedure.
		if sym.kind == "proc" and sym.name == "ggml_backend_dev_type" then
			return "backend_dev_get_type"
		end
		if sym.kind == "proc" and sym.name == "ggml_backend_graph_copy" then
			return "backend_graph_copy_create"
		end

		-- Parameter shadows the cgraph type in graph_dump_dot.
		if sym.kind == "param" and sym.name == "cgraph" then
			return "cgraph_"
		end
		-- Odin rejects `proc(tensor: ^tensor) -> ^tensor` — the param name
		-- shadows the type for the result. Same pattern for other self-typed
		-- params that also appear as results in this API.
		if sym.kind == "param" and (sym.name == "tensor" or sym.name == "src" or sym.name == "dst") then
			-- Only force rename when the default already matches a package type
			-- after strip (sym.default is post-affix); keep short names when safe.
			if sym.name == "tensor" then
				return "tensor_"
			end
		end
	end,
}

-- Reference rewrites for incomplete tag uses that still surface as C names
-- after opaque collapse (pool-only records not renamed via order).
config.types.map = {
	ggml_backend_buffer = "backend_buffer_t",
	ggml_threadpool = "threadpool_t",
}

-- Representative multipointers (array + length pairs in the public API).
config.procs.params = {
	["ggml_backend_sched_new.backends"] = { pointer = "multi" },
	["ggml_backend_sched_new.bufts"] = { pointer = "multi" },
	["ggml_gallocr_new_n.bufts"] = { pointer = "multi" },
}

return config
