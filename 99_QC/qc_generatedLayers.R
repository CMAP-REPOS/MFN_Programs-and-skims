#Compares output from XXX to previous version
#KCazzato 3/19/2025

library(tidyverse)
library(sf)


#SET PARAMETERS & VARIABLES####
oldDir = "V:/Secure/Master_Freight/working_pro/MFN_currentFY25.gdb"
newDir = "S:/AdminGroups/ResearchAnalysis/kcc/FY25/MFN/Current_copies/Output/MFN_tempFY25.gdb"
MHN_Dir = "V:/Secure/Master_Highway/mhn_c24q4.gdb"    ### Current MHN

years = c(2022, 2030, 2040, 2050, 2060)
layers = c("CMAP_Rail", "National_Rail", "National_Highway","Inland_Waterways", 
           "Crude_Oil_System", "NEC_NG_19_System", "Prod_17_18_System", "CMAP_Rail_nodes", 
           "National_Rail_nodes", "National_Hwy_nodes", "Inland_Waterway_nodes", "Crude_Oil_System_nodes", 
           "NEC_NG_19_nodes","Prod_17_18_nodes", "Meso_Logistic_Nodes", "Meso_Ext_Int_Centroids", 
           "conus_ak", "CMAP_Rail_Routes", "National_Rail_Routes")

#MHN formatting data
in_MHN_hwyproj_coding <- read_sf(dsn = MHN_Dir, layer = "hwyproj_coding", crs = 26771)
in_MHN_hwyproj <- read_sf(dsn = MHN_Dir, layer = "hwyproj", crs = 26771)

#Format MHN Project Information####
TIPIDs <- in_MHN_hwyproj %>% select(TIPID:RSP_ID) %>% st_drop_geometry() %>% filter(COMPLETION_YEAR != 9999)

projCode <- in_MHN_hwyproj_coding %>%
  select(TIPID, ACTION_CODE, ABB) %>%
  left_join(TIPIDs, by = join_by(TIPID)) %>%
  separate(ABB, into = c('INODE', 'JNODE', 'Reverse'), sep = "-") %>%
  mutate(INODE = as.numeric(INODE), JNODE = as.numeric(JNODE), Reverse = as.numeric(Reverse), ACTION_CODE = as.numeric(ACTION_CODE))

t1 <- projCode %>%
  select(-JNODE) %>%
  rename(NODE = INODE)
t2 <- projCode %>%
  select(-INODE) %>%
  rename(NODE = JNODE)

allNodes <- rbind(t1, t2) %>%
  distinct() %>%
  group_by(NODE) %>%
  mutate(count = n(), TIPPROJS = paste(TIPID, sep = ", ")) 

projNodes <- data.frame(NODE = c(unique(projCode$INODE), unique(projCode$JNODE))) %>%
  unique()
#COMPARE STATIC DATA####
for(layer in layers){
  print(layer)
  #Import Data
  in_new <- read_sf(dsn = newDir, layer =layer, crs = 26771) 
  in_old <- read_sf(dsn = oldDir, layer =layer, crs = 26771)
  
  resp = all.equal(in_new, in_old)
  if(resp != TRUE){stop()}
}

#COMPARE ITINERARIES####

##CMAP HIGHWAY YEAR LOOP####
#Create empty final df for data to be bound to
loopNodes <- data.frame(Year = as.numeric(), NODE_ID_T = as.numeric(), MESOZONE = as.integer(), 
                        POINT_X= as.numeric(), POINT_Y= as.numeric(), dfFlag = as.character())
loopLinks <- data.frame(Year = as.numeric(), INODE = as.numeric(), JNODE = as.numeric(), Type = as.numeric(),
                        VDF = as.numeric(), Miles = as.numeric(), Modes = as.character(), LANES = as.numeric(),
                        LANES2 = as.numeric(), Shape_Length = as.numeric(), dfFlag = as.character())
