# geometry of main_2 defined in: ./2901A00152.main_2.geo
GEN  main_2  This file describes the main_2  # type, name, descr
      26      12   0.000    # vertices, surfaces, rotation angle
#  X co-ord, Y co-ord, Z co-ord
      0.00000     0.00000     4.65000  # vert   1
     12.00000     0.00000     4.65000  # vert   2
     12.00000     7.97000     4.65000  # vert   3
      0.00000     7.97000     4.65000  # vert   4
      0.00000     0.00000     6.94000  # vert   5
     12.00000     0.00000     6.94000  # vert   6
     12.00000     7.97000     6.94000  # vert   7
      0.00000     7.97000     6.94000  # vert   8
      1.09000     0.00000     5.21000  # vert   9
      6.33000     0.00000     5.21000  # vert  10
      6.74000     0.00000     5.21000  # vert  11
      6.74000     0.00000     6.38000  # vert  12
      6.33000     0.00000     6.38000  # vert  13
      1.09000     0.00000     6.38000  # vert  14
     12.00000     2.68000     5.37000  # vert  15
     12.00000     4.64000     5.37000  # vert  16
     12.00000     5.29000     5.37000  # vert  17
     12.00000     5.29000     6.22000  # vert  18
     12.00000     4.64000     6.22000  # vert  19
     12.00000     2.68000     6.22000  # vert  20
      2.69000     7.97000     5.24000  # vert  21
      1.53000     7.97000     5.24000  # vert  22
      1.14000     7.97000     5.24000  # vert  23
      1.14000     7.97000     6.35000  # vert  24
      1.53000     7.97000     6.35000  # vert  25
      2.69000     7.97000     6.35000  # vert  26
# no of vertices followed by list of associated vert
   4,  1,  4,  3,  2,
   4,  5,  6,  7,  8,
  16,  1,  2,  6,  5,  1,  9, 14, 13, 10,  9,  1, 10, 13, 12, 11, 10,
   4,  9, 10, 13, 14,
   4, 10, 11, 12, 13,
  16,  2,  3,  7,  6,  2, 15, 20, 19, 16, 15,  2, 16, 19, 18, 17, 16,
   4, 15, 16, 19, 20,
   4, 16, 17, 18, 19,
  16,  3,  4,  8,  7,  3, 21, 26, 25, 22, 21,  3, 22, 25, 24, 23, 22,
   4, 21, 22, 25, 26,
   4, 22, 23, 24, 25,
   4,  4,  1,  5,  8,
# unused index
 0,0,0,0,0,0,0,0,0,0,0,0
# surfaces indentation (m)
 0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00
    3   0   0   0    # default insolation distribution
# surface attributes follow: 
# id  surface      geom  loc/  construction environment
# no  name         type  posn  name         other side
  1, floor         OPAQ  FLOR  M->M         ANOTHER        
  2, ceiling       OPAQ  CEIL  M->A_or_R    ANOTHER        
  3, front         OPAQ  VERT  M_wall       EXTERIOR       
  4, front-aper    TRAN  VERT  WNDW_200     EXTERIOR       
  5, front-frame   OPAQ  VERT  FRM_Vnl      EXTERIOR       
  6, right         OPAQ  VERT  M_wall       EXTERIOR       
  7, right-aper    TRAN  VERT  WNDW_200     EXTERIOR       
  8, right-frame   OPAQ  VERT  FRM_Vnl      EXTERIOR       
  9, back          OPAQ  VERT  M_wall       EXTERIOR       
 10, back-aper     TRAN  VERT  WNDW_200     EXTERIOR       
 11, back-frame    OPAQ  VERT  FRM_Vnl      EXTERIOR       
 12, left          OPAQ  VERT  M_wall_adb   ADIABATIC      
# base
  1  0  0  0  0  0    95.64 0
