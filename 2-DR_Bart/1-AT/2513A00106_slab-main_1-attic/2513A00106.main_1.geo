# geometry of main defined in: ./zone.geo
#ZONE_NAME: zone description type, zone name, description
GEN main_1 This file describes the main_1
#VER_SUR_ROT: vertex count, surface count, rotation angle CCW looking down (degrees)
28 12 135
#VERTICES: X co-ord, Y co-ord, Z co-ord
# line per vertex- base in counter-clockwise (CCW) fashion looking down, then top in CCW fashion
# then additional vertices for windows/doors
  0.00   0.00   0.00 # base v1; total v1
  8.55   0.00   0.00 # base v2; total v2
  8.55   6.48   0.00 # base v3; total v3
  0.00   6.48   0.00 # base v4; total v4
  0.00   0.00   2.44 # top v1; total v5
  8.55   0.00   2.44 # top v2; total v6
  8.55   6.48   2.44 # top v3; total v7
  0.00   6.48   2.44 # top v4; total v8
  1.95   0.00   0.54 # front-wndw v1; total v9
  4.76   0.00   0.54 # front-wndw v2; total v10
  5.69   0.00   0.54 # front-wndw v3; total v11
  5.69   0.00   1.90 # front-wndw v4; total v12
  4.76   0.00   1.90 # front-wndw v5; total v13
  1.95   0.00   1.90 # front-wndw v6; total v14
  7.54   0.00   0.10 # front-door v1; total v15
  8.45   0.00   0.10 # front-door v2; total v16
  8.45   0.00   2.13 # front-door v3; total v17
  7.54   0.00   2.13 # front-door v4; total v18
  8.55   5.47   0.10 # right-door v1; total v19
  8.55   6.38   0.10 # right-door v2; total v20
  8.55   6.38   2.13 # right-door v3; total v21
  8.55   5.47   2.13 # right-door v4; total v22
  6.01   6.48   0.66 # back-wndw v1; total v23
  3.41   6.48   0.66 # back-wndw v2; total v24
  2.54   6.48   0.66 # back-wndw v3; total v25
  2.54   6.48   1.78 # back-wndw v4; total v26
  3.41   6.48   1.78 # back-wndw v5; total v27
  6.01   6.48   1.78 # back-wndw v6; total v28
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
4 4 1 5 8 # left
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
  1, floor         OPAQ  FLOR  M_slab       BASESIMP       
  2, ceiling       OPAQ  CEIL  M->A_or_R    ANOTHER        
  3, front         OPAQ  VERT  M_wall       EXTERIOR       
  4, front-aper    TRAN  VERT  WNDW_200     EXTERIOR       
  5, front-frame   OPAQ  VERT  FRM_Vnl      EXTERIOR       
  6, front-door    OPAQ  VERT  D_wood_sld   EXTERIOR       
  7, right         OPAQ  VERT  M_wall_adb   ADIABATIC      
  8, right-door    OPAQ  VERT  D_wood_sld   EXTERIOR       
  9, back          OPAQ  VERT  M_wall       EXTERIOR       
 10, back-aper     TRAN  VERT  WNDW_200     EXTERIOR       
 11, back-frame    OPAQ  VERT  FRM_Vnl      EXTERIOR       
 12, left          OPAQ  VERT  M_wall_adb   ADIABATIC      
#END_SURFACE_ATTRIBUTES
#BASE: list of floor surface ID numbers (must have six elements), area of base (m^2); also leave the final line after this next line
1 0 0 0 0 0 55.4 0
