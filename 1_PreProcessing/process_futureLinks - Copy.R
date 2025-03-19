#KCC
#script to read MHN future network coding and produce future MFN networks

#--SET KEY PARAMETERS--####
inputDir = "V:/Secure/Master_Highway/mhn_c24q4.gdb"    ### Current MHN
outputDir = "S:/AdminGroups/ResearchAnalysis/kcc/FY25/MFN/Current_copies/Output/MFN_currentFY25.gdb"   ### Current MFN
outPath = "../../Output"

#--SETUP--
library(scales)
#library(plotrix)
library(tidyverse)
library(sf)
library(openxlsx)
library(sfheaders)
library(sp)
library(geosphere)

#--DEFINE NODES for QC
qc_centroidsCMAP <- data.frame(NODE_ID = c(1:132))                   ### 1-132 CMAP Centroids
qc_logisticCMAP <- data.frame(NODE_ID =c(133:150))                   ### 133-150 CMAP Logistic Nodes
qc_centroidsNational <- data.frame(NODE_ID = c(151:273, 310, 399))   ### 150-399 National Centroids
qc_poe <- data.frame(NODE_ID = c(3634, 3636, 3639, 3640, 3641, 3642, 3643, 3644, 3647, 3648))  ### 3634-3648 CMAP POE Nodes

#--READ DATA--####
#MHN formatting data
in_MHN_hwyproj_coding <- read_sf(dsn = inputDir, layer = "hwyproj_coding", crs = 26771)
in_MHN_hwynet_arc <- read_sf(dsn = inputDir, layer = "hwynet_arc", crs = 26771)
in_MHN_hwyproj <- read_sf(dsn = inputDir, layer = "hwyproj", crs = 26771)
in_MHN_hwynodes <- read_sf(dsn = inputDir, layer = "hwynet_node", crs = 26771) %>%
  rename(node = NODE, X = POINT_X, Y = POINT_Y) %>%
  select(node, X, Y) %>%
  mutate(NODE_ID = as.numeric(node))

#MFN formatting data
in_logisticNodes <- read_sf(dsn = outputDir, layer ="Meso_Logistic_Nodes", crs = 26771) %>% select(MESOZONE, POINT_X, POINT_Y, NODE_ID_T, SHAPE) %>% rename(NODE_ID = NODE_ID_T, Shape = SHAPE)
in_centroids <- read_sf(dsn = outputDir, layer ="Meso_Ext_Int_Centroids", crs = 26771) %>% select(MESOZONE, NODE_ID_T, POINT_X, POINT_Y, SHAPE) %>%rename(NODE_ID = NODE_ID_T)
in_mesozoneGeo<- read_sf(dsn = outputDir, layer ="Meso_External_CMAP_merge", crs = 26771)%>% select(MESOZONE, Shape)
in_Rail<- read_sf(dsn = outputDir, layer ="CMAP_Rail", crs = 26771)

#For links not flagged as base MESO in MHN but should be (to fix w/Tim at a later time)
in_forceMESO <- read.xlsx("../../Input/new_MHN_MESO-LINKS.xlsx", sheet = "base_MESO")
in_removeMESO <- read.xlsx("../../Input/removeLinks.xlsx")
#--FORMAT DATA--####
#Important Nodes####
#work to ensure all centroids and logistic nodes are properly included
#CMAP Centroids
centroidsCMAP <- in_centroids %>% 
  filter(NODE_ID <= 132) %>% 
  mutate(flag = "CMAP centroid") %>%
  rename(Shape = SHAPE) %>%
  select(NODE_ID, MESOZONE:POINT_Y, flag, Shape)   

#CMAP Logistic Nodes
logisticCMAP <- in_logisticNodes %>% 
  filter(NODE_ID >= 133 & NODE_ID <= 150)  %>% 
  mutate(flag = "CMAP logistic") %>%
  select(NODE_ID, MESOZONE:POINT_Y, flag, Shape)       

