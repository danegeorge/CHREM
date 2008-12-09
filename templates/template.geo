# geometry of main defined in: ../zones/main.geo
#ZONE_NAME: zone description type, zone name, description
GEN  zone zone_description
#VER_SUR_ROT: vertex count, surface count, rotation angle in degrees
8 6 0 
#VERTICES, X co-ord, Y co-ord, Z co-ord
# base in counter-clockwise (CCW) fashion looking down, then top in CCW fashion
#END_VERTICES
#SURFACES, no of vertices followed by list of associated vert
# CCW fashion looking from outside toward inside
#END_SURFACES
#UNUSED_INDEX, EQUAL TO NUMBER OF SURFACES?
0 0 0 0 0 0
#SURFACE_INDENTATION (m), EQUAL TO NUMBER OF SURFACES?
0 0 0 0 0 0
#INSOLATION
3 0 0 0 # default insolation distribution
#SURFACE_ATTRIBUTES: must be columner format (see exemplar for example)
# surface attributes follow: 
# id number
# surface name
# construction type OPAQ, TRAN
# placement FLOR, CEIL, VERT, SLOP
# construction name
# outside condition EXTERIOR, ANOTHER, BASESIMP
#END_SURFACE_ATTRIBUTES
#BASE, NUMBER OF SURFACES? AREA OF BASE?, ALSO LEAVE THE FINAL LINE AFTER THIS NEXT LINE
6 0 0 0 0 0 50 0
