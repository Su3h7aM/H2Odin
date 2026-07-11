-- Self-host generation config for libclang (Milestone 13, spec 0002).
--
-- H2Odin generates the libclang bindings its own Extraction stage imports.
-- Generated Odin lives at this package root (import path vendored:libclang).
-- Bootstrap is generation-over-generation: build/h2odin (linked against the
-- checked-in package) regenerates these files in place via make regen-libclang.
--
-- Layout (next to this config):
--
--   headers/*.h   pinned C API (flat under headers/; #include "Foo.h" form
--                 so -I headers finds the pin — not system /usr/include)
--   *.odin        generated package (output_folder = ".")
--
-- Naming follows the Odin convention (examples wiki): Ada_Case types and enum
-- values, snake_case procs/fields, SCREAMING_SNAKE constants. The package name
-- carries the namespace, so call sites read `clang.create_index(...)`,
-- `clang.Translation_Unit`. Affixes are stripped so:
--
--   clang_createIndex        -> create_index      (proc:  strip clang_, recase)
--   CXTranslationUnit        -> Translation_Unit  (type:  strip CX,   recase)
--   CXCursor_FunctionDecl    -> .Function_Decl    (value: strip CXCursor_)
--   CINDEX_VERSION_MAJOR     -> VERSION_MAJOR     (const: strip CINDEX_)
--
-- C libclang uses camelCase after the clang_ prefix, so after snake_case the
-- Odin name no longer equals the C suffix. The generator therefore emits
-- @(link_name = "clang_…") per proc (no foreign.link_prefix — that only
-- helps when C name == prefix + Odin name, as with sqlite3_/fff_).
--
-- This is the Unix build (`system:clang`). Windows multi-lib foreign import
-- parity (spec 0002 out-of-scope) stays deferred.
--
-- Every public header is listed in inputs so multi-header "ours" capture
-- keeps sibling typedef names (Index.h → CXString.h, …).

local h2o = require "h2odin"

local config = h2o.config()
config.package = "clang"
config.type_mode = "idiomatic"
config.comments = false

-- Relative to this config file's directory (vendored/libclang/).
config.preprocess.include_paths = { "headers" }

-- Paths relative to the config dir. Per-header layout emits one .odin file
-- per input (bindings/Index.odin, bindings/CXString.odin, …).
config.inputs = {
	"headers/Index.h",
	"headers/CXString.h",
	"headers/CXDiagnostic.h",
	"headers/CXErrorCode.h",
	"headers/CXFile.h",
	"headers/CXSourceLocation.h",
	"headers/BuildSystem.h",
	"headers/Documentation.h",
	"headers/Rewrite.h",
	"headers/CXCompilationDatabase.h",
	"headers/FatalErrorHandler.h",
	-- Platform.h / ExternC.h are macros-only; listing them keeps any future
	-- decls "ours" and matches the include graph without binding noise.
	"headers/Platform.h",
	"headers/ExternC.h",
}

-- Generated package is the package root (vendored:libclang). One Odin file
-- per configured input header.
config.output_folder = "."
config.output.layout = "per_header"

config.foreign.import_lib = "clang"

-- Opaque handles (spec 0005): typedefs of pointers to incomplete *Impl
-- records emit `distinct rawptr` automatically and the *Impl records are
-- dropped. void* handles stay plain rawptr unless listed here — match the
-- hand binding's type safety for Index / Client_Data.
config.types.distinct = {
	"CXIndex",
	"CXClientData",
}

-- Quality pass (M13): curate what Extraction actually calls. Full-API
-- pointer_lowering_guess cleanup is polish and stays deferred (spec 0002).
--
-- CXTranslationUnit_Flags is a mask enum (powers of two + a zero "None").
-- Drop None (empty bit_set is the zero value), log2 the rest into a bit_set
-- so call sites can write `{.Detailed_Preprocessing_Record}` like the hand
-- binding. The backing enum is renamed to the singular form below.
config.enums.member = function(member)
	if member.name == "CXTranslationUnit_None" then
		return { remove = true }
	end
	return nil
end
config.enums.bit_sets = {
	h2o.enum.bit_set {
		enum = "CXTranslationUnit_Flags",
		name = "Translation_Unit_Flags",
		mode = "log2",
	},
}

-- Keys are C names (procs.params runs before naming). Type spellings are final
-- Odin text emitted as-is.
--
-- - command_line_args / Tokens: multipointer shape matching Karl + extract's
--   `raw_data(...)` / `[^]Token` call sites (default lowering is ^T).
-- - options: C types this as unsigned; promote to the bit_set above so extract
--   can pass a flag set without a cast.
config.procs.params = {
	["clang_parseTranslationUnit.command_line_args"] = { type = "[^]cstring" },
	["clang_parseTranslationUnit.options"] = { type = "Translation_Unit_Flags" },
	["clang_tokenize.Tokens"] = { type = "^[^]Token" },
	["clang_disposeTokens.Tokens"] = { type = "[^]Token" },
}

config.naming = h2o.naming.odin {
	strip_prefixes = {
		proc = "clang_",
		type = "CX",
		const = "CINDEX_",
		-- Enum member prefixes are non-uniform: the member family prefix often
		-- differs from the enum type name (CXError_ on enum CXErrorCode; CX_BO_
		-- on enum CX_BinaryOperatorKind). strip_prefix_enum is a single global
		-- first-match list, so this is sorted LONGEST-FIRST to stop a short
		-- prefix (e.g. CX_) stealing a longer one (CX_SC_, CX_BO_,
		-- CXCursor_ExceptionSpecificationKind_).
		enum_value = {
			"CXCursor_ExceptionSpecificationKind_",
			"CXTemplateArgumentKind_",
			"CXSaveTranslationUnit_",
			"CXObjCDeclQualifier_",
			"CXCompletionContext_",
			"CXObjCPropertyAttr_",
			"CXIdxObjCContainer_",
			"CXTypeNullability_",
			"CXTypeLayoutError_",
			"CXTUResourceUsage_",
			"CXTranslationUnit_",
			"CXCompletionChunk_",
			"CXPrintingPolicy_",
			"CXBinaryOperator_",
			"CXUnaryOperator_",
			"CXIdxEntityLang_",
			"CXRefQualifier_",
			"CXIdxEntityRef_",
			"CXCodeComplete_",
			"CXAvailability_",
			"CXIdxDeclFlag_",
			"CXCallingConv_",
			"CXVisibility_",
			"CXSymbolRole_",
			"CXDiagnostic_",
			"CXChildVisit_",
			"CXSaveError_",
			"CXNameRange_",
			"CXIdxEntity_",
			"CXGlobalOpt_",
			"CXLoadDiag_",
			"CXLanguage_",
			"CXIndexOpt_",
			"CXReparse_",
			"CXLinkage_",
			"CXIdxAttr_",
			"CXResult_",
			"CXCursor_",
			"CXChoice_",
			"CXVisit_",
			"CXToken_",
			"CXError_",
			"CXType_",
			"CXEval_",
			"CXTLS_",
			"CX_SC_",
			"CX_BO_",
			"CX_",
		},
	},
	-- Tokenizer vocabulary for ambiguous C identifiers (USR, PCH, …).
	-- Surface → lower form; reduces naming_ambiguity noise on the first pass.
	known_tokens = {
		USR = "usr",
		PCH = "pch",
		TU = "tu",
		CX = "cx",
		ObjC = "objc",
		CPlusPlus = "cplusplus",
		Cxx = "cxx",
		GCC = "gcc",
		API = "api",
		AST = "ast",
		IB = "ib",
		UUID = "uuid",
	},
	-- Two distinct C enums collide after the CX strip: CXBinaryOperatorKind
	-- (members CXBinaryOperator_*, the current API) and the deprecated
	-- CX_BinaryOperatorKind (members CX_BO_*, returned only by the legacy
	-- clang_Cursor_getBinaryOpcode). Keep the current enum's natural name and
	-- qualify the deprecated one.
	--
	-- CXTranslationUnit_Flags → singular backing enum for the bit_set above
	-- (bit_set keeps the collective name Translation_Unit_Flags).
	overrides = {
		CX_BinaryOperatorKind = "Legacy_Binary_Operator_Kind",
		CXTranslationUnit_Flags = "Translation_Unit_Flag",
	},
	-- https://github.com/odin-lang/examples/wiki/Naming-and-style-convention
	override = function(sym)
		if sym.kind == "proc" or sym.kind == "var" or sym.kind == "field" or sym.kind == "param" then
			return h2o.naming.snake_case(sym.default)
		end
		if sym.kind == "type" or sym.kind == "enum_value" then
			return h2o.naming.ada_case(sym.default)
		end
		-- const: keep stripped C form (already SCREAMING_SNAKE for the macros).
		return nil
	end,
}

return config
