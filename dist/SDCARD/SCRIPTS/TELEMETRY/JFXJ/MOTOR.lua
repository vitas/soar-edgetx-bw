-- JFXJ/MOTOR.lua
-- Timestamp: 2026-10-30
-- Motor idle page, ported from the SoarF5J setup page for color screens

local CRV_POT = 12 -- Index of the curve that adds the idle to the motor channel at the bottom of the P1 range
local IDLE_MIN = 0
local IDLE_MAX = 100

-- While GV8 is above 50, L49 lets SF39 count the throttle trim clicks in GV8 instead of moving the trim
local GV_ADJUST = 7 -- Index of GV8
local ADJUST_MODE = 100 -- GV8 is held here while editing; each trim click moves it by one
local TRIM_THRESHOLD = 50
local LS_TRIM = 48 -- Index of L49
local SF_TRIM = 38 -- Index of SF39
local GVAR_MODE_SOURCE = 1

local cf = ...
local ui = {} -- Data shared with GUI
local potCrv -- Table with data for the Pot curve, or nil if the model has no three-point Pot curve
local first -- Index of the first point; older EdgeTX versions number the points from 0
local idle -- First point of the Pot curve
local midRatio -- Middle point per idle when editing started, so the P1 range keeps its shape
local trimFunction -- The model has L49 and SF39 for the throttle trim
local warned = false -- The propeller warning has been on the screen
local editing = false -- The propeller warning has been accepted

soarUtil.LoadWxH("JFXJ/MOTOR.lua", ui) -- Screen size specific function

local function ReadPotCurve()
	local crv = model.getCurve(CRV_POT)
	if not (crv and crv.name == "Pot" and crv.type == 1 and crv.y) then
		return nil
	end

	if crv.y[0] ~= nil then
		first = 0
	else
		first = 1
	end

	for i = first, first + 2 do
		if type(crv.y[i]) ~= "number" then
			return nil
		end
	end

	if crv.y[first + 3] ~= nil then
		return nil
	end

	return crv
end -- ReadPotCurve()

-- Models from older templates have no L49 and SF39; their idle is set with +/- only
local function HasTrimFunction()
	local gvar8 = getFieldInfo("gvar8")
	local throttleTrim = getFieldInfo("trim-thr")
	local counter = model.getLogicalSwitch(LS_TRIM)
	local trim = model.getCustomFunction(SF_TRIM)

	return gvar8 ~= nil and throttleTrim ~= nil and counter ~= nil and trim ~= nil and
		counter.func == LS_FUNC_VPOS and counter.v1 == gvar8.id and counter.v2 == TRIM_THRESHOLD and
		trim.func == FUNC_ADJUST_GVAR and trim.param == GV_ADJUST and trim.mode == GVAR_MODE_SOURCE and
		trim.value == throttleTrim.id and trim.active == 1 and trim.switch == getSwitchIndex("L49")
end -- HasTrimFunction()

local function SetIdle(value)
	value = math.max(IDLE_MIN, math.min(IDLE_MAX, value))
	if value == idle then
		return
	end

	idle = value
	potCrv.y[first] = idle
	potCrv.y[first + 1] = math.max(-100, math.min(100, math.floor(midRatio * idle + 0.5)))
	model.setCurve(CRV_POT, potCrv)
end -- SetIdle()

-- Turn the throttle trim clicks counted in GV8 into idle steps
local function ApplyTrimClicks()
	local count = model.getGlobalVariable(GV_ADJUST, 0)
	if count > TRIM_THRESHOLD and count ~= ADJUST_MODE then
		SetIdle(idle + count - ADJUST_MODE)
	end
	cf.SetAdjust(ADJUST_MODE)
end -- ApplyTrimClicks()

local function StartEditing()
	editing = true
	potCrv = ReadPotCurve()
	if not potCrv then
		return
	end

	idle = potCrv.y[first]
	if idle > 0 then
		midRatio = potCrv.y[first + 1] / idle
	else
		midRatio = 0.5
	end

	-- A count left over in GV8 is not taken as clicks
	trimFunction = HasTrimFunction()
	if trimFunction then
		cf.SetAdjust(ADJUST_MODE)
	end
end -- StartEditing()

local function run(event)
	-- Press EXIT to quit; the throttle trim then works as usual again
	if event == EVT_VIRTUAL_EXIT then
		if trimFunction then
			ApplyTrimClicks()
			cf.SetAdjust(0)
		end
		return true
	end

	-- The warning stays until ENTER is pressed while it is on the screen
	if not editing then
		if warned and event == EVT_VIRTUAL_ENTER then
			StartEditing()
		else
			warned = true
			ui.DrawWarning()
			soarUtil.ShowHelp({ enter = "CONTINUE", exit = "BACK" })
			return
		end
	end

	if potCrv then
		if trimFunction then
			ApplyTrimClicks()
		end

		if event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
			SetIdle(idle + 1)
		elseif event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
			SetIdle(idle - 1)
		end
	end

	ui.Draw(idle, trimFunction)
	if trimFunction then
		soarUtil.ShowHelp({ msg1 = "TrmT - adjust idle", ud = "ADJUST IDLE", exit = "DONE" })
	else
		soarUtil.ShowHelp({ ud = "ADJUST IDLE", exit = "DONE" })
	end
end -- run()

return {run = run}
