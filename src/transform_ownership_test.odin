package h2odin

import vmem "core:mem/virtual"
import "core:testing"

@(test)
test_header_ownership_uses_any_root_subtree_then_nearest_chain_root :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)
	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	_ = ir_register_input_headers(&ir, {"/public/a.h", "/public/sub/b.h"})
	append(&ir.header_reaches, Header_Reach{path = "/public/common.h", inclusion_chain = {"/public/sub/b.h", "/public/a.h"}})
	ir_add_func(&ir, Func_Decl{name = "from_common", return_type = ir_builtin_type(&ir, .Void), source_path = "/public/common.h"})

	assign_header_ownership(&ir)

	testing.expect_value(t, ir.funcs[0].home, Input_Header_Handle(2))
	testing.expect_value(t, ir.order[0].kind, Decl_Kind.Func)
}

@(test)
test_diamond_owner_uses_input_order_not_tu_reach_order :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)
	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	_ = ir_register_input_headers(&ir, {"/public/a.h", "/public/c.h", "/public/b.h"})
	append(&ir.header_reaches, Header_Reach{path = "/public/shared.h", inclusion_chain = {"/public/b.h", "/public/a.h"}})
	append(&ir.header_reaches, Header_Reach{path = "/public/shared.h", inclusion_chain = {"/public/c.h"}})
	ir_add_func(&ir, Func_Decl{name = "shared", return_type = ir_builtin_type(&ir, .Void), source_path = "/public/shared.h"})

	assign_header_ownership(&ir)

	testing.expect_value(t, ir.funcs[0].home, Input_Header_Handle(2))
	testing.expect_value(t, len(ir.diagnostics), 1)
	if len(ir.diagnostics) == 1 {
		testing.expect_value(t, ir.diagnostics[0].category, Diag_Category.Header_Ownership_Conflict)
	}
}

@(test)
test_owned_declaration_occurrence_beats_first_external_occurrence :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)
	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	_ = ir_register_input_headers(&ir, {"/public/root.h"})
	append(&ir.header_reaches, Header_Reach{path = "/public/root.h"})
	ir_add_func(&ir, Func_Decl{name = "redeclared", return_type = ir_builtin_type(&ir, .Void), source_path = "/external/api.h"})
	append(&ir.decl_occurrences, Decl_Occurrence{decl = ir.order[0], path = "/public/root.h"})

	assign_header_ownership(&ir)

	testing.expect_value(t, ir.funcs[0].home, Input_Header_Handle(1))
	testing.expect_value(t, ir.order[0].kind, Decl_Kind.Func)
}

@(test)
test_promote_reuses_unique_ownership_tombstone :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)
	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	handle := ir_create_record(&ir, Record_Decl{name = "Stub", is_complete = false})
	ir_promote_record(&ir, handle)
	testing.expect_value(t, len(ir.order), 1)
	testing.expect_value(t, ir.order[0].kind, Decl_Kind.Record)

	// Ownership tombstone: leave the slot but mark Invalid.
	ir.order[0].kind = .Invalid
	ir_promote_record(&ir, handle)

	// Reuse the same slot rather than appending a duplicate.
	testing.expect_value(t, len(ir.order), 1)
	testing.expect_value(t, ir.order[0].kind, Decl_Kind.Record)
	testing.expect_value(t, ir.order[0].index, u32(handle))
}
