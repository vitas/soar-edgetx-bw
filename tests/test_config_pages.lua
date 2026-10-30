-- Host tests for the F5J configuration pages. The real utility library, menu, loader, pages and
-- screen helpers run against stubbed EdgeTX Lua APIs.

local SDCARD = "dist/SDCARD"
local SCREENS = { { w = 128, h = 64 }, { w = 212, h = 64 } }

local CONSTANTS = {
  EVT_VIRTUAL_ENTER = 1, EVT_VIRTUAL_EXIT = 2, EVT_VIRTUAL_MENU = 3, EVT_VIRTUAL_MENU_LONG = 4,
  EVT_VIRTUAL_INC = 5, EVT_VIRTUAL_DEC = 6, EVT_VIRTUAL_INC_REPT = 7, EVT_VIRTUAL_DEC_REPT = 8,
  EVT_VIRTUAL_NEXT = 9, EVT_VIRTUAL_PREV = 10, EVT_VIRTUAL_NEXT_REPT = 11, EVT_VIRTUAL_PREV_REPT = 12,
  SMLSIZE = 0x01, MIDSIZE = 0x02, DBLSIZE = 0x04, INVERS = 0x08, BLINK = 0x10, RIGHT = 0x20,
  CENTER = 0x40, PREC1 = 0x80, PREC2 = 0x100, SOLID = 0, DOTTED = 0x200, FORCE = 0x400, ERASE = 0x800,
  LS_FUNC_VPOS = 1, FUNC_ADJUST_GVAR = 5
}

-- Field and switch ids the pages look up with getFieldInfo and getSwitchIndex
local FIELD_IDS = { input8 = 8, gvar8 = 230, ["trim-thr"] = 90 }
local SWITCH_IDS = { L49 = 149 }

-- Indexes as in the F5J templates (0-based like the EdgeTX API)
local CRV_FLP, CRV_AIL, CRV_POT, CRV_ELE = 4, 5, 12, 13
local GV_FLP, GV_AIL, GV_ELE, GV_ADJ = 1, 3, 2, 7
local LS_TRIM, SF_TRIM = 48, 38
local FM_NORMAL, FM_ADJUST = 0, 1
local PAGE_BRAKES, PAGE_MOTOR = 3, 7

-- Step input values that select airbrake curve points 1, 2 and 5
local STEP_POINT = { [1] = -1024, [2] = -512, [5] = 1024 }

local tests = {}

