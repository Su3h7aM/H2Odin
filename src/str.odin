package h2odin

import "core:strings"

// Pure string helpers exposed to Lua as h2o.str.* and reusable by the
// generator. They live here — not in policy.odin — so they stay testable
// without a live Lua VM (see AGENTS.md: algorithms registered by policy,
// never implemented inside it).

str_has_prefix :: proc(s, prefix: string) -> bool {
	return strings.has_prefix(s, prefix)
}

str_has_suffix :: proc(s, suffix: string) -> bool {
	return strings.has_suffix(s, suffix)
}

// Drop prefix when present; otherwise return s unchanged. Never returns an
// empty string when the whole input was the prefix — stripping would leave
// nothing to emit as a name.
str_strip_prefix :: proc(s, prefix: string) -> string {
	if prefix == "" || !strings.has_prefix(s, prefix) {
		return s
	}
	rest := s[len(prefix):]
	if rest == "" {
		return s
	}
	return rest
}

// Drop suffix when present; otherwise return s unchanged. Same empty-name
// refusal as strip_prefix.
str_strip_suffix :: proc(s, suffix: string) -> string {
	if suffix == "" || !strings.has_suffix(s, suffix) {
		return s
	}
	rest := s[:len(s) - len(suffix)]
	if rest == "" {
		return s
	}
	return rest
}
