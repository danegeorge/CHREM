# geometry of main defined in: ./zone.geo
#ZONE_NAME: zone description type, zone name, description
GEN main_2 This file describes the main_2
#VER_SUR_ROT: vertex count, surface count, rotation angle CCW looking down (degrees)
26 12 180
#VERTICES: X co-ord, Y co-ord, Z co-ord
# line per vertex- base in counter-clockwise (CCW) fashion looking down, then top in CCW fashion
# then additional vertices for windows/doors
  0.00   0.00   4.88 # base v1; total v1
  6.06   0.00   4.88 # base v2; total v2
  6.06   9.17   4.88 # base v3; total v3
  0.00   9.17   4.88 # base v4; total v4
  0.00   0.00   7.32 # top v1; total v5
  6.06   0.00   7.32 # top v2; total v6
  6.06   9.17   7.32 # top v3; total v7
  0.00   9.17   7.32 # top v4; total v8
  1.68   0.00   5.48 # front-wndw v1; total v9
  3.70   0.00   5.48 # front-wndw v2; total v10
  4.38   0.00   5.48 # front-wndw v3; total v11
  4.38   0.00   6.72 # front-wndw v4; total v12
  3.70   0.00   6.72 # front-wndw v5; total v13
  1.68   0.00   6.72 # front-wndw v6; total v14
  4.12   9.17   5.60 # back-wndw v1; total v15
  2.48   9.17   5.60 # back-wndw v2; total v16
  1.94   9.17   5.60 # back-wndw v3; total v17
  1.94   9.17   6.60 # back-wndw v4; total v18
  2.48   9.17   6.60 # back-wndw v5; total v19
  4.12   9.17   6.60 # back-wndw v6; total v20
  0.00   5.95   5.69 # left-wndw v1; total v21
  0.00   3.90   5.69 # left-wndw v2; total v22
  0.00   3.22   5.69 # left-wndw v3; total v23
  0.00   3.22   6.51 # left-wndw v4; total v24
  0.00   3.90   6.51 # left-wndw v5; total v25
  0.00   5.95   6.51 # left-wndw v6; total v26
#END_VERTICES
#SURFACES: line per surface- number of vertices followed by list of associated vert
# CCW fashion looking from outside toward inside
# return vertex is implied (i.e. 4 1 2 6 5 instead of 5 1 2 6 5 1)
4 1 4 3 2 # floor
4 5 6 7 8 # ceiling
16 1 2 6 5 1 9 14 13 10 9 1 10 13 12 11 10 # front
4 9 10 13 14 # front-aper
4 10 11 12 13 # front-frame
4 2 3 7 6 # right
16 3 4 8 7 3 15 20 19 16 15 3 16 19 18 17 16 # back
4 15 16 19 20 # back-aper
4 16 17 18 19 # back-frame
16 4 1 5 8 4 21 26 25 22 21 4 22 25 24 23 22 # left
4 21 22 25 26 # left-aper
4 22 23 24 25 # left-frame
#END_SURFACES
#UNUSED_INDEX: equal to number of surfaces
0 0 0 0 0 0 0 0 0 0 0 0
#SURFACE_INDENTATION (m): equal to number of surfaces
0 0 0 0 0 0 0 0 0 0 0 0
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
  2, ceiling       OPAQ  CEIL  M->A_or_R    ANOTHER        
  3, front         OPAQ  VERT  M_wall       EXTERIOR       
  4, front-aper    TRAN  VERT  WNDW_200     EXTERIOR       
  5, front-frame   OPAQ  VERT  FRM_wood     EXTERIOR       
  6, right         OPAQ  VERT  M_wall_adb   ADIABATIC      
  7, back          OPAQ  VERT  M_wall       EXTERIOR       
  8, back-aper     TRAN  VERT  WNDW_200     EXTERIOR       
  9, back-frame    OPAQ  VERT  FRM_wood     EXTERIOR       
 10, left          OPAQ  VERT  M_wall       EXTERIOR       
 11, left-aper     TRAN  VERT  WNDW_200     EXTERIOR       
 12, left-frame    OPAQ  VERT  FRM_wood     EXTERIOR       
#END_SURFACE_ATTRIBUTES
#BASE: list of floor surface ID numbers (must have six elements), area of base (m^2); also leave the final line after this next line
1 0 0 0 0 0 55.6 0
