/* STEP1_CREATE_GCD_FILE.SAS
      Craig Heither, rev. 09-24-2015

	This program creates the file "data_mesozone_gcd.csv" containing Great Circle Distances between all pairs of Mesozones.  The output file replaces the RSG version in the Meso model to address these issues: 
	  - The file RSG delivered measures GCD in Kilometers rather than Miles.
	  - The new file includes logistics nodes so that it can be used to develop the modepath costs.
	  - The new file will reflect the locations of US mesozones in the MFN (except Hawaii).
	  - The new file includes GCD values for intrazonal pairs (US mesozones only).
	
	This program also creates the file "data_mesozone_centroids.csv" to ensure the data used in the Meso model is consistent with the MFN data.
	
	revised 09-28-2017: Add code to create I-E and E-E POE files for Truck trips to be used in truck touring model.

*/

options noxwait;
*###=================================================================================###
    DEFINE INPUT/OUTPUT FILES
*###=================================================================================###;
%put &sysparm.;
%let scen=%scan(&sysparm,1);					                            *** -- Scenario number -- ***; 
%let year=%scan(&sysparm,2);					                            *** -- Scenario number -- ***; 
%let sasin=inputs\;	                                          *** -- Location of SAS input files -- ***;
%let outdir=outputs\&scen.;                                *** -- Location of output files for Meso Freight Model -- ***;
%let max=273;                                                 *** -- Maximum U.S. mesozone number -- ***;
%let poeMIN = 3634;
%let poeMAX = 3648;

  *##-- Inputs --##;
filename rsgdist "&sasin.data_mesozone_gcd.csv";              *** -- Original RSG file of Great Circle Distances -- ***;
filename cmap "&sasin.mesozone_latlon.csv";                   *** -- File of mesozone locations from Master Freight Network -- ***;
filename sqmi "&sasin.Mesozone_sqmi.csv";                     *** -- File of U.S. mesozone area (sq miles), does not include logistics nodes -- ***; 
filename cent "..\input_data\base_ntwk.txt";                  *** -- Emme network batchin file -- ***;
filename poe "..\input_data\poe.in";                  		  *** -- Emme batchin file containing unique POE codes -- ***;
filename mf40 "..\output_data\&scen.\mf40.in";      		  *** -- Emme skim file containing POEs used -- ***;
filename poecoord "..\input_data\base_ntwk.txt";              *** -- Emme batchin file containing POE coordinates -- ***;

  *##-- Output --##;
filename out1 "&outdir.\data_mesozone_gcd_&year..csv";               *** -- New output file of Great Circle Distances -- ***;
filename out2 "&outdir.\data_mesozone_centroids_&year..csv";         *** -- New output file of CMAP Mesozone centroid coordinates -- ***;
filename out3 "&outdir.\cmap_data_truck_IE_poe_&year..csv";          *** -- Output file of CMAP POEs used by truck I-E trips -- ***;
filename out4 "&outdir.\cmap_data_truck_EE_poe_&year..csv";          *** -- Output file of CMAP POEs used by truck E-E trips -- ***;

data _null_; command="if not exist &outdir (mkdir &outdir)"; call system(command); run;

*###=================================================================================###
    READ ORIGINAL FILE
*###=================================================================================###;
proc import datafile=rsgdist out=meso dbms=csv replace;
data meso(keep=Production_zone Production_lon Production_lat); set meso;
  proc sort nodupkey; by Production_zone;


*###=================================================================================###
    READ CMAP FILE
*###=================================================================================###;
proc import datafile=cmap out=cmapmeso dbms=csv replace;
data cmapmeso; set cmapmeso;
  ***-- Convert coordinates from decimal degrees to radians for consistency with RSG file -- ***;
  ***-- Conversion: decimal degrees * pi / 180 --***;
  Production_lon=Production_lon*constant('pi')/180;
  Production_lat=Production_lat*constant('pi')/180;
  proc sort nodupkey; by Production_zone;

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
		   
data allmeso(drop=delta_lon delta_lat a c); set allmeso;
  ***-- Calculate Great Circle Distance using Haversine formula -- ***;
  ***-- see http://www.movable-type.co.uk/scripts/latlong.html for discussion/documentation --***;
  ***-- or http://andrew.hedges.name/experiments/haversine/ --***;
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
proc import datafile=sqmi out=sqmi dbms=csv replace;  

  ***-- For simplicity, assume each mesozone is a square and the average trip distance -- ***;
  ***-- equals one-half of the length of each side: thus, sqrt(area)/2 -- ***;   