#QC CHECK input centroid and logistic node files have all the expected node IDs
qc_coreNodes = list(centroidsCMAP, logisticCMAP)
qc_coreNodesMatch = list(qc_centroidsCMAP, qc_logisticCMAP)

outFile <- file(paste(outPath, "/QC/specialNodes.txt", sep = ""))
sink(outFile, append = FALSE)
i = 1
for(df in qc_coreNodes){
  qcFile = as.data.frame(qc_coreNodesMatch[1]) 
  checkDF <- centroidsCMAP %>%
    filter(!(NODE_ID %in% qcFile$NODE_ID))
  print(nrow(checkDF))
  i = i+1
}
sink()

#Combine 
specialNodes <- st_as_sf(rbind(centroidsCMAP, logisticCMAP)) %>%
  st_cast("MULTIPOINT")  %>%
  rename(centroidX = POINT_X, centroidY = POINT_Y, specialID = NODE_ID)

#ID rail node140
rail140 <- in_Rail %>%
  st_drop_geometry() %>%
  filter(INODE_T == 140 | JNODE_T == 140)
#Format Base MHN####
manualRemove <- in_removeMESO %>% mutate(linkID = paste(INODE, JNODE, sep = "-"))
#Identify changes in links for all years
changes_MHN <- in_MHN_hwyproj_coding %>%
  mutate(NEW_THRULANES1 = ifelse(NEW_THRULANES1 == 0, NA, NEW_THRULANES1),    #if 0 then no change to _arc attributes, make NA to populate with current attribute later                           
         NEW_THRULANES2 = ifelse(NEW_THRULANES2 == 0, NA, NEW_THRULANES2),
         NEW_TYPE1 = ifelse(as.numeric(NEW_TYPE1) == 0, NA, as.numeric(NEW_TYPE1)),
         NEW_DIRECTIONS = ifelse(as.numeric(NEW_DIRECTIONS) == 0, NA, as.numeric(NEW_DIRECTIONS))) 

#MHN base meso links
base_MHN_MESO <- in_MHN_hwynet_arc %>%
  full_join(changes_MHN, by = "ABB") %>%                                                             #add new attributes to base MESO
  mutate(MESO = ifelse(ABB %in% in_forceMESO$LINK_ABB, 1, MESO),                                     #force MESO flag for list of additional links
         THRULANES1 = ifelse(!is.na(NEW_THRULANES1), NEW_THRULANES1, THRULANES1),
         THRULANES2 = ifelse(!is.na(NEW_THRULANES2), NEW_THRULANES2, THRULANES2),
         type = ifelse(!is.na(NEW_TYPE1), NEW_TYPE1, as.numeric(TYPE1)),
         DIRECTIONS = ifelse(!is.na(NEW_DIRECTIONS), NEW_DIRECTIONS, as.numeric(DIRECTIONS)),
         MESO = ifelse((ANODE %in% qc_poe$NODE_ID) | (BNODE %in% qc_poe$NODE_ID), 1, MESO)) %>%      #flag POE to keep in list
  filter(MESO == 1) %>%
  mutate(linkID = paste(ANODE, BNODE, sep = "-")) %>%
  distinct() %>%
  mutate(flag = "baseMESO", vdf = 10, Modes = "T", MESO = 1, flag = "base", typeMHN = type)%>%
  select(flag, linkID, ANODE, BNODE, DIRECTIONS, MESO, ACTION_CODE,
         type, typeMHN, vdf, MILES, Modes, THRULANES1, THRULANES2, SHAPE_Length, SHAPE) 

#MHN base meso nodes
base_MHN_MESO_nodes <- base_MHN_MESO %>%
  separate(linkID, sep = "-", into = c("ANODE", "BNODE")) %>%
  pivot_longer(cols = ANODE:BNODE, values_to = "nodes") %>%
  mutate(flag = "baseMESO") %>%
  select(nodes, flag) %>%
  distinct()

