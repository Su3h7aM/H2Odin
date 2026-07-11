package h2odin

import "core:strings"

// Foreign types — those a system header declares, not the library's own
// headers — are captured pool-only by Extraction. Transformation then either:
//
//   1. Maps a known system type to its Odin defining package (spec 0010):
//      POSIX names to core:sys/posix (sockaddr → posix.sockaddr), ISO C
//      library names to core:c/libc (time_t → libc.time_t). One spelling in
//      both type modes — these Odin types are `distinct` and OS-width
//      specific, so peeling them to fixed-width integers would break interop.
//   2. Promotes an incomplete stub so pointer references spell `^Name`, or
//   3. Diagnoses by-value use of an unmapped foreign type (layout unavailable).
//
// Config wins over the built-in map: a name in types.map / types.overrides is
// left for apply_type_rewrites. Library-specific and Windows spellings stay in
// config for now (spec 0010, decision 8).

Foreign_Type_Entry :: struct {
	c_name:    string,
	spelling:  string,
	// Scalars are width-guarded against the Odin type's size before mapping
	// (spec 0010, decision 6); compounds rely on the allowlist plus Odin's
	// own per-OS layout, since foreign layouts are deliberately not captured.
	is_scalar: bool,
}

// The built-in map (spec 0010). Every spelling is verified to exist as an
// exported name in the supported Odin version — `sockaddr_dl` and `ip_mreq`,
// for instance, are *not* exported by core:sys/posix and must not appear here.
// Grow this from validation-corpus needs, not by inventorying the packages.
FOREIGN_TYPE_MAP :: [?]Foreign_Type_Entry {
	// Scalars: POSIX-defined.
	{c_name = "dev_t", spelling = "posix.dev_t", is_scalar = true},
	{c_name = "blkcnt_t", spelling = "posix.blkcnt_t", is_scalar = true},
	{c_name = "blksize_t", spelling = "posix.blksize_t", is_scalar = true},
	{c_name = "fsblkcnt_t", spelling = "posix.fsblkcnt_t", is_scalar = true},
	{c_name = "off_t", spelling = "posix.off_t", is_scalar = true},
	{c_name = "gid_t", spelling = "posix.gid_t", is_scalar = true},
	{c_name = "pid_t", spelling = "posix.pid_t", is_scalar = true},
	{c_name = "clockid_t", spelling = "posix.clockid_t", is_scalar = true},
	// Scalars: ISO C library-defined (posix only re-exports these).
	{c_name = "time_t", spelling = "libc.time_t", is_scalar = true},
	{c_name = "clock_t", spelling = "libc.clock_t", is_scalar = true},
	// Compounds: POSIX-defined.
	{c_name = "sockaddr", spelling = "posix.sockaddr"},
	{c_name = "sockaddr_storage", spelling = "posix.sockaddr_storage"},
	{c_name = "sockaddr_in", spelling = "posix.sockaddr_in"},
	{c_name = "sockaddr_in6", spelling = "posix.sockaddr_in6"},
	{c_name = "sockaddr_un", spelling = "posix.sockaddr_un"},
	{c_name = "in_addr", spelling = "posix.in_addr"},
	{c_name = "in6_addr", spelling = "posix.in6_addr"},
	{c_name = "addrinfo", spelling = "posix.addrinfo"},
	{c_name = "fd_set", spelling = "posix.fd_set"},
	{c_name = "timeval", spelling = "posix.timeval"},
	{c_name = "iovec", spelling = "posix.iovec"},
	{c_name = "msghdr", spelling = "posix.msghdr"},
	{c_name = "cmsghdr", spelling = "posix.cmsghdr"},
	{c_name = "pollfd", spelling = "posix.pollfd"},
	{c_name = "linger", spelling = "posix.linger"},
	{c_name = "ipv6_mreq", spelling = "posix.ipv6_mreq"},
	// Compounds: ISO C library-defined.
	{c_name = "timespec", spelling = "libc.timespec"},
	{c_name = "tm", spelling = "libc.tm"},
}

