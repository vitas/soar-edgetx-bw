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

## Pocket Templates

The SD-card package includes four RadioMaster Pocket templates:

- `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F3K.yml`
- `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-XTail.yml`
- `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-MTail.yml`
- `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-VTail.yml`

The F3K template derives its behavior from Flitz3. The F5J templates derive
their common behavior from Sense and use these channel assignments:

| Channel | X-tail | M-tail | V-tail |
| --- | --- | --- | --- |
| CH1 | Left aileron | Left aileron | Left aileron |
| CH2 | Right aileron | Right aileron | Right aileron |
| CH3 | Motor | Motor | Motor |
| CH4 | Left flap | Left flap | Left flap |
| CH5 | Right flap | Right flap | Right flap |
| CH6 | Rudder | Rudder | Unused |
| CH7 | Elevator | Left elevator | Left V-tail |
| CH8 | Unused | Right elevator | Right V-tail |

### Pocket Switch Assignments

The Pocket templates use the following primary controls. EdgeTX position names
are included because they are more precise than physical up/down descriptions.

| Switch | F3K | F5J X-/M-/V-tail |
| --- | --- | --- |
| SA | Altitude-call control | Motor arm (`SA2`, latched by `L23`) |
| SB | Altitude-announcement control | Flight-time announcement (`SB2` through `L12`) |
| SC | Flight mode: Speed (`SC0`), Cruise (center), Float (`SC2`) | Flight mode: Speed (`SC0`), Cruise (center), Float (`SC2`) |
| SD | Brake/landing control (`SD2`); crow-off on `SD0` | Proportional crow enabled on `SD2` (`L36` off); score entry and landing announcement (`SD2` through `L7`); crow off and landing-off announcement (`SD0` through `L36`) |
| SE | Launch (`SE2` through `L7`) | Motor start/release (`SE2` through `L9`) |

For F5J, arm with SA before using SE. After the motor run and motor-off count,
move SD down to enable throttle-controlled proportional crow, finish the flight,
and open landing-score entry. Move SD up to force crow off. Hold SB down for
repeating flight-time announcements. Keep the motor disconnected while checking
these assignments on a newly created model.

The templates are sanitized: they contain no personal binding, registration,
or discovered telemetry data. Output calibration and flight trims are neutral,
and the physical aileron/flap alignment curves start with a linear response.
You must configure each template for the aircraft before flight.

To install and configure a template safely:

1. Back up the radio and current model.
2. Remove the propeller or disconnect the motor before applying the template.
   Keep propulsion isolated throughout receiver setup and output configuration.
3. Apply the template from the radio SD card.
4. Bind and configure the receiver, then discover telemetry sensors.
5. Configure endpoints, centers, reversals, and setup curves for the aircraft.
6. With the motor disconnected where possible, verify outputs, scripts, switch
   assignments, and failsafe behavior.
7. To verify motor direction, remove the propeller, reconnect the motor if
   needed, and power it only briefly.

## Install

1. Back up the radio SD card and models first.
2. Install the standard EdgeTX SD-card sound pack for your firmware version.
3. Copy the contents of `dist/SDCARD/` to the root of the radio SD card.
4. Import `models/pocket/pocket_vitas_3.12.etx` in EdgeTX Companion, or copy the
   model YAML files manually if you know your radio layout.
5. On the radio, keep propulsion isolated while verifying script screens,
   channel order, switch assignments, and failsafe. Remove the propeller before
   briefly powering the motor to verify its direction.

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

Host verification requires `make`, `bash`, `git`, `file`, `rg`, `lua`, `luac`,
and `ruby` with its standard-library Psych YAML parser.

Run `make verify` to check shell, Ruby, and Lua syntax, YAML structure, Lua
loading, F3K tasks, and model-template contracts.

## Credits

Original SoarOTX soaring scripts were created by Jesper Frickmann. This package
also includes OpenTX/EdgeTX SD-card components from their respective authors.

Pocket and EdgeTX BW adjustments by Vitaliy Ryumshyn.

## License

Most included scripts carry GPLv2 notices from SoarOTX, OpenTX, or EdgeTX. See
`LICENSE` and `NOTICE`; individual file headers remain authoritative.
