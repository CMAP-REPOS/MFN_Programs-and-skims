/* CREATE_EMME_BATCHIN_FILES_MFN_COS.SAS
   Nick Ferguson, last rev. 5/15/2017 edits dfr 2PM

-------------                                                             -------------
   THIS PROGRAM CREATES MESO FREIGHT NETWORK BATCHIN FILES FOR THE CRUDE OIL SYSTEM ONLY.
   IT IS CALLED BY CREATE_EMME_BATCHIN_FILES_MFN_COS.PY.
-------------                                                             -------------
__________________________________________________________________________________________________________________________  */

%let inpath=%scan(&sysparm,1,$);
%let outpath=%scan(&sysparm,2,$);

       *** READ IN NODE INFORMATION ***;
  proc import datafile="&inpath.\Temp\temp_cosnode.dbf" out=cosnode replace; 
  data cosnode(keep=node_id point_x point_y MESOZONE); set cosnode; run;
  proc import datafile="&inpath.\Temp\temp_centroid.dbf" out=centroid replace; 
  data centroid(keep=node_id point_x point_y MESOZONE); set centroid; node_id=node_id; *node_id=mesozone; *SC edit 2/11/2015; run;
  
  data nodes; format point_x point_y best15.6; set cosnode centroid; run;
  proc sort data=nodes nodupkey; by node_id; run;
  proc sort data=centroid; by node_id; run;
  data nodes; merge nodes centroid(in=hit); by node_id; if hit then delete; run;
  
  data centroids; format point_x point_y best15.6; set centroid; run;
  proc sort data=centroids; by node_id; run;

      *** READ IN LINK INFORMATION ***;
  proc import datafile="&inpath.\Temp\temp_cosarc.dbf" out=cosarc replace;
  data cosarc(keep=inode jnode miles modes type lanes vdf); set cosarc;
    output;
    c=inode; inode=jnode; jnode=c;
	output;
    run;

  options varlenchk=nowarn;
  data arcs; set cosarc; run;
  options varlenchk=warn;
  proc sort data=arcs; by inode jnode;

         /* ------------------------------------------------------------------------------ */
                        *** OUTPUT FILES ***;
           filename out2 "&outpath.\batchin\p1718_ntwk.txt";run;
         /* ------------------------------------------------------------------------------ */

      * - - - - - - - - - - - - - - - - - - - - - - - - - - *;
             **VERIFY THAT EACH LINK HAS A LENGTH**;
        data check; set arcs(where=(miles=0));
           proc print; title "CRUDE OIL SYSTEM NETWORK LINKS WITHOUT A CODED LENGTH";run;

             **VERIFY THAT EACH LINK HAS A MODE**;
        data check; set arcs(where=(modes is null));
           proc print; title "CRUDE OIL SYSTEM NETWORK LINKS WITHOUT A CODED MODE";
       * - - - - - - - - - - - - - - - - - - - - - - - - - - *;

  data arcs; set arcs;
   informat miles1 best9.2;
   miles1 = round(miles,.01);
   run;

      * - - - - - - - - - - - - - - - - - - - - - - - - - - *;
          **VERIFY THAT EACH NODE HAS COORDINATES**;
          data check; set nodes; if point_x='.' or point_y='.';
           proc print; title "CRUDE OIL SYSTEM NETWORK NODES WITH NO COORDINATES";run;
          **VERIFY THAT EACH CENTROID HAS COORDINATES**;
          data check; set centroids; if point_x='.' or point_y='.';
           proc print; title "MESO FREIGHT NETWORK CENTROIDS WITH NO COORDINATES";run;

          **VERIFY THAT EACH NODE HAS A UNIQUE NUMBER**;
           proc freq data=nodes; tables node_id / noprint out=check;
          data check; set check(where=(count>1));
           proc print noobs; var node_id count;
           title "CRUDE OIL SYSTEM NETWORK NODES WITH DUPLICATE NUMBERS";run;
          **VERIFY THAT EACH CENTROID HAS A UNIQUE NUMBER**;
           proc freq data=centroids; tables node_id / noprint out=check;
          data check; set check(where=(count>1));
           proc print noobs; var node_id count;
           title "MESO FREIGHT NETWORK CENTROIDS WITH DUPLICATE NUMBERS";run;
       * - - - - - - - - - - - - - - - - - - - - - - - - - - *;

      *** WRITE OUT COS NETWORK BATCHIN FILE ***;
  data _null_; set centroids;
    file out2;
    if _n_= 1 then put "c PRODUCT_17_18 NETWORK BATCHIN FILE" /
         "c &sysdate" /  'c node   x   y   UI1' / 't nodes init';
    put 'a*' +2 node_id +2 point_x +2 point_y +2 MESOZONE;
    run;
    
  data _null_; set nodes;
    file out2 mod;
    put 'a' +3 node_id +2 point_x +2 point_y +2 MESOZONE;
    run;
  
  data _null_; set arcs;
    file out2 mod;
    if _n_= 1 then put  'c i   j   mi   modes   type   lanes   vdf   ul1   ul2   ul3' / 't links init';
    put 'a' +3 inode +2 jnode +2 miles1 +2 modes +2 type +2 lanes +2 vdf +2 '0   0   0';
    run;
