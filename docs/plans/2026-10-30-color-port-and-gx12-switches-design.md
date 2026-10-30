# Color Port and GX12 Switch Layout Design

## Context

In October 2026 the color project (`soar-edgetx`) fixed template bugs and added
two setup features. The BW F5J templates share the same SoarOTX design and the
same bugs:

- `L46` and `L48` are `AND(NONE, NONE)`. EdgeTX evaluates an empty switch as
  true, so on M-tail the `AilEle` and `RudEle` mixes are always on in Cruise,
  Speed, and Float, although the README says they are off until a switch is
  assigned.
- On V-tail, `CH7` and `CH8` get the rudder and the elevator stick with the same
  sign and the brake/motor elevator compensation `CH22` with opposite signs, so
  one of them moves the tail the wrong way. V-tail also has no aileron-to-rudder
  mix.

The `gx12-*` templates are copies of the `pocket-*` templates with another
model name. The RadioMaster GX12 manual and the EdgeTX 2.12 GX12 simulator agree
that `SA`, `SD`, `SG`, and `SH` are momentary buttons, `SB`, `SC`, `SE`, and `SF`
are 3-position switches, and the radio has the `S1`/`S2` sliders, the `P1`/`P2`
dials, and six programmable buttons `SW1`-`SW6`. With the Pocket layout, the
GX12 motor is armed only while the `SA` button is held.

## Template Changes (all six F5J templates)

1. **NONE is off.** `L46` and `L48` become `!ON,NONE`. To use a mix, put a
   switch (or `ON`) in the first field of the logical switch.
2. **V-tail mixing (V-tail only).** Two virtual channels, as in the color
   project:
   - `CH18 Rudd`: `I0` 100 and `I2` x `GV3` (`AilRud`, no trim, like `CH6` on
     X-/M-tail).
   - `CH19 Elev`: `CH22` 100 and `I1` 100 (not in KAPOW, like the old lines).
   - `CH7` = 50% `CH18` - 50% `CH19`, `CH8` = 50% `CH18` + 50% `CH19`.

   Rudder and aileron move both servos the same way, elevator moves them in
   opposite directions. Each servo gets half of the former elevator travel, so
   the throws are set with the outputs.
3. **M-tail elevator differential (M-tail only).** Both `AilEle` lines get the
   differential -50, so the down-going half moves half as far. It is fixed
   because the Pocket and the GX12 have only nine GVs (same as the color TX16S
   template).
4. **Brake elevator curve.** New curve `CV14 BrE` (five points). `CH22` replaces
   the `BrkEle` and `BEOffs` lines with one line: `CH21` x `BkE` + `BkE` through
   `CV14`, which is `BkE x (1 + BrE / 100)`. The default
   `67, 17, -33, -83, -100` gives exactly the current compensation with the
   template flap curve `BrF` (`-100, -50, 0, 50, 67`), which today is
   `BkE x (67 - BrF) / 100`.
5. **Motor idle items.** `L49` = `GV8 > 50` and `SF39` = adjust `GV8` from the
   throttle trim `T3` while `L49` is on.
6. **Airbrake trims.** `SF14` (on `L14`) takes the aileron trim `T4` instead of
   the elevator trim for the aileron curve (`GV4`), and new `SF40` (on `L14`)
   takes the elevator trim `T2` into `GV3` for the elevator curve. `GV1`-`GV4`
   in the Adjust mode are already scratch values of the alignment page; `GV5`
   and `GV7` in the Adjust mode store the help flag and the battery threshold
   (`JFutil.lua`), so they stay untouched.

The brake curve start values (`CV5`/`CV6`, set in August) and the `P1` motor
input stay as they are.

## Configuration Pages

1. **Airbrakes (`JFXJ/BRKCRV.lua`).** A third plot `Ele` shows `CV14`. Throttle
   trim adjusts the flap curve, aileron trim the aileron curve, elevator trim
   the elevator curve, as in the color project. The last point (brakes off)
   stays at -100 and is not adjusted, so in normal flight the elevator stays
   where the trim puts it. The elevator does not move with the curve on this
   page, because the Adjust mode keeps its own `BkE` (the help flag). A model
   from an older template has no `BrE`: the plot shows `N/A`, and the page works
   as before.