data sqmi(drop=mesozone sqmi); set sqmi;
  dist=sqrt(sqmi)/2;  
  Production_zone=mesozone;
  Consumption_zone=mesozone;
   proc sort; by Consumption_zone Production_zone;

   
data allmeso(drop=dist); merge allmeso sqmi; by Consumption_zone Production_zone;
   if Consumption_zone=Production_zone then GCD=max(GCD,dist);
   if Production_zone=182 or Consumption_zone=182 then delete;   *** original Entire CMAP mesozone does not exist in meso model;
proc export outfile=out1 dbms=csv replace;


*###=================================================================================###
    CREATE NEW CMAP MESOZONE CENTROID COORDINATE FILE
*###=================================================================================###;  	
data centrd; infile cent missover obs=400;
   input @1 flag $2. @; 
    select(flag);
     when('a ','a*') input stop_zone x_coord y_coord;   
     otherwise delete;
    end;
data centrd(drop=flag); set centrd;	
   x_coord=round(x_coord/5280,0.001);  ** -- convert from State Plane feet to Miles -- **;
   y_coord=round(y_coord/5280,0.001);
  proc sort nodupkey; by stop_zone;
  
data x; set centrd(where=(stop_zone<=&max));	*** 09-28-2017: need to verify Canada/Mexicao are not needed ***;   
proc export outfile=out2 dbms=csv replace;

*###=================================================================================###
    CREATE POE FILE FOR TRUCK TOURING MODEL
*###=================================================================================###;  
data poe; infile poe missover firstobs=5;
  input poe code type $;
  
data trkpoe(drop=type); set poe(where=(type="T")); 
  i=_n_;
  proc sort; by i;

data trkpoe2(rename=(poe=poe2 code=code2)); set trkpoe;  
  do i=1 to 10;
    output;
  end;
  proc sort; by i;

 ** All possible combinations of POEs **;
data trk;*data trk(drop=i code2); merge trkpoe2 trkpoe; by i;
data trk(drop=i code2); set trk(where=(poe ne poe2));
  code=code+code2;
   proc sort nodupkey; by code; 

  ** --- POE Usage from Skims --- **;
data poe(keep=o dest code); infile mf40 missover dlm=' :' firstobs=5;
  input o d1 v1 d2 v2 d3 v3;
   dest=d1; code=v1; output;
   dest=d2; code=v2; output;
   dest=d3; code=v3; output;
   
data poe; set poe(where=(o>0 & dest>0)); 
  proc sort; by code;

proc sort data=trkpoe; by code;
data ie(drop=code i); merge poe(in=hit1) trkpoe(in=hit2); by code; if hit1 & hit2;
  rename o=Production_zone dest=Consumption_zone;
proc export outfile=out3 dbms=csv replace;

data passthru; merge poe(in=hit1) trk(in=hit2); by code; if hit1 & hit2;
  rename o=Production_zone dest=Consumption_zone;
 proc sort data=passthru; by Production_zone Consumption_zone;

  ** --- Use Distance to determine POE in-out order --- **;
   ** Mesozone centroid coordinates **;
data a1; set centrd;
 rename stop_zone=Production_zone x_coord=xp_coord y_coord=yp_coord;
  proc sort data=a1; by Production_zone;
data passthru; merge passthru(in=hit) a1; by Production_zone; if hit;
 proc sort data=passthru; by poe;
 
   ** POE coordinates **;
data poecrd; infile poecoord missover dlm=' :' firstobs=5 obs=2000;
  input a $ poe x1_coord y1_coord;
    if poeMIN<=poe<=poeMAX;
	x1_coord=round(x1_coord/5280,0.001);  ** -- convert from State Plane feet to Miles -- **;
	y1_coord=round(y1_coord/5280,0.001);
	proc sort; by poe;

data poecrd2; set poecrd;
  rename poe=poe2 x1_coord=x2_coord y1_coord=y2_coord;
proc sort data=poecrd2; by poe2;
	
data passthru; merge passthru(in=hit) poecrd; by poe; if hit;
 proc sort data=passthru; by poe2;	
 
data passthru; merge passthru(in=hit) poecrd2; by poe2; if hit;
  dist1=sqrt((xp_coord-x1_coord)**2 + (yp_coord-y1_coord)**2);
  dist2=sqrt((xp_coord-x2_coord)**2 + (yp_coord-y2_coord)**2);
  if dist2<dist1 then do;
    c=poe; poe=poe2; poe2=c; output;
  end;
  else do; output; end;
  keep Production_zone Consumption_zone poe poe2;
 proc sort data=passthru; by Production_zone Consumption_zone;

proc export outfile=out4 dbms=csv replace;	

/*
  *** Still To Do: Address Rail Pass Through 
*/
run;
