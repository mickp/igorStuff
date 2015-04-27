#pragma rtGlobals=1		// Use modern global access method.

Function OwonReadFolder()
	NewPath /O OwonData
	PathInfo OwonData
	
	Variable i = 0
	String fn

	Do
		fn = IndexedFile (OwonData, i, ".bin")
		If (strlen(fn) == 0)
			break;
		EndIf
		OwonRead(fn = S_Path + fn)
		i += 1
		fn = IndexedFile (OwonData, i, ".bin")
	While (1)
	
End

Function/T OwonRead([fn])
	String fn

	Variable refNum
	If (ParamIsDefault(fn))
		Open/R /T=".bin" refNum
	Else
		Open/R /T=".bin" refNum as fn
	EndIf
	
	String tmp
	
	String SensList, TimeBaseList
	//SensByKey = "0x01:5;0x02:10;0x03:20;0x04:50;0x05:100;0x06:200;0x07:500;0x08:1000;0x09:2000;0x0A:5000"
	SensList="0;5e-3;10e-3;20e-3;50e-3;100e-3;200e-3;500e-3;1000e-3;2000e-3;5000e-3"
	TimeBaseList="5e-9;10e-9;20e-9;50e-9;100e-9;200e-9;500e-9;1e-6;2e-6;5e-6;10e-6;20e-6;50e-6;100e-6;200e-6;500e-6;1e-3;2e-3;5e-3;10e-3;20e-3;50e-3;100e-3;200e-3;500e-3;1;2;5;10;25;50;100"
	String ChannelName
	Variable BlockLength, SampleCount1, SampleCount2, TimeBaseCode, VertSensCode
	Variable TimeBase, Sensitivity
	ChannelName = PadString("", 3, 0)
	tmp = PadString("", 4, 0)

	FSetPos refNum, 10
	FBinRead refNum, ChannelName
	FBinRead /F=3 refNum, BlockLength
	FBinRead /F=3 refNum, SampleCount1
	FBinRead /F=3 refNum, SampleCount2
	FBinRead refNum, tmp
	FBinRead /F=3 refNum, TimeBaseCode
	FBinRead /F=3 refNum, tmp
	FBinRead /F=3 refNum, VertSensCode			

	Sensitivity = str2num(StringFromList(VertSensCode, SensList))
	TimeBase = str2num(StringFromList(TimeBaseCode, TimeBaseList))
	
	String name = UniqueName(CleanupName( RemoveEnding(StringFromList (ItemsInList(S_FileName, ":") - 1, S_FileName, ":"), ".bin"), 0), 1, 0)
	
	Make /O/N=(SampleCount1) $(name)
	Wave target = $(name)
	
	FSetPos refNum, 10 + 51
	FBinRead /F=2 refNum, target
	SetScale /I x, 0, 10*TimeBase, "s", target
	SetScale d, -25 * Sensitivity, 25 * Sensitivity, "V", target
	target *= Sensitivity / 25
	
	Note $(name), "TimeBase = " + num2str(TimeBase)
	Note $(name), "Sensitivity = " + num2str(Sensitivity)

	Close refNum
	
	//Print S_Filename + " loaded into wave " + name + "."
	return name
End


Function OwonASDFolder([sens, path])
	Variable sens
	String path
	
	If (ParamIsDefault(sens))
		Variable gain
		prompt gain, "Gain", popup, "1;10e1;10e2"
		doprompt "", gain
		sens = 10^-(gain-1)
	EndIf
	
	If (ParamIsDefault(path))
		NewPath /O OwonASD
		PathInfo OwonASD
	Else
		NewPath /O OwonASD, path
	EndIf
	PathInfo OwonASD 	// Set S_Path
	
	Variable i = 0
	String fn, wn // filename and wavename
	
	Do
		fn = IndexedFile (OwonASD, i, ".bin")
		If (strlen(fn) == 0)
			break;
		EndIf

		wn = OwonRead(fn = S_Path + fn)
		Wave w = $wn
		w = w * sens
		
		WaveStats /Q w
		w -= V_avg

		Variable points = numpnts(w)
		Variable samplingrate = 1/deltax(w)

		if(i == 0)
			Make/O/N=(points/2 + 1) CurrentASD1 ASD1 PSD1 INT1
			SetScale/P x 0,samplingrate/(points),"Hz", CurrentASD1, ASD1
			PSD1 = 0
		endif
		
		Duplicate/O w TempASD
		Hanning TempASD
		FFT TempASD
		CurrentASD1=MagSqr(TempASD)
		CurrentASD1[1,points/2-1] *=2					//don't multiply 1st and last point by 2
		//because these bins dont get doubled when
		//you fold a 2-sided spectrum into a 1-sided
				
		CurrentASD1*=((8/3)/(samplingrate*points))	// 8/3 is factor for Hanning window
		
		// calculate the Average PSD now (CANNOT!! average the ASD)
		PSD1= PSD1*(i)/(i + 1) + CurrentASD1/(i + 1)
	
		// AFTER the averaging it is okay to take the sqrt
		CurrentASD1 = sqrt(CurrentASD1)
		ASD1 = sqrt(PSD1)
		
		//Calculate the IntWave
	
		Integrate PSD1/D=INT1 
		CopyScales ASD1 INT1

		killwaves w
		
		i += 1
		fn = IndexedFile (OwonData, i, ".bin")
	While (1)

	KillPath OwonASD	
End


Function OwonASD(Raw1)
		Wave Raw1
		Variable points = numpnts(Raw1)
		Variable samplingrate = 1/deltax(raw1)
		Variable counter = 0
		if(counter ==0)
			Make/O/N=(points/2 + 1) CurrentASD1 ASD1 PSD1 INT1
			SetScale/P x 0,samplingrate/(points),"Hz", CurrentASD1, ASD1
			PSD1 = 0
		endif
		
		Duplicate/O Raw1 TempASD
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
End

Function OwonASDFolderMany([sens, path])
	Variable sens
	String path
	
	If (ParamIsDefault(sens))
		Variable gain
		prompt gain, "Gain", popup, "1;10e1;10e2"
		doprompt "", gain
		sens = 10^-(gain-1)
	EndIf
	
	If (ParamIsDefault(path))
		NewPath /O OwonData
		PathInfo OwonData
	Else
		NewPath /O OwonData, path
	EndIf
	
	Variable i = 0
	String fullpath, foldername, savedf
	
	savedf = GetDataFolder(1)
	
	Do
		fullpath = IndexedDir (OwonData, i, 1)
		foldername = IndexedDir (OwonData, i, 0)
		If (strlen(foldername) == 0)
			break;
		EndIf
		
		NewDataFolder /O/S $foldername
		OwonASDFolder(path=fullpath, sens=sens)
		SetDataFolder savedf
		i += 1
	While(1)

	SetDataFolder savedf
End