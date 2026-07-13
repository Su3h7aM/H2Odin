package h2odin

import "core:strings"

// Foreign types — those a system header declares, not the library's own
// headers — are captured pool-only by Extraction. Transformation then either:
//
//   1. Maps a known system type to its Odin defining package:
//      POSIX names to core:sys/posix (sockaddr → posix.sockaddr), ISO C
//      library names to core:c/libc (time_t → libc.time_t). One spelling in
//      both type modes — these Odin types are `distinct` and OS-width
//      specific, so peeling them to fixed-width integers would break interop.
//   2. Promotes an incomplete stub so pointer references spell `^Name`, or
//   3. Diagnoses by-value use of an unmapped foreign type (layout unavailable).
//
// Config wins over the built-in map: a name in types.map / types.overrides is
// left for apply_configured_type_rewrites. On Windows, compounds that exist in
// core:sys/windows are rewritten to win32.* (platform_foreign_spelling);
// pure-POSIX names still need types.map.

Foreign_Type_Entry :: struct {
	c_name:    string,
	spelling:  string, // Unix/default defining-package spelling (posix.* / libc.*)
	// Scalars are width-guarded against the Odin type's size before mapping
	// compounds rely on the allowlist plus Odin's
	// own per-OS layout, since foreign layouts are deliberately not captured.
	is_scalar: bool,
}

// Every spelling in the built-in map is verified to exist as an
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
	{c_name = "socklen_t", spelling = "posix.socklen_t", is_scalar = true},
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

// C system types that core:sys/windows exports under the same bare name.
// Used only when the generation host is Windows (platform_foreign_spelling).
// Verified against Odin dev-2026-07a; grow from corpus needs, not inventory.
windows_compound_spelling :: proc(c_name: string) -> (spelling: string, ok: bool) {
	switch c_name {
	case "sockaddr":
		return "win32.sockaddr", true
	case "sockaddr_in":
		return "win32.sockaddr_in", true
	case "sockaddr_in6":
		return "win32.sockaddr_in6", true
	case "in_addr":
		return "win32.in_addr", true
	case "in6_addr":
		return "win32.in6_addr", true
	case "fd_set":
		return "win32.fd_set", true
	case "timeval":
		return "win32.timeval", true
	case "socklen_t":
		// Map entry is posix.socklen_t (scalar); Windows uses win32.socklen_t.
		return "win32.socklen_t", true
	}
	return "", false
}

Foreign_Type_Uses :: struct {
	record_referenced: []bool,
	record_by_value:   []bool,
	record_home:       []Input_Header_Handle,
	enum_referenced:   []bool,
	enum_home:         []Input_Header_Handle,
}