2. **Motor idle (`JFXJ/MOTOR.lua`, menu item `7. Motor idle`).** A propeller
   warning first (ENTER continues, EXIT goes back). Then the page holds `GV8`
   at 100, so `L49`/`SF39` turn each throttle trim click into a `GV8` step
   instead of moving the trim (thermal camber stays put). The page adds the
   steps to the first point of `CV13 Pot` and sets `GV8` back to 100. The range
   is 0..100 (the template value is 99: on BW the `P1` dial sets the motor
   power, and `CV13` lifts the bottom of its range). The middle point keeps its
   ratio to the first point from when editing started (half if the idle was 0):
   the BW template is `99, 32, 0`, not half like the color templates, so the
   `P1` range keeps its shape. The +/- keys also change the value, which is the
   way on models from older templates. `EXIT` applies the last clicks and sets
   `GV8` to 0 at once. The menu's `background` runs on every cycle, also while
   the menu is on the screen, and sets `GV8` to 0 while no page is open, so it
   would drop the clicks counted since the last run. The page does not start
   the motor.

   Every GV write makes EdgeTX wait again before it saves the model.
   `cf.SetAdjust` used to write `GV8` on every call, and the menu's `background`
   calls it on every cycle while no page is open, so the model was saved only
   while a page that writes nothing was open. With the owner's OK,
   `cf.SetAdjust` in `JFXJcf.lua` and `JFXKcf.lua` now writes `GV8` only when it
   changes; in the simulator the model is saved about a second after a page
   closes.

`JFXJcf.luac` is a compiled copy of the menu. EdgeTX loads it unless
`JFXJcf.lua` is newer, so after a ZIP download (equal timestamps) radios would
show the old menu. `JF5Jsk.luac` predates the 2026-08-02 change to
`JF5Jsk.lua`. With the owner's OK, both are removed from the package; the README
tells users to delete them on the radio.

## GX12 Switch Layout

The owner chose the layout on 2026-10-30. Only logical-switch definitions
change; mixes, special functions, timers, and scripts already read logical
switches. The `gx12-*` files stay copies of the `pocket-*` files apart from the
model name and these definitions.

| Logical switch | Role | Pocket | GX12 |
| --- | --- | --- | --- |
| F5J `L5` | Motor arm | `SA2,NONE` | `SE2,NONE` |
| F5J `L9` | Motor start/stop | `SE2,L11` (OR) | `SG2,L11` (OR) |
| F5J `L7` | Crow and landing | `SD2,NONE` | `SF2,NONE` |
| F5J `L36` | Crow off | `SD0,NONE` | `!SF2,NONE` |
| F5J `L1`, `L2`, `L8` | Unused SA chains | `SA0,L19`, `SA2,!SA2`, `SA2,L1` | `SE0,L19`, `SE2,!SE2`, `SE2,L1` |
| F3K `L1` | Altitude calls | `SA2,L17` | `SE2,L17` |
| F3K `L7` | Launch | `SE2,L9` (OR) | `SG2,L9` (OR) |
| F3K `L8` | Brake | `SD2,NONE` | `SF2,NONE` |
| F3K `L35` | Crow off | `SD0,NONE` | `!SF2,NONE` |

`SB` (announcements), `SC` (flight modes), and `P1` (motor power) stay. `SF1`
is crow off. Launch is on `SG` in F3K as well, to match the F5J motor start.
The `SA`, `SD`, and `SH` buttons, the sliders, `P2`, and `SW1`-`SW6` are free.

## Documentation

The README describes the NONE default, the V-tail layout, the M-tail
differential, the elevator curve, the Motor idle page, and a corrected GX12
section (hardware from the manual, the switch table above). BW guides and
screenshots are a separate later step.

## Testing

- `tests/test_model_templates.lua`: exact mix signatures for M-tail `CH7`/`CH8`,
  V-tail `CH7`/`CH8`/`CH18`/`CH19`, and `CH22`; `CV14` points; `L46`/`L48`,
  `L49`, `SF14`, `SF39`, and `SF40`; GX12 equals Pocket apart from the name and
  the logical switches above.
- `make verify`.
- EdgeTX Companion 2.12 Pocket and GX12 simulators: channel outputs for the
  mixes and the compensation, the GX12 switches, and both pages.
