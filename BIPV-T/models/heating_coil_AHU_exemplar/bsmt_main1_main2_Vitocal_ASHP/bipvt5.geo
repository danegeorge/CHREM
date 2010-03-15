# geometry of bipvt5 defined in: ./bipvt5.geo
GEN  bipvt5  This file describes the bipvt5  # type, name, descr
       8       6   0.000    # vertices, surfaces, rotation angle
#  X co-ord, Y co-ord, Z co-ord
      0.00000     3.16000    10.10000  # vert   1
     12.00000     3.16000    10.10000  # vert   2
     12.00000     3.94000    10.88000  # vert   3
      0.00000     3.94000    10.88000  # vert   4
      0.00000     3.12460    10.13540  # vert   5
     12.00000     3.12460    10.13540  # vert   6
     12.00000     3.90460    10.91540  # vert   7
      0.00000     3.90460    10.91540  # vert   8
# no of vertices followed by list of associated vert
   4,  2,  1,  4,  3,
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
  1, Bottom        OPAQ  SLOP  bipvt_insul  ANOTHER        
  2, Top           TRAN  SLOP  Glz_Abs      EXTERIOR       
  3, Inlet         OPAQ  SLOP  fict         ANOTHER        
  4, SideE         OPAQ  VERT  wood         EXTERIOR       
  5, Outlet        OPAQ  SLOP  fict         EXTERIOR       
  6, SideW         OPAQ  VERT  wood         EXTERIOR       
# base
  1  0  0  0  0  0    13.24 0
