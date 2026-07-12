package h2odin

import vmem "core:mem/virtual"
import "core:strings"
import "core:testing"

@(test)
test_calling_conv_odin_spelling_supported :: proc(t: ^testing.T) {
	cases := [?]struct {
		cc:       Calling_Conv,
		spelling: string,
	}{{.Default, "c"}, {.C, "c"}, {.Stdcall, "stdcall"}, {.Fastcall, "fastcall"}, {.Win64, "win64"}, {.Sys_V, "sysv"}}
	for c in cases {
		spelling, ok := calling_conv_odin_spelling(c.cc)
		testing.expectf(t, ok, "expected supported spelling for %v", c.cc)
		testing.expect_value(t, spelling, c.spelling)
	}
}

@(test)
test_calling_conv_odin_spelling_unsupported :: proc(t: ^testing.T) {
	unsupported := []Calling_Conv{.Thiscall, .Vectorcall, .Other, .Unknown}
	for cc in unsupported {
		spelling, ok := calling_conv_odin_spelling(cc)
		testing.expectf(t, !ok, "expected unsupported for %v", cc)
		// Fallback is still "c" so emission stays parseable; diagnostic fails the run.
		testing.expect_value(t, spelling, "c")
	}
}

@(test)
test_emit_func_writes_non_c_calling_convention :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)
	old := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old

	ir: IR
	ir_init(&ir)
	void_ty := ir_builtin_type(&ir, .Void)

	b: strings.Builder
	imports: Emit_Imports
	emit_func(&b, &ir, Func_Decl{name = "plain", return_type = void_ty, calling_conv = .C}, false, &imports)
	emit_func(&b, &ir, Func_Decl{name = "std", return_type = void_ty, calling_conv = .Stdcall}, false, &imports)
	emit_func(&b, &ir, Func_Decl{name = "fast", return_type = void_ty, calling_conv = .Fastcall}, false, &imports)
	text := strings.to_string(b)

	testing.expect(t, strings.contains(text, "plain :: proc("))
	testing.expect(t, !strings.contains(text, "plain :: proc \"c\""))
	testing.expect(t, strings.contains(text, "std :: proc \"stdcall\" ("))
	testing.expect(t, strings.contains(text, "fast :: proc \"fastcall\" ("))
}

@(test)
test_write_type_proc_uses_captured_calling_convention :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)
	old := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old

	ir: IR
	ir_init(&ir)
	void_ty := ir_builtin_type(&ir, .Void)
	stdcall_proc := ir_add_type(&ir, Type_Info{variant = Type_Proc{return_type = void_ty, calling_conv = .Stdcall}})
	fast_proc := ir_add_type(&ir, Type_Info{variant = Type_Proc{return_type = void_ty, calling_conv = .Fastcall}})
	c_proc := ir_add_type(&ir, Type_Info{variant = Type_Proc{return_type = void_ty, calling_conv = .C}})

	b: strings.Builder
	imports: Emit_Imports
	write_type(&b, &ir, stdcall_proc, 0, false, &imports)
	strings.write_string(&b, "\n")
	write_type(&b, &ir, fast_proc, 0, false, &imports)
	strings.write_string(&b, "\n")
	write_type(&b, &ir, c_proc, 0, false, &imports)
	text := strings.to_string(b)

	testing.expect(t, strings.contains(text, "proc \"stdcall\" ()"))
	testing.expect(t, strings.contains(text, "proc \"fastcall\" ()"))
	testing.expect(t, strings.contains(text, "proc \"c\" ()"))
}

@(test)
test_report_unsupported_calling_conventions :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)
	old := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old

	ir: IR
	ir_init(&ir)
	void_ty := ir_builtin_type(&ir, .Void)
	// Live (in order) unsupported func.
	ir_add_func(&ir, Func_Decl{name = "vec", return_type = void_ty, calling_conv = .Vectorcall})
	// Live typedef whose aliased type is a pointer to an unsupported proc type.
	thiscall_proc := ir_add_type(&ir, Type_Info{variant = Type_Proc{return_type = void_ty, calling_conv = .Thiscall}})
	ptr := ir_add_type(&ir, Type_Info{variant = Type_Pointer{pointee = thiscall_proc}})
	ir_add_typedef(&ir, Typedef_Decl{name = "This_Cb", aliased = ptr})
	// Filtered-out unsupported func: still in the pool, not in order.
	ir_add_func(&ir, Func_Decl{name = "dead_vec", return_type = void_ty, calling_conv = .Vectorcall})
	dead_index := u32(len(ir.funcs) - 1)
	// Drop dead from order (simulate symbols.remove).
	keep: [dynamic]Decl_Ref
	for ref in ir.order {
		if ref.kind == .Func && ref.index == dead_index {
			continue
		}
		append(&keep, ref)
	}
	clear(&ir.order)
	for ref in keep {
		append(&ir.order, ref)
	}

	report_unsupported_calling_conventions(&ir)
	// vec + This_Cb's procedure type; dead_vec must not contribute.
	testing.expect_value(t, len(ir.diagnostics), 2)
	for d in ir.diagnostics {
		testing.expect_value(t, d.category, Diag_Category.Unsupported_Calling_Conv)
	}
	testing.expect(t, strings.contains(ir.diagnostics[0].message, "vec"))
	testing.expect(t, strings.contains(ir.diagnostics[0].message, "vectorcall"))
	testing.expect(t, !strings.contains(ir.diagnostics[0].message, "dead_vec"))
	testing.expect(t, !strings.contains(ir.diagnostics[1].message, "dead_vec"))
}
