/* CREATE_EMME_BATCHIN_FILES_MFN_COS.SAS  (Jenner compatibility bundle)
   Nick Ferguson, last rev. 5/15/2017 edits dfr 2PM

-------------                                                             -------------
   THIS PROGRAM CREATES MESO FREIGHT NETWORK BATCHIN FILES FOR THE CRUDE OIL SYSTEM ONLY.
   IT IS CALLED BY CREATE_EMME_BATCHIN_FILES_MFN_COS.PY.
-------------                                                             -------------

   Adapted for self-contained execution: the two ArcGIS-exported .dbf inputs
   (Crude_Oil_System_nodes, Meso_Ext_Int_Centroids, Crude_Oil_System) are
   replaced by small inline DATA steps carrying the same columns the program
   keeps (node_id point_x point_y MESOZONE for nodes/centroids; inode jnode
   miles modes type lanes vdf for links). The verification logic, sorts,
   PROC FREQ duplicate checks and the batchin PUT statements are unchanged.
__________________________________________________________________________________________________________________________  */

       *** READ IN NODE INFORMATION ***;
  data cosnode(keep=node_id point_x point_y MESOZONE);
    input node_id point_x point_y MESOZONE;
    datalines;
101 1024510.5 1899430.2 11
102 1031220.0 1902880.7 11
103 1044870.3 1910120.9 12
104 1058990.1 1921550.4 12
105 1071230.8 1933470.6 13
106 1088410.2 1948990.1 13
107 1102560.7 1960220.5 14
108 1119880.4 1975510.0 14
;
  run;

  data centroid(keep=node_id point_x point_y MESOZONE);
    input node_id point_x point_y MESOZONE;
    datalines;
1 990120.4 1850330.7 1
2 1003450.9 1862910.2 2
3 1015770.6 1875640.8 3
;
  run;

  data nodes; format point_x point_y best15.6; set cosnode centroid; run;
  proc sort data=nodes nodupkey; by node_id; run;
  proc sort data=centroid; by node_id; run;
  data nodes; merge nodes centroid(in=hit); by node_id; if hit then delete; run;

  data centroids; format point_x point_y best15.6; set centroid; run;
  proc sort data=centroids; by node_id; run;

      *** READ IN LINK INFORMATION ***;
  data cosarc(keep=inode jnode miles modes type lanes vdf);
    length modes $ 4;
    input inode jnode miles modes $ type lanes vdf;
    output;
    c=inode; inode=jnode; jnode=c;
    output;
    datalines;
101 102 0.84 c 1 2 1
102 103 1.12 c 1 2 1
103 104 1.55 c 1 2 1
104 105 1.31 c 1 2 1
105 106 1.78 c 1 2 1
106 107 1.02 c 1 2 1
107 108 1.46 c 1 2 1
;
  run;

  options varlenchk=nowarn;
  data arcs; set cosarc; run;
  options varlenchk=warn;
  proc sort data=arcs; by inode jnode;

         /* ------------------------------------------------------------------------------ */
                        *** OUTPUT FILES ***;
           filename out2 "cos_ntwk.txt";run;
         /* ------------------------------------------------------------------------------ */

      * - - - - - - - - - - - - - - - - - - - - - - - - - - *;
             **VERIFY THAT EACH LINK HAS A LENGTH**;
        data check; set arcs(where=(miles=0));
           proc print; title "CRUDE OIL SYSTEM NETWORK LINKS WITHOUT A CODED LENGTH";run;

             **VERIFY THAT EACH LINK HAS A MODE**;
        data check; set arcs(where=(modes is missing));   /* SAS-equivalent of the original "is null" */
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
    if _n_= 1 then put "c CRUDE OIL SYSTEM NETWORK BATCHIN FILE" /
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
