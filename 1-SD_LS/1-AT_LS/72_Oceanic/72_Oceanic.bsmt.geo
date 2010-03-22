# geometry of bsmt defined in: ./72_Oceanic.bsmt.geo
GEN  bsmt  This file describes the bsmt  # type, name, descr
      48      20   0.000    # vertices, surfaces, rotation angle
#  X co-ord, Y co-ord, Z co-ord
      0.00000     0.00000    -2.72000  # vert   1
     -2.59508    -2.59508    -2.72000  # vert   2
     -3.46482    -1.72534    -2.72000  # vert   3
     -7.56604    -5.82656    -2.72000  # vert   4
     -6.69630    -6.69630    -2.72000  # vert   5
     -9.29138    -9.29138    -2.72000  # vert   6
     -3.88909   -14.69368    -2.72000  # vert   7
     -1.29400   -12.09860    -2.72000  # vert   8
     -0.42426   -12.96834    -2.72000  # vert   9
      3.67696    -8.86712    -2.72000  # vert  10
      2.80721    -7.99738    -2.72000  # vert  11
      5.40230    -5.40229    -2.72000  # vert  12
      0.00000     0.00000     0.00000  # vert  13
     -2.59508    -2.59508     0.00000  # vert  14
     -3.46482    -1.72534     0.00000  # vert  15
     -7.56604    -5.82656     0.00000  # vert  16
     -6.69630    -6.69630     0.00000  # vert  17
     -9.29138    -9.29138     0.00000  # vert  18
     -3.88909   -14.69368     0.00000  # vert  19
     -1.29400   -12.09860     0.00000  # vert  20
     -0.42426   -12.96834     0.00000  # vert  21
      3.67696    -8.86712     0.00000  # vert  22
      2.80721    -7.99738     0.00000  # vert  23
      5.40230    -5.40229     0.00000  # vert  24
     -5.04874   -13.53403    -1.47000  # vert  25
     -4.43356   -14.14921    -1.47000  # vert  26
     -4.43356   -14.14921    -0.60000  # vert  27
     -5.04874   -13.53403    -0.60000  # vert  28
     -3.18198   -13.98657    -1.72000  # vert  29
     -2.46073   -13.26532    -1.72000  # vert  30
     -2.46073   -13.26532    -0.54000  # vert  31
     -3.18198   -13.98657    -0.54000  # vert  32
      0.28284   -12.26123    -1.72000  # vert  33
      2.84964    -9.69443    -1.72000  # vert  34
      2.84964    -9.69443    -0.53000  # vert  35
      0.28284   -12.26123    -0.53000  # vert  36
      2.98399    -7.82060    -2.67000  # vert  37
      3.63452    -7.17006    -2.67000  # vert  38
      3.63452    -7.17006    -0.60000  # vert  39
      2.98399    -7.82060    -0.60000  # vert  40
      4.39820    -6.40638    -1.72000  # vert  41
      5.01338    -5.79120    -1.72000  # vert  42
      5.01337    -5.79120    -0.64000  # vert  43
      4.39819    -6.40638    -0.64000  # vert  44
      5.04875    -5.04874    -1.72000  # vert  45
      4.43356    -4.43355    -1.72000  # vert  46
      4.43356    -4.43355    -0.85000  # vert  47
      5.04875    -5.04874    -0.85000  # vert  48
# no of vertices followed by list of associated vert
  12,  1, 12, 11, 10,  9,  8,  7,  6,  5,  4,  3,  2,
  12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,
   4,  1,  2, 14, 13,
   4,  2,  3, 15, 14,
   4,  3,  4, 16, 15,
   4,  4,  5, 17, 16,
   4,  5,  6, 18, 17,
  10,  6,  7, 19, 18,  6, 25, 28, 27, 26, 25,
  10,  7,  8, 20, 19,  7, 29, 32, 31, 30, 29,
   4,  8,  9, 21, 20,
  10,  9, 10, 22, 21,  9, 33, 36, 35, 34, 33,
   4, 10, 11, 23, 22,
  16, 11, 12, 42, 41, 44, 43, 42, 12, 24, 23, 11, 37, 40, 39, 38, 37,
  10, 12,  1, 13, 24, 12, 45, 48, 47, 46, 45,
   4, 25, 26, 27, 28,
   4, 29, 30, 31, 32,
   4, 33, 34, 35, 36,
   4, 37, 38, 39, 40,
   4, 41, 42, 43, 44,
   4, 45, 46, 47, 48,
# unused index
 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
# surfaces indentation (m)
 0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00
    3   0   0   0    # default insolation distribution
# surface attributes follow: 
# id  surface      geom  loc/  construction environment
# no  name         type  posn  name         other side
  1, Floor         OPAQ  FLOR  BSMT_flor    BASESIMP       
  2, Ceiling       OPAQ  CEIL  MAIN_BSMT    ANOTHER        
  3, wall-front-1  OPAQ  UNKN  BSMT_wall_i  BASESIMP       
  4, wall-left-3   OPAQ  UNKN  BSMT_wall_i  BASESIMP       
  5, wall-front-2  OPAQ  UNKN  BSMT_wall_i  BASESIMP       
  6, wall-right-1  OPAQ  UNKN  BSMT_wall_i  BASESIMP       
  7, wall-front-3  OPAQ  UNKN  BSMT_wall_i  BASESIMP       
  8, wall-right-2  OPAQ  UNKN  BSMT_wall_i  BASESIMP       
  9, wall-back-1   OPAQ  UNKN  BSMT_wall_i  EXTERIOR       
 10, wall-right-3  OPAQ  UNKN  BSMT_wall_i  EXTERIOR       
 11, wall-back-2   OPAQ  UNKN  BSMT_wall_i  EXTERIOR       
 12, wall-left-1   OPAQ  UNKN  BSMT_wall_i  EXTERIOR       
 13, wall-back-3   OPAQ  UNKN  BSMT_wall_i  EXTERIOR       
 14, wall-left-2   OPAQ  UNKN  BSMT_wall_i  BASESIMP       
 15, wndw-right-1  TRAN  VERT  WNDW_200     EXTERIOR       
 16, wndw-back-1   TRAN  VERT  WNDW_200     EXTERIOR       
 17, wndw-back-2   TRAN  VERT  WNDW_200     EXTERIOR       
 18, door-back-1   OPAQ  VERT  DOOR_metal   EXTERIOR       
 19, wndw-back-3   TRAN  VERT  WNDW_200     EXTERIOR       
 20, wndw-left-1   TRAN  VERT  WNDW_200     EXTERIOR       
# base
  1  0  0  0  0  0   114.66 0
