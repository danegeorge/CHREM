# geometry of main defined in: ../zones/main.geo
#ZONE_NAME
GEN bsmt This file describes the bsmt
#VER_SUR_ROT
8 6 0.0 # vertices, surfaces, rotation angle
#VERTICES, X co-ord, Y co-ord, Z co-ord
0 0 -2.234
9.79795897113271 0 -2.234
9.79795897113271 9.79795897113271 -2.234
0 9.79795897113271 -2.234
0 0 0
9.79795897113271 0 0
9.79795897113271 9.79795897113271 0
0 9.79795897113271 0
#SURFACES, no of vertices followed by list of associated vert
4 1 2 6 5
4 2 3 7 6
4 3 4 8 7
4 4 1 5 8 
4 5 6 7 8
4 1 4 3 2
# unused index, EQUAL TO NUMBER OF SURFACES?
0 0 0 0 0 0
# surfaces indentation (m), EQUAL TO NUMBER OF SURFACES?
0.0 0.0 0.0 0.0 0.0 0.0
#INSOLATION
3 0 0 0 # default insolation distribution
# surface attributes follow: 
# id  surface      geom  loc/  construction environment
# no  name         type  posn  name         other side, LEAVE THE BELOW SPACING
#SURFACE_ATTRIBUTES
  1, Wall-1        OPAQ  VERT  CNST-1       BASESIMP       
  2, Wall-2        OPAQ  VERT  CNST-1       BASESIMP       
  3, Wall-3        OPAQ  VERT  CNST-1       BASESIMP       
  4, Wall-4        OPAQ  VERT  CNST-1       BASESIMP       
  5, Top-5         OPAQ  CEIL  CNST-1       ANOTHER        
  6, Base-6        OPAQ  FLOR  CNST-1       BASESIMP       
#BASE, NUMBER OF SURFACES? AREA OF BASE?, ALSO LEAVE THE FINAL LINE AFTER THIS NEXT LINE
6 0 0 0 0 0    96.00 0
