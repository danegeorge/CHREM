# geometry of main defined in: ./zone.geo
#ZONE_NAME: zone description type, zone name, description
GEN attc This file describes the attc
#VER_SUR_ROT: vertex count, surface count, rotation angle CCW looking down (degrees)
17 13 225
#VERTICES: X co-ord, Y co-ord, Z co-ord
# line per vertex- base in counter-clockwise (CCW) fashion looking down, then top in CCW fashion
# then additional vertices for windows/doors
0 0 2.41
3.67 0 2.41
3.67 -1.23 2.41
9.47 -1.23 2.41
9.47 0 2.41
13.14 0 2.41
13.14 7.64 2.41
9.47 7.64 2.41
9.47 8.87 2.41
3.67 8.87 2.41
3.67 7.64 2.41
0 7.64 2.41
6.57 0 4.5
13.14 4.435 4.5
6.57 8.87 4.5
0 4.435 4.5
6.57 4.435 4.5
#END_VERTICES
#SURFACES: line per surface- number of vertices followed by list of associated vert
# CCW fashion looking from outside toward inside
# return vertex is implied (i.e. 4 1 2 6 5 instead of 5 1 2 6 5 1)
12 1 12 11 10 9 8 7 6 5 4 3 2 1
4 1 2 17 16
4 2 3 13 17
3 3 4 13
4 4 5 17 13
4 5 6 14 17
3 6 7 14
4 7 8 17 14
4 8 9 15 17
3 9 10 15
4 10 11 17 15
4 11 12 16 17
3 12 1 16
#END_SURFACES
#UNUSED_INDEX: equal to number of surfaces
0 0 0 0 0 0 0 0 0 0 0 0 0
#SURFACE_INDENTATION (m): equal to number of surfaces
0 0 0 0 0 0 0 0 0 0 0 0 0
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
  2, wall-front-1  OPAQ  SLOP  ATTC_slop    EXTERIOR       
  3, wall-left-3   OPAQ  SLOP  ATTC_slop    EXTERIOR       
  4, wall-front-2  OPAQ  VERT  ATTC_gbl     EXTERIOR       
  5, wall-right-1  OPAQ  SLOP  ATTC_slop    EXTERIOR       
  6, wall-front-3  OPAQ  SLOP  ATTC_slop    EXTERIOR       
  7, wall-right-2  OPAQ  VERT  ATTC_gbl     EXTERIOR       
  8, wall-back-1   OPAQ  SLOP  ATTC_slop    EXTERIOR       
  9, wall-right-3  OPAQ  SLOP  ATTC_slop    EXTERIOR       
 10, wall-back-2   OPAQ  VERT  ATTC_gbl     EXTERIOR       
 11, wall-left-1   OPAQ  SLOP  ATTC_slop    EXTERIOR       
 12, wall-back-3   OPAQ  SLOP  ATTC_slop    EXTERIOR       
 13, wall-left-2   OPAQ  VERT  ATTC_gbl     EXTERIOR       
#END_SURFACE_ATTRIBUTES
#BASE: list of floor surface ID numbers (must have six elements), area of base (m^2); also leave the final line after this next line
1 0 0 0 0 0 114.6
