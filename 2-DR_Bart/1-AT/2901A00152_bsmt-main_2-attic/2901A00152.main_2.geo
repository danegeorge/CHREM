# geometry of main defined in: ./zone.geo
#ZONE_NAME: zone description type, zone name, description
GEN main_2 This file describes the main_2
#VER_SUR_ROT: vertex count, surface count, rotation angle CCW looking down (degrees)
26 12 225
#VERTICES: X co-ord, Y co-ord, Z co-ord
# line per vertex- base in counter-clockwise (CCW) fashion looking down, then top in CCW fashion
# then additional vertices for windows/doors
  0.00   0.00   4.65 # base v1; total v1
  3.83   0.00   4.65 # base v2; total v2
  3.83   7.97   4.65 # base v3; total v3
  0.00   7.97   4.65 # base v4; total v4
  0.00   0.00   6.94 # top v1; total v5
  3.83   0.00   6.94 # top v2; total v6
  3.83   7.97   6.94 # top v3; total v7
  0.00   7.97   6.94 # top v4; total v8
  1.09   0.00   5.21 # front-wndw v1; total v9
  2.33   0.00   5.21 # front-wndw v2; total v10
  2.74   0.00   5.21 # front-wndw v3; total v11
  2.74   0.00   6.38 # front-wndw v4; total v12
  2.33   0.00   6.38 # front-wndw v5; total v13
  1.09   0.00   6.38 # front-wndw v6; total v14
  3.83   2.68   5.37 # right-wndw v1; total v15
  3.83   4.64   5.37 # right-wndw v2; total v16
  3.83   5.29   5.37 # right-wndw v3; total v17
  3.83   5.29   6.22 # right-wndw v4; total v18
  3.83   4.64   6.22 # right-wndw v5; total v19
  3.83   2.68   6.22 # right-wndw v6; total v20
  2.69   7.97   5.24 # back-wndw v1; total v21
  1.53   7.97   5.24 # back-wndw v2; total v22
  1.14   7.97   5.24 # back-wndw v3; total v23
  1.14   7.97   6.35 # back-wndw v4; total v24
  1.53   7.97   6.35 # back-wndw v5; total v25
  2.69   7.97   6.35 # back-wndw v6; total v26
#END_VERTICES
#SURFACES: line per surface- number of vertices followed by list of associated vert
# CCW fashion looking from outside toward inside
# return vertex is implied (i.e. 4 1 2 6 5 instead of 5 1 2 6 5 1)
4 1 4 3 2 # floor
4 5 6 7 8 # ceiling
16 1 2 6 5 1 9 14 13 10 9 1 10 13 12 11 10 # front
4 9 10 13 14 # front-aper
4 10 11 12 13 # front-frame
16 2 3 7 6 2 15 20 19 16 15 2 16 19 18 17 16 # right
4 15 16 19 20 # right-aper
4 16 17 18 19 # right-frame
16 3 4 8 7 3 21 26 25 22 21 3 22 25 24 23 22 # back
4 21 22 25 26 # back-aper
4 22 23 24 25 # back-frame
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
  1, floor         OPAQ  FLOR  M->M         ANOTHER        
  2, ceiling       OPAQ  CEIL  M->A_or_R    ANOTHER        
  3, front         OPAQ  VERT  M_wall       EXTERIOR       
  4, front-aper    TRAN  VERT  WNDW_200     EXTERIOR       
  5, front-frame   OPAQ  VERT  FRM_Vnl      EXTERIOR       
  6, right         OPAQ  VERT  M_wall       EXTERIOR       
  7, right-aper    TRAN  VERT  WNDW_200     EXTERIOR       
  8, right-frame   OPAQ  VERT  FRM_Vnl      EXTERIOR       
  9, back          OPAQ  VERT  M_wall       EXTERIOR       
 10, back-aper     TRAN  VERT  WNDW_200     EXTERIOR       
 11, back-frame    OPAQ  VERT  FRM_Vnl      EXTERIOR       
 12, left          OPAQ  VERT  M_wall_adb   ADIABATIC      
#END_SURFACE_ATTRIBUTES
#BASE: list of floor surface ID numbers (must have six elements), area of base (m^2); also leave the final line after this next line
1 0 0 0 0 0 30.5 0
