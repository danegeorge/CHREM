# geometry of main defined in: ../zones/main.geo
#ZONE_NAME
GEN  main  main describes a  # type, name, descr
#VER_SUR_ROT
8 6 0.0 # vertices, surfaces, rotation angle
#VERTICES, X co-ord, Y co-ord, Z co-ord
00.00 00.00 00.00 # vert   1
10.00 00.00 00.00 # vert   2
10.00 05.00 00.00 # vert   3
00.00 05.00 00.00 # vert   4
00.00 00.00 02.70 # vert   5
10.00 00.00 02.70 # vert   6
10.00 05.00 02.70 # vert   7
00.00 05.00 02.70 # vert   8
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
  1, Wall-1        OPAQ  VERT  WALL-1       EXTERIOR       
  2, Wall-2        OPAQ  VERT  WALL-1       EXTERIOR       
  3, Wall-3        OPAQ  VERT  WALL-1       EXTERIOR       
  4, Wall-4        OPAQ  VERT  WALL-1       EXTERIOR       
  5, Top-5         OPAQ  CEIL  WALL-1       EXTERIOR       
  6, Base-6        OPAQ  FLOR  WALL-1       EXTERIOR       
#BASE, NUMBER OF SURFACES? AREA OF BASE?, ALSO LEAVE THE FINAL LINE AFTER THIS NEXT LINE
6 0 0 0 0 0 50.00 0
