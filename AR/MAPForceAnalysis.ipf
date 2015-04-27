#pragma rtGlobals=1		// Use modern global access method.

Function MAPTopHat(pw, yw, xw) : FitFunc
	Wave pw, yw, xw

	// pw[0] = y_low
	// pw[1] = y_high
	// pw[2] = x_low
	// pw[3] = x_high
	
	yw = xw[p] > pw[2] && xw[p] < pw[3] ? pw[1] : pw[0]

End


Function MAPForceAnalysis(w)
	Wave w
	
	String indexList = StringByKey("Indexes", note(w), ": " , "\r")
	String channelList = StringByKey("ForceSaveList", note(w), ": " , "\r")
	
	Variable deflIndex = -1
	Do
		deflIndex += 1
	While ((deflIndex < DimSize(w, 1)) && (cmpstr(GetDimLabel(w, 1, deflIndex), "Defl") != 0))

	Variable zIndex = -1
	Do
		zIndex += 1
	While ((zIndex < DimSize(w, 1)) && (cmpstr(GetDimLabel(w, 1, zIndex), "ZSnsr") != 0))

	Variable i, box
	box = 2
	
	//=====Noise characterisation=====
	Make /O /N=(dimsize(w,0), 27) noise
	noise = NaN
	For (i = 0; i < dimsize(w,0) - box; i += 1)
		Duplicate /O /R=[i, i+box-1][deflIndex] w, tmp
		WaveStats /Q /W tmp
		Wave stats = M_WaveStats
		noise[-1+i+box/2][] = stats[q]
	EndFor
	
	CopyScales w, noise
	//=====End noise characterisation
	
	//Display w[][%Defl] vs w[][%ZSnsr]
	//Display noise[][%Defl]
	
	//  Find contact point
	Variable extStart, extEnd, retStart, retEnd
	print indexList
	extStart = str2num(stringfromlist(0, indexList, ","))
	extEnd = str2num(stringfromlist(1, indexList, ","))
	if (ItemsInList(indexList, ",") > 3)
		retStart = str2num(stringfromlist(2, indexList, ","))
		retEnd = str2num(stringfromlist(3, indexList, ","))
	else
		retStart = extEnd
		retEnd = str2num(stringfromlist(2, indexList, ","))
	endif

	Variable dataIsRet = 1

	Variable pStart, pEnd	
	if (dataIsRet)
		pStart = retStart
		pEnd = retEnd
	else
		pstart = extStart
		pEnd = extEnd
	endif

	Duplicate /O /R=[pStart, pEnd][deflIndex] w, Defl, wWave
	Duplicate /O /R=[pStart, pEnd][zIndex] w, ZSnsr
	Redimension /N=-1 Defl, ZSnsr, wWave

	If (dataIsRet)
		Reverse Defl, ZSnsr, wWave
	EndIf

	wWave = ZSnsr - Defl
	
	Duplicate /O wWave chisqLine, chisqPower
	chisqLine = NaN
	chisqPower = NaN
	
	Duplicate /FREE wWave tmpwWave
		
	For (i = 10; i < numpnts(wWave) - 10 ; i += 1)
		CurveFit /Q /N /W=2 line, Defl[0,i] /X=wWave
		chisqLine[i] = V_chisq

		K0 = Defl[i]
		K1 = 1
		K2 = 3/2
		
		tmpwWave = wWave - wWave[i-1]

		CurveFit /G /Q /N /W=2 /H="101" power, Defl[i,] /X=tmpwWave
		chisqPower[i] = V_chisq
	EndFor
//	WaveStats /Q chisqLine
//	chisqLine /= V_Max
//	WaveStats /Q chisqPower
//	chisqPower /= V_Max
	
	Duplicate /O chisqLine, chisqAggregate
	chisqAggregate = chisqLine +   chisqPower
	
	WaveStats /Q chisqAggregate
	Print "Minimum at point ", V_MinRowLoc, " w = ", wWave[V_MinRowLoc]

End

Function MAPContactRegionFit(pw, yw, xw) : FitFunc
	Wave pw, yw, xw
	// pw[0] = b, contact-region scaling coefficient
	yw = pw[0] * (xw)^(3/2)

End

Function MAPContactFit(pw, yw, xw) : FitFunc
	Wave pw, yw, xw

	// pw[0] = i, an index to the input wave
	// pw[1] = m, gradient of straight line portion
	// pw[2] = c, intercept of straight line portion 
	// pw[3] = b, contact-region scaling coefficient
	
	//yw = p < pw[0] ? pw[2] + pw[1] * xw : yw[pw[0]-1] + pw[3] * (xw - xw[pw[0]])^(3/2)
	yw = xw < pw[0] ? pw[2] + pw[1] * xw : pw[2] + pw[1] * pw[0] + pw[3] * (xw - pw[0])^(3/2)
End