foreign_type_entry :: proc(name: string) -> (entry: Foreign_Type_Entry, ok: bool) {
	if name == "" {
		return {}, false
	}
	table := FOREIGN_TYPE_MAP
	for e in table {
		if e.c_name == name {
			return e, true
		}
	}
	return {}, false
}

apply_foreign_type_stubs :: proc(ir: ^IR, policy: ^Policy) {
	by_value := make(map[Decl_Handle]bool, context.temp_allocator)
	referenced := make(map[Decl_Handle]bool, context.temp_allocator)
	referrer_home := make(map[Decl_Handle]Input_Header_Handle, context.temp_allocator)

	scan_ordered_type_uses(ir, &by_value, &referenced, &referrer_home)

	for i in 0 ..< len(ir.records) {
		handle := Decl_Handle(i)
		rec := &ir.records[i]
		if !rec.is_foreign || rec.name == "" {
			continue
		}
		if !referenced[handle] {
			continue
		}
		if _, named := config_spelling(policy, rec.name); named {
			// apply_type_rewrites spells the use sites; the foreign record
			// stays unpromoted, so no stub declaration is emitted for it.
			continue
		}

		// Preferred path: known platform type → its Odin defining package.
		if spelling, mapped := platform_spelling(ir, policy, rec.name, 0); mapped {
			rewrite_record_refs_to_spelling(ir, handle, spelling, .Platform_Type)
			// Leave out of order — no local stub; use sites name posix.T.
			continue
		}

		// Incomplete stub: name only, no system fields.
		rec.fields = nil
		rec.is_complete = false
		rec.has_unrepresentable_fields = false
		if home, ok := referrer_home[handle]; ok && home != 0 {
			rec.home = home
		}
		if by_value[handle] {
			ir_diag(
				ir,
				.Unresolved_Type,
				"record %q is defined in a system header but used by value; emitted as incomplete struct {{}} (layout unavailable). Map it with types.map (e.g. to posix.%s) or add its header to config.inputs",
				rec.name,
				rec.name,
			)
		}
		ir_promote_record(ir, handle)
	}

	for i in 0 ..< len(ir.enums) {
		handle := Decl_Handle(i)
		enm := &ir.enums[i]
		if !enm.is_foreign || enm.name == "" {
			continue
		}
		if !referenced_enum(ir, handle) {
			continue
		}
		if _, named := config_spelling(policy, enm.name); named {
			continue // config spells the use sites; emit no stub
		}
		if spelling, mapped := platform_spelling(ir, policy, enm.name, 0); mapped {
			rewrite_enum_refs_to_spelling(ir, handle, spelling, .Platform_Type)
			continue
		}
		enm.members = nil
		if home, ok := referrer_home_for_enum(ir, handle); ok && home != 0 {
			enm.home = home
		}
		ir_diag(
			ir,
			.Unresolved_Type,
			"enum %q is defined in a system header; type name is retained without members. Map it with types.map or add its header to config.inputs",
			enm.name,
		)
		ir_promote_enum(ir, handle)
	}

	resolve_foreign_typedefs(ir, policy)
}

// Every reference to a foreign typedef (one a system header declares) must
// resolve here — the declaration is pool-only, so a
// surviving reference would name a type this package never emits. Two
// outcomes, in precedence order:
//
//   1. The built-in map (or config, which the map pass defers to) knows the
//      name: use sites spell posix.off_t / libc.time_t, keeping the distinct
//      C identity. The declaration stays unemitted — the Odin package that
//      owns the name already declares it.
//   2. Nothing knows it: peel to the underlying type (off_t → c.long), which
//      is what H2Odin has always done. The name is not ours to bind, but the
//      ABI is preserved either way.
resolve_foreign_typedefs :: proc(ir: ^IR, policy: ^Policy) {
	for i in 0 ..< len(ir.typedefs) {
		handle := Decl_Handle(i)
		td := ir.typedefs[i]
		if !td.is_foreign || td.name == "" || td.is_unresolvable {
			continue
		}
		// Config first (spec 0010, decision 5). A foreign typedef is never
		// emitted, so even types.overrides — which keeps *our* typedefs as
		// named aliases — must resolve at the use sites here.
		if spelling, named := config_spelling(policy, td.name); named {
			rewrite_typedef_refs_to_spelling(ir, handle, spelling, .Config_Override)
			continue
		}
		if spelling, mapped := platform_spelling(ir, policy, td.name, td.aliased); mapped {
			rewrite_typedef_refs_to_spelling(ir, handle, spelling, .Platform_Type)
			continue
		}
		peel_typedef_refs(ir, handle)
	}
}

