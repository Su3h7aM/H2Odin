# Shared helpers for scripts/* — source only, not an entry point.
# Not executable (and not a mise file task). Do not add #MISE headers here.
# shellcheck shell=bash

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$_SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

SRC_DIR=src
TEST_DIR=tests
BUILD_DIR=build
BIN="$BUILD_DIR/h2odin"

ODIN="${ODIN:-odin}"
ODINFMT="${ODINFMT:-odinfmt}"

ODIN_FLAGS=(-vet -strict-style -vet-tabs -disallow-do -warnings-as-errors)
COLLECTION_FLAGS=(-collection:vendored="$ROOT/vendored")
# Quiet success output from the Odin test runner (still prints failures).
# See https://odin-lang.org/docs/testing/#compile-time-options
TEST_DEFINES=(-define:ODIN_TEST_LOG_LEVEL=warning)

# Validation corpus (Milestone 15). Keep in sync with examples/README.md.
EXAMPLES=(fff sqlite3 bit_fields raylib box3d cgltf curl miniaudio)

# Pair the odin binary with its stdlib.
#
# mise often exports ODIN_ROOT for a nightly while PATH still resolves `odin`
# to /usr/bin/odin. That mix fails in Odin *runtime* sources with errors like
# "Invalid build tag platform: bedrock". If the selected binary ships with a
# sibling base/, pin ODIN_ROOT there; otherwise drop a foreign ODIN_ROOT so
# packaged layouts (e.g. /usr/bin/odin + /usr/lib/odin) use their own stdlib.
setup_odin() {
	local odin_path odin_dir
	odin_path="$(command -v "$ODIN" 2>/dev/null || true)"
	if [[ -z "$odin_path" ]]; then
		echo "error: odin not found on PATH (install via mise, or set ODIN=...)" >&2
		exit 1
	fi
	odin_dir="$(cd "$(dirname "$odin_path")" && pwd)"
	if [[ -d "$odin_dir/base" ]]; then
		export ODIN_ROOT="$odin_dir"
		RUN_ODIN=("$ODIN")
	else
		unset ODIN_ROOT || true
		RUN_ODIN=(env -u ODIN_ROOT "$ODIN")
	fi
}

run_odin() {
	setup_odin
	"${RUN_ODIN[@]}" "$@"
}

# True when build/h2odin is missing or any src/*.odin is newer.
need_rebuild() {
	[[ ! -f "$BIN" ]] && return 0
	local f
	while IFS= read -r -d '' f; do
		if [[ "$f" -nt "$BIN" ]]; then
			return 0
		fi
	done < <(find "$SRC_DIR" -name '*.odin' -print0 2>/dev/null)
	return 1
}

ensure_built() {
	if need_rebuild; then
		"$ROOT/scripts/build"
	fi
}
