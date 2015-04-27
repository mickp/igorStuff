#pragma rtGlobals=1		// Use modern global access method.
// Run va2process to:
//		import all data from a filesystem folder;
//		calculate and display the average PSD for files with the same base filename;
//		calculate 1/3rd octave bands for each file.

//Run va2analyze to 


StrConstant FILEEXT=".txt"

Function va2Layout(perPage)
	Variable perPage
	
	String plotList = ""
	String thisPlot
	
	Variable i, j
	
	//	Reverse the list of plots
	For ( i = ItemsInList(WinList("*", ";", "WIN:1")) - 1; i >= 0; i -= 1)
		plotList += StringFromList(i, WinList("*", ";", "WIN:1") ) + ";"
	EndFor
		
	For (i = 0; i < ceil(ItemsInList(plotList) / perPage); i += 1)
		NewLayout /K=1
		For (j = 0; j < perPage; j += 1)
			thisPlot = StringFromList(i * perPage + j, plotList)
			If (strLen(thisPlot) > 0)
				AppendLayoutObject graph $thisPlot
			Else
				AppendLayoutObject graph NULL
			EndIf
			Execute("Tile /O=1")
		EndFor
	EndFor
End


Function va2process()
	NewPath /O vaData
	PathInfo vaData
	
	Variable i = 0
	String fn, fnBase, wList, loadedWaves
	String fnBaseOld = ""
	
	Do
		fn = IndexedFile(vaData, i, FILEEXT)
		If (strlen(fn) == 0)
			fnBase = ""
		Else
			SplitString /E=("^(.*)[0-9]{4}" + FILEEXT) fn, fnBase
		EndIf
		
		If (cmpstr(fnBase, fnBaseOld) != 0)
			//	File basename has changed
			If(i != 0)
				//	Not the first file
				CalcAvgASD(wList)
				Display /K=1/N=$fnBaseOld :ASD1 as fnBaseOld
				//AppendToGraph /R INT1
				ModifyGraph log=1, loglinear=1, tickUnit(left)=1, rgb(ASD1)=(0,0,0) //,  rgb(INT1)=(0,0,0xffff), 
				Label left, "\\U"
				TextBox/C/N=title/Z=1/A=RT/X=0.00/Y=0.00 (fnBaseOld + "\tavg of " + num2istr(ItemsInList(wList)))
				DoUpdate				
				SetDataFolder ::
			EndIf
			fnBaseOld = fnBase
			If (strlen(fn))
				NewDataFolder /O/S $fnBase
			Else
				break
			EndIf
			wList = ""
		EndIf
		
		If (strlen(fn))
			wList +=  StringFromList(0,va2read(fn = S_Path + fn)) + ";"
		EndIf

		//	Next file
		i += 1
		fn = IndexedFile(vaData, i, FILEEXT)
	While(1)
	va2layout(6)	
End