// Replace references to a foreign typedef with the underlying type's own
// variant. Chains converge regardless of visit order: a slot rewritten to
// another foreign typedef's ref is itself rewritten when that decl is
// visited, and a slot whose alias was already peeled copies the peeled form.
peel_typedef_refs :: proc(ir: ^IR, handle: Decl_Handle) {
	td := ir.typedefs[int(handle)]
	if td.aliased == 0 {
		return
	}
	count := len(ir.types)
	for i in 0 ..< count {
		info := ir.types[i]
		ref, is_ref := info.variant.(Type_Typedef_Ref)
		if !is_ref || ref.decl != handle {
			continue
		}
		aliased := ir_type(ir, td.aliased)
		ir.types[i] = Type_Info {
			// The use site's const qualifier survives the peel.
			is_const = info.is_const || aliased.is_const,
			variant  = aliased.variant,
		}
	}
}

// The spelling config gives a type name, if any. types.overrides wins over
// types.map, matching the pass order in transform().
config_spelling :: proc(policy: ^Policy, name: string) -> (spelling: string, ok: bool) {
	if s, named := policy.type_overrides[name]; named {
		return s, true
	}
	if s, named := policy.type_map[name]; named {
		return s, true
	}
	return "", false
}

// The built-in spelling for a foreign C type name, if one applies here.
// Returns not-mapped when config names the type (config wins), when the name
// is not in the map, when the target does not define the Odin type, or when a
// scalar's measured C width disagrees with the Odin type's width on this
// target. `aliased` is the underlying type for typedefs and 0 for tags (which
// carry no scalar width).
platform_spelling :: proc(ir: ^IR, policy: ^Policy, name: string, aliased: Type_Handle) -> (spelling: string, ok: bool) {
	if _, in_config := config_spelling(policy, name); in_config {
		return "", false
	}
	entry, known := foreign_type_entry(name)
	if !known {
		return "", false
	}
	if !platform_spelling_supported(entry.spelling) {
		// e.g. posix.* on a Windows target: naming it would emit a type that
		// does not exist. Fall through to the stub/diagnostic path.
		ir_diag(
			ir,
			.Unresolved_Type,
			"foreign type %q would map to %s, which this target does not define; map it with types.map (e.g. a win32.* spelling)",
			name,
			entry.spelling,
		)
		return "", false
	}
	if !entry.is_scalar {
		// Compounds are not width-guarded: foreign layouts are deliberately
		// not captured, and Odin's package owns the per-OS layout. The
		// verified allowlist is what keeps these honest.
		return entry.spelling, true
	}

	// Width guard: never substitute a type whose width does not match on this
	// target (libc.time_t is unconditionally 64-bit; a 32-bit C time_t is a
	// different type). Diagnose and leave the C spelling alone.
	odin_size := platform_type_size(entry.spelling)
	measured := type_measured_size(ir, aliased)
	if odin_size <= 0 {
		ir_diag(
			ir,
			.Unresolved_Type,
			"foreign type %q maps to %s, whose width is unknown on this target; keeping the C spelling. Map it with types.map",
			name,
			entry.spelling,
		)
		return "", false
	}
	if measured > 0 && measured != odin_size {
		ir_diag(
			ir,
			.Unresolved_Type,
			"foreign type %q measures %d bytes but %s is %d bytes on this target; keeping the C spelling. Map it with types.map",
			name,
			measured,
			entry.spelling,
			odin_size,
		)
		return "", false
	}
	return entry.spelling, true
}

