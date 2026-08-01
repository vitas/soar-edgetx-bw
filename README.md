# Soar EdgeTX BW

EdgeTX black-and-white SD-card package and RadioMaster Pocket model archive
adapted from SoarOTX soaring scripts.

This repository is for small BW radios such as RadioMaster Pocket and related
128x64/212x64 EdgeTX radios. It keeps the original SoarOTX-style telemetry and
setup scripts, with model and SD-card adjustments for EdgeTX and Pocket use.

## What Is Included

- `dist/SDCARD/` - SD-card files to copy to the radio SD card root.
- `models/pocket/pocket_vitas_3.12.etx` - EdgeTX Companion archive for the
  RadioMaster Pocket setup.
- F3K/F5J/JFXJ/JFXK telemetry and setup scripts for BW screens.
- Custom soaring voice prompts used by the included models.
- Pocket model examples including `Dart-LT`, `Flitz3`, and `Sense`.

The graph screen has been removed from the included models. The active soaring
model screens are now score/timer plus setup/configuration; this avoids the
missing graph wrapper on Pocket.

## Install

1. Back up the radio SD card and models first.
2. Install the standard EdgeTX SD-card sound pack for your firmware version.
3. Copy the contents of `dist/SDCARD/` to the root of the radio SD card.
4. Import `models/pocket/pocket_vitas_3.12.etx` in EdgeTX Companion, or copy the
   model YAML files manually if you know your radio layout.
5. On the radio, verify script screens, channel order, switch assignments,
   failsafe, and motor behavior with the motor disconnected.

When updating an existing SD card, delete these old generated helper files if
they are present before copying the new package:

- `/SCRIPTS/TELEMETRY/128x64/ARMED.luac`
- `/SCRIPTS/TELEMETRY/128x64/JFutil.luac`
- `/SCRIPTS/TELEMETRY/128x64/MENU.luac`

They can prevent F3K/F5J timer and setup screens from opening on Pocket/128x64
EdgeTX radios.

## Notes

- This is a personal EdgeTX/Pocket adaptation of SoarOTX, not an official
  SoarOTX release.
- The full standard EdgeTX sound pack is intentionally not tracked here. Only
  the custom model prompts are committed.
- The package still includes some `.luac` files because precompiled scripts can
  reduce load time and memory pressure on small BW radios. Matching Lua source
  files are included where available.
- F3K task notes, including 2026 FAI task coverage and the custom `A2` task,
  are in `dist/SDCARD/SCRIPTS/TELEMETRY/F3K_readme.txt`.
- Keep the model-specific calibrations, receiver protocol, failsafe, and switch
  assignments under review before flying.

## Development

Run `make verify` to check shell and Lua syntax, Lua loading, F3K tasks, and
model templates.

## Credits

Original SoarOTX soaring scripts were created by Jesper Frickmann. This package
also includes OpenTX/EdgeTX SD-card components from their respective authors.

Pocket and EdgeTX BW adjustments by Vitaliy Ryumshyn.

## License

Most included scripts carry GPLv2 notices from SoarOTX, OpenTX, or EdgeTX. See
`LICENSE` and `NOTICE`; individual file headers remain authoritative.
