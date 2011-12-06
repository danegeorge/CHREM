# geometry of main defined in: ./zone.geo
#ZONE_NAME: zone description type, zone name, description
GEN main_1 This file describes the main_1
#VER_SUR_ROT: vertex count, surface count, rotation angle CCW looking down (degrees)
40 16 225
#VERTICES: X co-ord, Y co-ord, Z co-ord
# line per vertex- base in counter-clockwise (CCW) fashion looking down, then top in CCW fashion
# then additional vertices for windows/doors
  0.00   0.00   2.72 # base v1; total v1
 12.20   0.00   2.72 # base v2; total v2
 12.20   9.39   2.72 # base v3; total v3
  0.00   9.39   2.72 # base v4; total v4
  0.00   0.00   5.13 # top v1; total v5
 12.20   0.00   5.13 # top v2; total v6
 12.20   9.39   5.13 # top v3; total v7
  0.00   9.39   5.13 # top v4; total v8
  3.76   0.00   3.47 # front-wndw v1; total v9
  6.59   0.00   3.47 # front-wndw v2; total v10
  7.53   0.00   3.47 # front-wndw v3; total v11
  7.53   0.00   4.38 # front-wndw v4; total v12
  6.59   0.00   4.38 # front-wndw v5; total v13
  3.76   0.00   4.38 # front-wndw v6; total v14
 11.19   0.00   2.82 # front-door v1; total v15
 12.10   0.00   2.82 # front-door v2; total v16
 12.10   0.00   4.89 # front-door v3; total v17
 11.19   0.00   4.89 # front-door v4; total v18
 12.20   2.71   3.43 # right-wndw v1; total v19
 12.20   5.00   3.43 # right-wndw v2; total v20
 12.20   5.77   3.43 # right-wndw v3; total v21
 12.20   5.77   4.42 # right-wndw v4; total v22
 12.20   5.00   4.42 # right-wndw v5; total v23
 12.20   2.71   4.42 # right-wndw v6; total v24
 12.20   8.38   2.82 # right-door v1; total v25
 12.20   9.29   2.82 # right-door v2; total v26
 12.20   9.29   4.89 # right-door v3; total v27
 12.20   8.38   4.89 # right-door v4; total v28
  9.35   9.39   3.21 # back-wndw v1; total v29
  4.47   9.39   3.21 # back-wndw v2; total v30
  2.85   9.39   3.21 # back-wndw v3; total v31
  2.85   9.39   4.64 # back-wndw v4; total v32
  4.47   9.39   4.64 # back-wndw v5; total v33
  9.35   9.39   4.64 # back-wndw v6; total v34
  0.00   5.78   3.61 # left-wndw v1; total v35
  0.00   4.15   3.61 # left-wndw v2; total v36
  0.00   3.61   3.61 # left-wndw v3; total v37
  0.00   3.61   4.24 # left-wndw v4; total v38
  0.00   4.15   4.24 # left-wndw v5; total v39
  0.00   5.78   4.24 # left-wndw v6; total v40
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
16 4 1 5 8 4 35 40 39 36 35 4 36 39 38 37 36 # left
4 35 36 39 40 # left-aper
4 36 37 38 39 # left-frame
#END_SURFACES
#UNUSED_INDEX: equal to number of surfaces
0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
#SURFACE_INDENTATION (m): equal to number of surfaces
0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
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
  4, front-aper    TRAN  VERT  WNDW_201     EXTERIOR       
  5, front-frame   OPAQ  VERT  FRM_Vnl      EXTERIOR       
  6, front-door    OPAQ  VERT  D_mtl_EPS    EXTERIOR       
  7, right         OPAQ  VERT  M_wall       EXTERIOR       
  8, right-aper    TRAN  VERT  WNDW_201     EXTERIOR       
  9, right-frame   OPAQ  VERT  FRM_Vnl      EXTERIOR       
 10, right-door    OPAQ  VERT  D_mtl_EPS    EXTERIOR       
 11, back          OPAQ  VERT  M_wall       EXTERIOR       
 12, back-aper     TRAN  VERT  WNDW_201     EXTERIOR       
 13, back-frame    OPAQ  VERT  FRM_Vnl      EXTERIOR       
 14, left          OPAQ  VERT  M_wall       EXTERIOR       
 15, left-aper     TRAN  VERT  WNDW_201     EXTERIOR       
 16, left-frame    OPAQ  VERT  FRM_Vnl      EXTERIOR       
#END_SURFACE_ATTRIBUTES
#BASE: list of floor surface ID numbers (must have six elements), area of base (m^2); also leave the final line after this next line
1 0 0 0 0 0 114.6 0