// Size of a scalar type as libclang measured it on the generation target.
// Peels typedefs and already-substituted leaves. -1 when there is no scalar
// width to compare (never a reason to map — the caller keeps the C spelling).
type_measured_size :: proc(ir: ^IR, handle: Type_Handle) -> int {
	cur := handle
	// Bound the peel so a pathological typedef cycle cannot hang.
	for _ in 0 ..< 32 {
		if cur == 0 {
			return -1
		}
		#partial switch variant in ir_type(ir, cur).variant {
		case Type_Builtin:
			return variant.size
		case Type_Std:
			return variant.size
		case Type_Typedef_Ref:
			td := ir.typedefs[variant.decl]
			if td.is_unresolvable {
				return -1
			}
			cur = td.aliased
		case Type_Idiomatic_Leaf:
			cur = variant.original
		case:
			return -1
		}
	}
	return -1
}

// Replace every Type_Record_Ref to `handle` with an idiomatic leaf spelling.
rewrite_record_refs_to_spelling :: proc(ir: ^IR, handle: Decl_Handle, spelling: string, reason: Idiomatic_Reason) {
	count := len(ir.types)
	for i in 0 ..< count {
		info := ir.types[i]
		rec, is_rec := info.variant.(Type_Record_Ref)
		if !is_rec || rec.decl != handle {
			continue
		}
		original := ir_add_type(ir, info)
		ir.types[i] = Type_Info {
			is_const = info.is_const,
			variant = Type_Idiomatic_Leaf{original = original, spelling = strings.clone(spelling), reason = reason},
		}
	}
}

rewrite_enum_refs_to_spelling :: proc(ir: ^IR, handle: Decl_Handle, spelling: string, reason: Idiomatic_Reason) {
	count := len(ir.types)
	for i in 0 ..< count {
		info := ir.types[i]
		en, is_en := info.variant.(Type_Enum_Ref)
		if !is_en || en.decl != handle {
			continue
		}
		original := ir_add_type(ir, info)
		ir.types[i] = Type_Info {
			is_const = info.is_const,
			variant = Type_Idiomatic_Leaf{original = original, spelling = strings.clone(spelling), reason = reason},
		}
	}
}

rewrite_typedef_refs_to_spelling :: proc(ir: ^IR, handle: Decl_Handle, spelling: string, reason: Idiomatic_Reason) {
	count := len(ir.types)
	for i in 0 ..< count {
		info := ir.types[i]
		td, is_td := info.variant.(Type_Typedef_Ref)
		if !is_td || td.decl != handle {
			continue
		}
		original := ir_add_type(ir, info)
		ir.types[i] = Type_Info {
			is_const = info.is_const,
			variant = Type_Idiomatic_Leaf{original = original, spelling = strings.clone(spelling), reason = reason},
		}
	}
}

scan_ordered_type_uses :: proc(
	ir: ^IR,
	by_value: ^map[Decl_Handle]bool,
	referenced: ^map[Decl_Handle]bool,
	referrer_home: ^map[Decl_Handle]Input_Header_Handle,
) {
	for ref in ir.order {
		home := ir_decl_home(ir, ref)
		switch ref.kind {
		case .Invalid:
		case .Func:
			fn := ir.funcs[ref.index]
			scan_type_use(ir, fn.return_type, false, home, by_value, referenced, referrer_home)
			for p in fn.params {
				scan_type_use(ir, p.type, false, home, by_value, referenced, referrer_home)
			}
		case .Record:
			rec := ir.records[ref.index]
			for f in rec.fields {
				scan_type_use(ir, f.type, true, home, by_value, referenced, referrer_home)
			}
		case .Enum:
		case .Typedef:
			td := ir.typedefs[ref.index]
			scan_type_use(ir, td.aliased, true, home, by_value, referenced, referrer_home)
		case .Var:
			v := ir.vars[ref.index]
			scan_type_use(ir, v.type, true, home, by_value, referenced, referrer_home)
		case .Macro, .Bit_Set:
		}
	}
}

