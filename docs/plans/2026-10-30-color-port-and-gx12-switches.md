# Color Port and GX12 Switch Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the October 2026 color-project template fixes, the brake elevator curve, and the Motor idle page to the BW package, and give the GX12 templates a switch layout that works with its buttons.

**Architecture:** The six F5J templates get text-level YAML edits in their own style; the `gx12-*` files are regenerated from the `pocket-*` files with the model name and a fixed set of logical-switch definitions replaced. The SoarOTX configuration menu gets a third airbrake plot and a seventh page; drawing stays in the `128x64/` and `212x64/` helpers loaded with `soarUtil.LoadWxH`.

**Tech Stack:** EdgeTX 2.12 model YAML, EdgeTX Lua 5.2 telemetry scripts, Lua 5.5 host tests, Ruby/Psych, GNU Make, EdgeTX Companion 2.12 simulator libraries.

**Spec:** `docs/plans/2026-10-30-color-port-and-gx12-switches-design.md`

## Global Constraints

- Nine GVs only (`GV1`-`GV9`); no new GVs. `GV5` and `GV7` in flight mode 1 (Adjust) are storage (help flag, battery threshold) and must not be used as scratch.
- New indices: curve 13 (`CV14 BrE`), logical switch 48 (`L49`), special functions 38 (`SF39`) and 39 (`SF40`), outputs 17/18 (`CH18 Rudd`, `CH19 Elev`).
- F5J templates use EdgeTX's native style (`" -"` list items, `"   N:"` indexes, quoted strings); F3K uses the compact style (`"  - "`, `"  N:"`, unquoted). Edits keep each file's style; zero points stay omitted.
- `gx12-*` = `pocket-*` with `Pocket` -> `GX12` in the model name and the logical-switch definitions from the design table; nothing else differs.
- `BrE` default points: `67, 17, -33, -83, -100`. Idle range 0..100; the middle point keeps its ratio to the idle from when editing started, `math.floor(ratio * idle + 0.5)` (ratio 0.5 if the idle was 0).
- No commits unless the owner asks.

## Review Focus

- A model made from an older template (no `BrE`, no `L49`/`SF39`/`SF40`): the airbrake page must not write curve 13 and must keep the old trim help; the Motor idle page must change the idle only with +/-.
- `GV8` already above 50 when the Motor idle page opens (a leftover count): treat it as no clicks, then hold 100.
- The first ENTER that opens the Motor idle page must not also dismiss its warning.
- GX12 `SF` in the middle (`SF1`): crow off and no landing call.
- V-tail with full rudder and full elevator: each servo gets at most 100%.

---

### Task 1: Pocket F5J template fixes and new items

**Files:**
- Modify: `tests/test_model_templates.lua`
- Modify: `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-{XTail,MTail,VTail}.yml`
- Modify (copy with the name changed): `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/gx12-F5J-{XTail,MTail,VTail}.yml`

**Interfaces:**
- Produces: curve 13 `BrE`; `L49` (`FUNC_VPOS`, `gv(7),50`); `SF39` (`L49`, `ADJUST_GVAR`, `7,Src,T3,1`); `SF14` def `3,Src,T4,1`; `SF40` (`L14`, `ADJUST_GVAR`, `2,Src,T2,1`).

- [ ] **Step 1: Write the failing tests**
  - `F5J variants keep the Sense behavior sets`: curves end with `"Pot", "BrE"`; logical-switch indexes add `"48"`.
  - New `F5J variants keep NONE mix switches off`: `L46` and `L48` defs are `!ON,NONE`.
  - `F5J variants start physical curves linear ...`: utility points from index 30 append `67, 17, -33, -83, -100`.
  - New `F5J variants shape the brake elevator compensation with BrE` (destCh 21):
    `src=I3|weight=gv(4)|switch=NONE|curve=0:0|trim=0|mux=ADD|fm=000000000|offset=gv(4)|name=MotEle`,
    `src=MAX|weight=10|switch=NONE|curve=0:0|trim=1|mux=MUL|fm=000000000|offset=0|name=MotEle`,
    `src=ch(20)|weight=gv(4)|switch=NONE|curve=3:14|trim=0|mux=ADD|fm=000000000|offset=gv(4)|name=BrkEle`,
    `src=MAX|weight=gv(4)|switch=NONE|curve=0:0|trim=0|mux=REPL|fm=111011111|offset=0|name=KAPOW`.
  - New `F5J variants map the setup trims`: `SF14` def `3,Src,T4,1`; `SF39` = `L49`/`ADJUST_GVAR`/`7,Src,T3,1`; `SF40` = `L14`/`ADJUST_GVAR`/`2,Src,T2,1`; `L49` = `FUNC_VPOS`/`gv(7),50`.
  - M-tail `AilEle` signatures get `curve=0:-50` (both channels, weights stay `20` and `-20`); `L46`/`L48` defaults become `!ON,NONE`.
  - V-tail: `CH6` none; `CH7` = `src=ch(17)|weight=50|...|name=Vt-l`, `src=ch(18)|weight=-50|...`; `CH8` = `src=ch(17)|weight=50|...`, `src=ch(18)|weight=50|...|name=Vt-R`; destCh 17 = `src=I0|weight=100|...|trim=0|...`, `src=I2|weight=gv(2)|...|trim=1|...|name=AilRud`; destCh 18 = `src=ch(21)|weight=100|...|fm=000000000|...`, `src=I1|weight=100|...|fm=000100000|...`; outputs 17/18 named `Rudd`/`Elev`.

