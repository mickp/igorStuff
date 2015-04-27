#pragma rtGlobals=1		// Use modern global access method.

#If !(Exists("pnt2y") == 3 )
Function pnt2y(w, point)
	wave w
	variable point
	
	return DimOffset(w, 1) + point *DimDelta(w, 1)
End
#EndIf

Function MAPSurfaceNormals(w)
	//	Calculate surface normals at and between points on a regular grid.
	wave w
	
	Variable rows, cols
	rows = dimSize(w, 0)
	cols = dimSize(w, 1)
	
	//	Face normals
	Make /O/N=(rows-1, cols-1, 3) $(NameOfWave(w) + "_FNorms")
	wave f = $(NameOfWave(w) + "_FNorms")

	//	Vertex normals
	Duplicate /O w, $(NameOfWave(w) + "_VNorms")
	wave v = $(NameOfWave(w) + "_VNorms")
	Redimension /N=(rows,cols,3) v

	Variable i, j	//	counters i & j
	
	For(i = 0; i < rows-1; i += 1)
		For(j =0; j < cols-1; j += 1)

			//	Point positions:
			//	p1-->p2
			//	 |
			//	 v
			//	p3

			Variable x1, x2, x3, y1, y2, y3, z1, z2, z3 	// x,y,z for p1, p2 and p3
			Variable xn, yn, zn						//	x,y,z for surface normal
			Variable r								//	length of surface normal

			x1 = pnt2x(w, i)
			x2 = pnt2x(w, i+1)
			x3 = x1
			y1 = pnt2y(w, j)
			y2 = y1
			y3 = pnt2y(w, j+1)
			z1 = w[i][j]
			z2 = w[i+1][j]
			z3 = w[i][j+1]

			xn = (z1-z2)*(y3-y2)-(y1-y2)*(z3-z2)
			yn = (x1-x2)*(z3-z2)-(z1-z2)*(x3-x2)
			zn = (y1-y2)*(x3-x2)-(x1-x2)*(y3-y2)
			
			r = sqrt(xn^2 + yn^2 + zn^2)
			
			f[i][j][0] = xn / r
			f[i][j][1] = yn / r
			f[i][j][2] = zn / r
		Endfor 
	EndFor
	
	//	Average face normals to determine vertex normals.
	v[][][0] = (f[p-1][q-1][0] + f[p-1][q][0] + f[p][q-1][0] + f[p][q][0]) / 4
	v[][][1] = (f[p-1][q-1][1] + f[p-1][q][1] + f[p][q-1][1] + f[p][q][1]) / 4
	v[][][2] = (f[p-1][q-1][2] + f[p-1][q][2] + f[p][q-1][2] + f[p][q][2]) / 4

	return 0
End