scan_type_use :: proc(
	ir: ^IR,
	handle: Type_Handle,
	surface_by_value: bool,
	home: Input_Header_Handle,
	by_value: ^map[Decl_Handle]bool,
	referenced: ^map[Decl_Handle]bool,
	referrer_home: ^map[Decl_Handle]Input_Header_Handle,
) {
	if handle == 0 {
		return
	}
	info := ir_type(ir, handle)
	#partial switch v in info.variant {
	case Type_Record_Ref:
		referenced^[v.decl] = true
		if surface_by_value {
			by_value^[v.decl] = true
		}
		if home != 0 {
			if _, has := referrer_home^[v.decl]; !has {
				referrer_home^[v.decl] = home
			}
		}
	case Type_Pointer:
		scan_type_use(ir, v.pointee, false, home, by_value, referenced, referrer_home)
	case Type_Lowered_Pointer:
		scan_type_use(ir, v.pointee, false, home, by_value, referenced, referrer_home)
	case Type_Array:
		scan_type_use(ir, v.element, surface_by_value, home, by_value, referenced, referrer_home)
	case Type_Proc:
		scan_type_use(ir, v.return_type, false, home, by_value, referenced, referrer_home)
		for p in v.params {
			scan_type_use(ir, p.type, false, home, by_value, referenced, referrer_home)
		}
	case Type_Typedef_Ref:
		scan_type_use(ir, ir.typedefs[v.decl].aliased, surface_by_value, home, by_value, referenced, referrer_home)
	case Type_Idiomatic_Leaf:
		scan_type_use(ir, v.original, surface_by_value, home, by_value, referenced, referrer_home)
	}
}

referenced_enum :: proc(ir: ^IR, handle: Decl_Handle) -> bool {
	for ref in ir.order {
		#partial switch ref.kind {
		case .Func:
			fn := ir.funcs[ref.index]
			if type_mentions_enum(ir, fn.return_type, handle) {
				return true
			}
			for p in fn.params {
				if type_mentions_enum(ir, p.type, handle) {
					return true
				}
			}
		case .Record:
			for f in ir.records[ref.index].fields {
				if type_mentions_enum(ir, f.type, handle) {
					return true
				}
			}
		case .Typedef:
			if type_mentions_enum(ir, ir.typedefs[ref.index].aliased, handle) {
				return true
			}
		case .Var:
			if type_mentions_enum(ir, ir.vars[ref.index].type, handle) {
				return true
			}
		}
	}
	return false
}

referrer_home_for_enum :: proc(ir: ^IR, handle: Decl_Handle) -> (Input_Header_Handle, bool) {
	for ref in ir.order {
		home := ir_decl_home(ir, ref)
		if home == 0 {
			continue
		}
		#partial switch ref.kind {
		case .Func:
			fn := ir.funcs[ref.index]
			if type_mentions_enum(ir, fn.return_type, handle) {
				return home, true
			}
			for p in fn.params {
				if type_mentions_enum(ir, p.type, handle) {
					return home, true
				}
			}
		case .Record:
			for f in ir.records[ref.index].fields {
				if type_mentions_enum(ir, f.type, handle) {
					return home, true
				}
			}
		case .Typedef:
			if type_mentions_enum(ir, ir.typedefs[ref.index].aliased, handle) {
				return home, true
			}
		case .Var:
			if type_mentions_enum(ir, ir.vars[ref.index].type, handle) {
				return home, true
			}
		}
	}
	return 0, false
}

type_mentions_enum :: proc(ir: ^IR, handle: Type_Handle, enum_handle: Decl_Handle) -> bool {
	if handle == 0 {
		return false
	}
	info := ir_type(ir, handle)
	#partial switch v in info.variant {
	case Type_Enum_Ref:
		return v.decl == enum_handle
	case Type_Pointer:
		return type_mentions_enum(ir, v.pointee, enum_handle)
	case Type_Lowered_Pointer:
		return type_mentions_enum(ir, v.pointee, enum_handle)
	case Type_Array:
		return type_mentions_enum(ir, v.element, enum_handle)
	case Type_Proc:
		if type_mentions_enum(ir, v.return_type, enum_handle) {
			return true
		}
		for p in v.params {
			if type_mentions_enum(ir, p.type, enum_handle) {
				return true
			}
		}
	case Type_Typedef_Ref:
		return type_mentions_enum(ir, ir.typedefs[v.decl].aliased, enum_handle)
	case Type_Idiomatic_Leaf:
		return type_mentions_enum(ir, v.original, enum_handle)
	}
	return false
}
