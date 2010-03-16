# geometry of main defined in: ./zone.geo
#ZONE_NAME: zone description type, zone name, description
GEN main_1 This file describes the main_1
#VER_SUR_ROT: vertex count, surface count, rotation angle CCW looking down (degrees)
34 14 90
#VERTICES: X co-ord, Y co-ord, Z co-ord
# line per vertex- base in counter-clockwise (CCW) fashion looking down, then top in CCW fashion
# then additional vertices for windows/doors
  0.00   0.00   2.44 # base v1; total v1
 11.82   0.00   2.44 # base v2; total v2
 11.82  17.64   2.44 # base v3; total v3
  0.00  17.64   2.44 # base v4; total v4
  0.00   0.00   4.88 # top v1; total v5
 11.82   0.00   4.88 # top v2; total v6
 11.82  17.64   4.88 # top v3; total v7
  0.00  17.64   4.88 # top v4; total v8
  3.24   0.00   3.10 # front-wndw v1; total v9
  6.60   0.00   3.10 # front-wndw v2; total v10
  7.72   0.00   3.10 # front-wndw v3; total v11
  7.72   0.00   4.22 # front-wndw v4; total v12
  6.60   0.00   4.22 # front-wndw v5; total v13
  3.24   0.00   4.22 # front-wndw v6; total v14
 10.86   0.00   2.54 # front-door v1; total v15
 11.72   0.00   2.54 # front-door v2; total v16
 11.72   0.00   4.65 # front-door v3; total v17
 10.86   0.00   4.65 # front-door v4; total v18
 11.82   7.17   3.46 # right-wndw v1; total v19
 11.82   9.00   3.46 # right-wndw v2; total v20
 11.82   9.61   3.46 # right-wndw v3; total v21
 11.82   9.61   3.86 # right-wndw v4; total v22
 11.82   9.00   3.86 # right-wndw v5; total v23
 11.82   7.17   3.86 # right-wndw v6; total v24
 11.82  16.68   2.54 # right-door v1; total v25
 11.82  17.54   2.54 # right-door v2; total v26
 11.82  17.54   4.65 # right-door v3; total v27
 11.82  16.68   4.65 # right-door v4; total v28
  7.93  17.64   3.19 # back-wndw v1; total v29
  4.90  17.64   3.19 # back-wndw v2; total v30
  3.89  17.64   3.19 # back-wndw v3; total v31
  3.89  17.64   4.13 # back-wndw v4; total v32
  4.90  17.64   4.13 # back-wndw v5; total v33
  7.93  17.64   4.13 # back-wndw v6; total v34
#END_VERTICES
#SURFACES: line per surface- number of vertices followed by list of associated vert
# CCW fashion looking from outside toward inside
# return vertex is implied (i.e. 4 1 2 6 5 instead of 5 1 2 6 5 1)
4 1 4 3 2 # floor
4 5 6 7 8 # ceiling
22 1 2 6 5 1 9 14 13 10 9 1 10 13 12 11 10 1 15 18 17 16 15 # front
4 9 10 13 14 # front-aper
4 10 11 12 13 # front-frame
4 15 16 17 18 # front-door
22 2 3 7 6 2 19 24 23 20 19 2 20 23 22 21 20 2 25 28 27 26 25 # right
4 19 20 23 24 # right-aper
4 20 21 22 23 # right-frame
4 25 26 27 28 # right-door
16 3 4 8 7 3 29 34 33 30 29 3 30 33 32 31 30 # back
4 29 30 33 34 # back-aper
4 30 31 32 33 # back-frame
4 4 1 5 8 # left
#END_SURFACES
#UNUSED_INDEX: equal to number of surfaces
0 0 0 0 0 0 0 0 0 0 0 0 0 0
#SURFACE_INDENTATION (m): equal to number of surfaces
0 0 0 0 0 0 0 0 0 0 0 0 0 0
#INSOLATION
3 0 0 0 # default insolation distribution
#SURFACE_ATTRIBUTES: must be columner format with line for each surface (see exemplar for example)
# surface attributes follow: 
# id number
# surface name
# construction type OPAQ, TRAN
# placement FLOR, CEIL, VERT, SLOP
# construction name
# outside condition EXTERIOR, ANOTHER, BASESIMP, ADIABATIC
  1, floor         OPAQ  FLOR  M->B         ANOTHER        
  2, ceiling       OPAQ  CEIL  M->A_or_R    ANOTHER        
  3, front         OPAQ  VERT  M_wall       EXTERIOR       
  4, front-aper    TRAN  VERT  WNDW_234     EXTERIOR       
  5, front-frame   OPAQ  VERT  FRM_Vnl      EXTERIOR       
  6, front-door    OPAQ  VERT  D_mtl_EPS    EXTERIOR       
  7, right         OPAQ  VERT  M_wall       EXTERIOR       
  8, right-aper    TRAN  VERT  WNDW_234     EXTERIOR       
  9, right-frame   OPAQ  VERT  FRM_Vnl      EXTERIOR       
 10, right-door    OPAQ  VERT  D_mtl_EPS    EXTERIOR       
 11, back          OPAQ  VERT  M_wall       EXTERIOR       
 12, back-aper     TRAN  VERT  WNDW_234     EXTERIOR       
 13, back-frame    OPAQ  VERT  FRM_Vnl      EXTERIOR       
 14, left          OPAQ  VERT  M_wall       EXTERIOR       
#END_SURFACE_ATTRIBUTES
#BASE: list of floor surface ID numbers (must have six elements), area of base (m^2); also leave the final line after this next line
1 0 0 0 0 0 208.5 0
