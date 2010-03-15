# geometry of main_1 defined in: ./2901A00152.main_1.geo
GEN  main_1  This file describes the main_1  # type, name, descr
      36      15   0.000    # vertices, surfaces, rotation angle
#  X co-ord, Y co-ord, Z co-ord
      0.00000     0.00000     2.21000  # vert   1
     13.00000     0.00000     2.21000  # vert   2
     13.00000     7.97000     2.21000  # vert   3
      0.00000     7.97000     2.21000  # vert   4
      0.00000     0.00000     4.65000  # vert   5
     12.00000     0.00000     4.65000  # vert   6
     13.00000     0.00000     4.65000  # vert   7
     13.00000     7.97000     4.65000  # vert   8
     12.00000     7.97000     4.65000  # vert   9
      0.00000     7.97000     4.65000  # vert  10
      1.81000     0.00000     2.80000  # vert  11
      7.05000     0.00000     2.80000  # vert  12
      7.80000     0.00000     2.80000  # vert  13
      7.80000     0.00000     4.06000  # vert  14
      7.05000     0.00000     4.06000  # vert  15
      1.81000     0.00000     4.06000  # vert  16
      9.51000     0.00000     2.31000  # vert  17
     10.32000     0.00000     2.31000  # vert  18
     10.32000     0.00000     4.34000  # vert  19
      9.51000     0.00000     4.34000  # vert  20
     13.00000     2.38000     2.98000  # vert  21
     13.00000     4.11000     2.98000  # vert  22
     13.00000     4.68000     2.98000  # vert  23
     13.00000     4.68000     3.88000  # vert  24
     13.00000     4.11000     3.88000  # vert  25
     13.00000     2.38000     3.88000  # vert  26
     13.00000     6.96000     2.31000  # vert  27
     13.00000     7.87000     2.31000  # vert  28
     13.00000     7.87000     4.32000  # vert  29
     13.00000     6.96000     4.32000  # vert  30
      5.28000     7.97000     2.84000  # vert  31
      2.92000     7.97000     2.84000  # vert  32
      2.14000     7.97000     2.84000  # vert  33
      2.14000     7.97000     4.02000  # vert  34
      2.92000     7.97000     4.02000  # vert  35
      5.28000     7.97000     4.02000  # vert  36
# no of vertices followed by list of associated vert
   4,  1,  4,  3,  2,
   4,  5,  6,  9, 10,
   4,  6,  7,  8,  9,
  23,  1,  2,  7,  6,  5,  1, 11, 16, 15, 12, 11,  1, 12, 15, 14, 13, 12,  1, 17, 20, 19, 18, 17,
   4, 11, 12, 15, 16,
   4, 12, 13, 14, 15,
   4, 17, 18, 19, 20,
  22,  2,  3,  8,  7,  2, 21, 26, 25, 22, 21,  2, 22, 25, 24, 23, 22,  2, 27, 30, 29, 28, 27,
   4, 21, 22, 25, 26,
   4, 22, 23, 24, 25,
   4, 27, 28, 29, 30,
  17,  3,  4, 10,  9,  8,  3, 31, 36, 35, 32, 31,  3, 32, 35, 34, 33, 32,
   4, 31, 32, 35, 36,
   4, 32, 33, 34, 35,
   4,  4,  1,  5, 10,
# unused index
 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
# surfaces indentation (m)
 0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00
    3   0   0   0    # default insolation distribution
# surface attributes follow: 
# id  surface      geom  loc/  construction environment
# no  name         type  posn  name         other side
  1, floor         OPAQ  FLOR  M->B         ANOTHER        
  2, ceiling       OPAQ  CEIL  M->M         ANOTHER        
  3, ceiling-expo  OPAQ  UNKN  M_ceil_exp   EXTERIOR       
  4, front         OPAQ  VERT  M_wall       EXTERIOR       
  5, front-aper    TRAN  VERT  WNDW_200     EXTERIOR       
  6, front-frame   OPAQ  VERT  FRM_Vnl      EXTERIOR       
  7, front-door    OPAQ  VERT  D_mtl_EPS    EXTERIOR       
  8, right         OPAQ  VERT  M_wall       EXTERIOR       
  9, right-aper    TRAN  VERT  WNDW_200     EXTERIOR       
 10, right-frame   OPAQ  VERT  FRM_Vnl      EXTERIOR       
 11, right-door    OPAQ  VERT  D_mtl_EPS    EXTERIOR       
 12, back          OPAQ  VERT  M_wall       EXTERIOR       
 13, back-aper     TRAN  VERT  WNDW_200     EXTERIOR       
 14, back-frame    OPAQ  VERT  FRM_Vnl      EXTERIOR       
 15, left          OPAQ  VERT  M_wall_adb   ADIABATIC      
# base
  1  0  0  0  0  0   103.61 0
