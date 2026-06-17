/* STEP4_CREATE_ZONAL_TRUCK_TOUR_FILES.SAS  (Jenner compatibility bundle: zonal employment slice)
      Craig Heither, rev. 05-06-2016

   This program creates the CMAP zonal files used in the truck touring model.

   Adapted for self-contained execution: this bundle keeps the zonal-employment
   slice of Step 4 verbatim -- read the conformity subzone employment file and
   the subzone-zone-mesozone correspondence file, sort and MERGE them on
   subzone09, then PROC SUMMARY NWAY with CLASS Zone / VAR i18 / ID Mesozone to
   roll subzone employment up to zonal totals, and export the result. The
   bundled inputs are small CSVs with the same columns the program reads
   (subzone09/i18 for employment; subzone09/zone09/mesozone for the
   correspondence). The skim-file sections that read Emme matrix dumps via INFILE
   are outside this slice and are omitted.
*/

*###=================================================================================###
    PROVIDE ZONAL EMPLOYMENT FOR FIRM LOCATIONS
*###=================================================================================###;
  *##-- subzone total employment --##;
data szemp;
  input subzone09 i18;
  datalines;
1001 420
1002 135
1003 610
2001 288
2002 90
3001 512
3002 77
3003 203
;
run;
proc sort data=szemp; by subzone09; run;

  *##-- subzone-zone-mesozone correspondence file --##;
data corresp;
  input subzone09 zone09 mesozone;
  datalines;
1001 10 101
1002 10 101
1003 11 101
2001 20 102
2002 20 102
3001 30 103
3002 31 103
3003 31 103
;
run;
proc sort data=corresp; by subzone09; run;

data szemp(rename=(zone09=Zone mesozone=Mesozone)); merge szemp corresp; by subzone09;
  proc summary nway; class Zone; var i18; id Mesozone; output out=z sum=totalemp;

data z(drop=_type_ _freq_); set z;
proc export data=z outfile="cmap_data_zone_employment.csv" dbms=csv replace;

run;
