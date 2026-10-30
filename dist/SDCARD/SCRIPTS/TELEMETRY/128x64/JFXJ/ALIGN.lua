-- 128x64/JF/ALIGN.lua
-- Timestamp: 2020-04-18
-- Created by Jesper Frickmann

local ui = ... -- List of shared variables
local crv = soarUtil.LoadWxH("CURVE.lua") -- Screen size specific function
crv.n = ui.n
crv.width = 61
crv.height = 26

function ui.Draw(rgtAilY, lftAilY, rgtFlpY, lftFlpY, i)
	soarUtil.InfoBar("Alignment")

	lcd.drawLine(64, 9, 64, LCD_H, SOLID, FORCE)
	lcd.drawLine(1, 36, LCD_W, 36, SOLID, FORCE)

	lcd.drawText(1, 9, "LA", SMLSIZE)
	crv.Draw(1, 9, lftAilY, ui.n + 1 - i)

	lcd.drawText(1, 37, "LF", SMLSIZE)
	crv.Draw(1, 37, lftFlpY, ui.n + 1 - i)

	lcd.drawText(65, 37, "RF", SMLSIZE)
	crv.Draw(65, 37, rgtFlpY, i)

	lcd.drawText(65, 9, "RA", SMLSIZE)
	crv.Draw(65, 9, rgtAilY, i)
end -- Draw()

function ui.DrawReset(reset)
	soarUtil.InfoBar("Alignment")

	if reset == 1 then
		lcd.drawText(0, 10, "Do you want to reset")
		lcd.drawText(0, 20, "the flap/aileron")
		lcd.drawText(0, 30, "outputs?")
		lcd.drawText(0, 40, "ENTER = DO IT")
		lcd.drawText(0, 50, "EXIT = NO")
	else
		lcd.drawText(0, 10, "The flap/aileron")
		lcd.drawText(0, 20, "outputs did not pass")
		lcd.drawText(0, 30, "all checks. Reset?")
		lcd.drawText(0, 40, "ENTER = RESET")
		lcd.drawText(0, 50, "EXIT = NO")
	end
end -- DrawReset()

return ui