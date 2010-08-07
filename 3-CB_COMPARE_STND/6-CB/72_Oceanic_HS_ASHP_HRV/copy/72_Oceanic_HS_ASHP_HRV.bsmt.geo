# geometry of main defined in: ./zone.geo
#ZONE_NAME: zone description type, zone name, description
GEN bsmt This file describes the bsmt
#VER_SUR_ROT: vertex count, surface count, rotation angle CCW looking down (degrees)
20 10 225
#VERTICES: X co-ord, Y co-ord, Z co-ord
# line per vertex- base in counter-clockwise (CCW) fashion looking down, then top in CCW fashion
# then additional vertices for windows/doors
  0.00   0.00   0.00 # base v1; total v1
 12.20   0.00   0.00 # base v2; total v2
 12.20   9.39   0.00 # base v3; total v3
  0.00   9.39   0.00 # base v4; total v4
  0.00   0.00   2.72 # top v1; total v5
 12.20   0.00   2.72 # top v2; total v6
 12.20   9.39   2.72 # top v3; total v7
  0.00   9.39   2.72 # top v4; total v8
  9.39   9.39   0.55 # back-wndw v1; total v9
  4.46   9.39   0.55 # back-wndw v2; total v10
  2.81   9.39   0.55 # back-wndw v3; total v11
  2.81   9.39   2.17 # back-wndw v4; total v12
  4.46   9.39   2.17 # back-wndw v5; total v13
  9.39   9.39   2.17 # back-wndw v6; total v14
  0.00   5.79   1.01 # left-wndw v1; total v15
  0.00   4.15   1.01 # left-wndw v2; total v16
  0.00   3.60   1.01 # left-wndw v3; total v17
  0.00   3.60   1.71 # left-wndw v4; total v18
  0.00   4.15   1.71 # left-wndw v5; total v19
  0.00   5.79   1.71 # left-wndw v6; total v20
#END_VERTICES
#SURFACES: line per surface- number of vertices followed by list of associated vert
# CCW fashion looking from outside toward inside
# return vertex is implied (i.e. 4 1 2 6 5 instead of 5 1 2 6 5 1)
4 1 4 3 2 # floor
4 5 6 7 8 # ceiling
4 1 2 6 5 # front
4 2 3 7 6 # right
16 3 4 8 7 3 9 14 13 10 9 3 10 13 12 11 10 # back
4 9 10 13 14 # back-aper
4 10 11 12 13 # back-frame
16 4 1 5 8 4 15 20 19 16 15 4 16 19 18 17 16 # left
4 15 16 19 20 # left-aper
4 16 17 18 19 # left-frame
#END_SURFACES
#UNUSED_INDEX: equal to number of surfaces
0 0 0 0 0 0 0 0 0 0
#SURFACE_INDENTATION (m): equal to number of surfaces
0 0 0 0 0 0 0 0 0 0
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
  1, floor         OPAQ  FLOR  B_sl_cc      BASESIMP       
  2, ceiling       OPAQ  CEIL  B->M         ANOTHER        
  3, front         OPAQ  VERT  B_wall_cc    BASESIMP       
  4, right         OPAQ  VERT  B_wall_cc    BASESIMP       
  5, back          OPAQ  VERT  B_wall_pony  EXTERIOR       
  6, back-aper     TRAN  VERT  WNDW_201     EXTERIOR       
  7, back-frame    OPAQ  VERT  FRM_Vnl      EXTERIOR       
  8, left          OPAQ  VERT  B_wall_pony  EXTERIOR       
  9, left-aper     TRAN  VERT  WNDW_201     EXTERIOR       
 10, left-frame    OPAQ  VERT  FRM_Vnl      EXTERIOR       
#END_SURFACE_ATTRIBUTES
#BASE: list of floor surface ID numbers (must have six elements), area of base (m^2); also leave the final line after this next line
1 0 0 0 0 0 114.6 0