apply_foreign_types :: proc(ir: ^IR, policy: ^Policy) {
	uses := analyze_foreign_type_uses(ir)

	for i in 0 ..< len(ir.records) {
		handle := Decl_Handle(i)
		rec := &ir.records[i]
		if !rec.is_foreign || rec.name == "" {
			continue
		}
		if !uses.record_referenced[i] {
			continue
		}
		if _, named := configured_type_spelling(policy, rec.name); named {
			// apply_configured_type_rewrites spells the use sites; the foreign record
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
		if uses.record_home[i] != 0 {
			rec.home = uses.record_home[i]
		}
		if uses.record_by_value[i] {
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
		if !uses.enum_referenced[i] {
			continue
		}
		if _, named := configured_type_spelling(policy, enm.name); named {
			continue // config spells the use sites; emit no stub
		}
		if spelling, mapped := platform_spelling(ir, policy, enm.name, 0); mapped {
			rewrite_enum_refs_to_spelling(ir, handle, spelling, .Platform_Type)
			continue
		}
		enm.members = nil
		if uses.enum_home[i] != 0 {
			enm.home = uses.enum_home[i]
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
//   1. The built-in map or config knows the
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
		// Config first. A foreign typedef is never
		// emitted, so even types.overrides — which keeps *our* typedefs as
		// named aliases — must resolve at the use sites here.
		if spelling, named := configured_type_spelling(policy, td.name); named {
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

// The built-in spelling for a foreign C type name, if one applies here.
// Returns not-mapped when config names the type (config wins), when the name
// is not in the map, when the target does not define the Odin type, or when a
// scalar's measured C width disagrees with the Odin type's width on this
// target. `aliased` is the underlying type for typedefs and 0 for tags (which
// carry no scalar width).
platform_spelling :: proc(ir: ^IR, policy: ^Policy, name: string, aliased: Type_Handle) -> (spelling: string, ok: bool) {
	if _, in_config := configured_type_spelling(policy, name); in_config {
		return "", false
	}
	entry, known := foreign_type_entry(name)
	if !known {
		return "", false
	}
	// Host-specific spelling: Unix keeps the map's posix.*/libc.* names;
	// Windows rewrites compounds that core:sys/windows exports to win32.*.
	spelling = platform_foreign_spelling(entry)
	if spelling == "" {
		ir_diag(
			ir,
			.Unresolved_Type,
			"foreign type %q has no defining-package spelling on this target (Unix map entry %s); map it with types.map",
			name,
			entry.spelling,
		)
		return "", false
	}
	if !platform_spelling_supported(spelling) {
		// e.g. a spelling that cannot be imported on this host.
		ir_diag(ir, .Unresolved_Type, "foreign type %q would map to %s, which this target does not define; map it with types.map", name, spelling)
		return "", false
	}
	if !entry.is_scalar {
		// Compounds are not width-guarded: foreign layouts are deliberately
		// not captured, and Odin's package owns the per-OS layout. The
		// verified allowlist is what keeps these honest.
		return spelling, true
	}

	// Width guard: never substitute a type whose width does not match on this
	// target (libc.time_t is unconditionally 64-bit; a 32-bit C time_t is a
	// different type). Diagnose and leave the C spelling alone.
	odin_size := platform_type_size(spelling)
	measured := type_measured_size(ir, aliased)
	if odin_size <= 0 {
		ir_diag(
			ir,
			.Unresolved_Type,
			"foreign type %q maps to %s, whose width is unknown on this target; keeping the C spelling. Map it with types.map",
			name,
			spelling,
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
			spelling,
			odin_size,
		)
		return "", false
	}
	return spelling, true
}

// Size of a scalar type as libclang measured it on the generation target.
// Peels typedefs and already-substituted leaves. -1 when there is no scalar
// width to compare (never a reason to map — the caller keeps the C spelling).
type_measured_size :: proc(ir: ^IR, handle: Type_Handle) -> int {
	cur := handle
	// A chain cannot visit more distinct type slots than the pool contains.
	// The same bound also terminates malformed typedef cycles.
	for _ in 0 ..< len(ir.types) {
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

// Analyze live declaration roots once. Dense slices match the IR pools and
// make record and enum handling follow the same traversal. The scan guards its
// current recursion path, so malformed typedef cycles terminate without
// suppressing a later use with different by-value or home-header context.
analyze_foreign_type_uses :: proc(ir: ^IR) -> Foreign_Type_Uses {
	uses := Foreign_Type_Uses {
		record_referenced = make([]bool, len(ir.records), context.temp_allocator),
		record_by_value   = make([]bool, len(ir.records), context.temp_allocator),
		record_home       = make([]Input_Header_Handle, len(ir.records), context.temp_allocator),
		enum_referenced   = make([]bool, len(ir.enums), context.temp_allocator),
		enum_home         = make([]Input_Header_Handle, len(ir.enums), context.temp_allocator),
	}
	visiting := make([]bool, len(ir.types), context.temp_allocator)

	for declaration in ir.order {
		home := ir_decl_home(ir, declaration)
		switch declaration.kind {
		case .Invalid:
		case .Func:
			function := ir.funcs[declaration.index]
			scan_foreign_type_use(ir, function.return_type, true, home, &uses, &visiting)
			for parameter in function.params {
				scan_foreign_type_use(ir, parameter.type, true, home, &uses, &visiting)
			}
		case .Record:
			for field in ir.records[declaration.index].fields {
				scan_foreign_type_use(ir, field.type, true, home, &uses, &visiting)
			}
		case .Enum:
			scan_foreign_type_use(ir, ir.enums[declaration.index].backing, true, home, &uses, &visiting)
		case .Typedef:
			scan_foreign_type_use(ir, ir.typedefs[declaration.index].aliased, true, home, &uses, &visiting)
		case .Var:
			scan_foreign_type_use(ir, ir.vars[declaration.index].type, true, home, &uses, &visiting)
		case .Bit_Set:
			scan_foreign_type_use(ir, ir.bit_sets[declaration.index].elem, true, home, &uses, &visiting)
		case .Macro, .Wrapper:
		}
	}
	return uses
}

scan_foreign_type_use :: proc(ir: ^IR, handle: Type_Handle, surface_by_value: bool, home: Input_Header_Handle, uses: ^Foreign_Type_Uses, visiting: ^[]bool) {
	type_index := int(handle)
	if type_index <= 0 || type_index >= len(ir.types) || visiting^[type_index] {
		return
	}
	visiting^[type_index] = true
	defer visiting^[type_index] = false

	info := ir_type(ir, handle)
	#partial switch variant in info.variant {
	case Type_Record_Ref:
		record_index := int(variant.decl)
		uses.record_referenced[record_index] = true
		if surface_by_value {
			uses.record_by_value[record_index] = true
		}
		if home != 0 && uses.record_home[record_index] == 0 {
			uses.record_home[record_index] = home
		}
	case Type_Enum_Ref:
		enum_index := int(variant.decl)
		uses.enum_referenced[enum_index] = true
		if home != 0 && uses.enum_home[enum_index] == 0 {
			uses.enum_home[enum_index] = home
		}
	case Type_Pointer:
		scan_foreign_type_use(ir, variant.pointee, false, home, uses, visiting)
	case Type_Lowered_Pointer:
		scan_foreign_type_use(ir, variant.pointee, false, home, uses, visiting)
	case Type_Array:
		scan_foreign_type_use(ir, variant.element, surface_by_value, home, uses, visiting)
	case Type_Proc:
		scan_foreign_type_use(ir, variant.return_type, true, home, uses, visiting)
		for parameter in variant.params {
			scan_foreign_type_use(ir, parameter.type, true, home, uses, visiting)
		}
	case Type_Typedef_Ref:
		typedef := ir.typedefs[variant.decl]
		if !typedef.is_unresolvable {
			scan_foreign_type_use(ir, typedef.aliased, surface_by_value, home, uses, visiting)
		}
	case Type_Idiomatic_Leaf:
		// The decided spelling is terminal. Its original type remains only for
		// diagnostics and ABI auditing; emission does not follow it.
		return
	}
}
