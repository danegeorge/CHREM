# geometry of main defined in: ./72_Oceanic.main.geo
GEN  main  This file describes the main  # type, name, descr
24 14 225    # vertices, surfaces, rotation angle
#  X co-ord, Y co-ord, Z co-ord
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
    3   0   0   0    # default insolation distribution
# surface attributes follow: 
# id  surface      geom  loc/  construction environment
# no  name         type  posn  name         other side
  1, Floor         OPAQ  FLOR  MAIN_BSMT    ANOTHER        
  2, Ceiling       OPAQ  CEIL  MAIN_ceil    ANOTHER        
  3, wall-front-1  OPAQ  WALL  MAIN_wall    EXTERIOR       
  4, wall-left-3   OPAQ  WALL  MAIN_wall    EXTERIOR       
  5, wall-front-2  OPAQ  WALL  MAIN_wall    EXTERIOR       
  6, wall-right-1  OPAQ  WALL  MAIN_wall    EXTERIOR       
  7, wall-front-3  OPAQ  WALL  MAIN_wall    EXTERIOR       
  8, wall-right-2  OPAQ  WALL  MAIN_wall    EXTERIOR       
  9, wall-back-1   OPAQ  WALL  MAIN_wall    EXTERIOR       
 10, wall-right-3  OPAQ  WALL  MAIN_wall    EXTERIOR       
 11, wall-back-2   OPAQ  WALL  MAIN_wall    EXTERIOR       
 12, wall-left-1   OPAQ  WALL  MAIN_wall    EXTERIOR       
 13, wall-back-3   OPAQ  WALL  MAIN_wall    EXTERIOR       
 14, wall-left-2   OPAQ  WALL  MAIN_wall    EXTERIOR       
# base
  1  0  0  0  0  0   114.6 0