local function test(name, fn)
  tests[#tests + 1] = { name = name, fn = fn }
end

local function assert_equal(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %q, got %q", label, tostring(expected), tostring(actual)), 0)
  end
end

local function assert_true(value, label)
  if not value then
    error(label, 0)
  end
end

local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value) do
    result[key] = copy(item)
  end
  return result
end

local function points(curve)
  return table.concat(curve.y, ",", 1, #curve.y)
end

local function contains(list, value)
  for _, item in ipairs(list) do
    if item == value then return true end
  end
  return false
end

-- An unused curve as EdgeTX returns it: no name, five zero points.
local EMPTY_CURVE = { name = "", type = 0, smooth = false, points = 5, y = { 0, 0, 0, 0, 0 } }

local function new_radio(screen)
  local radio = {
    time = 0,
    values = {},
    curves = {},
    curve_writes = {},
    gvars = {},
    gvar_writes = 0,
    logical_switches = {},
    functions = {},
    frame = {}
  }
  local env = setmetatable({}, { __index = _G })
  for name, value in pairs(CONSTANTS) do
    env[name] = value
  end
  env.LCD_W, env.LCD_H = screen.w, screen.h

  env.getVersion = function() return "2.12.0", "test", 2, 12, 0 end
  env.getTime = function() return radio.time end
  env.getDateTime = function() return { hour = 12, min = 0 } end
  env.getValue = function(id) return radio.values[id] or 0 end
  env.getFieldInfo = function(name)
    local id = FIELD_IDS[name]
    return id and { id = id, name = name }
  end
  env.getSwitchIndex = function(name) return SWITCH_IDS[name] end
  env.loadScript = function(path) return loadfile(SDCARD .. path, "t", env) end

  env.model = {
    getCurve = function(index) return copy(radio.curves[index] or EMPTY_CURVE) end,
    setCurve = function(index, curve)
      radio.curves[index] = copy(curve)
      radio.curve_writes[#radio.curve_writes + 1] = index
      return 0
    end,
    getGlobalVariable = function(index, fm) return (radio.gvars[fm] or {})[index] or 0 end,
    setGlobalVariable = function(index, fm, value)
      radio.gvars[fm] = radio.gvars[fm] or {}
      radio.gvars[fm][index] = value
      radio.gvar_writes = radio.gvar_writes + 1
    end,
    getLogicalSwitch = function(index) return copy(radio.logical_switches[index] or { func = 0 }) end,
    getCustomFunction = function(index) return copy(radio.functions[index] or { func = 0, switch = 0 }) end
  }

  -- The texts and numbers drawn since the last lcd.clear()
  local function draw(item) radio.frame[#radio.frame + 1] = item end
  local function ignore() end
  env.lcd = {
    clear = function() radio.frame = {} end,
    drawScreenTitle = function(title) draw(title) end,
    drawText = function(_, _, text) draw(tostring(text)) end,
    drawNumber = function(_, _, value) draw(value) end,
    drawLine = ignore,
    drawFilledRectangle = ignore,
    drawRectangle = ignore,
    drawPixmap = ignore
  }

  radio.env = env
  return radio
end

local function gv(radio, index, fm)
  return radio.env.model.getGlobalVariable(index, fm)
end

local function set_gv(radio, index, fm, value)
  radio.env.model.setGlobalVariable(index, fm, value)
end

-- Starts a configuration menu as the radio does: the utility library first, then the menu
-- (JFXJcf unless another one is named).
local function start_menu(radio, name)
  assert(radio.env.loadScript("/SCRIPTS/FUNCTIONS/JFutil.lua"))()
  local soarUtil = radio.env.soarUtil
  local show_help = soarUtil.ShowHelp
  soarUtil.ShowHelp = function(help)
    radio.help = help
    return show_help(help)
  end
  radio.menu = assert(radio.env.loadScript("/SCRIPTS/TELEMETRY/" .. (name or "JFXJcf") .. ".lua"))()
end

-- Selects a menu page and opens it with ENTER. The loader needs three more runs to sweep, load,
-- and initialize the page; the next run is the page's first.
local function open_page(radio, number)
  for _ = 2, number do
    radio.menu.run(CONSTANTS.EVT_VIRTUAL_NEXT)
  end
  radio.menu.run(CONSTANTS.EVT_VIRTUAL_ENTER)
  for _ = 1, 3 do
    radio.menu.run(0)
  end
end

local function shows(radio, text)
  return contains(radio.frame, text)
end

-- A model with the template airbrake curves; without_elevator leaves CV14 empty like older templates.
local function brake_radio(screen, without_elevator)
  local radio = new_radio(screen)
  radio.curves[CRV_FLP] = { name = "BrF", type = 0, smooth = false, points = 5, y = { -100, -50, 0, 50, 67 } }
  radio.curves[CRV_AIL] = { name = "BrA", type = 0, smooth = false, points = 5, y = { -40, -30, -20, -10, 0 } }
  if not without_elevator then
    radio.curves[CRV_ELE] = { name = "BrE", type = 0, smooth = false, points = 5, y = { 67, 17, -33, -83, -100 } }
  end
  set_gv(radio, GV_ELE, FM_ADJUST, 9)
  start_menu(radio)
  open_page(radio, PAGE_BRAKES)
  return radio
end

local function screen_label(screen, text)
  return string.format("%dx%d %s", screen.w, screen.h, text)
end

test("airbrake page writes BrE from GV3 in the Adjust mode", function()
  for _, screen in ipairs(SCREENS) do
    local radio = brake_radio(screen)
    radio.values[FIELD_IDS.input8] = STEP_POINT[2]
    radio.menu.run(0)
    assert_equal(gv(radio, GV_ADJ, FM_NORMAL), 2, screen_label(screen, "airbrake adjust mode"))
    assert_equal(gv(radio, GV_ELE, FM_ADJUST), 17, screen_label(screen, "GV3 starts at BrE point 2"))

    set_gv(radio, GV_ELE, FM_ADJUST, 40)
    radio.menu.run(0)
    assert_equal(points(radio.curves[CRV_ELE]), "67,40,-33,-83,-100", screen_label(screen, "BrE after the trim"))
    assert_equal(points(radio.curves[CRV_FLP]), "-100,-50,0,50,67", screen_label(screen, "BrF stays"))
    assert_equal(points(radio.curves[CRV_AIL]), "-40,-30,-20,-10,0", screen_label(screen, "BrA stays"))
    assert_true(shows(radio, "Elev") and not shows(radio, "N/A"), screen_label(screen, "elevator plot"))
    assert_equal(radio.help.msg2, "TrmT/A/E - adjust", screen_label(screen, "trim help"))
  end
end)

test("airbrake page keeps the brakes-off point of BrE at -100", function()
  for _, screen in ipairs(SCREENS) do
    local radio = brake_radio(screen)
    radio.values[FIELD_IDS.input8] = STEP_POINT[5]
    radio.menu.run(0)
    set_gv(radio, GV_ELE, FM_ADJUST, 10)
    set_gv(radio, GV_FLP, FM_ADJUST, 60)
    radio.menu.run(0)
    assert_equal(points(radio.curves[CRV_ELE]), "67,17,-33,-83,-100", screen_label(screen, "BrE at brakes off"))
    assert_equal(points(radio.curves[CRV_FLP]), "-100,-50,0,50,60", screen_label(screen, "BrF at brakes off"))

    radio.values[FIELD_IDS.input8] = STEP_POINT[1]
    radio.menu.run(0)
    assert_equal(gv(radio, GV_ELE, FM_ADJUST), 67, screen_label(screen, "GV3 follows the selected point"))
  end
end)

test("airbrake page leaves models without BrE alone", function()
  for _, screen in ipairs(SCREENS) do
    local radio = brake_radio(screen, true)
    radio.values[FIELD_IDS.input8] = STEP_POINT[2]
    radio.menu.run(0)
    assert_equal(gv(radio, GV_ELE, FM_ADJUST), 9, screen_label(screen, "GV3 untouched"))
    set_gv(radio, GV_AIL, FM_ADJUST, -25)
    radio.menu.run(0)
    assert_equal(points(radio.curves[CRV_AIL]), "-40,-25,-20,-10,0", screen_label(screen, "BrA after the trim"))
    assert_true(not contains(radio.curve_writes, CRV_ELE), screen_label(screen, "CV14 not written"))
    assert_true(shows(radio, "N/A"), screen_label(screen, "elevator plot shows N/A"))
    assert_equal(radio.help.msg2, "TrmT, TrmE - adjust", screen_label(screen, "old trim help"))
  end
end)

-- A model with the template Pot curve and the L49/SF39 throttle trim function. Options:
-- pot (curve points), without_pot, without_trim (older templates), gv8 (GV8 before the menu starts).
local function motor_radio(screen, options)
  options = options or {}
  local radio = new_radio(screen)
  if not options.without_pot then
    radio.curves[CRV_POT] = {
      name = "Pot", type = 1, smooth = false, points = 3, x = { -100, 0, 100 }, y = options.pot or { 99, 32, 0 }
    }
  end
  if not options.without_trim then
    radio.logical_switches[LS_TRIM] = { func = CONSTANTS.LS_FUNC_VPOS, v1 = FIELD_IDS.gvar8, v2 = 50 }
    radio.functions[SF_TRIM] = {
      switch = SWITCH_IDS.L49, func = CONSTANTS.FUNC_ADJUST_GVAR, value = FIELD_IDS["trim-thr"],
      mode = 1, param = 7, active = 1
    }
  end
  if options.gv8 then
    set_gv(radio, GV_ADJ, FM_NORMAL, options.gv8)
  end
  start_menu(radio)
  open_page(radio, PAGE_MOTOR)
  return radio
end

-- Shows the propeller warning once, then accepts it
local function start_editing(radio)
  radio.menu.run(0)
  radio.menu.run(CONSTANTS.EVT_VIRTUAL_ENTER)
end

test("configuration menu lists the Motor idle page", function()
  for _, screen in ipairs(SCREENS) do
    local radio = new_radio(screen)
    start_menu(radio)
    for _ = 2, PAGE_MOTOR do
      radio.menu.run(CONSTANTS.EVT_VIRTUAL_NEXT)
    end
    assert_true(shows(radio, "7. Motor idle"), screen_label(screen, "menu item"))
  end
end)

test("configuration menus write GV8 only when it changes", function()
  for _, name in ipairs({ "JFXJcf", "JFXKcf" }) do
    for _, screen in ipairs(SCREENS) do
      local radio = new_radio(screen)
      set_gv(radio, GV_ADJ, FM_NORMAL, 2)
      start_menu(radio, name)
      radio.gvar_writes = 0
      for _ = 1, 3 do
        radio.menu.background()
      end
      local label = screen_label(screen, name)
      assert_equal(gv(radio, GV_ADJ, FM_NORMAL), 0, label .. " GV8 released")
      assert_equal(radio.gvar_writes, 1, label .. " GV writes")
    end
  end
end)

test("motor page waits for its own ENTER", function()
  for _, screen in ipairs(SCREENS) do
    local radio = motor_radio(screen)
    radio.menu.run(CONSTANTS.EVT_VIRTUAL_ENTER)
    assert_true(shows(radio, "WARNING"), screen_label(screen, "warning after an early ENTER"))
    assert_equal(gv(radio, GV_ADJ, FM_NORMAL), 0, screen_label(screen, "GV8 during the warning"))

    radio.menu.run(CONSTANTS.EVT_VIRTUAL_ENTER)
    assert_true(shows(radio, "Idle") and not shows(radio, "WARNING"), screen_label(screen, "editing"))
    assert_equal(gv(radio, GV_ADJ, FM_NORMAL), 100, screen_label(screen, "GV8 holds the throttle trim"))
  end
end)

test("motor page turns throttle trim clicks into idle steps", function()
  for _, screen in ipairs(SCREENS) do
    local radio = motor_radio(screen)
    start_editing(radio)
    set_gv(radio, GV_ADJ, FM_NORMAL, 97)
    radio.menu.run(0)
    assert_equal(points(radio.curves[CRV_POT]), "96,31,0", screen_label(screen, "Pot after three clicks down"))
    assert_equal(gv(radio, GV_ADJ, FM_NORMAL), 100, screen_label(screen, "GV8 after the clicks"))

    set_gv(radio, GV_ADJ, FM_NORMAL, 102)
    radio.menu.run(0)
    assert_equal(points(radio.curves[CRV_POT]), "98,32,0", screen_label(screen, "Pot after two clicks up"))
    assert_equal(table.concat(radio.curves[CRV_POT].x, ","), "-100,0,100", screen_label(screen, "Pot x"))
    assert_true(contains(radio.frame, 98), screen_label(screen, "idle on the screen"))

    radio.menu.run(CONSTANTS.EVT_VIRTUAL_INC)
    assert_equal(points(radio.curves[CRV_POT]), "99,32,0", screen_label(screen, "Pot after +"))
  end
end)

-- Every GV write restarts the radio's delay before it saves the model
test("motor page writes GV8 only after throttle trim clicks", function()
  for _, screen in ipairs(SCREENS) do
    local radio = motor_radio(screen)
    start_editing(radio)
    radio.gvar_writes = 0
    radio.menu.run(0)
    radio.menu.run(CONSTANTS.EVT_VIRTUAL_INC)
    assert_equal(radio.gvar_writes, 0, screen_label(screen, "GV writes without clicks"))

    set_gv(radio, GV_ADJ, FM_NORMAL, 98)
    radio.gvar_writes = 0
    radio.menu.run(0)
    assert_equal(radio.gvar_writes, 1, screen_label(screen, "GV writes after two clicks"))
    assert_equal(points(radio.curves[CRV_POT]), "98,32,0", screen_label(screen, "Pot after + and two clicks"))
  end
end)

test("motor page ignores a leftover GV8 count", function()
  for _, screen in ipairs(SCREENS) do
    local radio = motor_radio(screen, { gv8 = 120 })
    start_editing(radio)
    assert_equal(gv(radio, GV_ADJ, FM_NORMAL), 100, screen_label(screen, "GV8 reset"))
    radio.menu.run(0)
    assert_equal(points(radio.curves[CRV_POT]), "99,32,0", screen_label(screen, "Pot unchanged"))
  end
end)

test("motor page clamps the idle to 0..100", function()
  for _, screen in ipairs(SCREENS) do
    local radio = motor_radio(screen)
    start_editing(radio)
    set_gv(radio, GV_ADJ, FM_NORMAL, 105)
    radio.menu.run(0)
    assert_equal(points(radio.curves[CRV_POT]), "100,32,0", screen_label(screen, "Pot at the top"))

    radio = motor_radio(screen, { pot = { 2, 1, 0 } })
    start_editing(radio)
    set_gv(radio, GV_ADJ, FM_NORMAL, 95)
    radio.menu.run(0)
    radio.menu.run(CONSTANTS.EVT_VIRTUAL_DEC)
    assert_equal(points(radio.curves[CRV_POT]), "0,0,0", screen_label(screen, "Pot at the bottom"))
  end
end)

test("motor page changes the idle with +/- without the trim function", function()
  for _, screen in ipairs(SCREENS) do
    local radio = motor_radio(screen, { without_trim = true })
    start_editing(radio)
    assert_equal(gv(radio, GV_ADJ, FM_NORMAL), 0, screen_label(screen, "GV8 untouched"))
    radio.menu.run(CONSTANTS.EVT_VIRTUAL_INC_REPT)
    radio.menu.run(CONSTANTS.EVT_VIRTUAL_DEC)
    radio.menu.run(CONSTANTS.EVT_VIRTUAL_DEC_REPT)
    assert_equal(points(radio.curves[CRV_POT]), "98,32,0", screen_label(screen, "Pot after +--"))

    set_gv(radio, GV_ADJ, FM_NORMAL, 103)
    radio.menu.run(0)
    assert_equal(points(radio.curves[CRV_POT]), "98,32,0", screen_label(screen, "GV8 is no trim count"))
    assert_equal(gv(radio, GV_ADJ, FM_NORMAL), 103, screen_label(screen, "GV8 still untouched"))
  end
end)

test("motor page releases the throttle trim on EXIT", function()
  for _, screen in ipairs(SCREENS) do
    local radio = motor_radio(screen)
    start_editing(radio)
    set_gv(radio, GV_ADJ, FM_NORMAL, 99)
    radio.menu.run(CONSTANTS.EVT_VIRTUAL_EXIT)
    assert_equal(points(radio.curves[CRV_POT]), "98,32,0", screen_label(screen, "last click applied"))
    assert_equal(gv(radio, GV_ADJ, FM_NORMAL), 0, screen_label(screen, "GV8 released"))
    radio.menu.run(0)
    assert_true(shows(radio, "7. Motor idle"), screen_label(screen, "back in the menu"))
  end
end)

test("motor page shows N/A without the Pot curve", function()
  for _, screen in ipairs(SCREENS) do
    local radio = motor_radio(screen, { without_pot = true })
    start_editing(radio)
    radio.menu.run(CONSTANTS.EVT_VIRTUAL_INC)
    assert_true(shows(radio, "N/A"), screen_label(screen, "idle N/A"))
    assert_equal(gv(radio, GV_ADJ, FM_NORMAL), 0, screen_label(screen, "GV8 untouched"))
    assert_true(not contains(radio.curve_writes, CRV_POT), screen_label(screen, "CV13 not written"))
  end
end)

print("1.." .. tostring(#tests))
local failures = 0
for index, case in ipairs(tests) do
  local ok, message = pcall(case.fn)
  if ok then
    print("ok " .. tostring(index) .. " - " .. case.name)
  else
    failures = failures + 1
    print("not ok " .. tostring(index) .. " - " .. case.name)
    print("  ---")
    print("  message: " .. tostring(message):gsub("\n", " "))
    print("  ...")
  end
end

if failures > 0 then os.exit(1) end
