#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function TektronixReadFolder()
	NewPath /O TekData
	PathInfo TekData
	
	Variable i = 0
	String filelist = IndexedFile(TekData, -1, ".csv")
	String fn

	Display
	


	Do
		fn = StringFromList(i, filelist)
		If (strlen(fn) == 0)
			break;
		EndIf

		LoadWave /A /Q /J /B="C=2, T=2;" /L={0,18, 0, 3, 2}  /P=TekData fn
		
		fn = ReplaceString(".CSV", fn, "")
		
		Rename $(StringFromList(0, S_waveNames)), $(fn + "_time")
		Rename $(StringFromList(1, S_waveNames)), $(fn + "_V")
		
		AppendToGraph $(fn+"_V") vs $(fn + "_time")

		i += 1
	While (i < ItemsInList(filelist))
	
End