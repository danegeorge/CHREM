# complex fenestration construction properties of room defined in room.cfc
# Number of surfaces in the zone
8
# CFC index for each surface (type of the CFC material, i.e. 0=no CFC, 1,2,..= CFC types)
0,0,0,0,0,0,1,2
#
# CFC description
# type 1
# Number of CFC layers (exp. glazing, gap, blind)
3
#
# for Glazing: R-fr= front reflectance, R-bk= back reflectance, Tran= transmittance
# for Venetian Blind: R-fr= slat top reflectance, R-bk= slat bottom reflectance, Tran= slat transmittance
#
# For each layer: normal SOLAR optical properties - R_fr, R_bk, Tran.
# SOLAR
0.071   0.071   0.775   # glazing
0.000   0.000   0.000   # gas gap
0.850   0.150   0.000   # slat-type blind
#
# For each layer: normal VISIBLE optical properties - R_fr, R_bk, Tran. (CURRENTLY NOT USED)
# VISIBLE
0.080   0.080   0.881   # glazing
0.000   0.000   0.000   # gas gap
0.070   0.070   0.600   # slat-type blind
#
# For each layer: normal LONGWAVE radiative properties - R_fr, R_bk, Tran.
# LONGWAVE
0.160   0.160   0.000   # glazing
0.000   0.000   0.000   # gas gap
0.150   0.150   0.000   # slat-type blind
#
# type 2
# Number of CFC layers (exp. glazing, gap, blind)
   5   # layers in cfc type:  2
# For each layer: normal solar optical properties - R_fr, R_bk, Tran.
   0.071   0.071   0.775   # glazing
   0.000   0.000   0.000   # gas gap
   0.071   0.071   0.775   # glazing
   0.000   0.000   0.000   # gas gap
   0.500   0.500   0.000   # slat-type blind
# For each layer: normal visible optical properties - R_fr, R_bk, Tran. CURRENTLY NOT USED
   0.080   0.080   0.881   # glazing
   0.000   0.000   0.000   # gas gap
   0.080   0.080   0.881   # glazing
   0.000   0.000   0.000   # gas gap
   0.070   0.070   0.600   # slat-type blind
# For each layer: normal longwave radiative properties - R_fr, R_bk, Tran.
   0.160   0.160   0.000   # glazing
   0.000   0.000   0.000   # gas gap
   0.160   0.160   0.000   # glazing
   0.000   0.000   0.000   # gas gap
   0.150   0.150   0.000   # slat-type blind
# layer type index for cfc type:  1 (Layer types: 0-gas gap, 1-glazing, 2-venetian blind)
1,0,2
#
# Gas mixture properties for cfc type:  1
#
# GAS LAYER   2
0.290E+02        # molecular mass of gas mixture (g/gmole)
0.230E-02 0.799E-04        # a and b coeffs.- gas conductivity (W/m.K)
0.352E-05 0.498E-07        # a and b coeffs.- gas viscosity (N.s/m2)
0.100E+04 0.147E-01        # a and b coeffs.- specific heat (J/kg.K)
#
# slat-type blind attributes for cfc type:  1
# Slat geometry
# slat: width(mm); spacing(mm); angle(deg); orientation(HORZ/VERT); crown (mm); w/r ratio; slat thickness (mm)
25.400 21.170 0.000 VERT 1.610 0.499 0.330
#
# type 2
# layer type index for cfc type:  2
1,0,1,0,2
#
# Gas mixture properties for cfc type:  2
# gas layer   2
 0.290E+02        # molecular mass of gas mixture (g/gmole)
 0.230E-02  0.799E-04        # a and b coeffs.- gas conductivity (W/m.K)
 0.352E-05  0.498E-07        # a and b coeffs.- gas viscosity (N.s/m2)
 0.100E+04  0.147E-01        # a and b coeffs.- specific heat (J/kg.K)
# gas layer   4
 0.290E+02        # molecular mass of gas mixture (g/gmole)
 0.230E-02  0.799E-04        # a and b coeffs.- gas conductivity (W/m.K)
 0.352E-05  0.498E-07        # a and b coeffs.- gas viscosity (N.s/m2)
 0.100E+04  0.147E-01        # a and b coeffs.- specific heat (J/kg.K)
# slat-type blind attributes for cfc type:  2
# slat: width(mm); spacing(mm); angle(deg); orientation(HORZ/VERT); crown (mm); w/r ratio; slat thickness (mm)
  25.400  21.170   0.000  VERT    1.610   0.499   0.330
