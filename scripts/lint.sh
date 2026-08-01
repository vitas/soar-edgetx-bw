#!/usr/bin/env bash
set -euo pipefail

while IFS= read -r file; do
	bash -n "$file"
done < <(git ls-files 'scripts/*.sh' | LC_ALL=C sort)

# This imported legacy tool uses syntax rejected by host Lua and is outside soaring-package ownership.
while IFS= read -r file; do
	luac -p "$file"
done < <(
	find dist/SDCARD -type f -name '*.lua' \
		! -path 'dist/SDCARD/SCRIPTS/TOOLS/channelchange.lua' -print | LC_ALL=C sort
)

printf 'lint ok\n'
