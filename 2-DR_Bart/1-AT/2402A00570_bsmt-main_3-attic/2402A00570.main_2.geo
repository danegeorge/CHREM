# geometry of main defined in: ./zone.geo
#ZONE_NAME: zone description type, zone name, description
GEN main_2 This file describes the main_2
#VER_SUR_ROT: vertex count, surface count, rotation angle CCW looking down (degrees)
34 15 180
#VERTICES: X co-ord, Y co-ord, Z co-ord
# line per vertex- base in counter-clockwise (CCW) fashion looking down, then top in CCW fashion
# then additional vertices for windows/doors
  0.00   0.00   4.50 # base v1; total v1
  5.66   0.00   4.50 # base v2; total v2
  5.66   7.80   4.50 # base v3; total v3
  0.00   7.80   4.50 # base v4; total v4
  0.00   0.00   6.79 # top v1; total v5
  5.29   0.00   6.79 # top v2; total v6
  5.66   0.00   6.79 # top v3; total v7
  5.66   7.80   6.79 # top v4; total v8
  5.29   7.80   6.79 # top v5; total v9
  0.00   7.80   6.79 # top v6; total v10
  1.85   0.00   5.18 # front-wndw v1; total v11
  3.32   0.00   5.18 # front-wndw v2; total v12
  3.81   0.00   5.18 # front-wndw v3; total v13
  3.81   0.00   6.11 # front-wndw v4; total v14
  3.32   0.00   6.11 # front-wndw v5; total v15
  1.85   0.00   6.11 # front-wndw v6; total v16
  5.66   3.62   5.55 # right-wndw v1; total v17
  5.66   4.04   5.55 # right-wndw v2; total v18
  5.66   4.18   5.55 # right-wndw v3; total v19
  5.66   4.18   5.74 # right-wndw v4; total v20
  5.66   4.04   5.74 # right-wndw v5; total v21
  5.66   3.62   5.74 # right-wndw v6; total v22
  3.78   7.80   5.20 # back-wndw v1; total v23
  2.36   7.80   5.20 # back-wndw v2; total v24
  1.88   7.80   5.20 # back-wndw v3; total v25
  1.88   7.80   6.09 # back-wndw v4; total v26
  2.36   7.80   6.09 # back-wndw v5; total v27
  3.78   7.80   6.09 # back-wndw v6; total v28
  0.00   5.06   5.26 # left-wndw v1; total v29
  0.00   3.32   5.26 # left-wndw v2; total v30
  0.00   2.74   5.26 # left-wndw v3; total v31
  0.00   2.74   6.03 # left-wndw v4; total v32
  0.00   3.32   6.03 # left-wndw v5; total v33
  0.00   5.06   6.03 # left-wndw v6; total v34
#END_VERTICES
#SURFACES: line per surface- number of vertices followed by list of associated vert
# CCW fashion looking from outside toward inside
# return vertex is implied (i.e. 4 1 2 6 5 instead of 5 1 2 6 5 1)
4 1 4 3 2 # floor
4 5 6 9 10 # ceiling
4 6 7 8 9 # ceiling-exposed
17 1 2 7 6 5 1 11 16 15 12 11 1 12 15 14 13 12 # front
4 11 12 15 16 # front-aper
4 12 13 14 15 # front-frame
16 2 3 8 7 2 17 22 21 18 17 2 18 21 20 19 18 # right
4 17 18 21 22 # right-aper
4 18 19 20 21 # right-frame
17 3 4 10 9 8 3 23 28 27 24 23 3 24 27 26 25 24 # back
4 23 24 27 28 # back-aper
4 24 25 26 27 # back-frame
16 4 1 5 10 4 29 34 33 30 29 4 30 33 32 31 30 # left
4 29 30 33 34 # left-aper
4 30 31 32 33 # left-frame
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
  1, floor         OPAQ  FLOR  M->M         ANOTHER        
  2, ceiling       OPAQ  CEIL  M->M         ANOTHER        
  3, ceiling-exposed OPAQ  CEIL  M_ceil_exp   EXTERIOR       
  4, front         OPAQ  VERT  M_wall       EXTERIOR       
  5, front-aper    TRAN  VERT  WNDW_100     EXTERIOR       
  6, front-frame   OPAQ  VERT  FRM_wood     EXTERIOR       
  7, right         OPAQ  VERT  M_wall_adb   ADIABATIC      
  8, right-aper    TRAN  VERT  WNDW_100     EXTERIOR       
  9, right-frame   OPAQ  VERT  FRM_wood     EXTERIOR       
 10, back          OPAQ  VERT  M_wall       EXTERIOR       
 11, back-aper     TRAN  VERT  WNDW_200     EXTERIOR       
 12, back-frame    OPAQ  VERT  FRM_wood     EXTERIOR       
 13, left          OPAQ  VERT  M_wall       EXTERIOR       
 14, left-aper     TRAN  VERT  WNDW_200     EXTERIOR       
 15, left-frame    OPAQ  VERT  FRM_Al       EXTERIOR       
#END_SURFACE_ATTRIBUTES
#BASE: list of floor surface ID numbers (must have six elements), area of base (m^2); also leave the final line after this next line
1 0 0 0 0 0 44.1 0
