--[[
SCRIPT:
  channelchange.lua

AUTHOR
  Mike Shellim
  https://rc-soar.com/opentx

DESCRIPTION
  Script for reordering channels within range 1 - 16
  Channels are identified by their names, as defined in the Outputs menu.

COMPATIBILITY
  Supports most OpenTX transmitters (both mono and colour).

LIMITATIONS
  Does not check for broken channel references - these must be checked and fixed manually.

INSTALLATION / OPERATION
  Install as a One-Time' script as follows:
  1. Copy this file to the transmitter SD card. Anywhere is okay.
  2. Backup your setup
  3. From the Radio Setup->SD Card menu, navigate to this file.
  4. Long press Enter, and choose 'Execute'.
  5. Follow the onscreen instructions.

HISTORY
  v1.4 04/01/2023 MS Fixed run time error when mixer count is max (64)
  v1.3 31/08/2022 MS Added scrolling, increased channel count to 16
  v1.2 30/04/2021 MS Added support for X-Lite and T12 (after Miami Mike)
  v1.1 30/04/2021 MS reversed +/- key response (after Miami Mike)
  v1.0 06/04/2021 MS 1st release
--]]


--[[
UI State
--]]
local c1 -- source cursor
local c2 -- dest cursor
local doneintro -- intro completed flag

-- text and fonts
local allfontprops =
  { {ht=7, wid=7, attrs=SMLSIZE}, -- mono screens
    {ht=24, wid=18, attrs=MIDSIZE} -- colour screens
  }

local font -- active font
local firstvisiblechannel -- top visible channel
local chlistsize -- number of channels visible in scrollable list
local NCH = 16 -- number of channels

-- column positions
local xchan
local xoutput


-- ===============================================================================


--[[
FUNCTION: init
Initialisations
--]]
local function init()
  -- cursors
  c1 = 0
  c2 = nil
  
  -- font and drawing positions
  font = allfontprops [LCD_W == 480 and 2 or 1]
  xchan = 2*font.wid
  xoutput = 7*font.wid
  doneintro = false

  -- drawing limits
  firstvisiblechannel = 0
  chlistsize = math.floor (LCD_H  / font.ht ) - 1 -- Allowing for 1 heading line.

end

local function background()
end

--[[
FUNCTION: swap
Swap c1/c2 outputs and mixers
--]]
local function swap ()
  -- Swap outputs
  local tmp = model.getOutput (c1)
  model.setOutput (c1, model.getOutput (c2))
  model.setOutput (c2, tmp)

  -- swap mixes
  local lines1 = model.getMixesCount (c1)
  local lines2 = model.getMixesCount (c2)

  for ln = lines2 - 1, 0, -1 do
    tmp = model.getMix (c2, ln)
    model.deleteMix (c2, ln)
    model.insertMix (c1, 0, tmp)
  end

  for ln = lines1 + lines2 - 1, lines2, -1 do
    tmp = model.getMix (c1, ln)
    model.deleteMix (c1, ln)
    model.insertMix (c2, 0, tmp)
  end
end

--[[
FUNCTION: intro
displays intro screen
--]]
local function intro (event)
  local x = 2
  local y = 2
  lcd.drawText (x, y, "Channel change v1.4", font.attrs);      y = y + font.ht
  lcd.drawText (x, y, "http://rc-soar.com/OpenTX", font.attrs);  y = y + 2 * font.ht
  lcd.drawText (x, y, "Backup your setup first!", font.attrs);  y = y + 2*font.ht
  lcd.drawText (x, y, "Press ENTER to continue", font.attrs)
  return (event == EVT_ENTER_BREAK)
end


--[[
FUNCTION: adjusttopvisible
Adjusts index of top visible channel
--]]
local function adjusttopvisible (c)
  if c < firstvisiblechannel then
    firstvisiblechannel = c
  elseif c >= firstvisiblechannel + chlistsize then
    firstvisiblechannel = c - chlistsize + 1
  end
end

--[[
FUNCTION: prettyname
Pretty up the channel name.
--]]
local function prettyname (name)
  return ( (name == nil or #name == 0) and '-?-' or name )
end

--[[
FUNCTION: run
Run function
--]]
local function run(event)
  lcd.clear()

  -- Display the intro on first run
  if not doneintro then
    if intro (event) then
      doneintro = true
    end
    return 0
  end

  -- Process key presses
  if event == EVT_EXIT_BREAK then
    c2 = nil
  elseif event == EVT_ENTER_BREAK then

    -- Enter pressed. What happens depends on whether dest cursor is active
    if c2 then

      -- dest cursor is active. Do a swap.
      if not (c1 == c2) then
        swap ()
        c1 = c2
        c2 = nil
      end
    else

      -- activate dest cursor
      c2 = c1
    end
  else
    
    -- look for +/- events
    local inc = nil
    if event == EVT_MINUS_FIRST or event == EVT_ROT_RIGHT or event == EVT_DOWN_FIRST then
      inc = 1
    elseif event == EVT_PLUS_FIRST or event == EVT_ROT_LEFT or event == EVT_UP_FIRST then
      inc = -1
    end

    -- adjust active cursor. If both cursors are active and point to same channel, dest cursor has priority.
    if inc then
      if c2 then
        c2 = (c2 + inc) % NCH
        adjusttopvisible (c2)
      else
        c1 = (c1 + inc) % NCH
        adjusttopvisible (c1)
      end
    end
  end

  -- draw headings
  local y = 0
  local st
  if c2 then
    st = "Select DEST, Enter to swap"
  else
    st = "Select SOURCE, press Enter"
  end
  lcd.drawText (2, y, st, font.attrs)
  y = y + font.ht

  -- Draw channel list
  for i = firstvisiblechannel, math.min (firstvisiblechannel + chlistsize - 1, NCH - 1) do
    
    -- Draw cursor
    if (i == c2) then
        lcd.drawText (0, y, " ->", font.attrs + INVERS + BLINK)
    elseif (i==c1) then
        lcd.drawText (0, y, " ->", font.attrs + INVERS)
    end
    
    -- Draw channel number and name
    lcd.drawText (xchan, y, "CH" .. i + 1, font.attrs)
    lcd.drawText (xoutput, y, prettyname (model.getOutput (i).name), font.attrs)
    y = y + font.ht
    i = i + 1
  end

  return 0
end

return {init=init, background=background, run=run}

