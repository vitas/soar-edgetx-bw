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
local PAGE_SWITCHES, PAGE_ALIGN, PAGE_BRAKES, PAGE_MOTOR = 1, 3, 4, 8

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
    numbers = {},
    log = "",
    frame = {},
    blinks = {}
  }
  local env = setmetatable({}, { __index = _G })
  for name, value in pairs(CONSTANTS) do
    env[name] = value
  end
  env.LCD_W, env.LCD_H = screen.w, screen.h

  env.getVersion = function() return "2.12.0", "test", 2, 12, 0 end
  env.getTime = function() return radio.time end
  env.getDateTime = function() return { year = 2026, mon = 11, day = 8, hour = 12, min = 0 } end
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
  env.playDuration = play("duration")
  env.playFile, env.playHaptic = play("file"), play("haptic")
  env.playNumber = function(value)
    radio.played[#radio.played + 1] = "number"
    radio.numbers[#radio.numbers + 1] = value
  end

  -- The score log as the EdgeTX io library writes it; radio.log keeps the text written
  env.io = {
    open = function(path, mode)
      radio.log_path, radio.log_mode = path, mode
      return {}
    end,
    write = function(_, ...)
      radio.log = radio.log .. table.concat({ ... })
    end,
    close = function() end
  }

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
    resetSensor = function() end,
    getInfo = function() return { name = "F5J" } end
  }

  -- The texts and numbers drawn since the last lcd.clear(), the last blinking text, and all the
  -- blinking texts
  local function draw(item) radio.frame[#radio.frame + 1] = item end
  local function ignore() end
  env.lcd = {
    clear = function()
      radio.frame = {}
      radio.blinking = nil
      radio.blinks = {}
    end,
    drawScreenTitle = function(title) draw(title) end,
    drawText = function(_, _, text, flags)
      draw(tostring(text))
      if flags and math.floor(flags / CONSTANTS.BLINK) % 2 == 1 then
        radio.blinking = tostring(text)
        radio.blinks[#radio.blinks + 1] = tostring(text)
      end
    end,
    drawNumber = function(_, _, value) draw(value) end,
    drawTimer = function(_, _, value) draw(value) end,
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
    assert_true(shows(radio, "3. Align flaps & ailerons"), screen_label(screen, "back in the menu"))
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
    assert_true(shows(radio, "8. Motor idle"), screen_label(screen, "menu item"))
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
    assert_true(shows(radio, "8. Motor idle"), screen_label(screen, "back in the menu"))
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
local LS_CROW_OFF, LS_AIL_ELE, LS_RUD_ELE, LS_THROTTLE_CROW, LS_LANDING_MODE = 35, 45, 47, 49, 51
local LS_ARM_ON, LS_ARM_OFF = 40, 41
-- Ids of L33, L41 and L42 as switches that other logical switches read
local ID_L33, ID_L41, ID_L42 = 133, 141, 142

-- A model with the switches of the F5J templates, as on the Pocket or, with gx12, on the GX12.
-- Options: older_arming (older templates: on the Pocket L5 is the arm switch, on the GX12 each
-- L41 press flips L5), without_throttle_crow (older templates without L50), without_landing_mode
-- (older templates without L52), switches (more logical switches).
local function switch_radio(screen, gx12, options)
  options = options or {}
  local radio = new_radio(screen)
  local AND, OR = CONSTANTS.LS_FUNC_AND, CONSTANTS.LS_FUNC_OR
  local ls = radio.logical_switches
  local function sw(name) return SWITCH_IDS[name] end

  -- L41 turns the arming L5 on, and L42 or the end of a motor run (L33) turns it off
  ls[LS_ARM] = { func = CONSTANTS.LS_FUNC_STICKY, v1 = ID_L41, v2 = ID_L33 }
  ls[LS_ARM_ON] = { func = AND, v1 = sw("SA" .. DOWN), v2 = 0 }
  ls[LS_ARM_OFF] = { func = AND, v1 = sw("SA" .. UP), v2 = 0 }
  if options.older_arming and gx12 then
    -- L42 kept each press on L41 at least 0.3 s long
    ls[LS_ARM_ON] = { func = OR, v1 = sw("SA" .. DOWN), v2 = ID_L42 }
    ls[LS_ARM_OFF] = { func = AND, v1 = ID_L41, v2 = 0, duration = 3 }
  elseif options.older_arming then
    ls[LS_ARM] = { func = AND, v1 = sw("SA" .. DOWN), v2 = 0 }
    ls[LS_ARM_ON], ls[LS_ARM_OFF] = nil, nil
  end
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
  if not options.without_landing_mode then
    ls[LS_LANDING_MODE] = { func = AND, v1 = sw("!ON"), v2 = 0 }
  end
  if gx12 then
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

test("configuration menu lists the Switches page first", function()
  for _, screen in ipairs(SCREENS) do
    local radio = new_radio(screen)
    start_menu(radio)
    press(radio, 0)
    local items = {}
    for _, text in ipairs(radio.frame) do
      if type(text) == "string" and text:match("^%d%. ") then items[#items + 1] = text end
    end
    assert_equal(items[1], "1. Switches", screen_label(screen, "first menu item"))
    assert_equal(items[2], "2. Channel configuration", screen_label(screen, "second menu item"))
  end
end)

test("switches page shows the switch of each row", function()
  for _, screen in ipairs(SCREENS) do
    local radio = switch_radio(screen)
    for _, text in ipairs({ "Switches", "Motor arm", "SA" .. DOWN, "Motor disarm", "SA" .. UP, "Motor/timer",
      "SE" .. DOWN, "Speed", "SC" .. UP, "Float", "SC" .. DOWN, "Landing", "SD" .. DOWN }) do
      assert_true(shows(radio, text), screen_label(screen, "shows " .. text))
    end
    assert_true(not shows(radio, "Crow off"), screen_label(screen, "six rows on the screen"))

    press(radio, CONSTANTS.EVT_VIRTUAL_NEXT, 9)
    for _, text in ipairs({ "Crow off", "SD" .. UP, "Ail->Ele", "NONE", "Rud->Ele", "Timer report", "SB" .. DOWN }) do
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
    press(radio, CONSTANTS.EVT_VIRTUAL_NEXT, 3)
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
    assert_true(shows(radio, "1. Switches"), screen_label(screen, "back in the menu"))
  end
end)

-- NONE is the always-off !ON, because EdgeTX treats an empty switch as always on
test("switches page stores NONE as !ON and turns the throttle crow on for Crow off", function()
  for _, screen in ipairs(SCREENS) do
    local radio = switch_radio(screen)
    press(radio, CONSTANTS.EVT_VIRTUAL_NEXT, 6)
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

    -- Landing also writes the Landing mode flag
    press(radio, CONSTANTS.EVT_VIRTUAL_PREV)
    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    choose(radio, "NONE")
    radio.ls_writes = {}
    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    assert_equal(radio.logical_switches[LS_LANDING].v1, SWITCH_IDS["!ON"], screen_label(screen, "L7 off"))
    assert_equal(table.concat(radio.ls_writes, ","), table.concat({ LS_LANDING, LS_LANDING_MODE }, ","),
      screen_label(screen, "Landing writes"))
  end
end)

test("switches page leaves models without L50 to the crow-off switch", function()
  for _, screen in ipairs(SCREENS) do
    local radio = switch_radio(screen, false, { without_throttle_crow = true, without_landing_mode = true })
    press(radio, CONSTANTS.EVT_VIRTUAL_NEXT, 6)
    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    choose(radio, "NONE")
    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    assert_equal(table.concat(radio.ls_writes, ","), tostring(LS_CROW_OFF), screen_label(screen, "writes"))
    assert_true(radio.logical_switches[LS_THROTTLE_CROW] == nil, screen_label(screen, "L50 stays undefined"))
  end
end)

-- L52 lets the brake stick switch the Landing flight mode, so the page turns it on only while both
-- Landing and Crow off are NONE. ON counts as a switch.
test("switches page turns the Landing mode on only while Landing and Crow off are both NONE", function()
  for _, screen in ipairs(SCREENS) do
    local radio = switch_radio(screen)
    local function flag() return radio.logical_switches[LS_LANDING_MODE] end
    local function set(name)
      press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
      choose(radio, name)
      press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    end

    press(radio, CONSTANTS.EVT_VIRTUAL_NEXT, 6)
    set("NONE")
    assert_equal(flag().v1, SWITCH_IDS["!ON"], screen_label(screen, "L52 off while Landing has SD"))
    assert_equal(table.concat(radio.ls_writes, ","),
      table.concat({ LS_CROW_OFF, LS_THROTTLE_CROW, LS_LANDING_MODE }, ","), screen_label(screen, "Crow off writes"))

    press(radio, CONSTANTS.EVT_VIRTUAL_PREV)
    radio.ls_writes = {}
    set("NONE")
    assert_equal(flag().v1, SWITCH_IDS.ON, screen_label(screen, "L52 on"))
    assert_equal(flag().func, CONSTANTS.LS_FUNC_AND, screen_label(screen, "L52 function kept"))
    assert_equal(flag().v2, 0, screen_label(screen, "L52 second switch kept"))
    assert_equal(table.concat(radio.ls_writes, ","), table.concat({ LS_LANDING, LS_LANDING_MODE }, ","),
      screen_label(screen, "Landing writes"))

    set("ON")
    assert_equal(flag().v1, SWITCH_IDS["!ON"], screen_label(screen, "L52 off with Landing ON"))
    set("NONE")
    assert_equal(flag().v1, SWITCH_IDS.ON, screen_label(screen, "L52 on again"))
    press(radio, CONSTANTS.EVT_VIRTUAL_NEXT)
    set("SD" .. UP)
    assert_equal(flag().v1, SWITCH_IDS["!ON"], screen_label(screen, "L52 off with a crow-off switch"))
  end
end)

-- Models from older templates have no L52, and a pilot may have used L52 for something else
test("switches page leaves L52 alone unless it is the Landing mode flag", function()
  local own = {
    { func = CONSTANTS.LS_FUNC_OR, v1 = SWITCH_IDS["!ON"], v2 = 0 },
    { func = CONSTANTS.LS_FUNC_AND, v1 = SWITCH_IDS["!ON"], v2 = SWITCH_IDS["SB" .. UP] }
  }
  local cases = { { without_landing_mode = true } }
  for _, l52 in ipairs(own) do cases[#cases + 1] = { switches = { [LS_LANDING_MODE] = l52 } } end

  for _, screen in ipairs(SCREENS) do
    for case_index, options in ipairs(cases) do
      local radio = switch_radio(screen, false, options)
      local label = "case " .. tostring(case_index)
      press(radio, CONSTANTS.EVT_VIRTUAL_NEXT, 5)
      press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
      choose(radio, "NONE")
      press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
      press(radio, CONSTANTS.EVT_VIRTUAL_NEXT)
      press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
      choose(radio, "NONE")
      press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
      assert_equal(table.concat(radio.ls_writes, ","),
        table.concat({ LS_LANDING, LS_CROW_OFF, LS_THROTTLE_CROW }, ","), screen_label(screen, label .. " writes"))
      local l52 = own[case_index - 1]
      local kept = radio.logical_switches[LS_LANDING_MODE]
      if l52 then
        for _, field in ipairs({ "func", "v1", "v2" }) do
          assert_equal(kept[field], l52[field], screen_label(screen, label .. " L52 " .. field))
        end
      else
        assert_true(kept == nil, screen_label(screen, "L52 stays undefined"))
      end
    end
  end
end)

-- An empty switch keeps a defined logical switch on, so an empty Landing counts as a switch. L52
-- starts on here, as a model left it after both rows were NONE.
test("switches page counts an empty Landing switch as assigned", function()
  for _, screen in ipairs(SCREENS) do
    local radio = switch_radio(screen, false, { switches = {
      [LS_LANDING] = { func = CONSTANTS.LS_FUNC_AND, v1 = 0, v2 = 0 },
      [LS_LANDING_MODE] = { func = CONSTANTS.LS_FUNC_AND, v1 = SWITCH_IDS.ON, v2 = 0 } } })
    press(radio, CONSTANTS.EVT_VIRTUAL_NEXT, 6)
    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    choose(radio, "NONE")
    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    assert_equal(radio.logical_switches[LS_LANDING_MODE].v1, SWITCH_IDS["!ON"], screen_label(screen, "L52 off"))
    assert_equal(table.concat(radio.ls_writes, ","),
      table.concat({ LS_CROW_OFF, LS_THROTTLE_CROW, LS_LANDING_MODE }, ","), screen_label(screen, "writes"))
  end
end)

-- As Landing and Crow off, the arming has two rows: Motor arm writes L41, Motor disarm L42, and
-- the sticky arming L5 keeps reading both
test("switches page writes the Motor arm switch to L41 and the Motor disarm switch to L42", function()
  for _, screen in ipairs(SCREENS) do
    for _, gx12 in ipairs({ false, true }) do
      local radio = switch_radio(screen, gx12)
      local label = screen_label(screen, gx12 and "GX12" or "Pocket")
      assert_true(shows(radio, "Motor disarm") and shows(radio, "SA" .. UP), label .. " Motor disarm")
      press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
      choose(radio, "SB" .. DOWN)
      press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
      press(radio, CONSTANTS.EVT_VIRTUAL_NEXT)
      press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
      choose(radio, "SB" .. UP)
      press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
      local ls = radio.logical_switches
      assert_equal(table.concat(radio.ls_writes, ","), LS_ARM_ON .. "," .. LS_ARM_OFF, label .. " writes")
      assert_equal(ls[LS_ARM_ON].v1, SWITCH_IDS["SB" .. DOWN], label .. " L41")
      assert_equal(ls[LS_ARM_OFF].v1, SWITCH_IDS["SB" .. UP], label .. " L42")
      for _, index in ipairs({ LS_ARM_ON, LS_ARM_OFF }) do
        local name = label .. " L" .. tostring(index + 1)
        assert_equal(ls[index].func, CONSTANTS.LS_FUNC_AND, name .. " function")
        assert_equal(ls[index].v2, 0, name .. " second switch")
      end
      assert_true(ls[LS_ARM].v1 == ID_L41 and ls[LS_ARM].v2 == ID_L33, label .. " L5 kept")
    end
  end
end)

-- In models from older Pocket templates, L5 itself is the arm switch, and there is no disarm switch
test("switches page writes the Motor arm switch of older Pocket models to L5", function()
  for _, screen in ipairs(SCREENS) do
    local radio = switch_radio(screen, false, { older_arming = true })
    assert_true(not shows(radio, "Motor disarm"), screen_label(screen, "no Motor disarm"))
    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    choose(radio, "SB" .. UP)
    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    assert_equal(table.concat(radio.ls_writes, ","), tostring(LS_ARM), screen_label(screen, "writes"))
    assert_equal(radio.logical_switches[LS_ARM].v1, SWITCH_IDS["SB" .. UP], screen_label(screen, "L5"))
  end
end)

-- In models from older GX12 templates, each L41 press flips L5, and L42 lengthens the press
test("switches page moves the arming press of older GX12 models on L41", function()
  for _, screen in ipairs(SCREENS) do
    local radio = switch_radio(screen, true, { older_arming = true })
    assert_true(shows(radio, "SA" .. DOWN) and shows(radio, "SG" .. DOWN), screen_label(screen, "GX12 switches"))
    assert_true(not shows(radio, "Motor disarm"), screen_label(screen, "no Motor disarm"))
    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    choose(radio, "SB" .. UP)
    press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
    assert_equal(table.concat(radio.ls_writes, ","), tostring(LS_ARM_ON), screen_label(screen, "writes"))
    assert_equal(radio.logical_switches[LS_ARM_ON].v1, SWITCH_IDS["SB" .. UP], screen_label(screen, "L41"))
    assert_equal(radio.logical_switches[LS_ARM_ON].v2, ID_L42, screen_label(screen, "L41 keeps L42"))
    assert_equal(radio.logical_switches[LS_ARM].v1, ID_L41, screen_label(screen, "L5 keeps L41"))
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
    press(radio, CONSTANTS.EVT_VIRTUAL_NEXT, 8)
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

-- Logical switches the F3K Switches page writes (0-based like the EdgeTX API)
local F3K_ALT, F3K_SPEED, F3K_FLOAT, F3K_ALT10, F3K_LAUNCH, F3K_LANDING = 0, 2, 3, 5, 6, 7
local F3K_CROW_OFF, F3K_STICK_CROW, F3K_LANDING_MODE = 34, 49, 51
-- Ids of L1, L9, L17 and L53 as switches that other logical switches read
local ID_L1, ID_L9, ID_L17, ID_L53 = 101, 109, 117, 153

-- A model with the switches of the F3K templates, as on the Pocket or, with gx12, on the GX12:
-- Landing and Crow off at NONE, so the brake stick frees the brakes (L50) and switches the Landing
-- flight mode (L52). Options: older (older templates: Landing and Crow off on SD, no L50 and L52),
-- switches (more logical switches).
local function f3k_switch_radio(screen, gx12, options)
  options = options or {}
  local radio = new_radio(screen)
  local AND, OR = CONSTANTS.LS_FUNC_AND, CONSTANTS.LS_FUNC_OR
  local ls = radio.logical_switches
  local function sw(name) return SWITCH_IDS[name] end

  ls[F3K_ALT] = { func = AND, v1 = sw((gx12 and "SE" or "SA") .. DOWN), v2 = ID_L17 }
  ls[F3K_SPEED] = { func = AND, v1 = sw((gx12 and "SF" or "SC") .. UP), v2 = -ID_L53 }
  ls[F3K_FLOAT] = { func = AND, v1 = sw((gx12 and "SF" or "SC") .. DOWN), v2 = -ID_L53 }
  ls[F3K_ALT10] = { func = AND, v1 = sw("SB" .. DOWN), v2 = ID_L1 }
  ls[F3K_LAUNCH] = { func = OR, v1 = sw((gx12 and "SG" or "SE") .. DOWN), v2 = ID_L9 }
  ls[F3K_LANDING] = { func = AND, v1 = sw("!ON"), v2 = 0 }
  ls[F3K_CROW_OFF] = { func = AND, v1 = sw("!ON"), v2 = 0 }
  ls[F3K_STICK_CROW] = { func = AND, v1 = sw("ON"), v2 = 0 }
  ls[F3K_LANDING_MODE] = { func = AND, v1 = sw("ON"), v2 = 0 }
  if options.older then
    ls[F3K_SPEED].v2, ls[F3K_FLOAT].v2 = 0, 0
    ls[F3K_LANDING].v1, ls[F3K_CROW_OFF].v1 = sw("SD" .. DOWN), sw("SD" .. UP)
    ls[F3K_STICK_CROW], ls[F3K_LANDING_MODE] = nil, nil
  end
  for index, value in pairs(options.switches or {}) do
    ls[index] = value
  end
  start_menu(radio, "JFXKcf")
  open_page(radio, 1)
  radio.menu.run(0)
  return radio
end

-- Sets the selected row to the switch name
local function set_row(radio, name)
  press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
  choose(radio, name)
  press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
end

test("F3K configuration menu lists the Switches page first", function()
  for _, screen in ipairs(SCREENS) do
    local radio = new_radio(screen)
    start_menu(radio, "JFXKcf")
    press(radio, 0)
    local items = {}
    for _, text in ipairs(radio.frame) do
      if type(text) == "string" and text:match("^%d%. ") then items[#items + 1] = text end
    end
    assert_equal(table.concat(items, ", "), "1. Switches, 2. Channel configuration, 3. Align flaperons, "
      .. "4. Center flaperons, 5. Adjust other mixes, 6. Battery warning", screen_label(screen, "menu items"))
  end
end)

test("F3K switches page shows the switch of each row", function()
  for _, screen in ipairs(SCREENS) do
    for _, gx12 in ipairs({ false, true }) do
      local radio = f3k_switch_radio(screen, gx12)
      local label = screen_label(screen, gx12 and "GX12" or "Pocket")
      local launch, modes, alt = gx12 and "SG" or "SE", gx12 and "SF" or "SC", gx12 and "SE" or "SA"
      for _, text in ipairs({ "Switches", "Launch", launch .. DOWN, "Speed", modes .. UP, "Float", modes .. DOWN,
        "Landing", "NONE", "Crow off", "Alt calls", alt .. DOWN }) do
        assert_true(shows(radio, text), label .. " shows " .. text)
      end
      assert_true(not shows(radio, "Alt 10 sec"), label .. " six rows on the screen")

      press(radio, CONSTANTS.EVT_VIRTUAL_NEXT, 6)
      assert_true(shows(radio, "Alt 10 sec") and shows(radio, "SB" .. DOWN), label .. " after scrolling")
      assert_equal(#radio.ls_writes, 0, label .. " writes")
    end
  end
end)

-- The Launch, Speed, Float and altitude rows change only the first switch, so L3 and L4 keep
-- giving way to the Landing flight mode (L53), and L7 keeps its 0.3 s hold (L9)
test("F3K switches page writes each row to its logical switch", function()
  for _, screen in ipairs(SCREENS) do
    local radio = f3k_switch_radio(screen)
    local ls = radio.logical_switches
    local rows = {
      { F3K_LAUNCH, "SG" .. UP, ID_L9 }, { F3K_SPEED, "SB" .. UP, -ID_L53 }, { F3K_FLOAT, "SB" .. DOWN, -ID_L53 },
      { F3K_ALT, "SF" .. DOWN, ID_L17 }, { F3K_ALT10, "SF" .. UP, ID_L1 }
    }
    local positions = { 1, 2, 3, 6, 7 } -- Rows on the page
    for i, row in ipairs(rows) do
      press(radio, CONSTANTS.EVT_VIRTUAL_NEXT, positions[i] - (positions[i - 1] or 1))
      radio.ls_writes = {}
      set_row(radio, row[2])
      local name = screen_label(screen, "L" .. tostring(row[1] + 1))
      assert_equal(table.concat(radio.ls_writes, ","), tostring(row[1]), name .. " writes")
      assert_equal(ls[row[1]].v1, SWITCH_IDS[row[2]], name .. " switch")
      assert_equal(ls[row[1]].v2, row[3], name .. " second switch kept")
    end
  end
end)

-- L50 lets the brake stick free the brakes after a launch while Landing is NONE; L52 lets it switch
-- the Landing flight mode while Landing and Crow off are both NONE. ON counts as a switch.
test("F3K switches page turns the brake stick flags on only for NONE", function()
  for _, screen in ipairs(SCREENS) do
    local radio = f3k_switch_radio(screen)
    local ls = radio.logical_switches
    local function flags() return { ls[F3K_STICK_CROW].v1, ls[F3K_LANDING_MODE].v1 } end
    local NONE, ON = SWITCH_IDS["!ON"], SWITCH_IDS.ON

    press(radio, CONSTANTS.EVT_VIRTUAL_NEXT, 3)
    radio.ls_writes = {}
    set_row(radio, "SD" .. DOWN)
    assert_equal(ls[F3K_LANDING].v1, SWITCH_IDS["SD" .. DOWN], screen_label(screen, "L8"))
    assert_equal(table.concat(flags(), ","), NONE .. "," .. NONE, screen_label(screen, "flags with a Landing switch"))
    assert_equal(table.concat(radio.ls_writes, ","), table.concat({ F3K_LANDING, F3K_STICK_CROW, F3K_LANDING_MODE }, ","),
      screen_label(screen, "Landing writes"))

    set_row(radio, "NONE")
    assert_equal(table.concat(flags(), ","), ON .. "," .. ON, screen_label(screen, "flags with Landing back at NONE"))
    set_row(radio, "ON")
    assert_equal(table.concat(flags(), ","), NONE .. "," .. NONE, screen_label(screen, "flags with Landing ON"))
    set_row(radio, "NONE")

    press(radio, CONSTANTS.EVT_VIRTUAL_NEXT)
    radio.ls_writes = {}
    set_row(radio, "SD" .. UP)
    assert_equal(ls[F3K_CROW_OFF].v1, SWITCH_IDS["SD" .. UP], screen_label(screen, "L35"))
    assert_equal(table.concat(flags(), ","), ON .. "," .. NONE, screen_label(screen, "flags with a crow-off switch"))
    assert_equal(table.concat(radio.ls_writes, ","), table.concat({ F3K_CROW_OFF, F3K_LANDING_MODE }, ","),
      screen_label(screen, "Crow off writes"))
    for _, index in ipairs({ F3K_STICK_CROW, F3K_LANDING_MODE }) do
      assert_equal(ls[index].func, CONSTANTS.LS_FUNC_AND, screen_label(screen, "flag function kept"))
      assert_equal(ls[index].v2, 0, screen_label(screen, "flag second switch kept"))
    end
  end
end)

-- In models from older templates, the Landing switch alone frees the brakes after a launch, so
-- NONE there would keep them retracted for the rest of the flight. The page leaves both rows out.
test("F3K switches page leaves the Landing and Crow off rows out on older models", function()
  for _, screen in ipairs(SCREENS) do
    local radio = f3k_switch_radio(screen, false, { older = true })
    assert_true(shows(radio, "Launch") and shows(radio, "Alt 10 sec"), screen_label(screen, "five rows"))
    assert_true(not shows(radio, "Landing") and not shows(radio, "Crow off"), screen_label(screen, "no brake rows"))
    press(radio, CONSTANTS.EVT_VIRTUAL_NEXT, 3)
    set_row(radio, "SC" .. UP)
    assert_equal(table.concat(radio.ls_writes, ","), tostring(F3K_ALT), screen_label(screen, "Alt calls writes"))
  end
end)

-- Logical switch values as getValue returns them
local LS_ON, LS_OFF = 1024, -1024

-- A model in the glide after a motor run of 30 s. The landing switch L7 is SD down as in the
-- template; with landing_none the Switches page sets it to NONE after the score keeper started.
-- The screen is 128x64 unless another one is given.
local function glide_radio(landing_none, screen)
  local radio = new_radio(screen or SCREENS[1])
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

-- The score keeper's own screen. The loader needs four runs before an event reaches the screen.
local function keeper_screen(radio)
  for _ = 1, 4 do
    radio.keeper.run(0)
  end
end

local function keeper_press(radio, event, times)
  for _ = 1, times or 1 do
    radio.keeper.run(event)
  end
end

-- Flights written to the score log
local function log_lines(radio)
  return select(2, radio.log:gsub("\n", ""))
end

-- A landed model on the Save screen: ENTER confirms the landing points, the start height and the
-- flight time
local function save_radio(screen)
  local radio = glide_radio(false, screen)
  after_count(radio)
  radio.values[FIELD_IDS.ls7] = LS_ON
  radio.keeper.background()
  radio.values[FIELD_IDS.ls7] = LS_OFF
  keeper_screen(radio)
  keeper_press(radio, CONSTANTS.EVT_VIRTUAL_ENTER, 3)
  return radio
end

test("score keeper Save screen selects EXIT first and SAVE with the roller", function()
  for _, screen in ipairs(SCREENS) do
    local size = screen.w .. "x" .. screen.h .. ": "
    local radio = save_radio(screen)
    assert_true(shows(radio, "EXIT") and shows(radio, "SAVE"), size .. "Save screen")
    assert_equal(table.concat(radio.blinks, ","), "EXIT", size .. "selected first")
    keeper_press(radio, CONSTANTS.EVT_VIRTUAL_INC)
    assert_equal(table.concat(radio.blinks, ","), "SAVE", size .. "selected after a roller step")
    keeper_press(radio, CONSTANTS.EVT_VIRTUAL_DEC)
    assert_equal(table.concat(radio.blinks, ","), "EXIT", size .. "selected after a step back")
  end
end)

test("score keeper writes the flight with ENTER on SAVE", function()
  local radio = save_radio()
  keeper_press(radio, CONSTANTS.EVT_VIRTUAL_INC)
  keeper_press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
  assert_equal(log_lines(radio), 1, "flights in the log")
  assert_equal(radio.log_path, "/LOGS/JF F5J Scores.csv", "log file")
  assert_true(shows(radio, "Tgt"), "back in Ready")
end)

-- EXIT is the default, so ENTER alone does not save the flight
test("score keeper leaves the flight out of the log with ENTER on the first choice, EXIT", function()
  local radio = save_radio()
  keeper_press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
  assert_equal(log_lines(radio), 0, "flights in the log")
  assert_true(shows(radio, "Tgt"), "back in Ready")
end)

test("score keeper goes back to the flight time with RTN on the Save screen", function()
  local radio = save_radio()
  keeper_press(radio, CONSTANTS.EVT_VIRTUAL_INC)
  keeper_press(radio, CONSTANTS.EVT_VIRTUAL_EXIT)
  assert_true(not shows(radio, "SAVE"), "Save screen left")
  assert_true(shows(radio, "Flt"), "the flight time, not Ready")
  assert_equal(log_lines(radio), 0, "flights in the log")
  keeper_press(radio, CONSTANTS.EVT_VIRTUAL_ENTER)
  assert_true(shows(radio, "SAVE"), "ENTER returns to the Save screen")
  assert_equal(table.concat(radio.blinks, ","), "EXIT", "selected again on the return")
end)

test("score keeper starts a new flight when the motor restarts in the glide", function()
  local radio = glide_radio(false)
  after_count(radio)
  radio.timers[0].value = 400

  -- After a new arm, the motor starts again
  radio.fm = 2
  radio.keeper.background()
  assert_true(flight_timer_on(radio), "flight timer on")
  assert_equal(radio.timers[0].start, 600, "working time")
  assert_equal(radio.timers[0].value, 600, "working time left")

  -- The new flight runs as one from Ready
  radio.timers[0].value = 590
  radio.fm = 0
  radio.keeper.background()
  after_count(radio)
  radio.values[FIELD_IDS.ls7] = LS_ON
  radio.keeper.background()
  assert_true(not flight_timer_on(radio), "the landing switch lands")
  assert_equal(radio.timers[0].value, 10, "flight time")
  assert_equal(log_lines(radio), 0, "flights in the log")
end)

test("score keeper starts a new flight when the motor restarts after the landing", function()
  local radio = glide_radio(false)
  after_count(radio)
  radio.values[FIELD_IDS.ls7] = LS_ON
  radio.keeper.background()
  radio.values[FIELD_IDS.ls7] = LS_OFF
  assert_true(not flight_timer_on(radio), "landed")

  radio.fm = 2
  radio.keeper.background()
  assert_true(flight_timer_on(radio), "flight timer on")
  assert_equal(radio.timers[0].value, 600, "working time left")
  assert_equal(log_lines(radio), 0, "flights in the log")
end)

test("score keeper starts a new flight when the motor restarts on the Save screen", function()
  local radio = save_radio()
  radio.fm = 2
  radio.keeper.background()
  keeper_press(radio, 0)
  assert_true(flight_timer_on(radio), "flight timer on")
  assert_equal(radio.timers[0].value, 600, "working time left")
  assert_true(shows(radio, "Rem") and not shows(radio, "SAVE"), "the flight screen")
  assert_equal(log_lines(radio), 0, "flights in the log")
end)

-- The altimeter keeps its zero in the air, so the start height of a restarted flight is the
-- highest altitude after the restart, not the highest one since the arming on the ground
test("score keeper takes the start height of a restarted flight from the climb after the restart", function()
  local radio = glide_radio(false)
  local util = radio.env.soarUtil
  util.alt, util.altMax = 150, 150
  after_count(radio)

  util.alt = 60
  radio.fm = 2
  radio.keeper.background()
  util.alt = 120
  radio.keeper.background()
  util.alt = 118
  radio.fm = 0
  radio.keeper.background()
  radio.values[FIELD_IDS.ls1] = LS_ON
  after_count(radio)
  assert_equal(radio.numbers[#radio.numbers], 120, "start height called")
end)

test("score keeper keeps the altimeter zero when the motor is armed again in the air", function()
  local radio = glide_radio(false)
  local resets = 0
  radio.env.model.getSensor = function(index) return { name = index == 0 and "Alt" or "" } end
  radio.env.model.resetSensor = function() resets = resets + 1 end
  after_count(radio)

  radio.values[FIELD_IDS.ls23] = LS_ON
  radio.keeper.background()
  radio.fm = 2
  radio.keeper.background()
  assert_equal(resets, 0, "altimeter resets")
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