Function /S va2read([fn])
	String fn		// Optional filename.
	
	Variable fh, lineNumber	// File handle, line number
	// Open file browser if no filename is specified
	If (ParamIsDefault(fn))
		Open /R /T=FILEEXT fh
	Else
		Open /R /T=FILEEXT fh as fn
	EndIf
	
	//	VA2 functions and units
	String FuncList="ACCEL;VEL;DISP"
	String UnitsList="m/s^2;m/s;m"
	
	String buffer, key, value, sep
	String timestamp, units
	Variable dt, gain
	
	//	Read headers into variables
	lineNumber = 0
	Do
		FReadLine fh, buffer
		If (stringmatch(buffer, "*:*"))
			SplitString /E="^(.{1,8}):(.*|.*:.*)\r" buffer, key, value
			StrSwitch (key)
			
			Case "TIME":
				timestamp = value
				break
			Case "FREQ":
				dt = 1/str2num(value)
				break
			Case "FUNC":
				value = ReplaceString(" ", value, "")
				units = StringFromList(WhichListItem(value, FuncList,";"), UnitsList)
				break
			Case "GAIN":
				gain = str2num(value)
				break
			EndSwitch
		EndIf
		lineNumber += 1
	While (!stringmatch(buffer, "BEGIN*"))

	Close fh
	FStatus fh

	//	Now load the data
	LoadWave /O/A/W/D /G /L={0, lineNumber+1, 0, 0, 3} S_fileName
	
	String fnBase, fnNumber
	SplitString /E=("^(.*)([0-9]{4})"+FILEEXT) S_fileName, fnBase, fnNumber
	print fnBase, fnNumber
	
	String wNames = ""
	
	//	Scale loaded waves and rename
	Variable i
	For (i = 0; i < ItemsInList(S_waveNames); i += 1)
		String wn = StringFromList(i, S_waveNames)
		String newWn = fnBase + "_" + fnNumber + "_" + num2str(i)
		Wave w = $wn
		
		//	Subtract any DC offset
		WaveStats /Q w
		w -= V_Avg
		w *= gain
		SetScale /P x, 0, dt, "s", w
		SetScale d, 0, 0, units, w
		Note w, "TIME: " + timestamp + "\r"
		Note w, "GAIN: " + num2str(gain) + "\r"
		
		Duplicate/O w, $(newWn)
		KillWaves w
		
		wNames += newWn + ";"		
	EndFor
	
	return wNames
End

Function CalcAvgASD(wlist)
		String wlist

		Variable counter, points, samplingrate
		Wave w

		For (counter = 0; counter < ItemsInList(wList); counter += 1)

			Wave w = $(StringFromList(counter, wList))
			String units

			If (counter == 0)
				points = numpnts(w)
				samplingrate = 1 / deltax(w)
				units = StringByKey("DUNITS", WaveInfo(w,0))
				Make/O/N=(points/2 + 1) CurrentASD1 ASD1 PSD1 INT1
				SetScale/P x 0,samplingrate/(points),"Hz", CurrentASD1, ASD1
				PSD1 = 0
			Elseif (numpnts(w) != points)
				//	Check that all the waves have the same number of points
				print "Problem:  wave " + NameOfWave(w) + " has a different number of points than earlier waves."
				return -1

			ElseIf (1 / deltax(w) != samplingrate)
				//	Check that all the waves have the same sampling rate
				print "Problem:  wave " + NameOfWave(w) + " has a different sampling rate than earlier waves."
				return -1

			ElseIf (cmpstr(units, StringByKey("DUNITS", WaveInfo(w,0))) != 0)
				//	Check that all the waves have the same units
				print "Problem;  wave " + NameOfWave(w) + " has different units than earlier waves."
				return -1
			EndIf
			//	Do the calculation for current wave and update average PSD
			Duplicate/O w TempASD
			
			If (mod(numpnts(TempASD),2) != 0)
				DeletePoints 0, 1, TempASD
			EndIf
			
			Hanning TempASD
			FFT TempASD
			CurrentASD1=MagSqr(TempASD)
			CurrentASD1[1,points/2-1] *=2					//don't multiply 1st and last point by 2
			//because these bins dont get doubled when
			//you fold a 2-sided spectrum into a 1-sided
					
			CurrentASD1*=((8/3)/(samplingrate*points))	// 8/3 is factor for Hanning window
			
			// calculate the Average PSD now (CANNOT!! average the ASD)
			PSD1= PSD1*(counter)/(counter + 1) + CurrentASD1/(counter + 1)
		
			// AFTER the averaging it is okay to take the sqrt
			CurrentASD1 = sqrt(CurrentASD1)
			ASD1 = sqrt(PSD1)
			
			//Calculate the IntWave
		
			Integrate PSD1/D=INT1 
			CopyScales ASD1 INT1
			SetScale d, 0, 0, (units + " / Hz\S0.5") ASD1
			INT1[0] = NaN
			INT1[inf] = NaN
			
			// 1/3rd octave analysis
			Make /O/N=32 $(NameOfWave(w) + "_bands")
			Wave rms = $(NameOfWave(w) + "_bands")
			
			rms = Area(CurrentASD1, 10^(p/10)/10^0.05, 10^(p/10)*10^0.05)
			//	Convert from acceleration to velocity
			rms = AccelToVel(rms[p], 10^(p/10))
			SetScale d, 0, 0, "m/s", rms
		EndFor		
