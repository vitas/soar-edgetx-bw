-- 212x64/JFXJ/BRKCRV.lua
-- Timestamp: 2020-04-18
-- Created by Jesper Frickmann

local ui = ... -- List of shared variables
local crv = soarUtil.LoadWxH("CURVE.lua") -- Screen size specific function
crv.n = ui.n
crv.width = 36
crv.height = 56

-- yEle is nil if the model has no elevator curve; its trims are then throttle and elevator
function ui.Draw(yFlp, yAil, yEle, point)
	soarUtil.InfoBar("Airbrake curves")
	lcd.drawText(0, 14, "Use throttle to ")
	lcd.drawText(0, 26, "move airbrakes.")
	if yEle then
		lcd.drawText(0, 38, "Thr, ail, elev")
		lcd.drawText(0, 50, "trims adjust.")
	else
		lcd.drawText(0, 38, "Thr. and elev.")
		lcd.drawText(0, 50, "trim to adjust.")
	end

	lcd.drawLine(92, 10, 92, LCD_H, SOLID, FORCE)
	lcd.drawText(94, 9, "Flap", SMLSIZE)
	crv.Draw(94, 8, yFlp, point, 10)
	lcd.drawLine(132, 10, 132, LCD_H, SOLID, FORCE)
	lcd.drawText(134, 9, "Aile", SMLSIZE)
	crv.Draw(134, 8, yAil, point, 10)
	lcd.drawLine(172, 10, 172, LCD_H, SOLID, FORCE)
	lcd.drawText(174, 9, "Elev", SMLSIZE)
	if yEle then
		crv.Draw(174, 8, yEle, point, 10)
	else
		lcd.drawText(186, 33, "N/A", SMLSIZE)
	end
end -- Draw()

return ui