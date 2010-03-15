# geometry of attic defined in: ./2901A00152.attic.geo
GEN  attic  This file describes the attic  # type, name, descr
      16      10   0.000    # vertices, surfaces, rotation angle
#  X co-ord, Y co-ord, Z co-ord
      0.00000     0.00000     6.94000  # vert   1
     12.00000     0.00000     6.94000  # vert   2
     12.00000     7.97000     6.94000  # vert   3
      0.00000     7.97000     6.94000  # vert   4
      0.00000     3.94000    10.88000  # vert   5
     12.00000     3.94000    10.88000  # vert   6
     12.00000     4.04000    10.88000  # vert   7
      0.00000     4.04000    10.88000  # vert   8
      0.00000     0.79000     7.73000  # vert   9
     12.00000     0.79000     7.73000  # vert  10
      0.00000     1.58000     8.52000  # vert  11
     12.00000     1.58000     8.52000  # vert  12
      0.00000     2.37000     9.31000  # vert  13
     12.00000     2.37000     9.31000  # vert  14
      0.00000     3.16000    10.10000  # vert  15
     12.00000     3.16000    10.10000  # vert  16
# no of vertices followed by list of associated vert
   4,  1,  4,  3,  2,
   4,  5,  6,  7,  8,
   8,  2,  3,  7,  6, 16, 14, 12, 10,
   4,  3,  4,  8,  7,
   8,  4,  1,  9, 11, 13, 15,  5,  8,
   4,  1,  2, 10,  9,
   4,  9, 10, 12, 11,
   4, 11, 12, 14, 13,
   4, 13, 14, 16, 15,
   4, 15, 16,  6,  5,
# unused index
 0,0,0,0,0,0,0,0,0,0
# surfaces indentation (m)
 0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00
    3   0   0   0    # default insolation distribution
# surface attributes follow: 
# id  surface      geom  loc/  construction environment
# no  name         type  posn  name         other side
  1, floor         OPAQ  FLOR  A_or_R->M    ANOTHER        
  2, ceiling       OPAQ  CEIL  A_or_R_slop  EXTERIOR       
  3, right         OPAQ  VERT  A_or_R_gbl   EXTERIOR       
  4, back          OPAQ  SLOP  A_or_R_slop  EXTERIOR       
  5, left          OPAQ  VERT  A_or_R_gbl   ADIABATIC      
  6, bipvt1        OPAQ  SLOP  bipvt_insul  ANOTHER        
  7, bipvt2        OPAQ  SLOP  bipvt_insul  ANOTHER        
  8, bipvt3        OPAQ  SLOP  bipvt_insul  ANOTHER        
  9, bipvt4        OPAQ  SLOP  bipvt_insul  ANOTHER        
 10, bipvt5        OPAQ  SLOP  bipvt_insul  ANOTHER        
# base
  1  0  0  0  0  0    95.64 0