End

Function VA2Analyze(axis, [subset])
	String axis
	String subset
	String matchStr
	String idStr
	
	If (ParamIsDefault(subset))
		idStr = axis
		matchStr = "[A-Z]*_[A-Za-z]*_" + axis + "_[0-9]{4}_0_bands$"	
	Else
		idStr = subset + "_" + axis
		matchStr = "[A-Z]*_" + idStr + "_[0-9]{4}_0_bands$"
	EndIf

	
	String wl	 = ""	// wave list
	String wn	// wave name
	Variable index = 0	// iterator
	
	Make /O /N=32 bands
	wave bands = bands
	bands = 10^(p/10)
	
	String thisWaveList
	String folderList = StringByKey("FOLDERS", DataFolderDir(1))
	folderList = ReplaceString(",", folderList, ";")	
	
	//  Figure out the list of wavenames.
	For (index = 0; index < ItemsInList(folderList); index += 1)
		String folder = StringFromList(index, folderList)
		thisWaveList = StringByKey("WAVES", DataFolderDir(2, $(folder)))
		thisWaveList = ReplaceString(",", thisWaveList, ";")
		//Grep for the axis we're interested in, deleting the last semicolin and adding one as a prefixing because...
		thisWaveList = ";" + GrepList(thisWaveList, matchStr)
		thisWaveList = thisWaveList[0,strlen(thisWaveList)-2]
		//We're going to use the semicolons to find the start of names where we'll insert the data folder name
		thisWaveList = ReplaceString(";", thisWaveList, ";:"+ folder + ":")[1,inf] + ";"
		If(strlen(thisWaveList) > 1)
			wl += thisWaveList
		EndIf
	EndFor
	//SetDataFolder root:VA2Log:results
		
	If (strlen(wl) == 0)
		print "No waves matching that axis and subset."
		return 0
	EndIf
		
	//	Set up image for binning data
	variable ampoffset, ampdecades, ampbins
	ampoffset = 2e-9
	ampdecades = 5.5
	ampbins = 512

	Make /O/N=(32,ampbins) $(idStr + "BandImage")
	Make /O/N=(33) $(idStr + "BandImageBands")
	Make /O/N=(ampbins + 1) $(idStr + "BandImageAmps")

	Wave image = $(idStr + "BandImage")
	Wave imagebands = $(idStr + "BandImageBands")
	Wave imageamps = $(idStr + "BandImageAmps")
	
	image = 0
	imagebands = 10^(p/10)/10^0.05
	imageamps = ampoffset * 10^(ampdecades * p / (ampbins + 1))
	// amplitude to a point number:
	//	p = (ampbins / decades) * log(amp / offset)
	
	index = 0	
	do
		wn = StringFromList(index, wl, ";")
		if ( strlen(wn) == 0)
		//if ( strlen(wn) == 0  || index > 4096)	//	testing
			break
		else
			Wave w = $wn
		endif

		if (index == 0)
			Duplicate/O w, $(idStr+"MAX"), $(idStr+"MIN"), $(idStr+"MEAN")
			Wave maxw = $(idStr+"MAX")
			Wave minw = $(idStr+"MIN")
			Wave meanw = $(idStr+"MEAN")	
			Display /K=1/N=$idStr as idStr
			AppendToGraph /C=(0xaaaa, 0xaaaa, 0xaaaa) w vs bands
			ModifyGraph Log=1,tickUnit(left)=1
			Label left Axis + "-velocity (\\U rms)"
			SetScale d, 0, 0, "m/s", maxw, minw, meanw, imageamps	
			PauseUpdate
		else
			maxw = max(maxw, w)
			minw = min(minw, w)
			meanw = (w + index * meanw) / (index + 1)
			AppendToGraph /C=(0xcccc, 0xcccc, 0xcccc) w vs bands
		endif
		
			
		variable i
		for (i = 0; i < numpnts(w); i += 1)
			image[i][(ampbins / ampdecades) * log(w[i] / ampoffset)] += 1
		endfor
				
		index += 1			
	while(1)	
		
	ModifyGraph lsize=1.1

	TextBox /C /N=info /A=RB /X=0 /Y=0  num2str(index) + " measurements"

	Variable ntrace

	AppendToGraph meanw vs bands
	ntrace = ItemsInList(TraceNameList("", "", 1)) - 1
	ModifyGraph lsize[ntrace]=2

	//SetAxis bottom 1, 100
	ResumeUpdate
	
	CalcPercentile(10, image)
	AppendToGraph $(NameOfWave(image)+ "L10") vs bands
	ntrace = ItemsInList(TraceNameList("", "", 1)) - 1
	ModifyGraph lsize[ntrace]=2, lstyle[ntrace]=3
	
	CalcPercentile(90, image)
	AppendToGraph $(NameOfWave(image) + "L90") vs bands
	ntrace = ItemsInList(TraceNameList("", "", 1)) - 1
	ModifyGraph lsize[ntrace]=2, lstyle[ntrace]=9
	
	AppendToGraph /C=(0x0000, 0x0000, 0xcccc) root:NISTAvel vs root:NISTAx
	ntrace = ItemsInList(TraceNameList("", "", 1)) - 1
	ModifyGraph lsize[ntrace]=2
	
	SetDrawEnv xcoord= bottom, ycoord= left, linefgc= (0,0,52224), dash= 1, linethick= 2.00
	DrawLine 20,3.175e-06,1258.92541503906,3.175e-06
