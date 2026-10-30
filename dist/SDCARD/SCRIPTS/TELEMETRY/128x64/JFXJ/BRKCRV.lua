-- 128x64/JF/BRKCRV.lua
-- Timestamp: 2020-04-18
-- Created by Jesper Frickmann

local ui = ... -- List of shared variables
local crv = soarUtil.LoadWxH("CURVE.lua") -- Screen size specific function
crv.n = ui.n
crv.width = 39
crv.height = 56

-- yEle is nil if the model has no elevator curve
function ui.Draw(yFlp, yAil, yEle, point)
	soarUtil.InfoBar("Airbrakes")
	lcd.drawText(1, 9, "Flap", SMLSIZE)
	crv.Draw(1, 8, yFlp, point, 10)
	lcd.drawLine(42, 8, 42, LCD_H, SOLID, FORCE)
	lcd.drawText(44, 9, "Aile", SMLSIZE)
	crv.Draw(44, 8, yAil, point, 10)
	lcd.drawLine(85, 8, 85, LCD_H, SOLID, FORCE)
	lcd.drawText(87, 9, "Elev", SMLSIZE)
	if yEle then
		crv.Draw(87, 8, yEle, point, 10)
	else
		lcd.drawText(100, 33, "N/A", SMLSIZE)
	end
end -- Draw()

return ui