# F5J Logical Landing Controls Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Route Pocket F5J proportional crow, landing score entry, landing sounds, and flight-time announcements through dedicated logical switches.

**Architecture:** Keep `L7` as the SD-down landing-on signal, add `L12` as the SB-down time-announcement signal, and redefine the existing `BrkOff` gate `L36` as the SD-up crow-off signal. Mixes and special functions consume only those logical switches; the existing throttle-stick brake and surface mix chain remains unchanged.

**Tech Stack:** EdgeTX model YAML, Lua regression tests, GNU Make, Bash

---

### Task 1: Add Failing Logical-Control Regression Coverage

**Files:**
- Modify: `tests/test_model_templates.lua:787-880`

**Step 1: Require the new logical switches**

In `F5J variants keep the Sense behavior sets`, add logical-switch index `11`
to the expected set:

```lua
{ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "18", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "33", "34", "35", "36", "38", "39", "42", "43", "44" }
```

**Step 2: Require the physical-to-logical definitions**

In `F5J variants keep the Sense switch assignments`, add:

```lua
[11] = "SB2,NONE",
[35] = "SD0,NONE"
```

Then assert that `L12` and `L36` both use `FUNC_AND`:

```lua
for _, index in ipairs({ 11, 35 }) do
  assert_equal(scalar_field(indexed_block(content, "logicalSw", index), "func"), "FUNC_AND",
    variant.label .. " L" .. tostring(index + 1) .. " function")
end
```

**Step 3: Replace the voice-only test with the full consumer contract**

Replace `F5J variants map landing voice announcements to SD` with:

```lua
test("F5J variants route landing and time controls through logical switches", function()
  local special_functions = {
    [7] = { swtch = "L12", func = "PLAY_VALUE", def = "Tmr1,1,10", label = "time announcement" },
    [36] = { swtch = "L7", func = "PLAY_TRACK", def = "f3jlnd,1,1x", label = "landing on" },
    [37] = { swtch = "L36", func = "PLAY_TRACK", def = "crowof,1,1x", label = "landing off" }
  }

  for _, variant in ipairs(f5j_variants) do
    local content = read_file(variant.path)
    local brake = find_named_list_block(content, "expoData", 4, "Brake")
    assert_equal(scalar_field(brake, "srcRaw"), "Thr", variant.label .. " proportional crow source")

    local brake_off = find_mix_block_matching(mix_blocks_for(content, 20), { "name: BrkOff" })
    assert(brake_off, variant.label .. " missing BrkOff replacement mix")
    assert_equal(scalar_field(brake_off, "srcRaw"), "MAX", variant.label .. " BrkOff source")
    assert_equal(scalar_field(brake_off, "mltpx"), "REPL", variant.label .. " BrkOff multiplex")
    assert_equal(scalar_field(brake_off, "swtch"), "L36", variant.label .. " BrkOff logical switch")

    for index, expected in pairs(special_functions) do
      local custom_function = indexed_block(content, "customFn", index)
      assert_equal(scalar_field(custom_function, "swtch"), expected.swtch,
        variant.label .. " " .. expected.label .. " switch")
      assert_equal(scalar_field(custom_function, "func"), expected.func,
        variant.label .. " " .. expected.label .. " function")
      assert_equal(scalar_field(custom_function, "def"), expected.def,
        variant.label .. " " .. expected.label .. " definition")
    end
  end
end)
```

**Step 4: Run the template tests to verify they fail**

Run: `lua tests/test_model_templates.lua`

Expected: FAIL because logical switch block `11` (`L12`) is missing. The
consumer test would also report the old `L7` timer assignment and direct
physical landing sound assignments.

### Task 2: Implement the Logical Landing Controls

**Files:**
- Modify: `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-XTail.yml:1595-1765,1831-1942`
- Modify: `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-MTail.yml:1629-1799,1865-1976`
- Modify: `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-VTail.yml:1629-1799,1865-1976`
- Test: `tests/test_model_templates.lua`

**Step 1: Add logical switch L12 for SB-down time announcements**

Add this `logicalSw` block at index `11` in all three templates:

```yaml
   11:
      func: FUNC_AND
      def: "SB2,NONE"
      andsw: "NONE"
      lsPersist: 0
      lsState: 0
      delay: 0
      duration: 0
```

**Step 2: Redefine logical switch L36 as SD-up crow off**

Replace logical-switch block index `35` with:

```yaml
   35:
      func: FUNC_AND
      def: "SD0,NONE"
      andsw: "NONE"
      lsPersist: 0
      lsState: 0
      delay: 0
      duration: 0
```

Do not change the `BrkOff` replacement mix; it already consumes `L36`.

**Step 3: Assign the consumers to logical switches**

In each template, change:

```yaml
   7:
      swtch: "L12"
      func: PLAY_VALUE
      def: "Tmr1,1,10"
```

Use `swtch: "L7"` for custom function `36` (`f3jlnd`) and `swtch: "L36"`
for custom function `37` (`crowof`).

**Step 4: Run the template tests to verify they pass**

Run: `lua tests/test_model_templates.lua`

Expected: all model-template tests pass.

### Task 3: Document, Verify, and Commit

**Files:**
- Modify: `README.md:53-60`

**Step 1: Update the switch table**

Document F5J SB as the flight-time announcement control (`SB2` through `L12`).
Document F5J SD as proportional crow/landing on (`SD2` through `L7`) and crow
off (`SD0` through `L36`).

**Step 2: Inspect the complete diff**

Run:

```bash
git diff --check
git diff -- README.md tests/test_model_templates.lua dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-XTail.yml dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-MTail.yml dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-VTail.yml
```

Expected: no whitespace errors and only the approved logical-switch, consumer,
test, and documentation changes.

**Step 3: Run complete repository verification**

Run: `make verify`

Expected: exit 0, `lint ok`, all YAML/loading checks pass, and all Lua tests
pass.

**Step 4: Commit the correction**

```bash
git add README.md tests/test_model_templates.lua \
  dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-XTail.yml \
  dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-MTail.yml \
  dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-VTail.yml
git add -f docs/plans/2026-08-07-f5j-logical-landing-controls.md
git commit -s -m "fix: route F5J landing controls through logical switches"
```
