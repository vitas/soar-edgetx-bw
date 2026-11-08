-- JFXJ/SWITCH.lua
-- Timestamp: 2026-11-08
-- Switches page, ported from the SoarF5J setup page for color screens. Each row sets the switch
-- that one logical switch of the F5J templates reads first.

local LS_ARM = 4 -- Index of L5, the motor arming, a sticky switch
local LS_ARM_ON = 40 -- Index of L41, which turns L5 on
local LS_ARM_OFF = 41 -- Index of L42, which turns L5 off, as the end of a motor run does
local LS_LANDING = 6 -- Index of L7
local LS_CROW_OFF = 35 -- Index of L36
local LS_THROTTLE_CROW = 49 -- Index of L50, which lets the throttle crow lock (L38) work
local LS_LANDING_MODE = 51 -- Index of L52, which lets the brake stick switch the Landing flight mode

-- 1. row label 2. index of the logical switch
local rows = {
	{ "Motor arm", LS_ARM_ON },
	{ "Motor disarm", LS_ARM_OFF },
	{ "Motor/timer", 8 },
	{ "Speed", 2 },
	{ "Float", 3 },
	{ "Landing", LS_LANDING },
	{ "Crow off", LS_CROW_OFF },
	{ "Ail->Ele", 45 },
	{ "Rud->Ele", 47 },
	{ "Timer report", 11 } }

local ui = {} -- Data shared with GUI
local labels = {} -- Row labels
local values = {} -- Switch name of each row
local selection = 1 -- Selected row
local choice -- Position in the switch list while choosing a switch, nil otherwise

-- EdgeTX treats an empty switch as always on, so NONE is stored as the always-off "!ON"
local NONE = getSwitchIndex("!ON")
local ON = getSwitchIndex("ON")
local indices = { NONE, ON } -- Switch indices to choose from
local names = { "NONE", "ON" } -- And their names

soarUtil.LoadWxH("JFXJ/SWITCH.lua", ui) -- Screen size specific function

-- Models from older templates have no disarm switch, so they lose that row. On the Pocket, L5
-- itself was the arm switch; on the GX12, each L41 press flipped L5, and L42 lengthened the press.
do
	local olderPocket = model.getLogicalSwitch(LS_ARM).func ~= LS_FUNC_STICKY

	if olderPocket or model.getLogicalSwitch(LS_ARM_ON).func ~= LS_FUNC_AND then
		if olderPocket then
			rows[1][2] = LS_ARM
		end
		for i = 2, #rows - 1 do
			rows[i] = rows[i + 1]
		end
		rows[#rows] = nil
	end
end

-- Offer the physical and customizable switches, renamed ones too, but not trims, logical
-- switches, flight modes or telemetry. A switch position ends in CHAR_UP or CHAR_DOWN, and the
-- middle position of a three-position switch ends in "-". As on the color screens, the list also
-- offers the inverted positions ("!SB" .. CHAR_DOWN: SB not down), which switches() lists first.
do
	local positions = {}
	local listed = {}

	for index, name in switches() do
		positions[#positions + 1] = { index, name }
		listed[name] = true
	end

	local function EndsWith(text, suffix)
		return string.sub(text, -#suffix) == suffix
	end

	for _, position in ipairs(positions) do
		local index, name = position[1], position[2]
		local middle = EndsWith(name, "-") and listed[string.sub(name, 1, -2) .. CHAR_UP]

		if EndsWith(name, CHAR_UP) or EndsWith(name, CHAR_DOWN) or middle then
			indices[#indices + 1] = index
			names[#names + 1] = name
		end
	end
end

-- Position of a row's switch in the list, or nil if the page does not offer it; and the switch
local function Find(row)
	local ls = model.getLogicalSwitch(row[2])
	local index = ls.v1

	-- Older templates left the switch empty, which keeps a defined logical switch on
	if index == 0 then
		if ls.func == 0 then
			index = NONE
		else
			index = ON
		end
	end

	for i, idx in ipairs(indices) do
		if idx == index then
			return i, index
		end
	end

	return nil, index
end -- Find()

for i, row in ipairs(rows) do
	local position, index = Find(row)
	labels[i] = row[1]
	values[i] = names[position] or getSwitchName(index) or "???"
end

-- Turns on or off a flag that the F5J templates define as AND(!ON, NONE). Models from older
-- templates lack the flag, and any other logical switch there is left alone.
local function SetFlag(index, on)
	local flag = model.getLogicalSwitch(index)

	if flag.func == LS_FUNC_AND and flag.v2 == 0 then
		if on then
			flag.v1 = ON
		else
			flag.v1 = NONE
		end
		model.setLogicalSwitch(index, flag)
	end
end -- SetFlag()

local function SetSwitch(row, index)
	local ls = model.getLogicalSwitch(row[2])
	ls.v1 = index
	model.setLogicalSwitch(row[2], ls)

	-- With Crow off at NONE, L50 turns on the throttle crow
	if row[2] == LS_CROW_OFF then
		SetFlag(LS_THROTTLE_CROW, index == NONE)
	end

	-- With Landing and Crow off both at NONE, L52 lets the brake stick switch the Landing flight mode
	if row[2] == LS_LANDING or row[2] == LS_CROW_OFF then
		local landing = model.getLogicalSwitch(LS_LANDING).v1
		local crowOff = model.getLogicalSwitch(LS_CROW_OFF).v1
		SetFlag(LS_LANDING_MODE, landing == NONE and crowOff == NONE)
	end
end -- SetSwitch()

local function run(event)
	local forward = (event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_NEXT_REPT)
	local back = (event == EVT_VIRTUAL_PREV or event == EVT_VIRTUAL_PREV_REPT)

	if choice then
		if forward then
			choice = choice % #indices + 1
		elseif back then
			choice = (choice - 2) % #indices + 1
		elseif event == EVT_VIRTUAL_ENTER then
			SetSwitch(rows[selection], indices[choice])
			values[selection] = names[choice]
			choice = nil
		elseif event == EVT_VIRTUAL_EXIT then
			choice = nil
		end
	else
		if event == EVT_VIRTUAL_EXIT then
			return true
		elseif event == EVT_VIRTUAL_ENTER then
			choice = Find(rows[selection]) or 1
		elseif forward then
			selection = selection % #rows + 1
		elseif back then
			selection = (selection - 2) % #rows + 1
		end
	end

	if choice then
		ui.Draw(labels, values, selection, names[choice])
		soarUtil.ShowHelp({ enter = "SAVE", exit = "CANCEL", ud = "SWITCH" })
	else
		ui.Draw(labels, values, selection)
		soarUtil.ShowHelp({ enter = "EDIT", exit = "BACK", ud = "SELECT" })
	end
end -- run()

return {run = run}
