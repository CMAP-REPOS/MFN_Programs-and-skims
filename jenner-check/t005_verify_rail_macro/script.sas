/* VERIFY_RAIL_SERVICE.SAS  (Jenner compatibility bundle)
      Craig Heither, 06-14-2016

	This program reads the distance and in-vehicle times skims for each rail carrier to ensure no connector-to-connector paths are
	being used.

	Adapted for self-contained execution: the macro %ReadSkims is kept verbatim --
	a %do %while loop that, for each carrier, reads the Emme distance and in-vehicle
	time skim dumps via INFILE (missover, dlm=' :', firstobs=5), explodes the wide
	o/dest/value rows into long form, sorts nodupkey, MERGEs distance with time, and
	flags zero-skim pairs. The bundled mf61.in / mf62.in are small Emme matrix dumps
	in the same format the program reads. The output is written to a relative path;
	the call system() that created the QC directory in production is not needed here.
*/
*################################################################################################;

filename out1 "zone_connections.csv";

*###=================================================================================###
    -- EMME SKIM MATRIX DUMPS (wide o / dest:value rows, as the .in files hold) --
*###=================================================================================###;
  *##-- mf61: rail carrier distance --##;
data mf61_raw;
  input o d1 v1 d2 v2 d3 v3;
  datalines;
1 2 14.5 3 22.1 4 0
2 1 14.5 3 9.8 4 18.2
3 1 22.1 2 9.8 4 7.4
4 1 0 2 18.2 3 7.4
;
run;
  *##-- mf62: rail carrier in-vehicle time --##;
data mf62_raw;
  input o d1 v1 d2 v2 d3 v3;
  datalines;
1 2 31.0 3 47.5 4 0
2 1 31.0 3 20.4 4 39.1
3 1 47.5 2 20.4 4 15.8
4 1 0 2 39.1 3 15.8
;
run;

*###=================================================================================###
    -- PROCESS EMME SKIMS --
*###=================================================================================###;
%let i=61; %let j=62;
%macro ReadSkims;

   %do %while (&i le 63);
	 run;
      data dist&i(keep=o dest dist); set mf&i._raw;
		  dest=d1; dist=v1; output;
		  dest=d2; dist=v2; output;
		  dest=d3; dist=v3; output;
		  proc sort nodupkey; by o dest;
	  data dist&i; set dist&i(where=(o>0 & dest>0)); run;

      data ivtt&j(keep=o dest ivtt); set mf&j._raw;
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
proc export data=zones outfile="zone_connections.csv" dbms=csv replace;

run;
