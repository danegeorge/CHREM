# geometry of main defined in: ./zone.geo
#ZONE_NAME: zone description type, zone name, description
GEN main_1 This file describes the main_1
#VER_SUR_ROT: vertex count, surface count, rotation angle CCW looking down (degrees)
36 15 180
#VERTICES: X co-ord, Y co-ord, Z co-ord
# line per vertex- base in counter-clockwise (CCW) fashion looking down, then top in CCW fashion
# then additional vertices for windows/doors
  0.00   0.00   2.44 # base v1; total v1
  5.43   0.00   2.44 # base v2; total v2
  6.06   0.00   2.44 # base v3; total v3
  6.06   9.17   2.44 # base v4; total v4
  5.43   9.17   2.44 # base v5; total v5
  0.00   9.17   2.44 # base v6; total v6
  0.00   0.00   4.88 # top v1; total v7
  6.06   0.00   4.88 # top v2; total v8
  6.06   9.17   4.88 # top v3; total v9
  0.00   9.17   4.88 # top v4; total v10
  1.44   0.00   3.04 # front-wndw v1; total v11
  3.14   0.00   3.04 # front-wndw v2; total v12
  3.71   0.00   3.04 # front-wndw v3; total v13
  3.71   0.00   4.28 # front-wndw v4; total v14
  3.14   0.00   4.28 # front-wndw v5; total v15
  1.44   0.00   4.28 # front-wndw v6; total v16
  5.05   0.00   2.54 # front-door v1; total v17
  5.96   0.00   2.54 # front-door v2; total v18
  5.96   0.00   4.62 # front-door v3; total v19
  5.05   0.00   4.62 # front-door v4; total v20
  6.06   8.57   2.54 # right-door v1; total v21
  6.06   9.07   2.54 # right-door v2; total v22
  6.06   9.07   4.62 # right-door v3; total v23
  6.06   8.57   4.62 # right-door v4; total v24
  4.12   9.17   3.16 # back-wndw v1; total v25
  2.48   9.17   3.16 # back-wndw v2; total v26
  1.94   9.17   3.16 # back-wndw v3; total v27
  1.94   9.17   4.16 # back-wndw v4; total v28
  2.48   9.17   4.16 # back-wndw v5; total v29
  4.12   9.17   4.16 # back-wndw v6; total v30
  0.00   5.95   3.25 # left-wndw v1; total v31
  0.00   3.90   3.25 # left-wndw v2; total v32
  0.00   3.22   3.25 # left-wndw v3; total v33
  0.00   3.22   4.07 # left-wndw v4; total v34
  0.00   3.90   4.07 # left-wndw v5; total v35
  0.00   5.95   4.07 # left-wndw v6; total v36
#END_VERTICES
#SURFACES: line per surface- number of vertices followed by list of associated vert
# CCW fashion looking from outside toward inside
# return vertex is implied (i.e. 4 1 2 6 5 instead of 5 1 2 6 5 1)
4 1 6 5 2 # floor
4 2 5 4 3 # floor-exposed
4 7 8 9 10 # ceiling
23 1 2 3 8 7 1 11 16 15 12 11 1 12 15 14 13 12 1 17 20 19 18 17 # front
4 11 12 15 16 # front-aper
4 12 13 14 15 # front-frame
4 17 18 19 20 # front-door
10 3 4 9 8 3 21 24 23 22 21 # right
4 21 22 23 24 # right-door
17 4 5 6 10 9 4 25 30 29 26 25 4 26 29 28 27 26 # back
4 25 26 29 30 # back-aper
4 26 27 28 29 # back-frame
16 6 1 7 10 6 31 36 35 32 31 6 32 35 34 33 32 # left
4 31 32 35 36 # left-aper
4 32 33 34 35 # left-frame
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
  2, floor-exposed OPAQ  FLOR  M_floor_exp  EXTERIOR       
  3, ceiling       OPAQ  CEIL  M->M         ANOTHER        
  4, front         OPAQ  VERT  M_wall       EXTERIOR       
  5, front-aper    TRAN  VERT  WNDW_200     EXTERIOR       
  6, front-frame   OPAQ  VERT  FRM_wood     EXTERIOR       
  7, front-door    OPAQ  VERT  D_mtl_EPS    EXTERIOR       
  8, right         OPAQ  VERT  M_wall_adb   ADIABATIC      
  9, right-door    OPAQ  VERT  D_mtl_EPS    EXTERIOR       
 10, back          OPAQ  VERT  M_wall       EXTERIOR       
 11, back-aper     TRAN  VERT  WNDW_200     EXTERIOR       
 12, back-frame    OPAQ  VERT  FRM_wood     EXTERIOR       
 13, left          OPAQ  VERT  M_wall       EXTERIOR       
 14, left-aper     TRAN  VERT  WNDW_200     EXTERIOR       
 15, left-frame    OPAQ  VERT  FRM_wood     EXTERIOR       
#END_SURFACE_ATTRIBUTES
#BASE: list of floor surface ID numbers (must have six elements), area of base (m^2); also leave the final line after this next line
1 2 0 0 0 0 55.6 0
