-- 212x64/JFXJ/MOTOR.lua
-- Timestamp: 2026-10-30

local ui = ... -- List of shared variables

function ui.DrawWarning()
	soarUtil.InfoBar("Motor idle")
	lcd.drawText(0, 12, "WARNING", INVERS)
	lcd.drawText(0, 22, "The motor can run on this page.")
	lcd.drawText(0, 32, "Hold the model and keep clear")
	lcd.drawText(0, 42, "of the propeller!")
	lcd.drawText(0, 56, "ENTER - continue, EXIT - back", SMLSIZE)
end -- DrawWarning()

-- idle is nil if the model has no Pot curve
function ui.Draw(idle, trimFunction)
	soarUtil.InfoBar("Motor idle")
	lcd.drawText(0, 12, "Idle")

	if not idle then
		lcd.drawText(42, 12, "N/A", INVERS)
		lcd.drawText(0, 28, "This model has no CV13 Pot curve")
		lcd.drawText(0, 38, "for the idle.")
		return
	end

	lcd.drawNumber(60, 12, idle, RIGHT + INVERS)
	lcd.drawText(0, 26, "Start the motor and set P1 to")
	if trimFunction then
		lcd.drawText(0, 36, "the lowest power. Throttle trim")
		lcd.drawText(0, 46, "or +/- sets the idle.")
	else
		lcd.drawText(0, 36, "the lowest power. +/- sets")
		lcd.drawText(0, 46, "the idle.")
	end
	lcd.drawText(0, 56, "At 0 the motor stops.")
end -- Draw()

return ui
