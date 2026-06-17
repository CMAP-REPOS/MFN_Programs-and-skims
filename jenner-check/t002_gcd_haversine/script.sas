/* STEP1_CREATE_GCD_FILE.SAS  (Jenner compatibility bundle: Great Circle Distance core)
      Craig Heither, rev. 09-24-2015

   This program creates "data_mesozone_gcd.csv" containing Great Circle Distances
   between all pairs of Mesozones, using the Haversine formula.

   Adapted for self-contained execution: this bundle keeps the Great Circle
   Distance core of Step 1 verbatim -- the CMAP coordinate read, the
   degrees->radians conversion, the PROC SQL cross-join that forms every
   mesozone pair, the Haversine GCD calculation, the both-directions expansion,
   and the intrazonal-distance step that uses sqrt(area)/2. The downstream POE
   and centroid sections (which read Emme batchin files via INFILE) and the
   call system() mkdir are outside this slice and are omitted. The mesozone
   coordinate and area inputs are bundled small CSVs.
*/

%let max=273;                                                 *** -- Maximum U.S. mesozone number -- ***;

*###=================================================================================###
    READ ORIGINAL FILE  (mesozone lon/lat in decimal degrees)
*###=================================================================================###;
data meso(keep=Production_zone Production_lon Production_lat);
  input Production_zone Production_lon Production_lat;
  datalines;
1 -87.6298 41.8781
2 -88.0834 42.0334
3 -87.9073 41.9742
4 -87.8612 41.7508
5 -88.3201 41.5868
6 -87.6877 41.5250
;
run;
  proc sort data=meso nodupkey; by Production_zone;


*###=================================================================================###
    READ CMAP FILE
*###=================================================================================###;
data cmapmeso;
  input Production_zone Production_lon Production_lat;
  ***-- Convert coordinates from decimal degrees to radians for consistency with RSG file -- ***;
  ***-- Conversion: decimal degrees * pi / 180 --***;
  Production_lon=Production_lon*constant('pi')/180;
  Production_lat=Production_lat*constant('pi')/180;
  datalines;
1 -87.6298 41.8781
2 -88.0834 42.0334
3 -87.9073 41.9742
4 -87.8612 41.7508
5 -88.3201 41.5868
6 -87.6877 41.5250
;
run;
  proc sort data=cmapmeso nodupkey; by Production_zone;

*###=================================================================================###
    MERGE FILES, OVERWRITE RSG DATA WITH CMAP
*###=================================================================================###;
data meso; merge meso cmapmeso; by Production_zone;


*###=================================================================================###
    CREATE ALL POTENTIAL MESOZONE COMBINATIONS
*###=================================================================================###;
data orig; set meso;
data dest(rename=(Production_zone=Consumption_zone Production_lon=Consumption_lon Production_lat=Consumption_lat)); set meso;

proc sql noprint;
    create table allmeso as
           select orig.*,
                  dest.*
	       from orig, dest;
quit;

data allmeso(drop=delta_lon delta_lat a c); set allmeso;
  ***-- Calculate Great Circle Distance using Haversine formula -- ***;
  ***-- see http://www.movable-type.co.uk/scripts/latlong.html for discussion/documentation --***;
  delta_lon=Consumption_lon - Production_lon;
  delta_lat=Consumption_lat - Production_lat;
  a=sin(delta_lat/2)**2 + cos(Production_lat)*cos(Consumption_lat)*sin(delta_lon/2)**2;
  c=2*arsin(min(1,sqrt(a)));
  GCD=c*3961;  **-- 3961 is radius of Earth in miles, about 39 degrees from equator (Washington DC);

data allmeso(drop=a b c); set allmeso;
  ***-- Ensure Both Directions are included -- ***;
  output;
  if Production_zone ne Consumption_zone then do;
    a=Production_zone; b=Production_lon; c=Production_lat;
	Production_zone=Consumption_zone; Production_lon=Consumption_lon; Production_lat=Consumption_lat;
	Consumption_zone=a; Consumption_lon=b; Consumption_lat=c;
	output;
  end;
  proc sort nodupkey; by Consumption_zone Production_zone;


*###=================================================================================###
    PROVIDE A DISTANCE FOR INTRAZONAL PAIRS (U.S. MESOZONES ONLY)
*###=================================================================================###;
data sqmi;
  input mesozone sqmi;
  datalines;
1 12.4
2 9.8
3 15.1
4 11.3
5 20.6
6 8.2
;
run;

  ***-- For simplicity, assume each mesozone is a square and the average trip distance -- ***;
  ***-- equals one-half of the length of each side: thus, sqrt(area)/2 -- ***;
data sqmi(drop=mesozone sqmi); set sqmi;
  dist=sqrt(sqmi)/2;
  Production_zone=mesozone;
  Consumption_zone=mesozone;
   proc sort; by Consumption_zone Production_zone;


data allmeso(drop=dist); merge allmeso sqmi; by Consumption_zone Production_zone;
   if Consumption_zone=Production_zone then GCD=max(GCD,dist);
proc export data=allmeso outfile="data_mesozone_gcd.csv" dbms=csv replace;

run;
