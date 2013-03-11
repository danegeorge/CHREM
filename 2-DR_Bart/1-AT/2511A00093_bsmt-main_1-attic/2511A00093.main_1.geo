# geometry of main defined in: ./zone.geo
#ZONE_NAME: zone description type, zone name, description
GEN main_1 This file describes the main_1
#VER_SUR_ROT: vertex count, surface count, rotation angle CCW looking down (degrees)
34 14 180
#VERTICES: X co-ord, Y co-ord, Z co-ord
# line per vertex- base in counter-clockwise (CCW) fashion looking down, then top in CCW fashion
# then additional vertices for windows/doors
  0.00   0.00   2.44 # base v1; total v1
 10.82   0.00   2.44 # base v2; total v2
 10.82   7.21   2.44 # base v3; total v3
  0.00   7.21   2.44 # base v4; total v4
  0.00   0.00   4.88 # top v1; total v5
 10.82   0.00   4.88 # top v2; total v6
 10.82   7.21   4.88 # top v3; total v7
  0.00   7.21   4.88 # top v4; total v8
  3.45   0.00   3.23 # front-wndw v1; total v9
  5.78   0.00   3.23 # front-wndw v2; total v10
  6.56   0.00   3.23 # front-wndw v3; total v11
  6.56   0.00   4.09 # front-wndw v4; total v12
  5.78   0.00   4.09 # front-wndw v5; total v13
  3.45   0.00   4.09 # front-wndw v6; total v14
  9.91   0.00   2.54 # front-door v1; total v15
 10.72   0.00   2.54 # front-door v2; total v16
 10.72   0.00   4.57 # front-door v3; total v17
  9.91   0.00   4.57 # front-door v4; total v18
 10.82   5.84   2.54 # right-door v1; total v19
 10.82   7.11   2.54 # right-door v2; total v20
 10.82   7.11   4.52 # right-door v3; total v21
 10.82   5.84   4.52 # right-door v4; total v22
  7.27   7.21   3.19 # back-wndw v1; total v23
  4.48   7.21   3.19 # back-wndw v2; total v24
  3.55   7.21   3.19 # back-wndw v3; total v25
  3.55   7.21   4.13 # back-wndw v4; total v26
  4.48   7.21   4.13 # back-wndw v5; total v27
  7.27   7.21   4.13 # back-wndw v6; total v28
  0.00   5.22   3.04 # left-wndw v1; total v29
  0.00   2.80   3.04 # left-wndw v2; total v30
  0.00   1.99   3.04 # left-wndw v3; total v31
  0.00   1.99   4.28 # left-wndw v4; total v32
  0.00   2.80   4.28 # left-wndw v5; total v33
  0.00   5.22   4.28 # left-wndw v6; total v34
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
10 2 3 7 6 2 19 22 21 20 19 # right
4 19 20 21 22 # right-door
16 3 4 8 7 3 23 28 27 24 23 3 24 27 26 25 24 # back
4 23 24 27 28 # back-aper
4 24 25 26 27 # back-frame
16 4 1 5 8 4 29 34 33 30 29 4 30 33 32 31 30 # left
4 29 30 33 34 # left-aper
4 30 31 32 33 # left-frame
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
  4, front-aper    TRAN  VERT  WNDW_200     EXTERIOR       
  5, front-frame   OPAQ  VERT  FRM_wood     EXTERIOR       
  6, front-door    OPAQ  VERT  D_wood_sld   EXTERIOR       
  7, right         OPAQ  VERT  M_wall_adb   ADIABATIC      
  8, right-door    OPAQ  VERT  D_mtl_Plur   EXTERIOR       
  9, back          OPAQ  VERT  M_wall       EXTERIOR       
 10, back-aper     TRAN  VERT  WNDW_200     EXTERIOR       
 11, back-frame    OPAQ  VERT  FRM_wood     EXTERIOR       
 12, left          OPAQ  VERT  M_wall       EXTERIOR       
 13, left-aper     TRAN  VERT  WNDW_200     EXTERIOR       
 14, left-frame    OPAQ  VERT  FRM_wood     EXTERIOR       
#END_SURFACE_ATTRIBUTES
#BASE: list of floor surface ID numbers (must have six elements), area of base (m^2); also leave the final line after this next line
1 0 0 0 0 0 78.0 0
