#pragma rtGlobals=1		// Use modern global access method.

Function LayerDifferenceAsNewLayer()
	//	A - B as a modified layer A (e.g. HeightTraceMod0) in topmost image window
	string layerAname = "LateralTrace"		//  edit as appropriate
	string layerBname = "LateralRetrace"	//  edit as appropriate
	
	wave data = ImageNameToWaveRef( "", StringFromList( 0, ImageNameList( "",";"), ";") )
	variable LayerNum
	
	string EntryDataFolder = GetDataFolder(1)
	SetDataFolder GetWavesDataFolder(data, 1)
	
	//  Extract layer B
	LayerNum = FindDimLabel(data, 2, layerBname)
	if (LayerNum == -2)
		DoAlert 0, "Couldn't find " + layerBname + "."
		SetDataFolder EntryDataFolder
		return -1
	endif
	ExtractLayerNum( data, LayerNum, DestName="LayerB")
	Wave LayerB
	
	//  Extract layer A and do subtraction
	LayerNum = FindDimLabel(data, 2, layerAname)
	if (LayerNum == -2)
		DoAlert 0, "Couldn't find " + layerAname + "."
		KillWaves /Z LayerB
		SetDataFolder EntryDataFolder		
		return -1
	endif
	ExtractLayerNum( data, LayerNum)
	Wave LayerData
	LayerData -= LayerB[p][q]
	
	//  Insert as new layer
	InsertLayerNum(0, 0)
	
	//  Clean up
	KillWaves /Z LayerB, LayerData	
	SetDataFolder EntryDataFolder
End