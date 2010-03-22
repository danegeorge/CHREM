# geometry of main defined in: ./zone.geo
#ZONE_NAME: zone description type, zone name, description
GEN bsmt This file describes the bsmt
24 14 225    # vertices, surfaces, rotation angle
#  X co-ord, Y co-ord, Z co-ord
0 0 -2.72
3.67 0 -2.72
3.67 -1.23 -2.72
9.47 -1.23 -2.72
9.47 0 -2.72
13.14 0 -2.72
13.14 7.64 -2.72
9.47 7.64 -2.72
9.47 8.87 -2.72
3.67 8.87 -2.72
3.67 7.64 -2.72
0 7.64 -2.72
0 0 0
3.67 0 0
3.67 -1.23 0
9.47 -1.23 0
9.47 0 0
13.14 0 0
13.14 7.64 0
9.47 7.64 0
9.47 8.87 0
3.67 8.87 0
3.67 7.64 0
0 7.64 0
#END_VERTICES
#SURFACES: line per surface- number of vertices followed by list of associated vert
# CCW fashion looking from outside toward inside
# return vertex is implied (i.e. 4 1 2 6 5 instead of 5 1 2 6 5 1)
# no of vertices followed by list of associated vert
12 1 12 11 10 9 8 7 6 5 4 3 2 1
12 13 14 15 16 17 18 19 20 21 22 23 24
4 1 2 14 13
4 2 3 15 14
4 3 4 16 15
4 4 5 17 16
4 5 6 18 17
4 6 7 19 18
4 7 8 20 19
4 8 9 21 20
4 9 10 22 21
4 10 11 23 22
4 11 12 24 23
4 12 1 13 24
# unused index
0 0 0 0 0 0 0 0 0 0 0 0 0 0
# surfaces indentation (m)
0 0 0 0 0 0 0 0 0 0 0 0 0 0
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
  1, Floor         OPAQ  FLOR  BSMT_flor    BASESIMP       
  2, Ceiling       OPAQ  CEIL  MAIN_BSMT    ANOTHER        
  3, wall-front-1  OPAQ  WALL  BSMT_wall_i  EXTERIOR       
  4, wall-left-3   OPAQ  WALL  BSMT_wall_i  EXTERIOR       
  5, wall-front-2  OPAQ  WALL  BSMT_wall_i  EXTERIOR       
  6, wall-right-1  OPAQ  WALL  BSMT_wall_i  EXTERIOR       
  7, wall-front-3  OPAQ  WALL  BSMT_wall_i  EXTERIOR       
  8, wall-right-2  OPAQ  WALL  BSMT_wall_i  EXTERIOR       
  9, wall-back-1   OPAQ  WALL  BSMT_wall_i  EXTERIOR       
 10, wall-right-3  OPAQ  WALL  BSMT_wall_i  EXTERIOR       
 11, wall-back-2   OPAQ  WALL  BSMT_wall_i  EXTERIOR       
 12, wall-left-1   OPAQ  WALL  BSMT_wall_i  EXTERIOR       
 13, wall-back-3   OPAQ  WALL  BSMT_wall_i  EXTERIOR       
 14, wall-left-2   OPAQ  WALL  BSMT_wall_i  EXTERIOR       
# base
  1  0  0  0  0  0   114.6 0
