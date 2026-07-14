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
	_, digits, base, negative, syntax_ok := parse_c_integer_literal_syntax(s)
	if !syntax_ok {
		return 0, false
	}
	v, parse_ok := strconv.parse_i64_of_base(digits, base)
	if !parse_ok {
		return 0, false
	}
	if negative {
		v = -v
	}
	return v, true
}

// c_integer_literal_for_emission validates the full unsigned range accepted by
// Odin while returning a suffix-free body that still aliases the input.
c_integer_literal_for_emission :: proc(spelling: string) -> (body: string, ok: bool) {
	digits: string
	base: int
	negative, syntax_ok: bool
	body, digits, base, negative, syntax_ok = parse_c_integer_literal_syntax(spelling)
	if !syntax_ok {
		return "", false
	}
	if negative {
		_, ok = strconv.parse_i64_of_base(digits, base)
	} else {
		_, ok = strconv.parse_u64_of_base(digits, base)
	}
	return body, ok
}

// parse_c_integer_literal_syntax separates the source spelling without
// allocating. body excludes C's type suffix; digits excludes sign and radix.
parse_c_integer_literal_syntax :: proc(spelling: string) -> (body, digits: string, base: int, negative, ok: bool) {
	if len(spelling) == 0 {
		return
	}
	end := len(spelling)
	for end > 0 {
		character := spelling[end - 1]
		if character == 'u' || character == 'U' || character == 'l' || character == 'L' {
			end -= 1
			continue
		}
		break
	}
	if end == 0 {
		return
	}
	body = spelling[:end]
	digits = body
	if digits[0] == '-' {
		negative = true
		digits = digits[1:]
	} else if digits[0] == '+' {
		digits = digits[1:]
	}
	if len(digits) == 0 {
		return
	}

	base = 10
	if len(digits) > 2 && digits[0] == '0' && (digits[1] == 'x' || digits[1] == 'X') {
		base = 16
		digits = digits[2:]
	} else if len(digits) > 2 && digits[0] == '0' && (digits[1] == 'b' || digits[1] == 'B') {
		base = 2
		digits = digits[2:]
	} else if len(digits) > 1 && digits[0] == '0' && is_ascii_digit(digits[1]) {
		base = 8
		digits = digits[1:]
	}
	ok = len(digits) > 0
	return
}

// First matching prefix from the list, or "" if none.
// Used by macro grouping exclude_prefixes / prefix checks.
macro_matches_prefix :: proc(name, prefix: string) -> bool {
	return prefix != "" && strings.has_prefix(name, prefix)
}
