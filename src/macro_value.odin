package h2odin

import "core:strconv"
import "core:strings"

// Pure helpers for reading object-like macro replacement lists as values.
// Used by macro grouping (Transformation) and by the Lua macro view.

// True when the macro is a single integer literal (optional C suffixes).
macro_is_integer :: proc(decl: Macro_Decl) -> bool {
	_, ok := macro_integer_value(decl)
	return ok
}

// Parse a single-token integer macro body into i64. Accepts decimal, 0x/0X
// hex, 0b/0B binary, and optional u/U/l/L suffixes. Function-like macros and
// multi-token bodies are not integers.
macro_integer_value :: proc(decl: Macro_Decl) -> (value: i64, ok: bool) {
	if decl.is_function_like || len(decl.tokens) != 1 {
		return 0, false
	}
	token := decl.tokens[0]
	if token.kind != .Literal {
		return 0, false
	}
	return parse_c_integer_literal(token.spelling)
}

parse_c_integer_literal :: proc(s: string) -> (value: i64, ok: bool) {
	if len(s) == 0 {
		return 0, false
	}
	// Strip trailing C type suffixes (u, l, ul, ll, ull, …), case-insensitive.
	end := len(s)
	for end > 0 {
		c := s[end - 1]
		if c == 'u' || c == 'U' || c == 'l' || c == 'L' {
			end -= 1
			continue
		}
		break
	}
	if end == 0 {
		return 0, false
	}
	body := s[:end]

	base := 10
	num := body
	if len(body) > 2 && body[0] == '0' && (body[1] == 'x' || body[1] == 'X') {
		base = 16
		num = body[2:]
	} else if len(body) > 2 && body[0] == '0' && (body[1] == 'b' || body[1] == 'B') {
		base = 2
		num = body[2:]
	} else if len(body) > 1 && body[0] == '0' && is_ascii_digit(body[1]) {
		// C octal. Rare in flag macros; still accept.
		base = 8
		num = body[1:]
	}
	if len(num) == 0 {
		return 0, false
	}
	// strconv.parse_i64_of_base rejects leading +; handle sign.
	negative := false
	if num[0] == '-' {
		negative = true
		num = num[1:]
	} else if num[0] == '+' {
		num = num[1:]
	}
	if len(num) == 0 {
		return 0, false
	}
	v, parse_ok := strconv.parse_i64_of_base(num, base)
	if !parse_ok {
		return 0, false
	}
	if negative {
		v = -v
	}
	return v, true
}

// First matching prefix from the list, or "" if none.
// Used by macro grouping exclude_prefixes / prefix checks.
macro_matches_prefix :: proc(name, prefix: string) -> bool {
	return prefix != "" && strings.has_prefix(name, prefix)
}