#--SELECT ADDITIONAL FUTURE YEAR MESO LINKS--####
#--DEPENDING ON ACTION CODE, ENSURE FUTURE LINKS FROM PROJECT HAVE ACCURATE MESO FLAG VALUE
#1=modify link
#2=replace link
#3=delete link
#4=add link
#years = list(2030)
#yr = 2030
#years = list(2022, 2025, 2030, 2035, 2040, 2050, 2060)
years = list(2022, 2030, 2040, 2050, 2060)
for(yr in years){
  #Set year
  if(yr == 2060){
    year = 2050
  }else{
    year = yr
  }
  
  #1. GENERATE LINKS FROM MHN####
  #Select tip projects completed by this year####
  tipIDS <- in_MHN_hwyproj %>% 
    filter(COMPLETION_YEAR != 9999) %>%                                    #remove projects no longer active
    filter(TIPID != "2080005") %>%                                         #remove LSD project since no access
    filter(TIPID != "9110006") %>%                                         #remove project; random link giving me issues
    mutate(COMPLETION_YEAR = as.numeric(COMPLETION_YEAR)) %>%
    st_drop_geometry() %>%                                                 #remove geometry
    filter(COMPLETION_YEAR <= year)                                        #--SELECT ALL PROJECTS AND LINKids FROM HWYPROJ FOR YEAR
  #--Format MHN tip projects into an sf df####
  mhn_links <- tipIDS %>%
    left_join(changes_MHN, by = "TIPID") %>%                               #--JOIN HWYPROJ_CODING FOR SELECTED LINKids
    st_drop_geometry() %>%
    left_join(in_MHN_hwynet_arc, by = "ABB") %>%                           #--JOIN HWYNET_ARC FOR SELECTED LINKids
    mutate(vdf = 10, Modes = "T", MESO = 1, flag = "tipProj",
           typeMHN = as.numeric(TYPE1), DIRECTIONS = as.numeric(DIRECTIONS),
           THRULANES1 = ifelse(THRULANES1 == 0, NEW_THRULANES1, THRULANES1),
           THRULANES2 = ifelse(BASELINK == 0, NEW_THRULANES2, THRULANES2),
           type = ifelse(typeMHN == 0, NEW_TYPE1, typeMHN)) %>%
    select(flag, TIPID, COMPLETION_YEAR, ACTION_CODE, ABB, ANODE, BNODE, DIRECTIONS, MESO, type, typeMHN, vdf, MILES, Modes, THRULANES1, THRULANES2, SHAPE_Length, SHAPE) %>%
    separate(ABB, into = c("ANODE", "BNODE", "del"), sep = "-") %>%
    mutate(MESO = ifelse(MESO == 0, NA, MESO),
           yesA = ifelse(ANODE %in% base_MHN_MESO_nodes$nodes == TRUE, 1, 0),
           yesB = ifelse(BNODE %in% base_MHN_MESO_nodes$nodes == TRUE, 1, 0)) %>%
    group_by(TIPID) %>%
    fill(MESO, .direction = "updown") %>%
    ungroup() %>%
    mutate(MESO = ifelse(is.na(MESO), 0, MESO)) %>%
    mutate(allFlags = MESO+yesA+yesB) %>%
    mutate(allFlags = ifelse(allFlags == 0, NA, allFlags)) %>%
    group_by(TIPID) %>%
    fill(allFlags, .direction = "updown") %>%
    ungroup() %>%
    filter(allFlags > 0)%>%
    mutate(linkID = paste(ANODE, BNODE, sep = "-"))  %>%
    select(flag, linkID, ANODE, BNODE, DIRECTIONS, MESO, ACTION_CODE, type, typeMHN, vdf, MILES, Modes, THRULANES1, THRULANES2, SHAPE_Length, SHAPE)
  
  #--Create df of links to be removed####
  removeBaseMeso <- mhn_links %>%
    filter(ACTION_CODE == 3)  %>%
    select(linkID) 

  #2. FORMAT With Base MESO####
  #Format MFN Links1####
  futureLinks_baseT <- mhn_links %>%               #MHN future links
    mutate(timau = NA) %>%
    select(colnames(base_MHN_MESO)) %>%            #Join with base MESO links
    rbind(base_MHN_MESO) %>%
    select(-ACTION_CODE) %>%
    group_by(linkID) %>%
    fill(THRULANES1, .direction = "updown") %>%   #Fill attributes
    fill(THRULANES2, .direction = "updown") %>%
    fill(type, .direction = "updown") %>%
    distinct() %>%
    ungroup() %>%
    filter(!(linkID %in% removeBaseMeso)) %>%     #remove if link is to be removed by MHN coding
    rename(Length = SHAPE_Length, INODE = ANODE, JNODE = BNODE, Miles = MILES, lanes = THRULANES1, lanes2 = THRULANES2) %>%
    mutate(INODE = as.numeric(INODE), JNODE = as.numeric(JNODE)) %>%
    group_by(linkID) %>%
    mutate(count = n()) %>%
    ungroup() %>%
    mutate(#DIRECTIONS = ifelse(DIRECTIONS == 3, 2, DIRECTIONS),
           DIRECTIONS = ifelse(count>1 & flag == "base", NA, DIRECTIONS)) %>%
    group_by(linkID) %>%
    fill(DIRECTIONS, .direction = "updown") %>%
    ungroup() %>%
    filter(!(linkID %in% manualRemove$linkID))
  
  tempNodes2 <- futureLinks_baseT %>%
    st_drop_geometry() %>%
    select(INODE, JNODE) %>%
    pivot_longer(cols = INODE:JNODE, names_to = "type", values_to = "NODE_ID") %>%
    select(NODE_ID) %>%
    group_by(NODE_ID) %>%
    mutate(count = n())
  
  
  #Format MFN Nodes1####
  #Identify potential nodes for connectors to attach to
  #from link, filter DIRECTIONS == 2 & TYPEMHN == 1
  tempNodes1 <- futureLinks_baseT %>%
    st_drop_geometry() %>%
    filter(DIRECTIONS == 2) %>%
    filter(typeMHN == 1) %>%
    select(INODE, JNODE) %>%
    pivot_longer(cols = INODE:JNODE, names_to = "type", values_to = "NODE_ID") %>%
    select(NODE_ID) %>%
    group_by(NODE_ID) %>%
    unique() %>%
    ungroup() %>%
    arrange(NODE_ID) %>%
    mutate(MHN_ID = as.numeric(NODE_ID))
  
  base_nodes <- tempNodes1 %>%
    left_join(in_MHN_hwynodes, by = "NODE_ID") %>%
    select(MHN_ID, X, Y, Shape) %>%
    rename(POINT_X = X, POINT_Y = Y)
  
  base_nodes_pt <- base_nodes %>% st_drop_geometry()
  
  
  
  #Attach special nodes to base nodes and find distance####
  temp_dist1 <- specialNodes %>%
    cross_join(base_nodes_pt) %>%
    mutate(distance = sqrt(((centroidX - POINT_X)^2) + ((centroidY - POINT_Y)^2))) 
  
  #Identify duplicate MHN nodes and MFN special nodes####
  #if any within XXX distance, remove and use centroid
  duplicateNodes <- temp_dist1 %>% filter(distance <= 0.001)     
  
  #Develop special links#### 
  connectors <- temp_dist1 %>%
    filter(!(MHN_ID %in% duplicateNodes$MHN_ID)) %>%
    group_by(specialID) %>%
    filter(distance == min(distance))%>%
    ungroup() %>%
    mutate(lineID = specialID,
           lineID2 = MHN_ID) %>%
    select(lineID, lineID2, POINT_X, POINT_Y, centroidX, centroidY) %>%
    pivot_longer(cols = c(POINT_X, centroidX), names_to = "type", values_to = "coordX") %>%
    pivot_longer(cols = c(POINT_Y, centroidY), names_to = "typeY", values_to = "coordY") %>%
    mutate(retain_c = ifelse(type == "centroidX" & typeY == "centroidY", 1, 0),
           retain_n = ifelse(type == "POINT_X" & typeY == "POINT_Y", 1, 0)) %>%
    filter(retain_c == 1 | retain_n == 1) %>%
    select(lineID, lineID2, coordX, coordY) %>%
    distinct()
  
  connectors = st_as_sf(connectors, coords = c("coordX", "coordY"), crs = 26771) #crs = 26771 this is the projection to be used for all shape files
  
  allConnectors_f <- st_as_sf(connectors, wkt = geometry) %>% 
    group_by(lineID, lineID2) %>%
    summarise(do_union = FALSE) %>%
    st_cast("MULTILINESTRING") %>%
    rename(specialID = lineID, NODE_ID = lineID2) %>%
    left_join(st_drop_geometry(specialNodes), by = ("specialID")) %>%
    mutate(linkID = paste(specialID, NODE_ID, sep = "-"),
           INODE= specialID, JNODE = NODE_ID, 
           Length = st_length(geometry),
           DIRECTIONS = 2, MESO = 1, type = 4, TYPE2 = "0", vdf = 10, POSTEDSPEED1 = 0, POSTEDSPEED2 = 0, Miles = Length/5280, Modes = "T",
           lanes = 2, lanes2 = 2, timau = NA) %>%
    rename(SHAPE = geometry) %>%
    mutate(count = NA, typeMHN = NA) %>%
    select(colnames(futureLinks_baseT))
  
  #ADD Special Links TO BASE####
  finalLinks1 <- futureLinks_baseT %>% 
    filter(!(INODE %in% duplicateNodes$MHN_ID)) %>%         #remove links associated with duplicate nodes first
    filter(!(JNODE %in% duplicateNodes$MHN_ID)) %>%
    rbind(allConnectors_f) %>%
    st_as_sf() %>% 
    st_cast("MULTILINESTRING") %>%
    select(linkID:type, vdf, Miles:lanes2, SHAPE) %>%
    mutate(type = as.numeric(type),
           lanes = ifelse(lanes < 2, 2, lanes),
           lanes2 = ifelse(lanes2 == 0 | is.na(lanes2), lanes, lanes2)) %>%
    filter(!is.na(type)) %>%
    filter(!is.na(lanes)) %>%
    distinct() %>%
    mutate(lanes = ifelse(INODE <= 150, 1, lanes),
           lanes2 = ifelse(INODE <= 150, 1, lanes2),
      #     DIRECTIONS = case_when(
      #       INODE > 5000 & (lanes == lanes2 & lanes == 1) ~ 1,
      #       INODE > 5000 & (lanes == lanes2 & lanes == 2) ~ 2,
      #       .default = DIRECTIONS
      #     )
  ) %>%
    rename(Type = type, VDF = vdf, LANES = lanes, LANES2 = lanes2)%>%
    select(DIRECTIONS, Type, VDF, 
           INODE, JNODE, Miles, Modes, LANES, LANES2) %>%
    mutate(MESOZONE = 1)
  
  #3. FINALIZE####
  #--Format final MFN link fields####
  finalLinks <- finalLinks1 %>% 
    distinct() %>%
    mutate(Meso = 1, 
           Type = case_when(
             INODE < 133 ~ 4,
             INODE >= 133 & INODE <=150 ~ 7,
             INODE > 150 ~ 1
           ),
        #   DIRECTIONS = ifelse(INODE <= 1999, 2, DIRECTIONS),
        #   DIRECTIONS = ifelse(INODE %in% qc_poe$NODE_ID, 2, DIRECTIONS),
           Shape_Length = st_length(SHAPE)
           ) %>%
    select(INODE, JNODE, Meso, DIRECTIONS:LANES2, SHAPE, Shape_Length) %>%
    mutate(DIRECTIONS = as.character(DIRECTIONS)) %>%
    group_by(INODE, JNODE) %>%
    mutate(count = n()) %>%
    filter(count == 1 | row_number() == 1) %>%
    group_by(INODE, JNODE) %>%
    mutate(count = n())
  
  qc_final <- finalLinks %>%
    group_by(INODE) %>%
    mutate(Icount = n()) %>%
    group_by(JNODE) %>%
    mutate(Jcount = n())

  #--Format final MFN node fields####
  finalNodes <- finalLinks %>%
    st_drop_geometry() %>%
    select(INODE, JNODE) %>%
    pivot_longer(cols = INODE:JNODE, names_to = "type", values_to = "NODE_ID") %>%
    select(NODE_ID) %>%
    group_by(NODE_ID) %>%
    unique() %>%
    ungroup() %>%
    arrange(NODE_ID) %>%
    mutate(NODE_ID = as.integer(NODE_ID)) %>%
    left_join(in_MHN_hwynodes, by = "NODE_ID") %>%
    select(NODE_ID, X, Y, Shape) %>%
    mutate(X = ifelse(NODE_ID < 2000, NA, X),
           Y = ifelse(NODE_ID < 2000, NA, Y)) %>%
    left_join(specialNodes, by = c("NODE_ID" = "specialID")) %>%
    mutate(POINT_X = ifelse(is.na(X), centroidX, X),
           POINT_Y = ifelse(is.na(Y), centroidY, Y)) %>%
    select(-Shape.y) %>%
    ungroup()%>%
    mutate(idcount = length(unique(NODE_ID)))%>%
    select(NODE_ID, POINT_X, POINT_Y) %>%
    mutate(xcoord = POINT_X, ycoord = POINT_Y) %>%
    st_as_sf(coords = c("xcoord", "ycoord"), crs = 26771)  %>%
    st_intersection(in_mesozoneGeo) %>%
    distinct() %>%
    group_by(NODE_ID) %>%
    mutate(count = n()) %>%
    ungroup() %>%
    filter(!(count == 2 & MESOZONE == 187)) %>%
    rename(NODE_ID_T=NODE_ID)
  
  #Identify node140 links####
  node140 <- finalLinks %>%
    st_drop_geometry() %>%
    filter(INODE == 140 | JNODE == 140) %>%
    select(INODE, JNODE)
  
  #Identify node143 links####
  node143 <- finalLinks %>%
    st_drop_geometry() %>%
    filter(INODE == 143 | JNODE == 143) %>%
    select(INODE, JNODE)
  
  #OUTPUT####
  file = paste("y", as.character(yr), sep = "")
  outLinkFile = paste("CMAP_HWY_LINK_", file, sep = "")
  st_write(obj = finalLinks, layer = outLinkFile, dsn = outputDir, append = FALSE)
  outNodeFile = paste("CMAP_HWY_NODE_", file, sep = "")
  st_write(obj =finalNodes, layer = outNodeFile, dsn = outputDir, append = FALSE)
  
  #Write Node 140 file####
  out140File = paste(outPath, "/Lognodes/unlink_lognode140_", file, ".txt", sep = "")
  sink(out140File, append = FALSE)
  writeLines(noquote("c MESO FREIGHT NETWORK BATCHIN FILE"))
  writeLines(noquote(paste("c ", "Generated: ", Sys.Date(), sep = "")))
  writeLines(noquote("c File to remove the highway and rail connector links for logistics node 140."))
  writeLines("")
  writeLines("")
  writeLines(noquote("t links"))
  writeLines(noquote(paste("d= ", node140$INODE, "   ", node140$JNODE)))
  writeLines(noquote(paste("d= ", rail140$INODE_T, "   ", rail140$JNODE_T)))
  sink()
  
  #Write Node 143 file####
  out143File = paste(outPath, "/Lognodes/unlink_lognode143_", file, ".txt", sep = "")
  sink(out143File, append = FALSE)
  writeLines(noquote("c MESO FREIGHT NETWORK BATCHIN FILE"))
  writeLines(noquote(paste("c ", "Generated: ", Sys.Date(), sep = "")))
  writeLines(noquote("c File to remove the South Suburban Airport connector links for logistics node 143."))
  writeLines("")
  writeLines("")
  writeLines(noquote("t links"))
  writeLines(noquote(paste("d= ", node143$INODE, "   ", node143$JNODE)))
  sink()

}

