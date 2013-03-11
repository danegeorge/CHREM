# geometry of main defined in: ./zone.geo
#ZONE_NAME: zone description type, zone name, description
GEN main_1 This file describes the main_1
#VER_SUR_ROT: vertex count, surface count, rotation angle CCW looking down (degrees)
36 15 225
#VERTICES: X co-ord, Y co-ord, Z co-ord
# line per vertex- base in counter-clockwise (CCW) fashion looking down, then top in CCW fashion
# then additional vertices for windows/doors
  0.00   0.00   2.21 # base v1; total v1
  7.42   0.00   2.21 # base v2; total v2
  7.42   7.97   2.21 # base v3; total v3
  0.00   7.97   2.21 # base v4; total v4
  0.00   0.00   4.65 # top v1; total v5
  3.83   0.00   4.65 # top v2; total v6
  7.42   0.00   4.65 # top v3; total v7
  7.42   7.97   4.65 # top v4; total v8
  3.83   7.97   4.65 # top v5; total v9
  0.00   7.97   4.65 # top v6; total v10
  1.81   0.00   2.80 # front-wndw v1; total v11
  4.05   0.00   2.80 # front-wndw v2; total v12
  4.80   0.00   2.80 # front-wndw v3; total v13
  4.80   0.00   4.06 # front-wndw v4; total v14
  4.05   0.00   4.06 # front-wndw v5; total v15
  1.81   0.00   4.06 # front-wndw v6; total v16
  6.51   0.00   2.31 # front-door v1; total v17
  7.32   0.00   2.31 # front-door v2; total v18
  7.32   0.00   4.34 # front-door v3; total v19
  6.51   0.00   4.34 # front-door v4; total v20
  7.42   2.38   2.98 # right-wndw v1; total v21
  7.42   4.11   2.98 # right-wndw v2; total v22
  7.42   4.68   2.98 # right-wndw v3; total v23
  7.42   4.68   3.88 # right-wndw v4; total v24
  7.42   4.11   3.88 # right-wndw v5; total v25
  7.42   2.38   3.88 # right-wndw v6; total v26
  7.42   6.96   2.31 # right-door v1; total v27
  7.42   7.87   2.31 # right-door v2; total v28
  7.42   7.87   4.32 # right-door v3; total v29
  7.42   6.96   4.32 # right-door v4; total v30
  5.28   7.97   2.84 # back-wndw v1; total v31
  2.92   7.97   2.84 # back-wndw v2; total v32
  2.14   7.97   2.84 # back-wndw v3; total v33
  2.14   7.97   4.02 # back-wndw v4; total v34
  2.92   7.97   4.02 # back-wndw v5; total v35
  5.28   7.97   4.02 # back-wndw v6; total v36
#END_VERTICES
#SURFACES: line per surface- number of vertices followed by list of associated vert
# CCW fashion looking from outside toward inside
# return vertex is implied (i.e. 4 1 2 6 5 instead of 5 1 2 6 5 1)
4 1 4 3 2 # floor
4 5 6 9 10 # ceiling
4 6 7 8 9 # ceiling-exposed
23 1 2 7 6 5 1 11 16 15 12 11 1 12 15 14 13 12 1 17 20 19 18 17 # front
4 11 12 15 16 # front-aper
4 12 13 14 15 # front-frame
4 17 18 19 20 # front-door
22 2 3 8 7 2 21 26 25 22 21 2 22 25 24 23 22 2 27 30 29 28 27 # right
4 21 22 25 26 # right-aper
4 22 23 24 25 # right-frame
4 27 28 29 30 # right-door
17 3 4 10 9 8 3 31 36 35 32 31 3 32 35 34 33 32 # back
4 31 32 35 36 # back-aper
4 32 33 34 35 # back-frame
4 4 1 5 10 # left
#END_SURFACES
#UNUSED_INDEX: equal to number of surfaces
0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
#SURFACE_INDENTATION (m): equal to number of surfaces
0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
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
  2, ceiling       OPAQ  CEIL  M->M         ANOTHER        
  3, ceiling-exposed OPAQ  CEIL  M_ceil_exp   EXTERIOR       
  4, front         OPAQ  VERT  M_wall       EXTERIOR       
  5, front-aper    TRAN  VERT  WNDW_200     EXTERIOR       
  6, front-frame   OPAQ  VERT  FRM_Vnl      EXTERIOR       
  7, front-door    OPAQ  VERT  D_mtl_EPS    EXTERIOR       
  8, right         OPAQ  VERT  M_wall       EXTERIOR       
  9, right-aper    TRAN  VERT  WNDW_200     EXTERIOR       
 10, right-frame   OPAQ  VERT  FRM_Vnl      EXTERIOR       
 11, right-door    OPAQ  VERT  D_mtl_EPS    EXTERIOR       
 12, back          OPAQ  VERT  M_wall       EXTERIOR       
 13, back-aper     TRAN  VERT  WNDW_200     EXTERIOR       
 14, back-frame    OPAQ  VERT  FRM_Vnl      EXTERIOR       
 15, left          OPAQ  VERT  M_wall_adb   ADIABATIC      
#END_SURFACE_ATTRIBUTES
#BASE: list of floor surface ID numbers (must have six elements), area of base (m^2); also leave the final line after this next line
1 0 0 0 0 0 59.1 0
