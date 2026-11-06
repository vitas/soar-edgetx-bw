-- Host tests for the F5J configuration pages and the F5J score keeper. The real utility library,
-- menu, loader, pages, screen helpers and score keeper run against stubbed EdgeTX Lua APIs.

local SDCARD = "dist/SDCARD"
local SCREENS = { { w = 128, h = 64 }, { w = 212, h = 64 } }

local CONSTANTS = {
  EVT_VIRTUAL_ENTER = 1, EVT_VIRTUAL_EXIT = 2, EVT_VIRTUAL_MENU = 3, EVT_VIRTUAL_MENU_LONG = 4,
  EVT_VIRTUAL_INC = 5, EVT_VIRTUAL_DEC = 6, EVT_VIRTUAL_INC_REPT = 7, EVT_VIRTUAL_DEC_REPT = 8,
  EVT_VIRTUAL_NEXT = 9, EVT_VIRTUAL_PREV = 10, EVT_VIRTUAL_NEXT_REPT = 11, EVT_VIRTUAL_PREV_REPT = 12,
  SMLSIZE = 0x01, MIDSIZE = 0x02, DBLSIZE = 0x04, INVERS = 0x08, BLINK = 0x10, RIGHT = 0x20,
  CENTER = 0x40, PREC1 = 0x80, PREC2 = 0x100, SOLID = 0, DOTTED = 0x200, FORCE = 0x400, ERASE = 0x800,
  LS_FUNC_VPOS = 1, LS_FUNC_AND = 8, LS_FUNC_OR = 9, LS_FUNC_STICKY = 18, FUNC_ADJUST_GVAR = 5,
  CHAR_UP = "\192", CHAR_DOWN = "\193"
}
local UP, DOWN = CONSTANTS.CHAR_UP, CONSTANTS.CHAR_DOWN

-- Field ids the pages and the score keeper look up with getFieldInfo
local FIELD_IDS = {
  input8 = 8, gvar8 = 230, ["trim-thr"] = 90, ls1 = 301, ls7 = 307, ls8 = 308, ls9 = 309, ls23 = 323
}

-- Switches as switches() lists them on a B&W radio: two- and three-position switches, mixed with
-- trims, logical switches, a flight mode and ON, which the Switches page does not offer
local SWITCH_POSITIONS = {
  { 1, "SA" .. UP }, { 3, "SA" .. DOWN },
  { 4, "SB" .. UP }, { 5, "SB-" }, { 6, "SB" .. DOWN },
  { 7, "SC" .. UP }, { 8, "SC-" }, { 9, "SC" .. DOWN },
  { 10, "SD" .. UP }, { 12, "SD" .. DOWN },
  { 13, "SE" .. UP }, { 15, "SE" .. DOWN },
  { 16, "SF" .. UP }, { 17, "SF-" }, { 18, "SF" .. DOWN },
  { 19, "SG" .. UP }, { 21, "SG" .. DOWN },
  { 50, "Tr1-" }, { 51, "Tr1+" },
  { 100, "L1" }, { 149, "L49" }, { 180, "FM2" }, { 200, "ON" }
}

-- Switch ids the pages look up with getSwitchIndex; a "!" turns the id negative as in EdgeTX
local SWITCH_IDS = { ["!ON"] = -200 }
for _, position in ipairs(SWITCH_POSITIONS) do
  SWITCH_IDS[position[2]] = position[1]
end

-- Indexes as in the F5J templates (0-based like the EdgeTX API)
local CRV_FLP, CRV_AIL, CRV_POT, CRV_ELE = 4, 5, 12, 13
local GV_FLP, GV_AIL, GV_ELE, GV_ADJ = 1, 3, 2, 7
local LS_TRIM, SF_TRIM = 48, 38
local FM_NORMAL, FM_ADJUST = 0, 1
local PAGE_ALIGN, PAGE_BRAKES, PAGE_MOTOR, PAGE_SWITCHES = 2, 3, 7, 8

