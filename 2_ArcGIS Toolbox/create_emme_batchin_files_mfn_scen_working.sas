/* CREATE_EMME_BATCHIN_FILES_MFN.SAS
   Nick Ferguson, last rev. 12/22/2014 2016 rev.DFR_4/15/2016

-------------                                                             -------------
   THIS PROGRAM CREATES MESO FREIGHT NETWORK AND RAIL ITINERARY BATCHIN FILES.
   IT IS CALLED BY CREATE_EMME_BATCHIN_FILES_MFN.PY.
-------------                                                             -------------
__________________________________________________________________________________________________________________________  */

%let inpath=%scan(&sysparm,1,$);
%let outpath=%scan(&sysparm,2,$);
%let hwyNodeName=%scan(&sysparm,3,$);
%let hwyLinkName=%scan(&sysparm,4,$);

     *** READ IN RAIL HEADER INFORMATION ***;
  proc import datafile="&inpath.\temp_CMAP_Rail_Routes.dbf" out=railroute1 replace; run;
  data rev_railroute1(drop=desc_2 start_node2 end_node2); set railroute1;
      desc_2=rev_desc;
	  start_node2=end_node;
	  end_node2=start_node;
	  desc_=desc_2;
	  start_node=start_node2;
	  end_node=end_node2;
	  run;
  proc import datafile="&inpath.\temp_National_Rail_Routes.dbf" out=railroute2 replace; run;
  data railroute2(drop=tot_t_time); set railroute2; tot_time=tot_t_time;
  data rev_railroute2(drop=desc_2 start_node2 end_node2); set railroute2;
      desc_2=rev_desc;
	  start_node2=end_node;
	  end_node2=start_node;
	  desc_=desc_2;
	  start_node=start_node2;
	  end_node=end_node2;
	  run;

  options varlenchk=nowarn;
  data routes; format headway best9.2; length desc_ $ 10; set railroute1 rev_railroute1 railroute2 rev_railroute2; run;
  options varlenchk=warn;
  proc sort data=routes; by desc_; run;

    *** READ IN RAIL ITINERARY INFORMATION ***;
  proc import datafile="&inpath.\temp_railitin1.dbf" out=railitin1 replace; run;
  proc import datafile="&inpath.\temp_railitin2.dbf" out=railitin2 replace; run; 

  data itins; set railitin1 railitin2; run;
  proc sort data=itins; by desc_ seg_order; run;

       *** READ IN NODE INFORMATION ***;
  proc import datafile="&inpath.\temp_CMAP_Rail_nodes.dbf" out=railnode1 replace; 
  data railnode1(keep=node_id point_x point_y MESOZONE); set railnode1; run;
  proc import datafile="&inpath.\temp_National_Rail_nodes.dbf" out=railnode2 replace; 
  data railnode2(keep=node_id point_x point_y MESOZONE); set railnode2; run;
  proc import datafile="&inpath.\&hwyNodeName." out=hwynode1 replace; 
  data hwynode1(keep=node_id point_x point_y MESOZONE); set hwynode1; run;
  proc import datafile="&inpath.\temp_National_Hwy_nodes.dbf" out=hwynode2 replace; 
  data hwynode2(keep=node_id point_x point_y MESOZONE); set hwynode2; run;
  proc import datafile="&inpath.\temp_Inland_Waterway_nodes.dbf" out=waternode replace; 
  data waternode(keep=node_id point_x point_y MESOZONE); set waternode; run;
  proc import datafile="&inpath.\temp_Meso_Logistic_Nodes.dbf" out=lognode replace; 
  data lognode(keep=node_id point_x point_y MESOZONE); set lognode; node_id=node_id; *node_id=id; *SC edit 2/11/2015; run;
  proc import datafile="&inpath.\temp_Meso_Ext_Int_Centroids.dbf" out=centroid replace; 
  data centroid(keep=node_id point_x point_y MESOZONE); set centroid; node_id=node_id; *node_id=mesozone; *SC edit 2/11/2015; run;
  
  data nodes; format point_x point_y best15.6; set railnode1 railnode2 hwynode1 hwynode2 waternode lognode centroid; run;
  proc sort data=nodes nodupkey; by node_id; run;
  proc sort data=lognode; by node_id; run;
  proc sort data=centroid; by node_id; run;
  data nodes; merge nodes lognode(in=hit); by node_id; if hit then delete; run;
  data nodes; merge nodes centroid(in=hit); by node_id; if hit then delete; run;

  data centroids; format point_x point_y best15.6; set lognode centroid; run;
  proc sort data=centroids; by node_id; run;

      *** READ IN LINK INFORMATION ***;
  proc import datafile="&inpath.\temp_CMAP_Rail.dbf" out=railarc1 replace;
  data railarc1(keep=inode jnode miles modes type lanes vdf); set railarc1;
    output;
    if modes = 'e' then modes = 'a';
    else if modes = 'a' then modes = 'e';
    c=inode; inode=jnode; jnode=c;
	output;
    run;
  proc import datafile="&inpath.\temp_National_Rail.dbf" out=railarc2 replace;
  data railarc2(keep=inode jnode miles modes type lanes vdf); set railarc2;
    output;
    if modes = 'e' then modes = 'a';
    else if modes = 'a' then modes = 'e';
    c=inode; inode=jnode; jnode=c;
	output;
    run;
  proc import datafile="&inpath.\&hwyLinkName." out=hwyarc1 replace;
  data hwyarc1(keep=inode jnode miles modes type lanes vdf); set hwyarc1;
    inode=inode; jnode=jnode; /*inode=anode; jnode=bnode;*/  *SC edit, 02/10/2015;
    output;
    if directions = 2 then do;
	  c=inode; inode=jnode; jnode=c;
	  output;
	  end;
	else if directions = 3 then do;
	  c=inode; inode=jnode; jnode=c; lanes=lanes2;
	  output;
	  end;
    run;
  proc import datafile="&inpath.\temp_National_Highway.dbf" out=hwyarc2 replace;
  data hwyarc2(keep=inode jnode miles modes type lanes vdf); set hwyarc2;
    output;
    c=inode; inode=jnode; jnode=c;
	output;
    run;
  proc import datafile="&inpath.\temp_Inland_Waterways.dbf" out=waterarc replace;
  data waterarc(keep=inode jnode miles modes type lanes vdf); set waterarc;
    output;
    c=inode; inode=jnode; jnode=c;
	output;
    run;

  options varlenchk=nowarn;
  data arcs; set railarc1 railarc2 hwyarc1 hwyarc2 waterarc; run;
  options varlenchk=warn;
  proc sort data=arcs; by inode jnode;

         /* ------------------------------------------------------------------------------ */
                        *** OUTPUT FILES ***;
           filename out1 "&outpath.\lines.in";run;
           filename out2 "&outpath.\base_ntwk.txt";run;
         /* ------------------------------------------------------------------------------ */
   
         * - - - - - - - - - - - - - - - - - *;
              **REPORT ROUTES WITHOUT ITINERARY**;
           data check(keep=desc_); merge itins(in=hit1) routes(in=hit2); by desc_; if hit2 & not hit1;
           proc sort data=check; by desc_;
           data check; set check;
             proc print; var desc_;
             title "No Itinerary: route does not have an itinerary"; run;
 
              **REPORT ITINERARY GAPS**;
           data check; set itins;
           proc sort data=check; by desc_ seg_order;
           data check; set check;
             z=lag(jnode); *z=lag(b_node); *SC edit 2/11/2015; ln=lag(desc_);
             if desc_=ln & inode ne z then output; *if desc_=ln & a_node ne z then output; *SC edit 2/11/2015;
              proc print; var desc_ inode jnode seg_order z; *var desc_ a_node b_node seg_order z; *SC edit 2/11/2015;
               title "Gap in Itinerary: z is jnode of Previous Segment"; *title "Gap in Itinerary: z is b_node of Previous Segment"; *SC edit 2/11/2015; run;
         * - - - - - - - - - - - - - - - - - *;

  proc sort data=routes; by desc_; run;

  data combine; merge itins(in=hit1) routes(in=hit2); by desc_; if hit1 and hit2; proc sort; by desc_ seg_order; run;
  data combine; set combine; by desc_ seg_order;
    if last.desc_ then layover='3'; run;
  
	*** WRITE OUT RAIL ITINERARY BATCHIN FILE ***;
  data combine; set combine; by desc_;
      informat trav_time best9.2;
	  trav_time = round(t_time,.01);
      name="'"||compress(desc_)||"'";
      desc="'"||compress(desc_)||"'";

	 file out1;
     if _n_=1 then put "c MESO FREIGHT RAIL ITINERARY BATCHIN FILE" /
          "c &sysdate" / "c us1 holds segment travel time, us2 holds zone fare" / "t lines init";
     if first.desc_ then put 'a' +1 name +2 mode +2 vehicle +2 headway +2 speed
           +2 desc_ / +2 'path=no';
 	 if last.desc_ then put +4 'dwt=0.01' +3 inode +2 'ttf=10' +3 'us1=' +0 trav_time +(6-length(left(trim(trav_time)))) 'us2=' +0 '0' / +15 jnode +2 'lay=' +0 layover;
     else if (layover ne '0' and layover ne '') then put +4 'dwt=0.01' +3 inode +2 'ttf=10' +3 'us1=' +0 trav_time +(6-length(left(trim(trav_time)))) 'us2=' +0 '0' +2 'lay=' +0 layover;
     else put +4 'dwt=0.01' +3 inode +2 'ttf=10' +3 'us1=' +0 trav_time +(6-length(left(trim(trav_time)))) 'us2=' +0 '0';
	 run;
	 /*if last.desc_ then put +4 'dwt=0.01' +3 a_node +2 'ttf=10' +3 'us1=' +0 trav_time +(6-length(left(trim(trav_time)))) 'us2=' +0 '0' / +15 b_node +2 'lay=' +0 layover;
     else if (layover ne '0' and layover ne '') then put +4 'dwt=0.01' +3 a_node +2 'ttf=10' +3 'us1=' +0 trav_time +(6-length(left(trim(trav_time)))) 'us2=' +0 '0' +2 'lay=' +0 layover;
     else put +4 'dwt=0.01' +3 a_node +2 'ttf=10' +3 'us1=' +0 trav_time +(6-length(left(trim(trav_time)))) 'us2=' +0 '0';
	 run;*/ *SC edit 2/11/2015

      * - - - - - - - - - - - - - - - - - - - - - - - - - - *;
             **VERIFY THAT EACH LINK HAS A LENGTH**;
        data check; set arcs(where=(miles=0));
           proc print; title "MESO FREIGHT NETWORK LINKS WITHOUT A CODED LENGTH";run;

             **VERIFY THAT EACH LINK HAS A MODE**;
        data check; set arcs(where=(modes is null));
           proc print; title "MESO FREIGHT NETWORK LINKS WITHOUT A CODED MODE";*/
       * - - - - - - - - - - - - - - - - - - - - - - - - - - *;

  data arcs; set arcs;
   informat miles1 best9.2;
   miles1 = round(miles,.01);
   run;

      * - - - - - - - - - - - - - - - - - - - - - - - - - - *;
          **VERIFY THAT EACH NODE HAS COORDINATES**;
          data check; set nodes; if point_x='.' or point_y='.';
           proc print; title "MESO FREIGHT NETWORK NODES WITH NO COORDINATES";run;
		   **VERIFY THAT EACH CENTROID HAS COORDINATES**;
          data check; set centroids; if point_x='.' or point_y='.';
           proc print; title "MESO FREIGHT NETWORK CENTROIDS WITH NO COORDINATES";run;

          **VERIFY THAT EACH NODE HAS A UNIQUE NUMBER**;
           proc freq data=nodes; tables node_id / noprint out=check;
          data check; set check(where=(count>1));
           proc print noobs; var node_id count;
           title "MESO FREIGHT NETWORK NODES WITH DUPLICATE NUMBERS";run;
		   **VERIFY THAT EACH CENTROID HAS A UNIQUE NUMBER**;
           proc freq data=centroids; tables node_id / noprint out=check;
          data check; set check(where=(count>1));
           proc print noobs; var node_id count;
           title "MESO FREIGHT NETWORK CENTROIDS WITH DUPLICATE NUMBERS";run;
       * - - - - - - - - - - - - - - - - - - - - - - - - - - *;

      *** WRITE OUT NETWORK BATCHIN FILE ***;
  data _null_; set centroids;
    file out2;
    if _n_= 1 then put "c MESO FREIGHT NETWORK BATCHIN FILE" /
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
