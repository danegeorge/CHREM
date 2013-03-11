# geometry of main defined in: ./zone.geo
#ZONE_NAME: zone description type, zone name, description
GEN main This file describes the main
#VER_SUR_ROT: vertex count, surface count, rotation angle CCW looking down (degrees)
48 16 0
#VERTICES: X co-ord, Y co-ord, Z co-ord
# line per vertex- base in counter-clockwise (CCW) fashion looking down, then top in CCW fashion
# then additional vertices for windows/doors
  0.00   0.00   0.00 # base v1
  7.78   0.00   0.00 # base v2
  7.78   7.78   0.00 # base v3
  0.00   7.78   0.00 # base v4
  0.00   0.00   4.88 # top v5
  7.78   0.00   4.88 # top v6
  7.78   7.78   4.88 # top v7
  0.00   7.78   4.88 # top v8
  2.96   0.00   1.50 # front window-frame v0
  3.24   0.00   1.50 # front window-frame v1
  3.24   0.00   3.38 # front window-frame v2
  2.96   0.00   3.38 # front window-frame v3
  3.24   0.00   1.50 # front window-aperture v0
  4.83   0.00   1.50 # front window-aperture v1
  4.83   0.00   3.38 # front window-aperture v2
  3.24   0.00   3.38 # front window-aperture v3
  6.64   0.00   0.20 # front door v0
  7.58   0.00   0.20 # front door v1
  7.58   0.00   2.20 # front door v2
  6.64   0.00   2.20 # front door v3
  7.78   2.81   1.35 # right window-frame v0
  7.78   3.13   1.35 # right window-frame v1
  7.78   3.13   3.52 # right window-frame v2
  7.78   2.81   3.52 # right window-frame v3
  7.78   3.13   1.35 # right window-aperture v0
  7.78   4.97   1.35 # right window-aperture v1
  7.78   4.97   3.52 # right window-aperture v2
  7.78   3.13   3.52 # right window-aperture v3
  7.78   6.69   0.20 # right door v0
  7.78   7.58   0.20 # right door v1
  7.78   7.58   2.20 # right door v2
  7.78   6.69   2.20 # right door v3
  4.33   7.78   1.99 # back window-frame v0
  4.20   7.78   1.99 # back window-frame v1
  4.20   7.78   2.88 # back window-frame v2
  4.33   7.78   2.88 # back window-frame v3
  4.20   7.78   1.99 # back window-aperture v0
  3.45   7.78   1.99 # back window-aperture v1
  3.45   7.78   2.88 # back window-aperture v2
  4.20   7.78   2.88 # back window-aperture v3
  0.00   5.17   1.16 # left window-frame v0
  0.00   4.79   1.16 # left window-frame v1
  0.00   4.79   3.72 # left window-frame v2
  0.00   5.17   3.72 # left window-frame v3
  0.00   4.79   1.16 # left window-aperture v0
  0.00   2.61   1.16 # left window-aperture v1
  0.00   2.61   3.72 # left window-aperture v2
  0.00   4.79   3.72 # left window-aperture v3
#END_VERTICES
#SURFACES: line per surface- number of vertices followed by list of associated vert
# CCW fashion looking from outside toward inside
# return vertex is implied (i.e. 4 1 2 6 5 instead of 5 1 2 6 5 1)
4 1 4 3 2 # surf1 - floor
4 5 6 7 8 # surf2 - ceiling
4 9 10 11 12 # front frame
4 13 14 15 16 # front window
4 17 18 19 20 # front door
22 1 2 6 5 1 9 12 11 10 9 1 13 16 15 14 13 1 17 20 19 18 17 # front side
4 21 22 23 24 # right frame
4 25 26 27 28 # right window
4 29 30 31 32 # right door
22 2 3 7 6 2 21 24 23 22 21 2 25 28 27 26 25 2 29 32 31 30 29 # right side
4 33 34 35 36 # back frame
4 37 38 39 40 # back window
16 3 4 8 7 3 33 36 35 34 33 3 37 40 39 38 37 # back side
4 41 42 43 44 # left frame
4 45 46 47 48 # left window
16 4 1 5 8 4 41 44 43 42 41 4 45 48 47 46 45 # left side
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
  1, Floor         OPAQ  FLOR  MAIN_BSMT    ANOTHER        
  2, Ceiling       OPAQ  CEIL  MAIN_ceil    ANOTHER        
  3, front-Frm     OPAQ  VERT  FRAME_vnl    EXTERIOR       
  4, front-Aper    TRAN  VERT  WNDW_200     EXTERIOR       
  5, front-Door    OPAQ  VERT  DOOR_wood    EXTERIOR       
  6, Side-front    OPAQ  VERT  MAIN_wall    EXTERIOR       
  7, right-Frm     OPAQ  VERT  FRAME_vnl    EXTERIOR       
  8, right-Aper    TRAN  VERT  WNDW_200     EXTERIOR       
  9, right-Door    OPAQ  VERT  DOOR_wood    EXTERIOR       
 10, Side-right    OPAQ  VERT  MAIN_wall    EXTERIOR       
 11, back-Frm      OPAQ  VERT  FRAME_vnl    EXTERIOR       
 12, back-Aper     TRAN  VERT  WNDW_200     EXTERIOR       
 13, Side-back     OPAQ  VERT  MAIN_wall    EXTERIOR       
 14, left-Frm      OPAQ  VERT  FRAME_vnl    EXTERIOR       
 15, left-Aper     TRAN  VERT  WNDW_200     EXTERIOR       
 16, Side-left     OPAQ  VERT  MAIN_wall    EXTERIOR       
#END_SURFACE_ATTRIBUTES
#BASE: list of floor surface ID numbers (must have six elements), area of base (m^2); also leave the final line after this next line
1 0 0 0 0 0 60.56
