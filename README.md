# Soar EdgeTX BW

EdgeTX black-and-white SD-card package and RadioMaster Pocket model archive
adapted from SoarOTX soaring scripts.

This repository is for small BW radios such as RadioMaster Pocket, RadioMaster
GX12, and related 128x64/212x64 EdgeTX radios. It keeps the original
SoarOTX-style telemetry and setup scripts, with model and SD-card adjustments
for EdgeTX and Pocket/GX12 use.

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

### M-tail Elevator Mixes

`M-tail` drives the two elevator servos from `CH7` and `CH8` and adds two
optional differential elevator mixes:

| Mix | Enable switch | Default | Effect |
| --- | --- | --- | --- |
| `AilEle` (aileron to elevator) | `L46` | `NONE` | `+20` on `CH7`, `-20` on `CH8` |
| `RudEle` (rudder to elevator) | `L48` | `NONE` | `+20` on `CH7`, `-20` on `CH8` |

The opposite `CH8` sign keeps the two mirrored elevator servos moving together.
Both mixes are active in `Cruise`, `Speed`, and `Float`, and disabled in
`Adjust`, `Motor`, and `KAPOW`. `L46` and `L48` are defined on every F5J variant
but default to `NONE`, so assign a physical switch in the radio's Logical
Switches menu before using either mix. The mixes are only present on `M-tail`;
`X-tail` has a single elevator output and `V-tail` uses its two surfaces for the
V-tail mix.

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

## RadioMaster GX12

The same four templates are also provided for the RadioMaster GX12, which is
supported by EdgeTX from v2.11 and uses the same 128x64 black-and-white
interface as the Pocket:

- `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/gx12-F3K.yml`
- `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/gx12-F5J-XTail.yml`
- `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/gx12-F5J-MTail.yml`
- `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/gx12-F5J-VTail.yml`

The `gx12-*` files are identical to the matching `pocket-*` templates apart from
the model name, so the channel assignments, switch assignments, and
`AilEle`/`RudEle` mixes described above apply unchanged.

| Item | GX12 |
| --- | --- |
| EdgeTX target | `gx12` (`PCB=X7`, `PCBREV=GX12`) |
| Display | 128x64 monochrome OLED |
| Processor | STM32F407 |
| Global variables | 9 (`GV1`-`GV9`), same as the Pocket |
| Switches | `SA` 2-position, `SB`/`SC` 3-position, `SD` 2-position, `SE`/`SF` 3-position |
| Function switches | 8 RGB function switches (`FS1`-`FS8`) in 4 groups |
| Storage | 512 MB internal memory, mounted as the SD-card root over USB |

The templates only use positions `0` and `2` on `SA` and `SD`, so the GX12's
2-position `SA`/`SD` work without changes. The GX12 has no extended global
variables, so the fixed `AilEle`/`RudEle` weights (`+20`/`-20`) are required
there as well. The templates do not use the `FS1`-`FS8` function switches.

The GX12 has no SD card: copy the contents of `dist/SDCARD/` to the root of the
internal storage instead. The `models/pocket/pocket_vitas_3.12.etx` archive is
Pocket-specific because it carries the Pocket `RADIO/radio.yml`; for the GX12,
create a model from a `gx12-*` template on the radio or export an archive from
your own GX12 in EdgeTX Companion.

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