- [ ] **Step 2: Run `lua tests/test_model_templates.lua`** — expected: the new and changed tests fail.

- [ ] **Step 3: Edit the three Pocket F5J templates** with a one-off script (scratchpad) that inserts and replaces blocks in the native style: curve 13 block after curve 12, points 73-77, `L49` after `L48`, `SF39`/`SF40` after `SF38`, `SF14` def, `CH22` lines, `L46`/`L48` defs, M-tail `AilEle` curves, V-tail `CH7`/`CH8` lines plus destCh 17/18 blocks before the first destCh 19 block, and outputs 17/18 between 11 and 19. Copy each to its `gx12-*` file with `name: "GX12 ..."`.

- [ ] **Step 4: Run `make test`** — expected: all pass.

### Task 2: GX12 switch layout

**Files:**
- Modify: `tests/test_model_templates.lua` (mirror test, new GX12 switch test)
- Modify: `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/gx12-F3K.yml`, `gx12-F5J-{XTail,MTail,VTail}.yml`

**Interfaces:**
- Consumes: Task 1 templates.

- [ ] **Step 1: Write the failing tests**
  - Replace `GX12 variants mirror the Pocket templates except for the model name` with `GX12 variants mirror the Pocket templates except name and switches`: `gx12` with its `logicalSw` section replaced by the Pocket one equals Pocket with the name replaced.
  - New `GX12 variants use the GX12 switch layout`: F5J `L1` `SE0,L19`, `L2` `SE2,!SE2`, `L5` `SE2,NONE`, `L7` `SF2,NONE`, `L8` `SE2,L1`, `L9` `SG2,L11`, `L36` `!SF2,NONE`, `L3`/`L4`/`L12` unchanged; F3K `L1` `SE2,L17`, `L7` `SG2,L9`, `L8` `SF2,NONE`, `L35` `!SF2,NONE`; no `SA`/`SD` source left in any GX12 `logicalSw`.

- [ ] **Step 2: Run `lua tests/test_model_templates.lua`** — expected: the two GX12 tests fail.

