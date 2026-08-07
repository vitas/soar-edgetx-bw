# F5J Landing Voice Switches Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make every Pocket F5J template announce landing on SD down and landing off on SD up without changing score-entry behavior.

**Architecture:** Keep the existing `L7 = SD2` logical switch and Lua score-keeper flow intact. Correct only the two voice special-function switch fields in each template, protect the mapping with a shared template regression test, and document both physical positions.

**Tech Stack:** EdgeTX model YAML, Lua regression tests, GNU Make, Bash

---

### Task 1: Add the Failing Landing Voice Regression Test

**Files:**
- Modify: `tests/test_model_templates.lua:841`

**Step 1: Write the failing test**

Add this test after `F5J variants keep the Sense switch assignments`:

```lua
test("F5J variants map landing voice announcements to SD", function()
  local announcements = {
    [36] = { swtch = "SD2", track = "f3jlnd,1,1x", label = "landing on" },
    [37] = { swtch = "SD0", track = "crowof,1,1x", label = "landing off" }
  }

  for _, variant in ipairs(f5j_variants) do
    local content = read_file(variant.path)
    for index, expected in pairs(announcements) do
      local custom_function = indexed_block(content, "customFn", index)
      assert_equal(scalar_field(custom_function, "swtch"), expected.swtch,
        variant.label .. " " .. expected.label .. " switch")
      assert_equal(scalar_field(custom_function, "func"), "PLAY_TRACK",
        variant.label .. " " .. expected.label .. " function")
      assert_equal(scalar_field(custom_function, "def"), expected.track,
        variant.label .. " " .. expected.label .. " track")
    end
  end
end)
```

**Step 2: Run the test to verify it fails**

Run: `lua tests/test_model_templates.lua`

Expected: FAIL in `F5J variants map landing voice announcements to SD`, reporting that the landing-on switch is `L35` instead of `SD2`.

### Task 2: Correct All F5J Template Voice Assignments

**Files:**
- Modify: `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-XTail.yml:1935`
- Modify: `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-MTail.yml:1969`
- Modify: `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-VTail.yml:1969`
- Test: `tests/test_model_templates.lua`

**Step 1: Change the landing-on special functions**

In `customFn` block `36` of every F5J template, replace:

```yaml
swtch: "L35"
```

with:

```yaml
swtch: "SD2"
```

Keep `func: PLAY_TRACK` and `def: "f3jlnd,1,1x"` unchanged.

**Step 2: Change the landing-off special functions**

In `customFn` block `37` of every F5J template, replace:

```yaml
swtch: "L45"
```

with:

```yaml
swtch: "SD0"
```

Keep `func: PLAY_TRACK` and `def: "crowof,1,1x"` unchanged.

**Step 3: Run the regression test to verify it passes**

Run: `lua tests/test_model_templates.lua`

Expected: PASS for every test, including `F5J variants map landing voice announcements to SD`.

### Task 3: Document and Verify the Corrected Mapping

**Files:**
- Modify: `README.md:56`

**Step 1: Update the F5J SD switch documentation**

Change the F5J SD table entry to state that `SD2` ends the flight, opens score entry, and announces landing, while `SD0` announces landing off/crow off.

**Step 2: Inspect the focused diff**

Run:

```bash
git diff --check
git diff -- README.md tests/test_model_templates.lua dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-XTail.yml dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-MTail.yml dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-VTail.yml
```

Expected: no whitespace errors and only the requested switch, test, and documentation changes.

**Step 3: Run complete verification**

Run: `make verify`

Expected: exit 0, `lint ok`, all YAML checks pass, and all Lua regression tests pass.

**Step 4: Commit the fix**

```bash
git add README.md tests/test_model_templates.lua \
  dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-XTail.yml \
  dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-MTail.yml \
  dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-VTail.yml
git add -f docs/plans/2026-08-07-f5j-landing-voice-switches.md
git commit -s -m "fix: correct F5J landing voice switches"
```
