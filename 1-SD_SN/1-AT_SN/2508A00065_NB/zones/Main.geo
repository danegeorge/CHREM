# geometry of Main defined in: user/2508A00065_NB/zones/Main.geo
GEN  Main  simplified elevation of main zone  # type, name, descr
      34       12 0.000    # vertices, surfaces, rotation angle
#  X co-ord, Y co-ord, Z co-ord
    6.84600  9.54600  0.25000   # vert 1  
    6.84600  9.54600  5.11000   # vert 2  
    6.84600  0.00000  5.11000   # vert 3  
    6.84600  0.00000  0.25000   # vert 4  
    0.00000  0.00000  5.11000   # vert 5  
    0.00000  0.00000  0.25000   # vert 6  
    0.00000  9.54600  5.11000   # vert 7  
    0.00000  9.54600  0.25000   # vert 8  
    6.84600  5.82813  2.14282   # vert 9  
    6.84600  4.62613  2.14282   # vert 10 
    6.84600  4.62613  3.94282   # vert 11 
    6.84600  5.82813  3.94282   # vert 12 
    5.89577  0.00000  0.25000   # vert 13 
    5.08577  0.00000  0.25000   # vert 14 
    5.08577  0.00000  2.32000   # vert 15 
    5.89577  0.00000  2.32000   # vert 16 
    4.04555  0.00000  1.58131   # vert 17 
    0.23055  0.00000  1.58131   # vert 18 
    0.23055  0.00000  4.68131   # vert 19 
    4.04555  0.00000  4.68131   # vert 20 
    0.00000  3.71787  2.14282   # vert 21 
    0.00000  4.91987  2.14282   # vert 22 
    0.00000  4.91987  3.94282   # vert 23 
    0.00000  3.71787  3.94282   # vert 24 
    1.13956  9.54600  0.25000   # vert 25 
    1.94956  9.54600  0.25000   # vert 26 
    1.94956  9.54600  2.32000   # vert 27 
    1.13956  9.54600  2.32000   # vert 28 
    3.17912  9.54600  1.78292   # vert 29 
    6.13112  9.54600  1.78292   # vert 30 
    6.13112  9.54600  3.78292   # vert 31 
    3.17912  9.54600  3.78292   # vert 32 
    6.84600  5.82813  0.25000   # vert 33 
    0.00000  3.71787  0.25000   # vert 34 
# no of vertices followed by list of associated vert
  12,   1,   2,   3,   4,   1,  33,   9,  10,  11,  12,   9,  33,
  16,   4,   3,   5,   6,   4,  13,  14,  15,  17,  18,  19,  20,  17,  15,  16,  13,
  12,   6,   5,   7,   8,   6,  34,  21,  22,  23,  24,  21,  34,
  16,   8,   7,   2,   1,   8,  25,  26,  27,  29,  30,  31,  32,  29,  27,  28,  25,
   4,   1,   4,   6,   8,
   4,   7,   5,   3,   2,
   4,   9,  12,  11,  10,
   4,  13,  16,  15,  14,
   4,  17,  20,  19,  18,
   4,  21,  24,  23,  22,
   4,  25,  28,  27,  26,
   4,  29,  32,  31,  30,
# unused index
 0   0   0   0   0   0   0   0   0   0   0   0  
# surfaces indentation (m)
0.000 0.000 0.000 0.000 0.000 0.000 0.000 0.000 0.000 0.000 0.000 0.000 
    3    0    0    0  # default insolation distribution
# surface attributes follow: 
# id surface       geom  loc/   mlc db      environment
# no name          type  posn   name        other side
  1, Wall_2        OPAQ  VERT  ext_wall     EXTERIOR       
  2, Wall_1        OPAQ  VERT  ext_wall     EXTERIOR       
  3, Wall_4        OPAQ  VERT  ext_wall     EXTERIOR       
  4, Wall_3        OPAQ  VERT  ext_wall     EXTERIOR       
  5, to_bsm        OPAQ  FLOR  floors       Foundation-1   
  6, to_attic      OPAQ  CEIL  ceiling      Ceiling01      
  7, Right0001     TRAN  VERT  window       EXTERIOR       
  8, Door-01       OPAQ  VERT  ext_door     EXTERIOR       
  9, Front0001     TRAN  VERT  window       EXTERIOR       
 10, Left0001      TRAN  VERT  window       EXTERIOR       
 11, Door-02       OPAQ  VERT  ext_door     EXTERIOR       
 12, Back0001      TRAN  VERT  window       EXTERIOR       
# base
5   0   0   0   0   0   65.35    
