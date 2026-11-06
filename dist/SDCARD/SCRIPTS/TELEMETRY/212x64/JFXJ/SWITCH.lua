-- 212x64/JFXJ/SWITCH.lua
-- Timestamp: 2026-11-06

local ui = ... -- List of shared variables
local firstRow = 1 -- Row on the first line of the screen
local COL2 = 150 -- Right edge of the switch names

-- choice is the switch that blinks in the selected row while a switch is chosen
function ui.Draw(labels, values, selected, choice)
	soarUtil.InfoBar("Switches")

	-- Scroll if necessary
	if selected < firstRow then
		firstRow = selected
	elseif selected - firstRow > 5 then
		firstRow = selected - 5
	end

	for line = 1, math.min(6, #labels - firstRow + 1) do
		local row = line + firstRow - 1
		local y0 = 1 + 9 * line

		if row ~= selected then
			lcd.drawText(0, y0, labels[row])
			lcd.drawText(COL2, y0, values[row], RIGHT)
		elseif choice then
			lcd.drawText(0, y0, labels[row])
			lcd.drawText(COL2, y0, choice, RIGHT + INVERS + BLINK)
		else
			lcd.drawText(0, y0, labels[row], INVERS)
			lcd.drawText(COL2, y0, values[row], RIGHT)
		end
	end
end -- Draw()

return ui