-- The wing outputs CH1, CH2, CH4 and CH5 and the alignment curves they use
local WING = {
  { output = 0, name = "Ai-L", curve = 0, curve_name = "LA" },
  { output = 1, name = "Ai-R", curve = 1, curve_name = "RA" },
  { output = 3, name = "Fl-L", curve = 2, curve_name = "LF" },
  { output = 4, name = "Fl-R", curve = 3, curve_name = "RF" }
}

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

-- An output without a curve as EdgeTX returns it for each of the 32 channels.
local DEFAULT_OUTPUT = { name = "", min = -1000, max = 1000, offset = 0, ppmCenter = 0, symetrical = 0, revert = 0 }

local function new_radio(screen)
  local radio = {
    time = 0,
    values = {},
    curves = {},
    curve_writes = {},
    outputs = {},
    output_writes = {},
    gvars = {},
    gvar_writes = 0,
    logical_switches = {},
    ls_writes = {},
    functions = {},
    timers = {},
    fm = 0,
    played = {},
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
  env.getSwitchName = function(index)
    for _, position in ipairs(SWITCH_POSITIONS) do
      if position[1] == index then return position[2] end
      if position[1] == -index then return "!" .. position[2] end
    end
    return nil
  end
  -- As in EdgeTX 2.12, switches() starts with the inverted switches, from the last one back
  env.switches = function()
    local list = {}
    for i = #SWITCH_POSITIONS, 1, -1 do
      list[#list + 1] = { -SWITCH_POSITIONS[i][1], "!" .. SWITCH_POSITIONS[i][2] }
    end
    for _, position in ipairs(SWITCH_POSITIONS) do
      list[#list + 1] = position
    end
    local i = 0
    return function()
      i = i + 1
      local position = list[i]
      if position then return position[1], position[2] end
    end
  end
  env.loadScript = function(path) return loadfile(SDCARD .. path, "t", env) end
  env.getFlightMode = function() return radio.fm, "" end
  local function play(kind) return function() radio.played[#radio.played + 1] = kind end end
  env.playNumber, env.playDuration = play("number"), play("duration")
  env.playFile, env.playHaptic = play("file"), play("haptic")

  env.model = {
    getCurve = function(index) return copy(radio.curves[index] or EMPTY_CURVE) end,
    setCurve = function(index, curve)
      radio.curves[index] = copy(curve)
      radio.curve_writes[#radio.curve_writes + 1] = index
      return 0
    end,
    getOutput = function(index)
      if index < 0 or index > 31 then return nil end
      return copy(radio.outputs[index] or DEFAULT_OUTPUT)
    end,
    setOutput = function(index, output)
      radio.outputs[index] = copy(output)
      radio.output_writes[#radio.output_writes + 1] = index
    end,
    getGlobalVariable = function(index, fm) return (radio.gvars[fm] or {})[index] or 0 end,
    setGlobalVariable = function(index, fm, value)
      radio.gvars[fm] = radio.gvars[fm] or {}
      radio.gvars[fm][index] = value
      radio.gvar_writes = radio.gvar_writes + 1
    end,
    getLogicalSwitch = function(index) return copy(radio.logical_switches[index] or { func = 0 }) end,
    setLogicalSwitch = function(index, ls)
      radio.logical_switches[index] = copy(ls)
      radio.ls_writes[#radio.ls_writes + 1] = index
    end,
    getCustomFunction = function(index) return copy(radio.functions[index] or { func = 0, switch = 0 }) end,
    getTimer = function(index) return copy(radio.timers[index] or { start = 0, value = 0 }) end,
    setTimer = function(index, timer)
      radio.timers[index] = radio.timers[index] or { start = 0, value = 0 }
      for key, value in pairs(timer) do
        radio.timers[index][key] = value
      end
    end,
    getSensor = function() return { name = "" } end,
    resetSensor = function() end
  }

  -- The texts and numbers drawn since the last lcd.clear(), and the last blinking text
  local function draw(item) radio.frame[#radio.frame + 1] = item end
  local function ignore() end
  env.lcd = {
    clear = function()
      radio.frame = {}
      radio.blinking = nil
    end,
    drawScreenTitle = function(title) draw(title) end,
    drawText = function(_, _, text, flags)
      draw(tostring(text))
      if flags and math.floor(flags / CONSTANTS.BLINK) % 2 == 1 then
        radio.blinking = tostring(text)
      end
    end,
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

-- A model whose wing outputs are aligned away from neutral; left_aileron replaces the points of the
-- left aileron curve.
local function wing_radio(screen, left_aileron)
  local radio = new_radio(screen)
  for _, wing in ipairs(WING) do
    local y = (wing.curve == 0 and left_aileron) or { -100, -40, 10, 60, 100 }
    radio.curves[wing.curve] = { name = wing.curve_name, type = 0, smooth = true, points = 5, y = y }
    radio.outputs[wing.output] = {
      name = wing.name, min = -900, max = 950, offset = 30, ppmCenter = 0, symetrical = 0, revert = 0,
      curve = wing.curve
    }
  end
  start_menu(radio)
  open_page(radio, PAGE_ALIGN)
  return radio
end

-- True if a text on the screen mentions a reset
local function asks_reset(radio)
  for _, item in ipairs(radio.frame) do
    if type(item) == "string" and item:lower():find("reset", 1, true) then
      return true
    end
  end
  return false
end

-- Numbers as text; whole floats print like the radio's integers
local function numbers(list)
  local texts = {}
  for index, value in ipairs(list) do
    texts[index] = string.format("%g", value)
  end
  return table.concat(texts, ",")
end

test("alignment page asks before it resets the wing outputs", function()
  for _, screen in ipairs(SCREENS) do
    local radio = wing_radio(screen)
    radio.menu.run(0)
    assert_true(shows(radio, "LA") and not asks_reset(radio), screen_label(screen, "curves"))

    radio.menu.run(CONSTANTS.EVT_VIRTUAL_ENTER)
    assert_true(asks_reset(radio) and not shows(radio, "LA"), screen_label(screen, "reset question"))

    radio.menu.run(CONSTANTS.EVT_VIRTUAL_EXIT)
    assert_true(shows(radio, "LA") and not asks_reset(radio), screen_label(screen, "curves after EXIT"))
    assert_equal(#radio.curve_writes + #radio.output_writes, 0, screen_label(screen, "writes"))
  end
end)

test("alignment page resets the wing outputs after a second ENTER", function()
  for _, screen in ipairs(SCREENS) do
    local radio = wing_radio(screen)
    radio.menu.run(CONSTANTS.EVT_VIRTUAL_ENTER)
    radio.menu.run(CONSTANTS.EVT_VIRTUAL_ENTER)
    for _, wing in ipairs(WING) do
      local out = radio.outputs[wing.output]
      local label = screen_label(screen, wing.name)
      assert_equal(numbers(radio.curves[wing.curve].y), "-100,-50,0,50,100", label .. " curve")
      assert_equal(numbers({ out.min, out.offset, out.max }), "-1000,0,1000", label .. " output")
    end
    assert_true(shows(radio, "LA") and not asks_reset(radio), screen_label(screen, "curves after the reset"))
  end
end)

test("alignment page offers a reset for wing outputs that fail the checks", function()
  for _, screen in ipairs(SCREENS) do
    local radio = wing_radio(screen, { -100, 20, 10, 60, 100 })
    radio.menu.run(0)
    assert_true(asks_reset(radio) and not shows(radio, "LA"), screen_label(screen, "reset offer"))

    radio.menu.run(CONSTANTS.EVT_VIRTUAL_EXIT)
    radio.menu.run(0)
    assert_true(shows(radio, "2. Align flaps & ailerons"), screen_label(screen, "back in the menu"))
    assert_equal(#radio.curve_writes + #radio.output_writes, 0, screen_label(screen, "writes"))
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

-- Logical switches the Switches page writes (0-based like the EdgeTX API)
local LS_ARM, LS_SPEED, LS_LANDING, LS_TIME = 4, 2, 6, 11
local LS_CROW_OFF, LS_AIL_ELE, LS_RUD_ELE, LS_ARM_TOGGLE, LS_THROTTLE_CROW = 35, 45, 47, 40, 49

-- A model with the switches of the F5J templates, as on the Pocket or, with gx12, on the GX12.
-- Options: without_throttle_crow (older templates without L50), switches (more logical switches).
local function switch_radio(screen, gx12, options)
  options = options or {}
  local radio = new_radio(screen)
  local AND, OR = CONSTANTS.LS_FUNC_AND, CONSTANTS.LS_FUNC_OR
  local ls = radio.logical_switches
  local function sw(name) return SWITCH_IDS[name] end

  ls[LS_ARM] = { func = AND, v1 = sw("SA" .. DOWN), v2 = 0 }
  ls[8] = { func = OR, v1 = sw("SE" .. DOWN), v2 = 111 }
  ls[LS_SPEED] = { func = AND, v1 = sw("SC" .. UP), v2 = 0 }
  ls[3] = { func = AND, v1 = sw("SC" .. DOWN), v2 = 0 }
  ls[LS_LANDING] = { func = AND, v1 = sw("SD" .. DOWN), v2 = 0 }
  ls[LS_CROW_OFF] = { func = AND, v1 = sw("SD" .. UP), v2 = 0 }
  ls[LS_AIL_ELE] = { func = AND, v1 = sw("!ON"), v2 = 0 }
  ls[LS_RUD_ELE] = { func = AND, v1 = sw("!ON"), v2 = 0 }
  ls[LS_TIME] = { func = AND, v1 = sw("SB" .. DOWN), v2 = 0 }
  if not options.without_throttle_crow then
    ls[LS_THROTTLE_CROW] = { func = AND, v1 = sw("!ON"), v2 = 0 }
  end
  if gx12 then
    -- The GX12 arming is a sticky switch that each press on L41 flips
    ls[LS_ARM] = { func = CONSTANTS.LS_FUNC_STICKY, v1 = 141, v2 = 133 }
    ls[LS_ARM_TOGGLE] = { func = OR, v1 = sw("SA" .. DOWN), v2 = 142 }
    ls[8] = { func = OR, v1 = sw("SG" .. DOWN), v2 = 111 }
    ls[LS_SPEED] = { func = AND, v1 = sw("SF" .. UP), v2 = 0 }
    ls[3] = { func = AND, v1 = sw("SF" .. DOWN), v2 = 0 }
    ls[LS_TIME] = { func = AND, v1 = sw("SC" .. DOWN), v2 = 0 }
  end
  for index, value in pairs(options.switches or {}) do
    ls[index] = value
  end
  start_menu(radio)
  open_page(radio, PAGE_SWITCHES)
  radio.menu.run(0)
  return radio
end

local function press(radio, event, times)
  for _ = 1, times or 1 do
    radio.menu.run(event)
  end
end

-- Turns the wheel while choosing until the blinking switch is name
local function choose(radio, name)
  for _ = 1, 2 * #SWITCH_POSITIONS do
    if radio.blinking == name then return end
    radio.menu.run(CONSTANTS.EVT_VIRTUAL_NEXT)
  end
  error("cannot choose " .. name, 0)
end

test("configuration menu lists the Switches page", function()
  for _, screen in ipairs(SCREENS) do
    local radio = new_radio(screen)
    start_menu(radio)
    press(radio, CONSTANTS.EVT_VIRTUAL_NEXT, PAGE_SWITCHES - 1)
    assert_true(shows(radio, "8. Switches"), screen_label(screen, "menu item"))
  end
end)

test("switches page shows the switch of each row", function()
  for _, screen in ipairs(SCREENS) do
    local radio = switch_radio(screen)
    for _, text in ipairs({ "Switches", "Motor arm", "SA" .. DOWN, "Motor/timer", "SE" .. DOWN, "Speed",
      "SC" .. UP, "Float", "SC" .. DOWN, "Landing", "SD" .. DOWN, "Crow off", "SD" .. UP }) do
      assert_true(shows(radio, text), screen_label(screen, "shows " .. text))
    end
    assert_true(not shows(radio, "Timer report"), screen_label(screen, "six rows on the screen"))

    press(radio, CONSTANTS.EVT_VIRTUAL_NEXT, 8)
    for _, text in ipairs({ "Ail->Ele", "NONE", "Rud->Ele", "Timer report", "SB" .. DOWN }) do
      assert_true(shows(radio, text), screen_label(screen, "after scrolling shows " .. text))
    end
    assert_equal(#radio.ls_writes, 0, screen_label(screen, "writes"))
  end
end)

-- As on the color screens, the list offers the inverted positions too, in the order switches()
-- lists them, but no trims, logical switches or flight modes
test("switches page offers NONE, ON and the inverted and plain switch positions", function()
  for _, screen in ipairs(SCREENS) do
    local radio = switch_radio(screen)
    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    local offered = {}
    for _ = 1, 2 * #SWITCH_POSITIONS do
      offered[#offered + 1] = radio.blinking
      press(radio, CONSTANTS.EVT_VIRTUAL_NEXT)
      if radio.blinking == offered[1] then break end
    end
    assert_equal(table.concat(offered, " "), table.concat({
      "SA" .. DOWN, "SB" .. UP, "SB-", "SB" .. DOWN, "SC" .. UP, "SC-", "SC" .. DOWN, "SD" .. UP,
      "SD" .. DOWN, "SE" .. UP, "SE" .. DOWN, "SF" .. UP, "SF-", "SF" .. DOWN, "SG" .. UP, "SG" .. DOWN,
      "NONE", "ON",
      "!SG" .. DOWN, "!SG" .. UP, "!SF" .. DOWN, "!SF-", "!SF" .. UP, "!SE" .. DOWN, "!SE" .. UP,
      "!SD" .. DOWN, "!SD" .. UP, "!SC" .. DOWN, "!SC-", "!SC" .. UP, "!SB" .. DOWN, "!SB-", "!SB" .. UP,
      "!SA" .. DOWN, "!SA" .. UP,
      "SA" .. UP }, " "), screen_label(screen, "switch list"))

    press(radio, CONSTANTS.EVT_VIRTUAL_PREV)
    assert_equal(radio.blinking, "SA" .. UP, screen_label(screen, "back one"))
  end
end)

test("switches page writes the chosen switch after ENTER", function()
  for _, screen in ipairs(SCREENS) do
    local radio = switch_radio(screen)
    press(radio, CONSTANTS.EVT_VIRTUAL_NEXT, 2)
    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    assert_equal(radio.blinking, "SC" .. UP, screen_label(screen, "choosing starts at the current switch"))
    press(radio, CONSTANTS.EVT_VIRTUAL_NEXT)
    assert_equal(#radio.ls_writes, 0, screen_label(screen, "no write while choosing"))

    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    local speed = radio.logical_switches[LS_SPEED]
    assert_equal(speed.v1, SWITCH_IDS["SC-"], screen_label(screen, "L3 switch"))
    assert_equal(speed.func, CONSTANTS.LS_FUNC_AND, screen_label(screen, "L3 function kept"))
    assert_equal(table.concat(radio.ls_writes, ","), tostring(LS_SPEED), screen_label(screen, "writes"))
    assert_true(radio.blinking == nil and shows(radio, "SC-"), screen_label(screen, "shows the new switch"))
  end
end)

test("switches page keeps the switch after EXIT while choosing", function()
  for _, screen in ipairs(SCREENS) do
    local radio = switch_radio(screen)
    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    press(radio, CONSTANTS.EVT_VIRTUAL_NEXT, 3)
    press(radio, CONSTANTS.EVT_VIRTUAL_EXIT)
    assert_equal(#radio.ls_writes, 0, screen_label(screen, "writes"))
    assert_true(radio.blinking == nil and shows(radio, "SA" .. DOWN), screen_label(screen, "old switch"))

    press(radio, CONSTANTS.EVT_VIRTUAL_EXIT)
    press(radio, 0)
    assert_true(shows(radio, "8. Switches"), screen_label(screen, "back in the menu"))
  end
end)

-- NONE is the always-off !ON, because EdgeTX treats an empty switch as always on
test("switches page stores NONE as !ON and turns the throttle crow on for Crow off", function()
  for _, screen in ipairs(SCREENS) do
    local radio = switch_radio(screen)
    press(radio, CONSTANTS.EVT_VIRTUAL_NEXT, 5)
    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    choose(radio, "NONE")
    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    assert_equal(radio.logical_switches[LS_CROW_OFF].v1, SWITCH_IDS["!ON"], screen_label(screen, "L36 off"))
    assert_equal(radio.logical_switches[LS_THROTTLE_CROW].v1, SWITCH_IDS.ON, screen_label(screen, "L50 on"))
    assert_equal(radio.logical_switches[LS_THROTTLE_CROW].func, CONSTANTS.LS_FUNC_AND,
      screen_label(screen, "L50 function kept"))

    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    choose(radio, "SD" .. UP)
    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    assert_equal(radio.logical_switches[LS_CROW_OFF].v1, SWITCH_IDS["SD" .. UP], screen_label(screen, "L36 back"))
    assert_equal(radio.logical_switches[LS_THROTTLE_CROW].v1, SWITCH_IDS["!ON"], screen_label(screen, "L50 off"))

    -- Landing has no linked switch
    press(radio, CONSTANTS.EVT_VIRTUAL_PREV)
    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    choose(radio, "NONE")
    radio.ls_writes = {}
    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    assert_equal(radio.logical_switches[LS_LANDING].v1, SWITCH_IDS["!ON"], screen_label(screen, "L7 off"))
    assert_equal(table.concat(radio.ls_writes, ","), tostring(LS_LANDING), screen_label(screen, "Landing writes"))
  end
end)

test("switches page leaves models without L50 to the crow-off switch", function()
  for _, screen in ipairs(SCREENS) do
    local radio = switch_radio(screen, false, { without_throttle_crow = true })
    press(radio, CONSTANTS.EVT_VIRTUAL_NEXT, 5)
    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    choose(radio, "NONE")
    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    assert_equal(table.concat(radio.ls_writes, ","), tostring(LS_CROW_OFF), screen_label(screen, "writes"))
    assert_true(radio.logical_switches[LS_THROTTLE_CROW] == nil, screen_label(screen, "L50 stays undefined"))
  end
end)

test("switches page moves the GX12 arming press on L41", function()
  for _, screen in ipairs(SCREENS) do
    local radio = switch_radio(screen, true)
    assert_true(shows(radio, "SA" .. DOWN) and shows(radio, "SG" .. DOWN), screen_label(screen, "GX12 switches"))
    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    choose(radio, "SB" .. UP)
    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    assert_equal(table.concat(radio.ls_writes, ","), tostring(LS_ARM_TOGGLE), screen_label(screen, "writes"))
    assert_equal(radio.logical_switches[LS_ARM_TOGGLE].v1, SWITCH_IDS["SB" .. UP], screen_label(screen, "L41"))
    assert_equal(radio.logical_switches[LS_ARM_TOGGLE].v2, 142, screen_label(screen, "L41 keeps L42"))
    assert_equal(radio.logical_switches[LS_ARM].v1, 141, screen_label(screen, "L5 keeps L41"))
  end
end)

-- Older templates left a switch empty, which keeps a defined logical switch on; switches set in
-- Companion to something the page does not offer show by name, and choosing starts at NONE.
test("switches page shows an empty switch as ON and other switches by name", function()
  for _, screen in ipairs(SCREENS) do
    local radio = switch_radio(screen, false, { switches = {
      [LS_AIL_ELE] = { func = CONSTANTS.LS_FUNC_AND, v1 = 0, v2 = 0 },
      [LS_RUD_ELE] = { func = CONSTANTS.LS_FUNC_AND, v1 = SWITCH_IDS.L1, v2 = 0 }
    } })
    press(radio, CONSTANTS.EVT_VIRTUAL_NEXT, 7)
    assert_true(shows(radio, "ON") and shows(radio, "L1"), screen_label(screen, "ON and L1"))
    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    assert_equal(radio.blinking, "NONE", screen_label(screen, "choosing starts at NONE"))
    press(radio, CONSTANTS.EVT_VIRTUAL_EXIT)
    press(radio, CONSTANTS.EVT_VIRTUAL_PREV)
    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    assert_equal(radio.blinking, "ON", screen_label(screen, "empty switch is ON"))
    assert_equal(#radio.ls_writes, 0, screen_label(screen, "writes"))
  end
end)

-- Logical switch values as getValue returns them
local LS_ON, LS_OFF = 1024, -1024

-- A model in the glide after a motor run of 30 s. The landing switch L7 is SD down as in the
-- template; with landing_none the Switches page sets it to NONE after the score keeper started.
local function glide_radio(landing_none)
  local radio = new_radio(SCREENS[1])
  radio.time = 1000
  radio.logical_switches[LS_LANDING] = { func = CONSTANTS.LS_FUNC_AND, v1 = SWITCH_IDS["SD" .. DOWN], v2 = 0 }
  radio.timers[0] = { start = 600, value = 600 }
  radio.timers[1] = { start = 0, value = 0 }
  for _, name in ipairs({ "ls1", "ls7", "ls8", "ls9", "ls23" }) do
    radio.values[FIELD_IDS[name]] = LS_OFF
  end
  assert(radio.env.loadScript("/SCRIPTS/FUNCTIONS/JFutil.lua"))()
  radio.keeper = assert(radio.env.loadScript("/SCRIPTS/TELEMETRY/JF5Jsk.lua"))()
  if landing_none then
    radio.logical_switches[LS_LANDING].v1 = SWITCH_IDS["!ON"]
  end

  -- The motor runs, stops, and the trigger is released
  radio.fm = 2
  radio.keeper.background()
  radio.timers[0].value = 570
  radio.fm = 0
  radio.keeper.background()
  return radio
end

-- The score keeper runs the flight timer with GV9
local function flight_timer_on(radio)
  return gv(radio, 8, FM_NORMAL) == 1
end

-- Lets the 10 s count after the motor stop run out
local function after_count(radio)
  radio.time = radio.time + 1100
  radio.keeper.background()
end

test("score keeper ends the flight with the landing switch", function()
  local radio = glide_radio(false)
  assert_true(flight_timer_on(radio), "flight timer on in the glide")
  after_count(radio)

  radio.values[FIELD_IDS.ls9] = LS_ON
  radio.keeper.background()
  assert_true(flight_timer_on(radio), "the trigger does not land")

  radio.values[FIELD_IDS.ls9] = LS_OFF
  radio.values[FIELD_IDS.ls7] = LS_ON
  radio.keeper.background()
  assert_true(not flight_timer_on(radio), "the landing switch lands")
  assert_equal(radio.timers[0].value, 30, "flight time")
end)

-- As in the original SoarOTX F5J, where the trigger ends the flight
test("score keeper ends the flight with the trigger while Landing is NONE", function()
  local radio = glide_radio(true)
  radio.values[FIELD_IDS.ls9] = LS_ON
  radio.keeper.background()
  assert_true(flight_timer_on(radio), "no landing during the 10 s count")

  radio.values[FIELD_IDS.ls9] = LS_OFF
  after_count(radio)
  assert_true(flight_timer_on(radio), "flight timer on after the count")

  radio.values[FIELD_IDS.ls9] = LS_ON
  radio.keeper.background()
  assert_true(not flight_timer_on(radio), "the trigger lands")
  assert_equal(radio.timers[0].value, 30, "flight time")
  assert_true(contains(radio.played, "duration"), "flight time announced")
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
