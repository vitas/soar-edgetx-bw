-- JF FxK Configuration Menu
-- Timestamp: 2020-05-01
-- Created by Jesper Frickmann
-- Depends on library functions in FUNCTIONS/JFutil.lua

local active = false
local lastRun = 0
local cf = {} -- List of shared variables
local selection = 1

-- Menu texts. The switches come first, because the other pages are set up with them.
local texts = {
	"1. Switches",
	"2. Channel configuration",
	"3. Align flaperons",
	"4. Center flaperons",
	"5. Adjust other mixes",
	"6. Battery warning" }

local menu = soarUtil.LoadWxH("MENU.lua") -- Screen size specific menu
menu.items = texts
menu.title = "Configuration"
	
-- Lua files to be loaded and unloaded
local files = {
	"/SCRIPTS/TELEMETRY/JFXK/SWITCH.lua",
	"/SCRIPTS/TELEMETRY/JF/CHANNELS.lua",
	"/SCRIPTS/TELEMETRY/JFXK/ALIGN.lua",
	"/SCRIPTS/TELEMETRY/JFXK/CENTER.lua",
	"/SCRIPTS/TELEMETRY/JFXK/ADJMIX.lua",
	"/SCRIPTS/TELEMETRY/JF/BATTERY.lua" }

-- Enable/disable adjustment function. GV8 is written only when it changes: background() calls this
-- on every cycle, and every GV write makes EdgeTX wait again before it saves the model.
function cf.SetAdjust(adj)
	if model.getGlobalVariable(7, 0) ~= adj then
		model.setGlobalVariable(7, 0, adj)
	end
end

local function background()
	if active then
		-- Do not leave loaded configuration scripts in the background
		if getTime() - lastRun > 100 then
			soarUtil.Unload(files[selection])
			active = false
		end
	else
		-- Disable adjustment function
		cf.SetAdjust(0)
	end
end -- background()

local function run(event)
	local att
	local x
	
	soarUtil.ToggleHelp(event)

	-- Trap key events
	if event == EVT_VIRTUAL_ENTER then
		active = true
	end

	if active then
		-- Run the active function
		lastRun = getTime()
		if soarUtil.RunLoadable(files[selection], event, cf) then
			soarUtil.Unload(files[selection])
			active = false
		end
	else
		-- Handle menu key events
		if event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_NEXT_REPT then
			selection = selection + 1
			if selection > #texts then 
				selection = 1
			end
		end
		
		if event == EVT_VIRTUAL_PREV or event == EVT_VIRTUAL_PREV_REPT then
			selection = selection - 1
			if selection <= 0 then 
				selection = #texts
			end
		end
		
		menu.Draw(selection)
		soarUtil.ShowHelp({ enter = "SELECT", ud = "MOVE" })
	end
end

return {background = background, run = run}