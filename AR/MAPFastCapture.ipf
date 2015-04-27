#pragma rtGlobals=1		// Use modern global access method.#pragma ModuleName = MAPFastCaptureStrConstant pkgdir = "root:packages:MAP"StrConstant seglenstr = "256;512;1024;2048;4096;8192;16384;32768;65536"StrConstant windowstr = "Square;Hann;Parzen;Welch;Hamming;BlackmanHarris3;KaiserBessel"StrConstant sqrootstr = "Linear (Units/Sqrt(Hz));Power (Units^2/Hz))"StrConstant destwavename = "root:FastCaptureData"Function InitMAPFastCapture()		//	Used by the UserPanels machinery to set up data structures	If(!DataFolderExists(pkgdir))		NewDatafolder $pkgdir	EndIf		If(!Exists(pkgdir + ":MAPFastCaptureLength"))		Variable /G $(pkgdir + ":MAPFastCaptureLength") = 8.6e6		Make /O /N=1 $destwavename	EndIf	EndFunction MAPFastCaptureDoPSD()		//	Does the PSD calculation using BigPSD	Wave FastCaptureData = $destwavename		//	Grab values from controls and do the calculation	ControlInfo /W=MAPFastCapture MAPFastCapturePSDSeglen	Variable seglen = V_Value	ControlInfo /W=MAPFastCapture MAPFastCapturePSDWindow	Variable window = V_Value	ControlInfo /W=MAPFastCapture MAPFastCapturePSDSqroot	Variable Sqroot = V_Value	MAPFastCaptureMakeWorkingPanel(msg="Calculating PSD.")	BigPSDFunc(destwavename, seglen, window, Sqroot)	MAPFastCaptureKillWorkingPanel()	//	If the PSD isn't visible, display it.	DoWindow /F FastCapturePSD0	If(V_Flag == 0)		Display /K=1 /N=FastCapturePSD0 $(destwavename + "_PSD")  as "Fast capture PSD"		ModifyGraph log(left)=1	EndIf	//	Enable button to save PSD as force curve	MasterARGhostFunc("","MAPFastCaptureSavePSD")EndFunction MAPFastCaptureCallback(Action)	//	This sets up and reads back the fast capture data	String Action		String CallBackStr, ErrorStr = ""	Wave DestWave = $destwavename		StrSwitch (Action)		Case "Error":		//	There was an error in fast capture setup			print "There was a problem - check the error log."			MasterARGhostFunc("","MAPFastCaptureGo")			break		Case "Read":	//	Read the fast capture buffer, then call this function again to tell it we're done.			CallBackStr = "MAPFastCaptureCallback(\"Done\")"			ErrorStr = num2str(td_ReadCapture("Cypher.Capture.0", DestWave, CallBackStr)) + ","			If ( ARReportError(ErrorStr) )				MAPFastCaptureCallback("Error")			EndIf			break		Case "Done":	//	Fast capture read-back completed			//	Display the data if it's not already visible			DoWindow /F FastCaptureData0			If(V_Flag == 0)				Display /K=1 /N=FastCaptureData0 $destwavename  as "Fast capture data"			Else				//	I need to do this, or Igor won't update the graph for ages.				RemoveFromGraph /W=FastCaptureData0 FastCaptureData				AppendToGraph /W=FastCaptureData0 $destwavename 			EndIf						//	Do the PSD calculation, if the checkbox is checked.			ControlInfo /W=MAPFastCapture MAPFastCapturePSDCheckBox			If (V_Value)	// Calculate PSD checkbox is checked				MAPFastCaptureDoPSD()			EndIf      			ControlInfo /W=MAPFastCapture  MAPFastCaptureForceCheckBox			Variable DoForceCurve = V_Value			// Reset user callbacks			If(DoForceCurve)				ARCheckFunc("ARUserCallbackMasterCheck_1",0)				ARCheckFunc("ARUserCallbackForceDoneCheck_1", 0)				PDS("ARUserCallbackForceDone","")				CtrlNamedBackground MAPFastCaptureTrigger, stop			EndIf			//	We're done - enable the save-raw-data button now there is data, and re-enable the fast capture 'Go' button			MasterARGhostFunc("","MAPFastCaptureGo;MAPFastCaptureSaveData")			break	EndSwitchEndFunction MAPFastCaptureTriggerTask(s)		// This is a background task that triggers fast capture when a force plot starts	STRUCT WMBackgroundStruct &s	SVAR WhatIsRunning = root:packages:MFP3D:Main:WhatsRunning	//	Fast capture doesn't recognise controller events, yet.	//	In lieu of events, I use an Igor background task that checks WhatIsRunning up to 60 times a second (once per Igor tic).	//	This function is triggered by "Force" appearing in WhatIsRunning.	//	There's a lot that gets done between "Force" being written to WhatIsRunning and the actual start of the force curve.	//	If I trigger fast capture immediately on seeing "Force", 90% of the time I see a 0.5s or longer delay between the start of fast capture	//	and the start of the force curve ... that's a lot of points at 80 MHz!  It'd be nice to wait 0.5s before triggering fast capture, but then I	//	might miss the force curve 10% of the time, and I expect the "Force" to force-curve-start delay could vary greatly from PC to PC.			If(stringmatch(WhatIsRunning, "*Force*") )		CtrlNamedBackground MAPFastCaptureTrigger, stop		td_WV("Cypher.Capture.0.Trigger", 1)	EndIf	return 0	// Continue background taskEndFunction MAPFastCaptureButtonProc(ba) : ButtonControl	//	Fast capture panel button procedure	STRUCT WMButtonAction &ba	If(ba.eventCode != 2)	// return now if event is not mouseup		return 0	EndIf	StrSwitch( ba.ctrlName )		case "MAPFastCaptureGo": // Go button - set up fast capture and do it.			String ErrorStr = ""			Wave DestWave = $destwavename			NVAR DataLength = $(pkgdir + ":MAPFastCaptureLength")						//	Write data rate and number of points to hardware			ControlInfo /W=MAPFastCapture  MAPFastCaptureDataRate			Variable DataRateIndex = V_Value - 1			ControlInfo /W=MAPFastCapture  MAPFastCaptureForceCheckBox			Variable DoForceCurve = V_Value			ErrorStr += num2str(td_WV("Cypher.Capture.0.Rate", DataRateIndex)) +","			ErrorStr += num2str(td_WV("Cypher.Capture.0.Length", DataLength)) +","			//	Set up and trigger fast capture			MasterARGhostFunc("MAPFastCaptureGo", "")	// Disable 'go' button to stop concurrent attempts to fast capture			If(DoForceCurve)	//	We're doing a force curve				//	Use UserEvents to deal with readback				ARCheckFunc("ARUserCallbackMasterCheck_1",1)				ARCheckFunc("ARUserCallbackForceDoneCheck_1", 1)				PDS("ARUserCallbackForceDone","MAPFastCaptureCallback(\"Read\")")				//	Use a background function to look for when the force curve starts, at least until FastCapture can recognise controller events				CtrlNamedBackground MAPFastCaptureTrigger, period=1, proc=MAPFastCaptureTriggerTask				CtrlNamedBackground MAPFastCaptureTrigger, start				//	Start the force curve as if the 'Single Force' button was pressed				DoForceFunc("SingleForce_2")			Else	//	We're not doing a force curve.				//	Trigger fast capture directly				ErrorStr += num2str(td_WV("Cypher.Capture.0.Trigger", 1)) +","				//	Read back the data, or throw an error				If( ARReportError(ErrorStr) == 0)					MAPFastCaptureCallback("Read")				Else					MAPFastCaptureCallback("Error")				EndIf			EndIf			break					case "MAPFastCaptureSaveData":	//	Save the raw data as a force curve			MAPFastCaptureMakeWorkingPanel(msg="Saving data.")			DoUpdate			Wave/Z Data = $destwavename 			Duplicate/FREE Data,xWave			Ax2Wave(Data,0,xWave)			ARSaveAsForce(1 | (GV("SaveForce") & 2),"SaveForce","Time;DeflV;",xWave,xWave,Data,$"", $"",$"",$"")			MAPFastCaptureKillWorkingPanel()			break		case "MAPFastCaptureSavePSD":	//	Save the PSD as a force curve			MAPFastCaptureMakeWorkingPanel(msg="Saving PSD.")			Wave/Z Data = $(destwavename + "_PSD")			Duplicate/FREE Data,xWave			Ax2Wave(Data,0,xWave)			ARSaveAsForce(1 | (GV("SaveForce") & 2),"SaveForce","Freq;DeflV;",xWave,xWave,Data,$"", $"",$"",$"")			MAPFastCaptureKillWorkingPanel()	endswitch	return 0End//	Functions for a status window.Function MAPFastCaptureMakeWorkingPanel([msg])	String msg		If(ParamIsDefault(msg))		msg = "Doing stuff."	EndIf	NewPanel /FLT=2/K=2/N=Working /W=(320,320,660,400)	DrawText 20,32,msg	ValDisplay valdisp0,pos={20,38},size={300,18},limits={0,100,0},barmisc={0,0}	ValDisplay valdisp0,value= _NUM:0	ValDisplay valdisp0,mode= 4	SetActiveSubwindow _endfloat_	DoUpdate/W=Working/E=1		// mark this as our progress window	SetWindow Working,hook(spinner)= MAPFastCaptureUpdateWorkingEndFunction MAPFastCaptureKillWorkingPanel()	KillWindow WorkingEndFunction MAPFastCaptureUpdateWorking(s)		STRUCT WMWinHookStruct &s	if( s.eventCode == 23 )		ValDisplay valdisp0,value= _NUM:1,win=Working		DoUpdate/W=Working		if( V_Flag == 2 )	// we only have one button and that means abort			KillWindow $s.winName			return 1		endif	endif	return 0EndFunction PerformLongCalc(nmax)	Variable nmax		Variable i,s	for(i=0;i<nmax;i+=1)		s+= sin(i/nmax)	endforEndFunction MAPFastCapturePopMenuProc(pa) : PopupMenuControl	//	Fast capture panel popup menu procedure	STRUCT WMPopupAction &pa		//	Return straight away if event is not mouse up.	if (pa.EventCode != 2)		return(0)	endif	Variable popNum = pa.popNum	String popStr = pa.popStr			StrSwitch (pa.ctrlName)		case "MAPFastCaptureDataRate":	//	Update acquisition time display on change of data rate			NVAR DataLength = $(pkgdir + ":MAPFastCaptureLength")			Make /FREE Freqs = {80e6, 20e6, 5e6}			ValDisplay MAPFastCaptureDuration value=_NUM:(DataLength / Freqs[pa.popNum-1])		break				case "MAPFastCapturePSDSeglen":	//	Update PSD on change of PSD calculation parameters		case "MAPFastCapturePSDWindow":		case "MAPFastCapturePSDSqroot":		ControlInfo /W=MAPFastCapture MAPFastCapturePSDCheckBox		If(V_Value)			MAPFastCaptureDoPSD()		EndIf		break	EndSwitch	return 0EndFunction MAPFastCaptureSetVarProc(sva) : SetVariableControl	//	Fast capture panel setvar procedure	STRUCT WMSetVariableAction &sva	switch( sva.eventCode )		//	Catch any change of value		case 1: // mouse up		case 2: // Enter key		case 3: // Live update			Variable dval = sva.dval			String sval = sva.sval						StrSwitch (sva.vName)			case "MAPFastCaptureLength":				//	Cypher doesn't like odd numbers for the data length - it seems to hang the DSP.				If(mod(dval,2))					NVAR var = $(pkgdir + ":" + sva.vName)					dval += 1					var = dval				EndIf				//	Update the acquisiton time display				Make /FREE Freqs = {80e6, 20e6, 5e6}				ControlInfo /W=MAPFastCapture MAPFastCaptureDataRate				ValDisplay MAPFastCaptureDuration value=_NUM:(dval / Freqs[V_Value-1])					break			EndSwitch		case -1: // control being killed			break	endswitch	return 0End Function MAPFastCaptureCheckProc(cba) : CheckBoxControl		// Fast capture panel checkbox procedure	STRUCT WMCheckboxAction &cba	//	Return straight away if event is not mouse up.	if (cba.EventCode != 2)		return(0)	endif	StrSwitch(cba.ctrlName)		case "MAPFastCapturePSDCheckBox":			Variable checked = cba.checked			//	If unchecked, kill the PSD graph			If (!checked)				DoWindow /K FastCapturePSD0				MasterARGhostFunc("MAPFastCaptureSavePSD","")			Else			If (numpnts($destwavename) > 1)	//	If checked and data exists, calculate the PSD now.				MAPFastCaptureDoPSD()			EndIf		EndIf		break	EndSwitch	return 0End//	Build the fast capture panel//	After 'saving' the panel, comment out the "ValDisplay MAPFastCaptureDuration,value=..." line;//	The value map be incorrect after rebuilding the panel, so it should be blank until updated by a control.Window MAPFastCapture() : Panel	PauseUpdate; Silent 1		// building window...	NewPanel /K=1 /W=(915,57,1233,325)	SetDrawLayer ProgBack	SetDrawEnv linethick= 3,linefgc= (0,39168,39168),fillpat= 0	DrawRect 3,3,315,265	SetDrawLayer UserBack	SetDrawEnv fillpat= 0	DrawRRect 11,21,309,92	SetDrawEnv fillpat= 0	DrawRRect 11,110,309,190	DrawText 13,22,"sampling parameters"	DrawText 13,111,"PSD calculation"	SetDrawEnv fillpat= 0	DrawRRect 11,197,309,226	DrawText 17,220,"save data to force curve"	Button UserPanelRenameButton_0,pos={40,233},size={80,20},proc=ARUserPanelButtonFunc,title="Rename"	Button UserPanelRenameButton_0,userdata= A":gnHZ3^Yr.F(KB53^Ih4CisSU6uQRXD.RU,F#lU.H#.V?;Iso\\@<,jk3`U64E_p1^AScEK4%W7<:18!N3__n:7U^@[6XaqUF`M%GBlIZG87?[Q;dji\\A3)D+"	Button UserPanelRenameButton_0,font="Arial",fColor=(61440,61440,61440)	Button UserPanelSaveButton_0,pos={140,233},size={80,20},proc=ARUserPanelButtonFunc,title="Save"	Button UserPanelSaveButton_0,userdata= A":gnHZ3^Yr.F(KB53^Ih4CisSU6uQRXD.RU,F#lU.H#.V?;Iso\\@<,jk3`U64E_p1^AScEK4%W7<:18!N3__n:7U^@[6XaqUF`M%GBlIZG87?[Q;dji\\A3)D+"	Button UserPanelSaveButton_0,font="Arial",fColor=(61440,61440,61440)	PopupMenu UserPanelColorPop_0,pos={220,233},size={83,22},proc=ARUserPanelPopFunc,title="Color"	PopupMenu UserPanelColorPop_0,userdata= A"zz5iWsez5iWsez",font="Arial",fSize=12	PopupMenu UserPanelColorPop_0,mode=0,popColor= (0,39168,39168),value= #"\"*COLORPOP*\""	PopupMenu MAPFastCaptureDataRate,pos={87,26},size={93,22},bodyWidth=72,proc=MAPFastCapturePopMenuProc,title="rate"	PopupMenu MAPFastCaptureDataRate,mode=3,popvalue="5 MHz",value= #"\"80 MHz;20 MHz;5 MHz\""	SetVariable MAPFastCaptureLengthSetVar,pos={51,53},size={129,16},bodyWidth=72,proc=MAPFastCaptureSetVarProc,title="data length"	SetVariable MAPFastCaptureLengthSetVar,limits={-inf,inf,2},value= root:packages:MAP:MAPFastCaptureLength	Button MAPFastCaptureGo,pos={256,68},size={50,20},proc=MAPFastCaptureButtonProc,title="Go"	Button MAPFastCaptureGo,fColor=(61440,61440,61440)	CheckBox MAPFastCapturePSDCheckBox,pos={220,116},size={86,14},proc=MAPFastCaptureCheckProc,title="calculate PSD"	CheckBox MAPFastCapturePSDCheckBox,value= 0,side= 1	PopupMenu MAPFastCapturePSDSeglen,pos={14,114},size={203,22},bodyWidth=128,proc=MAPFastCapturePopMenuProc,title="segment length"	PopupMenu MAPFastCapturePSDSeglen,mode=1,popvalue="256",value= #"seglenstr"	PopupMenu MAPFastCapturePSDWindow,pos={27,139},size={190,22},bodyWidth=128,proc=MAPFastCapturePopMenuProc,title="window type"	PopupMenu MAPFastCapturePSDWindow,mode=1,popvalue="Square",value= #"windowstr"	PopupMenu MAPFastCapturePSDSqroot,pos={64,164},size={153,22},bodyWidth=128,proc=MAPFastCapturePopMenuProc,title="units"	PopupMenu MAPFastCapturePSDSqroot,mode=2,popvalue="Power (Units^2/Hz))",value= #"sqrootstr"	ValDisplay MAPFastCaptureDuration,pos={28,75},size={151,14},bodyWidth=72,title="acquisition time "	ValDisplay MAPFastCaptureDuration,format="%.2W0Ps",frame=0	ValDisplay MAPFastCaptureDuration,valueBackColor=(60928,60928,60928)	ValDisplay MAPFastCaptureDuration,limits={0,0,0},barmisc={0,1000}//	ValDisplay MAPFastCaptureDuration,value=	CheckBox MAPFastCaptureForceCheckBox,pos={219,51},size={87,14},proc=MAPFastCaptureCheckProc,title="do force curve"	CheckBox MAPFastCaptureForceCheckBox,value= 0,side= 1	Button MAPFastCaptureSaveData,pos={159,202},size={72,20},disable=2,proc=MAPFastCaptureButtonProc,title="raw data"	Button MAPFastCaptureSaveData,fColor=(61440,61440,61440)	Button MAPFastCaptureSavePSD,pos={234,202},size={72,20},disable=2,proc=MAPFastCaptureButtonProc,title="PSD"	Button MAPFastCaptureSavePSD,fColor=(61440,61440,61440)	SetWindow kwTopWin,hook(AR)=UserCnTPanelHookEndMacro