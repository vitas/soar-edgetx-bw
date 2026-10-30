-- 128x64/JFXJ/MOTOR.lua
-- Timestamp: 2026-10-30

local ui = ... -- List of shared variables

function ui.DrawWarning()
	soarUtil.InfoBar("Motor idle")
	lcd.drawText(0, 10, "WARNING", INVERS)
	lcd.drawText(0, 19, "The motor can run on")
	lcd.drawText(0, 28, "this page. Hold the")
	lcd.drawText(0, 37, "model, keep clear of")
	lcd.drawText(0, 46, "the propeller!")
	lcd.drawText(0, 57, "ENTER - continue", SMLSIZE)
end -- DrawWarning()

-- idle is nil if the model has no Pot curve
function ui.Draw(idle, trimFunction)
	soarUtil.InfoBar("Motor idle")
	lcd.drawText(0, 12, "Idle")

	if not idle then
		lcd.drawText(42, 12, "N/A", INVERS)
		lcd.drawText(0, 28, "No CV13 Pot curve", SMLSIZE)
		lcd.drawText(0, 36, "for the idle.", SMLSIZE)
		return
	end

	lcd.drawNumber(60, 12, idle, RIGHT + INVERS)
	lcd.drawText(0, 26, "Start the motor and turn", SMLSIZE)
	lcd.drawText(0, 34, "P1 to the lowest power.", SMLSIZE)
	if trimFunction then
		lcd.drawText(0, 42, "Throttle trim or ROT", SMLSIZE)
	else
		lcd.drawText(0, 42, "ROT", SMLSIZE)
	end
	lcd.drawText(0, 50, "sets the idle; 0 = stop.", SMLSIZE)
end -- Draw()

return ui
