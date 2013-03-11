# geometry of main defined in: ./zone.geo
#ZONE_NAME: zone description type, zone name, description
GEN main_1 This file describes the main_1
#VER_SUR_ROT: vertex count, surface count, rotation angle CCW looking down (degrees)
44 18 180
#VERTICES: X co-ord, Y co-ord, Z co-ord
# line per vertex- base in counter-clockwise (CCW) fashion looking down, then top in CCW fashion
# then additional vertices for windows/doors
  0.00   0.00   2.06 # base v1; total v1
  5.65   0.00   2.06 # base v2; total v2
  6.47   0.00   2.06 # base v3; total v3
  6.47   7.80   2.06 # base v4; total v4
  5.65   7.80   2.06 # base v5; total v5
  0.00   7.80   2.06 # base v6; total v6
  0.00   0.00   4.50 # top v1; total v7
  5.66   0.00   4.50 # top v2; total v8
  6.47   0.00   4.50 # top v3; total v9
  6.47   7.80   4.50 # top v4; total v10
  5.66   7.80   4.50 # top v5; total v11
  0.00   7.80   4.50 # top v6; total v12
  1.84   0.00   2.79 # front-wndw v1; total v13
  3.32   0.00   2.79 # front-wndw v2; total v14
  3.82   0.00   2.79 # front-wndw v3; total v15
  3.82   0.00   3.77 # front-wndw v4; total v16
  3.32   0.00   3.77 # front-wndw v5; total v17
  1.84   0.00   3.77 # front-wndw v6; total v18
  5.56   0.00   2.16 # front-door v1; total v19
  6.37   0.00   2.16 # front-door v2; total v20
  6.37   0.00   4.19 # front-door v3; total v21
  5.56   0.00   4.19 # front-door v4; total v22
  6.47   3.24   3.18 # right-wndw v1; total v23
  6.47   3.62   3.18 # right-wndw v2; total v24
  6.47   3.75   3.18 # right-wndw v3; total v25
  6.47   3.75   3.38 # right-wndw v4; total v26
  6.47   3.62   3.38 # right-wndw v5; total v27
  6.47   3.24   3.38 # right-wndw v6; total v28
  6.47   6.89   2.16 # right-door v1; total v29
  6.47   7.70   2.16 # right-door v2; total v30
  6.47   7.70   4.19 # right-door v3; total v31
  6.47   6.89   4.19 # right-door v4; total v32
  4.33   7.80   2.81 # back-wndw v1; total v33
  2.69   7.80   2.81 # back-wndw v2; total v34
  2.14   7.80   2.81 # back-wndw v3; total v35
  2.14   7.80   3.75 # back-wndw v4; total v36
  2.69   7.80   3.75 # back-wndw v5; total v37
  4.33   7.80   3.75 # back-wndw v6; total v38
  0.00   5.07   2.87 # left-wndw v1; total v39
  0.00   3.32   2.87 # left-wndw v2; total v40
  0.00   2.73   2.87 # left-wndw v3; total v41
  0.00   2.73   3.69 # left-wndw v4; total v42
  0.00   3.32   3.69 # left-wndw v5; total v43
  0.00   5.07   3.69 # left-wndw v6; total v44
#END_VERTICES
#SURFACES: line per surface- number of vertices followed by list of associated vert
# CCW fashion looking from outside toward inside
# return vertex is implied (i.e. 4 1 2 6 5 instead of 5 1 2 6 5 1)
4 1 6 5 2 # floor
4 2 5 4 3 # floor-exposed
4 7 8 11 12 # ceiling
4 8 9 10 11 # ceiling-exposed
24 1 2 3 9 8 7 1 13 18 17 14 13 1 14 17 16 15 14 1 19 22 21 20 19 # front
4 13 14 17 18 # front-aper
4 14 15 16 17 # front-frame
4 19 20 21 22 # front-door
22 3 4 10 9 3 23 28 27 24 23 3 24 27 26 25 24 3 29 32 31 30 29 # right
4 23 24 27 28 # right-aper
4 24 25 26 27 # right-frame
4 29 30 31 32 # right-door
18 4 5 6 12 11 10 4 33 38 37 34 33 4 34 37 36 35 34 # back
4 33 34 37 38 # back-aper
4 34 35 36 37 # back-frame
16 6 1 7 12 6 39 44 43 40 39 6 40 43 42 41 40 # left
4 39 40 43 44 # left-aper
4 40 41 42 43 # left-frame
#END_SURFACES
#UNUSED_INDEX: equal to number of surfaces
0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
#SURFACE_INDENTATION (m): equal to number of surfaces
0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
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
  2, floor-exposed OPAQ  FLOR  M_floor_exp  EXTERIOR       
  3, ceiling       OPAQ  CEIL  M->M         ANOTHER        
  4, ceiling-exposed OPAQ  CEIL  M_ceil_exp   EXTERIOR       
  5, front         OPAQ  VERT  M_wall       EXTERIOR       
  6, front-aper    TRAN  VERT  WNDW_100     EXTERIOR       
  7, front-frame   OPAQ  VERT  FRM_wood     EXTERIOR       
  8, front-door    OPAQ  VERT  D_wood_sld   EXTERIOR       
  9, right         OPAQ  VERT  M_wall_adb   ADIABATIC      
 10, right-aper    TRAN  VERT  WNDW_100     EXTERIOR       
 11, right-frame   OPAQ  VERT  FRM_wood     EXTERIOR       
 12, right-door    OPAQ  VERT  D_wood_sld   EXTERIOR       
 13, back          OPAQ  VERT  M_wall       EXTERIOR       
 14, back-aper     TRAN  VERT  WNDW_200     EXTERIOR       
 15, back-frame    OPAQ  VERT  FRM_wood     EXTERIOR       
 16, left          OPAQ  VERT  M_wall       EXTERIOR       
 17, left-aper     TRAN  VERT  WNDW_200     EXTERIOR       
 18, left-frame    OPAQ  VERT  FRM_Al       EXTERIOR       
#END_SURFACE_ATTRIBUTES
#BASE: list of floor surface ID numbers (must have six elements), area of base (m^2); also leave the final line after this next line
1 2 0 0 0 0 50.5 0
