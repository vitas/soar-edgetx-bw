#!/usr/bin/env bash
set -euo pipefail

jfutil="dist/SDCARD/SCRIPTS/FUNCTIONS/JFutil.lua"
fail=0

require_line() {
	local file="$1"
	local pattern="$2"

	if ! rg -n --fixed-strings -- "$pattern" "$file" >/dev/null; then
		printf 'missing in %s: %s\n' "$file" "$pattern" >&2
		fail=1
	fi
}

require_absent() {
	local file="$1"
	local pattern="$2"

	if rg -n --fixed-strings -- "$pattern" "$file" >/dev/null; then
		printf 'unexpected in %s: %s\n' "$file" "$pattern" >&2
		fail=1
	fi
}

require_line "$jfutil" 'local file = string.format("/SCRIPTS/TELEMETRY/%ix%i/%s", LCD_W, LCD_H, file)'
require_line "$jfutil" 'local chunk = loadScript(file, "tx")'
require_absent "$jfutil" 'string.format("/SCRIPTS/TELEMETRY/%ix%i/%s/", LCD_W, LCD_H, file)'
require_absent "$jfutil" 'return collectgarbage()'
require_absent "dist/SDCARD/SCRIPTS/TELEMETRY/JF3K/MENU.lua" 'return collectgarbage()'
require_absent "dist/SDCARD/SCRIPTS/TELEMETRY/JF5K/MENU.lua" 'return collectgarbage()'

while IFS= read -r luac; do
	if ! file "$luac" | rg -q 'Lua bytecode, version 5\.2$'; then
		printf 'unsupported EdgeTX telemetry bytecode: %s (%s)\n' "$luac" "$(file "$luac")" >&2
		fail=1
	fi
done < <(find dist/SDCARD/SCRIPTS/TELEMETRY -name '*.luac' -print | sort)

files=(
	dist/SDCARD/SCRIPTS/FUNCTIONS/JFutil.lua
	dist/SDCARD/SCRIPTS/TELEMETRY/JF3Ksk.lua
	dist/SDCARD/SCRIPTS/TELEMETRY/JF5Jsk.lua
	dist/SDCARD/SCRIPTS/TELEMETRY/JFXJcf.lua
	dist/SDCARD/SCRIPTS/TELEMETRY/JFXKcf.lua
	dist/SDCARD/SCRIPTS/TELEMETRY/JF3K/*.lua
	dist/SDCARD/SCRIPTS/TELEMETRY/JF5J/*.lua
	dist/SDCARD/SCRIPTS/TELEMETRY/JFXJ/*.lua
	dist/SDCARD/SCRIPTS/TELEMETRY/JFXK/*.lua
	dist/SDCARD/SCRIPTS/TELEMETRY/JF/CHANNELS.lua
	dist/SDCARD/SCRIPTS/TELEMETRY/JF/BATTERY.lua
	dist/SDCARD/SCRIPTS/TELEMETRY/128x64/JFXJ/*.lua
	dist/SDCARD/SCRIPTS/TELEMETRY/128x64/JFXK/*.lua
	dist/SDCARD/SCRIPTS/TELEMETRY/212x64/JFXJ/*.lua
	dist/SDCARD/SCRIPTS/TELEMETRY/212x64/JFXK/*.lua
)

while IFS= read -r file; do
	for size in 128x64 212x64; do
		if [ ! -f "dist/SDCARD/SCRIPTS/TELEMETRY/$size/$file" ]; then
			printf 'missing screen helper: %s/%s\n' "$size" "$file" >&2
			fail=1
		fi
	done
done < <(rg -o 'LoadWxH\("[^"]+"' "${files[@]}" | sed -E 's/.*LoadWxH\("([^"]+)"/\1/' | sort -u)

exit "$fail"
