package h2odin

import "core:strings"

// Pure identifier tokenization and case conversion. Policy only *registers*
// these into the Lua VM; the algorithms live here so they stay unit-testable
// without a live Lua state (see AGENTS.md).

// Split a C identifier into lowercased word atoms.
//
// known maps exact surface spellings (e.g. "SQLite3", "UTF8", "NOMEM") to a
// lower form that may itself contain underscores ("no_mem" → two atoms).
// Longest match wins at each position. When a shorter known key also matches
// at the same index and another known key continues after it — competing
// segmentations such as ABC = AB|C vs A|BC — the split is ambiguous
// (naming_ambiguity). Map keys are unique, so equal-length collisions cannot
// occur; real dictionary ambiguity is overlapping lengths.
//
// Heuristic (when no known token matches):
//   - underscores are separators
//   - camelCase and acronym edges split words (XMLHttp → Xml, Http)
//   - digits stay attached to the adjacent letters in the same segment
//     (sqlite3, open_v2, H264 stay single atoms) — the common C shape.
// known_tokens upgrades casing/grouping of domain vocabulary; it is not
// required just to keep "v2" glued together.
naming_tokenize :: proc(name: string, known: map[string]string = nil, allocator := context.allocator) -> (tokens: []string, ambiguous: bool) {
	if name == "" {
		return nil, false
	}

	keys := known_token_keys_longest_first(known, context.temp_allocator)
	out: [dynamic]string
	out.allocator = allocator
	i := 0

	for i < len(name) {
		if name[i] == '_' {
			i += 1
			continue
		}

		best_key := longest_known_at(name, i, keys)
		if best_key != "" {
			if known_segmentation_ambiguous_at(name, i, keys, len(best_key)) {
				ambiguous = true
			}
			lower := known[best_key]
			for part in strings.split(lower, "_", context.temp_allocator) {
				if part != "" {
					append(&out, strings.clone(part, allocator))
				}
			}
			i += len(best_key)
			continue
		}

		start := i
		// Alphanumeric run with camelCase splits. Digits do not start a new
		// atom by themselves — they continue the current word.
		if is_ascii_digit(name[i]) {
			for i < len(name) && (is_ascii_digit(name[i]) || is_ascii_alpha(name[i])) {
				if i > start && camel_boundary(name, i) {
					break
				}
				i += 1
			}
		} else {
			i += 1
			for i < len(name) {
				c := name[i]
				if c == '_' {
					break
				}
				if is_ascii_alpha(c) && camel_boundary(name, i) {
					break
				}
				if is_ascii_digit(c) || is_ascii_alpha(c) {
					i += 1
					continue
				}
				// Unexpected character in a C identifier — take it alone.
				break
			}
		}
		append(&out, strings.to_lower(name[start:i], allocator))
	}

	return out[:], ambiguous
}

// Longest known key matching name[i:]. Keys are unique map surfaces, so at
// most one key of a given length can match; longer always wins when present.
longest_known_at :: proc(name: string, i: int, keys: []string) -> string {
	for key in keys {
		if i + len(key) <= len(name) && name[i:i + len(key)] == key {
			return key
		}
	}
	return ""
}

// True when a strictly shorter known key matches at i and another known key
// continues after it — so the dictionary admits a different tiling than pure
// longest-match (e.g. AB vs A+BC on "ABC").
known_segmentation_ambiguous_at :: proc(name: string, i: int, keys: []string, best_len: int) -> bool {
	if best_len <= 1 {
		return false
	}
	for key in keys {
		s := len(key)
		if s == 0 || s >= best_len {
			continue
		}
		if i + s > len(name) || name[i:i + s] != key {
			continue
		}
		if known_match_at(name, i + s, keys) {
			return true
		}
	}
	return false
}

known_match_at :: proc(name: string, i: int, keys: []string) -> bool {
	if i >= len(name) {
		return false
	}
	for key in keys {
		if i + len(key) <= len(name) && name[i:i + len(key)] == key {
			return true
		}
	}
	return false
}

known_token_keys_longest_first :: proc(known: map[string]string, allocator := context.allocator) -> []string {
	if known == nil || len(known) == 0 {
		return nil
	}
	keys := make([dynamic]string, 0, len(known), allocator)
	for k in known {
		append(&keys, k)
	}
	for i in 1 ..< len(keys) {
		j := i
		for j > 0 && len(keys[j - 1]) < len(keys[j]) {
			keys[j - 1], keys[j] = keys[j], keys[j - 1]
			j -= 1
		}
	}
	return keys[:]
}

// camelCase boundary at index i: previous is lower/digit and current is upper,
// or an upper run ends before a capital that starts a new word (XMLHttp).
camel_boundary :: proc(name: string, i: int) -> bool {
	if i <= 0 || i >= len(name) {
		return false
	}
	prev := name[i - 1]
	cur := name[i]
	if !is_ascii_upper(cur) {
		return false
	}
	if is_ascii_lower(prev) || is_ascii_digit(prev) {
		return true
	}
	if is_ascii_upper(prev) && i + 1 < len(name) && is_ascii_lower(name[i + 1]) {
		return true
	}
	return false
}

is_ascii_digit :: proc(c: u8) -> bool {
	return c >= '0' && c <= '9'
}

is_ascii_alpha :: proc(c: u8) -> bool {
	return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

is_ascii_lower :: proc(c: u8) -> bool {
	return c >= 'a' && c <= 'z'
}

is_ascii_upper :: proc(c: u8) -> bool {
	return c >= 'A' && c <= 'Z'
}

naming_snake_case :: proc(name: string, known: map[string]string = nil, allocator := context.allocator) -> (result: string, ambiguous: bool) {
	tokens, amb := naming_tokenize(name, known, context.temp_allocator)
	ambiguous = amb
	if len(tokens) == 0 {
		return strings.clone(name, allocator), ambiguous
	}
	return strings.join(tokens, "_", allocator), ambiguous
}

naming_ada_case :: proc(name: string, known: map[string]string = nil, allocator := context.allocator) -> (result: string, ambiguous: bool) {
	tokens, amb := naming_tokenize(name, known, context.temp_allocator)
	ambiguous = amb
	if len(tokens) == 0 {
		return strings.clone(name, allocator), ambiguous
	}
	parts := make([]string, len(tokens), context.temp_allocator)
	for tok, i in tokens {
		parts[i] = capitalize_ascii(tok, context.temp_allocator)
	}
	return strings.join(parts, "_", allocator), ambiguous
}

capitalize_ascii :: proc(s: string, allocator := context.allocator) -> string {
	if len(s) == 0 {
		return ""
	}
	b := make([]byte, len(s), allocator)
	copy(b, s)
	if b[0] >= 'a' && b[0] <= 'z' {
		b[0] -= 'a' - 'A'
	}
	return string(b)
}

Naming_Case :: enum {
	Snake,
	Ada,
	As_Is,
}

naming_case_for_kind :: proc(kind: Symbol_Kind) -> Naming_Case {
	switch kind {
	case .Func, .Var, .Field, .Param:
		return .Snake
	case .Type, .Const, .Enum_Member:
		return .Ada
	}
	return .Ada
}

naming_apply_case :: proc(
	name: string,
	kind: Symbol_Kind,
	known: map[string]string = nil,
	allocator := context.allocator,
) -> (
	result: string,
	ambiguous: bool,
) {
	switch naming_case_for_kind(kind) {
	case .Snake:
		return naming_snake_case(name, known, allocator)
	case .Ada:
		return naming_ada_case(name, known, allocator)
	case .As_Is:
		return strings.clone(name, allocator), false
	}
	return strings.clone(name, allocator), false
}
