#pragma rtGlobals=1		// Use modern global access method.

Macro MAPAnnotateHistogram()
	String strNote = ""

	ControlInfo Parm0
	strNote += "scale\t" + num2str(V_Value) + "\r"

	ControlInfo Parm1
	strNote += "mean\t" + num2str(V_Value) + "\r"

	ControlInfo Parm2
	strNote += "width\t" + num2str(V_Value) + "\r"

	TextBox/K/N=MAPAnnotation
	
	TextBox/C/N=MAPAnnotation/F=0 strNote
End


Function MAPColours()
//	SetChannelColorMap("Channel11", NaN, "Mocha")
//	SetChannelColorMap("Channel21", NaN, "YellowHot")
//	SetChannelColorMap("Channel31", NaN, "VioletOrangeYellow")
//	SetChannelColorMap("Channel41", NaN, "YellowHot")
//	SetChannelColorMap("Channel51", NaN, "VioletOrangeYellow")

	Variable i
	Struct ARRTImageInfo InfoStruct
	String ChannelString
	String ColourString
	
	For (i = 1; i <= 5; i += 1)
	ChannelString = "Channel" + num2str(i) + "1"
	InfoStruct.ChannelNum = i
	InfoStruct.IsNap = 0
	ARGetChannelInfo(InfoStruct)
	StrSwitch(InfoStruct.DataType)
		case "Height":
			ColourString = "Mocha"
			break
		case "Amplitude":
		case "Amplitude1":
		case "Amplitude2":
			ColourString = "YellowHot"
			break
		case "Phase":
		case "Phase1":
		case "Phase2":
			ColourString = "VioletOrangeYellow"
			break			
		default:
			ColourString = "Greys"
	EndSwitch
	SetChannelColorMap(ChannelString, NaN, ColourString)
	EndFor
End
