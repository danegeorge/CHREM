# geometry of main defined in: ./zone.geo
#ZONE_NAME: zone description type, zone name, description
GEN main_1 This file describes the main_1
#VER_SUR_ROT: vertex count, surface count, rotation angle CCW looking down (degrees)
36 15 225
#VERTICES: X co-ord, Y co-ord, Z co-ord
# line per vertex- base in counter-clockwise (CCW) fashion looking down, then top in CCW fashion
# then additional vertices for windows/doors
  0.00   0.00   2.44 # base v1; total v1
 11.24   0.00   2.44 # base v2; total v2
 11.24  11.24   2.44 # base v3; total v3
  0.00  11.24   2.44 # base v4; total v4
  0.00   0.00   4.88 # top v1; total v5
 11.24   0.00   4.88 # top v2; total v6
 11.24  11.24   4.88 # top v3; total v7
  0.00  11.24   4.88 # top v4; total v8
  2.41   0.00   2.92 # front-wndw v1; total v9
  6.62   0.00   2.92 # front-wndw v2; total v10
  8.02   0.00   2.92 # front-wndw v3; total v11
  8.02   0.00   4.40 # front-wndw v4; total v12
  6.62   0.00   4.40 # front-wndw v5; total v13
  2.41   0.00   4.40 # front-wndw v6; total v14
 10.33   0.00   2.54 # front-door v1; total v15
 11.14   0.00   2.54 # front-door v2; total v16
 11.14   0.00   4.57 # front-door v3; total v17
 10.33   0.00   4.57 # front-door v4; total v18
 11.24   3.64   3.18 # right-wndw v1; total v19
 11.24   6.61   3.18 # right-wndw v2; total v20
 11.24   7.60   3.18 # right-wndw v3; total v21
 11.24   7.60   4.14 # right-wndw v4; total v22
 11.24   6.61   4.14 # right-wndw v5; total v23
 11.24   3.64   4.14 # right-wndw v6; total v24
  7.78  11.24   3.13 # back-wndw v1; total v25
  4.54  11.24   3.13 # back-wndw v2; total v26
  3.46  11.24   3.13 # back-wndw v3; total v27
  3.46  11.24   4.19 # back-wndw v4; total v28
  4.54  11.24   4.19 # back-wndw v5; total v29
  7.78  11.24   4.19 # back-wndw v6; total v30
  0.00   7.65   3.17 # left-wndw v1; total v31
  0.00   4.61   3.17 # left-wndw v2; total v32
  0.00   3.59   3.17 # left-wndw v3; total v33
  0.00   3.59   4.15 # left-wndw v4; total v34
  0.00   4.61   4.15 # left-wndw v5; total v35
  0.00   7.65   4.15 # left-wndw v6; total v36
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
16 2 3 7 6 2 19 24 23 20 19 2 20 23 22 21 20 # right
4 19 20 23 24 # right-aper
4 20 21 22 23 # right-frame
16 3 4 8 7 3 25 30 29 26 25 3 26 29 28 27 26 # back
4 25 26 29 30 # back-aper
4 26 27 28 29 # back-frame
16 4 1 5 8 4 31 36 35 32 31 4 32 35 34 33 32 # left
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
  2, ceiling       OPAQ  CEIL  M->A_or_R    ANOTHER        
  3, front         OPAQ  VERT  M_wall       EXTERIOR       
  4, front-aper    TRAN  VERT  WNDW_200     EXTERIOR       
  5, front-frame   OPAQ  VERT  FRM_wood     EXTERIOR       
  6, front-door    OPAQ  VERT  D_wood_sld   EXTERIOR       
  7, right         OPAQ  VERT  M_wall       EXTERIOR       
  8, right-aper    TRAN  VERT  WNDW_200     EXTERIOR       
  9, right-frame   OPAQ  VERT  FRM_Al       EXTERIOR       
 10, back          OPAQ  VERT  M_wall       EXTERIOR       
 11, back-aper     TRAN  VERT  WNDW_200     EXTERIOR       
 12, back-frame    OPAQ  VERT  FRM_Al       EXTERIOR       
 13, left          OPAQ  VERT  M_wall       EXTERIOR       
 14, left-aper     TRAN  VERT  WNDW_200     EXTERIOR       
 15, left-frame    OPAQ  VERT  FRM_Al       EXTERIOR       
#END_SURFACE_ATTRIBUTES
#BASE: list of floor surface ID numbers (must have six elements), area of base (m^2); also leave the final line after this next line
1 0 0 0 0 0 126.3 0
