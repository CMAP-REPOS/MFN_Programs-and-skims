/* VERIFY_RAIL_SERVICE.SAS
      Craig Heither, 06-14-2016

	This program reads the distance and in-vehicle times skims for each rail carrier to ensure no connector-to-connector paths are
	being used.
*/
*################################################################################################; 
%let scen=&sysparm;					                            *** -- Scenario number -- ***; 
%let emdir=output_data\&scen.\;	                            *** -- Location of Emme skims -- ***;

filename out1 "output_data\qc\zone_connections.csv";

options noxwait;

data _null_; command="if not exist output_data\qc (md ..\output_data\qc)" ; 
    call system(command); 
	
*###=================================================================================###
    -- PROCESS EMME SKIMS --
*###=================================================================================###;
%let i=61; %let j=62;
%macro ReadSkims;

   %do %while (&i le 63);
	 run;
      data dist&i(keep=o dest dist); infile "&emdir.mf&i..in" missover dlm=' :' firstobs=5;
	    input o d1 v1 d2 v2 d3 v3;
		  dest=d1; dist=v1; output;
		  dest=d2; dist=v2; output;
		  dest=d3; dist=v3; output;
		  proc sort nodupkey; by o dest;
	  data dist&i; set dist&i(where=(o>0 & dest>0)); run;

      data ivtt&j(keep=o dest ivtt); infile "&emdir.mf&j..in" missover dlm=' :' firstobs=5;
	    input o d1 v1 d2 v2 d3 v3;
		  dest=d1; ivtt=v1; output;
		  dest=d2; ivtt=v2; output;
		  dest=d3; ivtt=v3; output;
		  proc sort nodupkey; by o dest;
	  data ivtt&j; set ivtt&j(where=(o>0 & dest>0)); run;
		
      data rail&i; merge dist&i ivtt&j; by o dest;
	   length mode $2.;
	    mode="&OP";
	    if dist>0 & ivtt>0 then delete;
		run; 
 		
	  %let i=%eval(&i+4); %let j=%eval(&j+4);

   %end;
  run;

%mend ReadSkims;
%ReadSkims
/* end of macro */

data review; set rail61;
  if o<dest;   *** only need one direction of zonal interchange ***;
   proc sort; by o dest;
  proc transpose out=zones prefix=mode; by o dest; var mode;
data zones(drop=_name_); set zones;  
proc export outfile=out1 dbms=csv replace;

run;
