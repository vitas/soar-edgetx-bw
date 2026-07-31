#!/usr/bin/env bash
set -euo pipefail

sk1="dist/SDCARD/SCRIPTS/TELEMETRY/JF3K/SK1.lua"
f3k="dist/SDCARD/SCRIPTS/TELEMETRY/F3K.lua"

fail=0

require_line() {
	local file="$1"
	local pattern="$2"

	if ! rg -n --fixed-strings -- "$pattern" "$file" >/dev/null; then
		printf 'missing in %s: %s\n' "$file" "$pattern" >&2
		fail=1
	fi
}

require_count() {
	local file="$1"
	local pattern="$2"
	local expected="$3"
	local count

	count=$({ rg -o --fixed-strings -- "$pattern" "$file" || true; } | wc -l | tr -d ' ')
	if [ "$count" != "$expected" ]; then
		printf 'expected %s occurrence(s) in %s, found %s: %s\n' "$expected" "$file" "$count" "$pattern" >&2
		fail=1
	fi
}

require_line "$sk1" '"A2. Last flight 10:00"'
require_line "$sk1" '"L. One flight only"'
require_line "$sk1" '"N. Best flight"'
require_line "$sk1" '{ 600, -1, 1, false, 599, 2, false } -- A2. Last flight 10:00'
require_line "$sk1" '{ 600, 1, 1, true, 599, 2, false },  -- L. One flight only'
require_line "$sk1" '{ 600, -1, 1, false, 599, 1, false },  -- N. Best flight'
require_count "$sk1" '"A2. Last flight 10:00"' 1
require_count "$sk1" '{ 600, -1, 1, false, 599, 2, false }' 1

require_line "$f3k" 'A2 = "A2. Last flight 10:00",'
require_line "$f3k" 'L = "L. One flight only",'
require_line "$f3k" 'N = "N. Best flight",'
require_line "$f3k" '{ lang.A2, 600, -1, 1, false, 599, 2'
require_line "$f3k" '{ lang.L, 600, 1, 1, true, 599, 2'
require_line "$f3k" '{ lang.N, 600, -1, 1, false, 599, 1'
require_count "$f3k" 'A2 = "A2. Last flight 10:00",' 1
require_count "$f3k" '{ lang.A2, 600, -1, 1, false, 599, 2' 1

exit "$fail"