for(year in years){
  print(year)
  #Define Link 
  links = paste("CMAP_HWY_LINK_y", year, sep = "")
  nodes = paste("CMAP_HWY_NODE_y", year, sep = "")
  
  #Import New Data
  in_new_links_cmap <- read_sf(dsn = newDir, layer =links, crs = 26771) 
  in_new_nodes_cmap <- read_sf(dsn = newDir, layer =nodes, crs = 26771)
  
  #Import Old Data
  if(year == 2022){
    links = "CMAP_HWY_LINK_base"
    nodes = "CMAP_HWY_NODE_base"
  }
  in_old_links_cmap <- read_sf(dsn = oldDir, layer =links, crs = 26771) 
  in_old_nodes_cmap <- read_sf(dsn = oldDir, layer =nodes, crs = 26771)
  
  #NODES
  resp = all.equal(in_old_nodes_cmap, in_new_nodes_cmap)
  if(length(resp) != 1){
    print('NODES NOT EQUAL')
    in_old_nodes_cmap <- in_old_nodes_cmap %>% mutate(flagOld = 1) %>% select(NODE_ID_T, MESOZONE, POINT_X, POINT_Y, flagOld, SHAPE)
    in_new_nodes_cmap <- in_new_nodes_cmap %>% mutate(flagNew = 1)%>% select(NODE_ID_T, MESOZONE, POINT_X, POINT_Y, flagNew, SHAPE)
    
    tNodes <- st_join(in_old_nodes_cmap, in_new_nodes_cmap) %>%
      st_drop_geometry() %>%
      mutate(flagOld = ifelse(is.na(flagOld), 0, flagOld),
             flagNew = ifelse(is.na(flagNew), 0, flagNew),
             flags = flagOld + flagNew) %>%
      filter(flags < 2) %>%
      mutate(Year = year,
             MESOZONE = ifelse(is.na(MESOZONE.x), MESOZONE.y, MESOZONE.x),
             NODE_ID_T = ifelse(is.na(NODE_ID_T.x), NODE_ID_T.y, NODE_ID_T.x),
             POINT_X = ifelse(is.na(POINT_X.x), POINT_X.y, POINT_X.x),
             POINT_Y = ifelse(is.na(POINT_Y.x), POINT_Y.y, POINT_Y.x),
             dfFlag = ifelse(is.na(POINT_Y.x), 'new', 'old')
      ) %>%
      select(colnames(loopNodes)) %>%
      distinct()
  
    loopNodes <- loopNodes %>% rbind(tNodes)  
    #
  }else{
    print('NODES ARE EQUAL')
  }
  
  #LINKS
  resp = all.equal(in_new_links_cmap, in_old_links_cmap)
  if(length(resp) != 1){
    print("LINKS NOT EQUAL")
    
    in_old_links_cmap <- in_old_links_cmap %>% mutate(flagOld = 1) %>% select(INODE:Shape_Length, flagOld, SHAPE)
    in_new_links_cmap <- in_new_links_cmap %>% mutate(flagNew = 1)%>% select(INODE:Shape_Length, flagNew, SHAPE)
    
    tLinks <- st_join(in_old_links_cmap, in_new_links_cmap) %>%
      st_drop_geometry() %>%
      mutate(flagOld = ifelse(is.na(flagOld), 0, flagOld),
             flagNew = ifelse(is.na(flagNew), 0, flagNew),
             flags = flagOld + flagNew) %>%
      filter(flags < 2) %>%
      mutate(Year = year,
             INODE = ifelse(is.na(INODE.x), INODE.y, INODE.x),
             JNODE = ifelse(is.na(JNODE.x), JNODE.y, JNODE.x),
             Type = ifelse(is.na(Type.x), Type.y, Type.x),
             VDF = ifelse(is.na(VDF.x), VDF.y, VDF.x),
             Miles = ifelse(is.na(Miles.x), Miles.y, Miles.x),
             Modes = ifelse(is.na(Modes.x), Modes.y, Modes.x),
             LANES = ifelse(is.na(LANES.x), LANES.y, LANES.x),
             LANES2 = ifelse(is.na(LANES2.x), LANES2.y, LANES2.x),
             Shape_Length = ifelse(is.na(Shape_Length.x), Shape_Length.y, Shape_Length.x),
             dfFlag = ifelse(is.na(INODE.x), 'new', 'old')
      ) %>%
      select(colnames(loopLinks)) %>%
      distinct()
    
    loopLinks <- loopLinks %>% rbind(tLinks)

    #
    }else{
    print("LINKS ARE EQUAL")
  }
  
}

#after we have all loopnodes and looplinks, QC range of IDs and then check with TIPIDS