# geometry of main defined in: ./zone.geo
#ZONE_NAME: zone description type, zone name, description
GEN attc This file describes the attc
#VER_SUR_ROT: vertex count, surface count, rotation angle CCW looking down (degrees)
8 6 0
#VERTICES: X co-ord, Y co-ord, Z co-ord
# line per vertex- base in counter-clockwise (CCW) fashion looking down, then top in CCW fashion
# then additional vertices for windows/doors
  0.00   0.00   4.88 # base v1
  7.78   0.00   4.88 # base v2
  7.78   7.78   4.88 # base v3
  0.00   7.78   4.88 # base v4
  0.00 3.84   6.50 # top v5
  7.78 3.84   6.50 # top v6
  7.78 3.94   6.50 # top v7
  0.00 3.94   6.50 # top v8
#END_VERTICES
#SURFACES: line per surface- number of vertices followed by list of associated vert
# CCW fashion looking from outside toward inside
# return vertex is implied (i.e. 4 1 2 6 5 instead of 5 1 2 6 5 1)
4 1 4 3 2 # surf1 - floor
4 5 6 7 8 # surf2 - ceiling
4 1 2 6 5 # surf3 - front side
4 2 3 7 6 # surf4 - right side
4 3 4 8 7 # surf5 - back side
4 4 1 5 8 # surf6 - left side
#END_SURFACES
#UNUSED_INDEX: equal to number of surfaces
0 0 0 0 0 0
#SURFACE_INDENTATION (m): equal to number of surfaces
0 0 0 0 0 0
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
  1, Floor         OPAQ  FLOR  R_MAIN_ceil  ANOTHER        
  2, Ceiling       OPAQ  CEIL  ATTC_slop    EXTERIOR       
  3, Side          OPAQ  SLOP  ATTC_slop    EXTERIOR       
  4, Side          OPAQ  VERT  ATTC_gbl     EXTERIOR       
  5, Side          OPAQ  SLOP  ATTC_slop    EXTERIOR       
  6, Side          OPAQ  VERT  ATTC_gbl     EXTERIOR       
#END_SURFACE_ATTRIBUTES
#BASE: list of floor surface ID numbers (must have six elements), area of base (m^2); also leave the final line after this next line
1 0 0 0 0 0 60.56
