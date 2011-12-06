# geometry of bsmt defined in: ./2511B00345.bsmt.geo
GEN  bsmt  This file describes the bsmt  # type, name, descr
       8       6   0.000    # vertices, surfaces, rotation angle
#  X co-ord, Y co-ord, Z co-ord
      0.00000     0.00000     0.00000  # vert   1
      0.00000    11.82000     0.00000  # vert   2
    -17.64000    11.82000     0.00000  # vert   3
    -17.64000     0.00000     0.00000  # vert   4
      0.00000     0.00000     2.44000  # vert   5
      0.00000    11.82000     2.44000  # vert   6
    -17.64000    11.82000     2.44000  # vert   7
    -17.64000     0.00000     2.44000  # vert   8
# no of vertices followed by list of associated vert
   4,  1,  4,  3,  2,
   4,  5,  6,  7,  8,
   4,  1,  2,  6,  5,
   4,  2,  3,  7,  6,
   4,  3,  4,  8,  7,
   4,  4,  1,  5,  8,
# unused index
 0,0,0,0,0,0
# surfaces indentation (m)
 0.00,0.00,0.00,0.00,0.00,0.00
    3   0   0   0    # default insolation distribution
# surface attributes follow: 
# id  surface      geom  loc/  construction environment
# no  name         type  posn  name         other side
  1, floor         OPAQ  FLOR  B_slab       BASESIMP       
  2, ceiling       OPAQ  CEIL  M->B         ANOTHER        
  3, front         OPAQ  VERT  B_wall       BASESIMP       
  4, right         OPAQ  VERT  B_wall       BASESIMP       
  5, back          OPAQ  VERT  B_wall       BASESIMP       
  6, left          OPAQ  VERT  B_wall       BASESIMP       
# base
  1  0  0  0  0  0   208.50 0
