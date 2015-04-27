#pragma rtGlobals=1		// Use modern global access method.
Function MAPFastLDRamp(distance, rate)
	Variable distance // in microns
	Variable rate // in microns per second
	
	variable status = 0
	variable countX, countY
	
	countX = ReadMotorCount("LDX")
	if (IsNaN(countX))
		print "Could not read motor position."
		status = -1
	else
		countY = ReadMotorCount("LDY")
		if (IsNaN(countY))
			print "Could not read motor position."
			status = -1
		endif
	endif

	
	variable micronsPerCountX = GV("LDXEncoderResolution") * 1e6
	variable micronsPerCountY = GV("LDYEncoderResolution") * 1e6
	
	countX += distance / micronsPerCountX
	
	variable speedX = rate / micronsPerCountX
	
	if (SpeedX < GV("LDXVelocityMinimum"))
		print "Rate too low."
		status = -1
	endif
	
	if (SpeedX > GV("LDXVelocityMaximum"))
		print "Rage too high."
		status = -1
	endif

	if (status)
		print "LD motor move aborted."
		return status
	endif

	MoveMotorsToCountWithSpeeds("LDX", countX, speedX, "LDY", countY, 1)	
End