End

Function /WAVE CalcPercentile(percentile, dists)
	Variable percentile	//	which percentile
	Wave dists	//	distributions
	
	String name = nameofwave(dists)
	Wave amps = $(name+"Amps")
	Variable rows, cols, index
	rows = DimSize (dists, 0)
	cols = DimSize(dists, 1)
	
//	Wave tmpdist = NewFreeWave(0x20 , cols) // 32-bit integer wave
	Make /O/N=(rows) $(name + "L" + num2istr(percentile))
	Wave L = $(name + "L" + num2istr(percentile))
	
	for (index = 0; index < rows; index += 1)
		Make /FREE /N=(cols) tmpdist=0
		tmpdist = dists[index][p]
		integrate tmpdist
		FindLevel /Q/P tmpdist, (1 - (percentile / 100)) * ( tmpdist[inf])
		L[index] = amps[V_LevelX]
	endfor	
	
	return L
End

Function MakeNISTAWaves()
	Make /O /N=3 NISTA, NISTAx
	Wave NISTA, NISTAx
	NISTAx[] = {1, 20, 100}
	NISTA = CalcNISTA(NISTAx[p])
	
	Make /O /N=2 NISTA1, NISTA1x
	Wave NISTA1, NISTA1x
	NISTA1x[] = {5, 100}
	NISTA1 = CalcNISTA1(NISTA1x[p])
End

Function CalcNISTA(x)
	variable x
	variable velocity
	
	if (0 <= x && x < 20)
		velocity = 2 * pi * x * 0.0254e-6
	elseif (20 <= x && x <= 100)
		velocity = 125 * 0.0254e-6
	else
		velocity = NaN
	endif
	
	return velocity	
End

Function CalcNISTA1(x)
	variable x
	variable velocity
	
	if (5 <= x && x <= 100)
		velocity = 30 * 0.0254e-6
	else
		velocity = NaN
	endif
	
	return velocity	
End

Function VelToAccel(v, f)
	Variable v, f	//	velocity, frequency
	return 2 * pi * f * v	
End

Function AccelToVel(a, f)
	Variable a, f
	return a / (2 * pi * f)
End