- [ ] **Step 3: Regenerate the four `gx12-*` files** from `pocket-*` (name + the defs above, in each file's quoting style).

- [ ] **Step 4: Run `make test`** — expected: all pass.

### Task 3: Airbrake page with the elevator curve

**Files:**
- Create: `tests/test_config_pages.lua` (EdgeTX API stubs, loads the page files with `loadfile`)
- Modify: `Makefile` (`lua tests/test_config_pages.lua` in `test`)
- Modify: `dist/SDCARD/SCRIPTS/TELEMETRY/JFXJ/BRKCRV.lua`, `128x64/JFXJ/BRKCRV.lua`, `212x64/JFXJ/BRKCRV.lua`

**Interfaces:**
- Produces: `ui.Draw(yFlp, yAil, yEle, point)` in both screen helpers; `yEle` is `nil` when the model has no `BrE`.

- [ ] **Step 1: Write the failing tests** in `tests/test_config_pages.lua`:
  - `airbrake page writes BrE from GV3 in the Adjust mode`: with curve 13 named `BrE`, step input at point 2 and `GV3` FM1 = 40, `run` stores curve 13 `y[2] = 40`.
  - `airbrake page keeps the brakes-off point of BrE at -100`: at point 5 with `GV3` FM1 = 10, curve 13 `y[5]` stays -100.
  - `airbrake page leaves models without BrE alone`: no curve 13 -> no `setCurve(13, ...)`, `Draw` gets `yEle = nil`, help `msg2` is `TrmT, TrmE - adjust`; with `BrE` it is `TrmT/A/E - adjust`.

- [ ] **Step 2: Run `lua tests/test_config_pages.lua`** — expected: FAIL.

- [ ] **Step 3: Implement** `CRV_ELE = 13` and `GV_ELE = 2` in `JFXJ/BRKCRV.lua` (valid when curve 13 is named `BrE` with five points); the 128x64 helper draws three plots 41 px wide with a `N/A` third column for `nil`; the 212x64 helper keeps its help text column and fits three 36 px plots.

- [ ] **Step 4: Run `make test`** — expected: all pass.

### Task 4: Motor idle page

**Files:**
- Modify: `tests/test_config_pages.lua`
- Create: `dist/SDCARD/SCRIPTS/TELEMETRY/JFXJ/MOTOR.lua`, `128x64/JFXJ/MOTOR.lua`, `212x64/JFXJ/MOTOR.lua`
- Modify: `dist/SDCARD/SCRIPTS/TELEMETRY/JFXJcf.lua` (`"7. Motor idle"`, `"/SCRIPTS/TELEMETRY/JFXJ/MOTOR.lua"`, `cf.SetAdjust`)
- Modify: `dist/SDCARD/SCRIPTS/TELEMETRY/JFXKcf.lua` (`cf.SetAdjust`)

**Interfaces:**
- Produces: `ui.DrawWarning()` and `ui.Draw(idle, trimFunction)` in both screen helpers; `idle` is `nil` when curve 12 is not the three-point `Pot` curve.

- [ ] **Step 1: Write the failing tests**:
  - `motor page waits for its own ENTER`: the opening `EVT_VIRTUAL_ENTER` on the first run shows the warning; a later ENTER starts editing and sets `GV8` FM0 to 100.
  - `motor page turns throttle trim clicks into idle steps`: template `99, 32, 0`, `GV8` = 97 -> curve 12 `y = {96, 31, 0}`, `GV8` back to 100; `GV8` = 102 -> `{98, 32, 0}`.
  - `motor page writes GV8 only after throttle trim clicks`: no GV write on a run without clicks (also after `+`); one write after `GV8` = 98.
  - `configuration menus write GV8 only when it changes`: `JFXJcf` and `JFXKcf` with `GV8` = 2, three `background` calls -> one write, `GV8` = 0.
  - `motor page ignores a leftover GV8 count`: `GV8` = 120 before editing -> no idle change, `GV8` = 100.
  - `motor page clamps the idle to 0..100` and `changes it with +/- without the trim function` (no `L49`/`SF39`: `GV8` is not touched).
  - `motor page releases the throttle trim on EXIT`: the last clicks are applied and `GV8` is 0.
  - `motor page shows N/A without the Pot curve`: no curve write, `GV8` untouched.
  - `configuration menu lists the Motor idle page` (`JFXJcf.lua` has the text and the file).

- [ ] **Step 2: Run `lua tests/test_config_pages.lua`** — expected: FAIL.

- [ ] **Step 3: Implement** the page with the color project's checks (`L49` `LS_FUNC_VPOS` on `gvar8` with 50, `SF39` `FUNC_ADJUST_GVAR` on param 7, mode source, value `trim-thr`, active, switch `L49`); on `EXIT` the page applies the last clicks and sets `GV8` to 0 itself, because the menu's `background` resets `GV8` on its next cycle and would drop them; `cf.SetAdjust` in both menus writes `GV8` only when it changes, because every GV write delays saving the model.

- [ ] **Step 4: Run `make verify`** — expected: all pass.

### Task 5: README and the compiled menu

**Files:**
- Modify: `README.md`

- [ ] **Step 1:** Update the M-tail mixes (NONE default, differential -50), add the V-tail layout, the elevator curve, the Motor idle page, and rewrite the GX12 section (hardware from the manual, the switch table).
- [ ] **Step 2:** Ask the owner to remove `dist/SDCARD/SCRIPTS/TELEMETRY/JFXJcf.luac` (and the stale `JF5Jsk.luac`); until then, note it in the README update instructions.
- [ ] **Step 3: Run `make verify`** — expected: all pass.

### Task 6: Simulator check

- [ ] **Step 1:** Pocket and GX12 libraries with each F5J template: `L48` off -> full rudder leaves M-tail `CH7`/`CH8`; V-tail elevator moves `CH7`/`CH8` opposite, rudder and aileron the same way; `CH22` with the new template equals the old one at brakes 0/25/50/75/100%.
- [ ] **Step 2:** GX12: `SE2` arms, `SG` starts and stops the motor, `SF2` enables crow, `SF0`/`SF1` force crow off.
- [ ] **Step 3:** Both pages on the 128x64 screen: three plots, trims move only the curves; Motor idle: warning, trim clicks change `CV13` and `CH3` at minimum motor, `GV8` back to 0 after EXIT.
