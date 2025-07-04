#KCC
#script to read MHN future network coding and produce future MFN networks

#--SET KEY PARAMETERS--####
args = commandArgs(trailingOnly=T)
oldConf = as.character(args[1])
newConf = as.character(args[2])
inBaseYr = as.numeric(args[3])
inFirstYr = as.numeric(args[4])
inLastYr = as.numeric(args[5])

inputDir = paste("../Input/MHN_", newConf, ".gdb", sep="")    ### Current MHN
outputDir = paste("../Output/MFN_updated_", newConf, ".gdb", sep="")   ### Current MFN
outPath = "../Output"
outFile <- file(paste(outPath, "/QC/specialNodes.txt", sep = ""))
outDir1 = "../Output/QC/"
outDir2 = "../Output/Lognodes/"
dir.create(outDir1)
dir.create(outDir2)

#--SETUP--
packages <- c("tidyverse", "scales", "openxlsx", "sf", "sfheaders", "sp", "geosphere")
package.check <- lapply(
  packages,
  FUN = function(x) {
    if (!require(x, character.only = TRUE)) {
      install.packages(x, dependencies = TRUE)
      library(x, character.only = TRUE)
    }
  }
)

#if (!require("arcgisbinding", character.only = TRUE)) {
#  install.packages("arcgisbinding", repos="https://r.esri.com", type="win.binary")
#  library("arcgisbinding", character.only = TRUE)
#  arc.check_product()
#}

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
in_forceMESO <- read.xlsx("../Input/new_MHN_MESO-LINKS.xlsx", sheet = "base_MESO")
in_removeMESO <- read.xlsx("../Input/removeLinks.xlsx")
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

sink(outFile, append = FALSE)
i = 1
for(df in qc_coreNodes){
  qcFile = as.data.frame(qc_coreNodesMatch[1]) 
  checkDF <- centroidsCMAP %>%
    filter(!(NODE_ID %in% qcFile$NODE_ID))
 # print(nrow(checkDF))
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
#Create list of links to be removed(hanging links)
manualRemove <- in_removeMESO %>% mutate(linkID = paste(INODE, JNODE, sep = "-"))

#Create reference DF with NA for links that don't have any changes in attributes
changes_MHN <- in_MHN_hwyproj_coding %>%
  mutate(NEW_THRULANES1 = ifelse(NEW_THRULANES1 == 0, NA, NEW_THRULANES1),    #if 0 then no change to _arc attributes, make NA to populate with current attribute later                           
         NEW_THRULANES2 = ifelse(NEW_THRULANES2 == 0, NA, NEW_THRULANES2),
         NEW_TYPE1 = ifelse(as.numeric(NEW_TYPE1) == 0, NA, as.numeric(NEW_TYPE1)),
         NEW_DIRECTIONS = ifelse(as.numeric(NEW_DIRECTIONS) == 0, NA, as.numeric(NEW_DIRECTIONS)),
         flagChange = 1) %>%
  select(TIPID:NEW_TYPE1, NEW_THRULANES1, NEW_THRULANES2, ABB, flagChange)

#MHN base meso links
base_MHN_MESO <- in_MHN_hwynet_arc %>%
  mutate(MESO = ifelse(ABB %in% in_forceMESO$LINK_ABB, 1, MESO),                                     #force MESO flag for list of additional links
         MESO = ifelse((ANODE %in% qc_poe$NODE_ID) | (BNODE %in% qc_poe$NODE_ID), 1, MESO)) %>%      #flag POE to keep in list
  filter(MESO == 1) %>%
  mutate(linkID = paste(ANODE, BNODE, sep = "-"),
         type = ifelse(!is.na(TYPE1), TYPE1, as.numeric(TYPE1))) %>%
  distinct() %>%
  mutate(flag = "baseMESO", vdf = 10, Modes = "T", MESO = 1, typeMHN = type)%>%
  select(flag, linkID, ABB, ANODE, BNODE, DIRECTIONS, MESO,
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
i = inFirstYr
while(i <= inLastYr){
  if(i == inFirstYr){
    years <- list(inBaseYr, inFirstYr)
  }else{
    years <-append(years, i)
  }
  i = i+5
}
print(years)
for(yr in years){
  #Set year
  if(yr == 2060){
    year = 2050
  }else{
    year = yr
  }
  
  #1. GENERATE LINKS FROM MHN####
  #Select tip projects completed by this year##
  tipIDS <- in_MHN_hwyproj %>% 
    filter(COMPLETION_YEAR != 9999) %>%                                    #remove projects no longer active
    filter(TIPID != "2080005") %>%                                         #remove LSD project since no access
    filter(TIPID != "9110006") %>%                                         #remove project; random link giving me issues
    mutate(COMPLETION_YEAR = as.numeric(COMPLETION_YEAR)) %>%
    st_drop_geometry() %>%                                                 #remove geometry
    filter(COMPLETION_YEAR <= year)                                        #--SELECT ALL PROJECTS AND LINKids FROM HWYPROJ FOR YEAR

  #Identify changes in links for all years
  updated_MHN_MESO <- tipIDS %>%
    left_join(changes_MHN, by = join_by(TIPID)) %>%
    left_join(in_MHN_hwynet_arc, by = "ABB", relationship = "many-to-many") %>%                                                             #add new attributes to base MESO
    mutate(MESO = ifelse(MESO == 1, 1, NA)) %>%
    group_by(TIPID) %>%
    fill(MESO, .direction = "updown") %>%
    mutate(MESO = ifelse(ABB %in% in_forceMESO$LINK_ABB, 1, MESO),                                     #force MESO flag for list of additional links
           THRULANES1 = ifelse(!is.na(NEW_THRULANES1), NEW_THRULANES1, THRULANES1),
           THRULANES2 = ifelse(!is.na(NEW_THRULANES2), NEW_THRULANES2, THRULANES2),
           type = ifelse(!is.na(NEW_TYPE1), NEW_TYPE1, as.numeric(TYPE1)),
           DIRECTIONS = ifelse(!is.na(NEW_DIRECTIONS), NEW_DIRECTIONS, as.numeric(DIRECTIONS)),
           MESO = ifelse((ANODE %in% qc_poe$NODE_ID) | (BNODE %in% qc_poe$NODE_ID), 1, MESO),
           remNA = ifelse((is.na(NEW_DIRECTIONS) & is.na(NEW_TYPE1)) & (is.na(NEW_THRULANES1) & is.na(NEW_THRULANES2)),1,0)) %>%      #flag POE to keep in list
    filter(MESO == 1) %>%
    filter(remNA != 1)
  
  #grab list of removal
  removeBaseMeso <- updated_MHN_MESO %>%
    filter(ACTION_CODE == 3)  %>%
    select(ABB) %>%
    unique()
  
  #Continue
  updated_MHN_MESO <- updated_MHN_MESO %>%
    filter(ACTION_CODE != 3) %>%
    mutate(linkID = paste(ANODE, BNODE, sep = "-")) %>%
    distinct() %>%
    mutate(flag = "tipProj", vdf = 10, Modes = "T", MESO = 1, typeMHN = type)%>%
    select(flag, TIPID, linkID, ABB, ANODE, BNODE, DIRECTIONS, MESO, ACTION_CODE,
           type, typeMHN, vdf, MILES, Modes, THRULANES1, THRULANES2, SHAPE_Length, SHAPE) %>%
    distinct() %>%
    group_by(ABB) %>%
    mutate(count = n()) %>%
    ungroup() %>%
    left_join(tipIDS, by = "TIPID") %>%
    group_by(ABB) %>%
    arrange(COMPLETION_YEAR) %>%
    mutate(remFlag = ifelse(count > 1 & row_number() == 1, 1, 0)) %>%
    filter(remFlag == 0) %>%
    ungroup() %>%
    select(flag, linkID, ABB, ANODE, BNODE, DIRECTIONS, MESO,
           type, typeMHN, vdf, MILES, Modes, THRULANES1, THRULANES2, SHAPE_Length) 
    
  nBaseMESO <- base_MHN_MESO %>%
    st_drop_geometry() %>%
    filter(!(ABB %in% updated_MHN_MESO$ABB)) %>%
    select(colnames(updated_MHN_MESO)) %>%
    rbind(updated_MHN_MESO) %>%                               #remove any of these from base meso, then bind base meso
    filter(!(ABB %in% removeBaseMeso$ABB)) %>%                #then remove final remove action list
    filter(!(linkID %in% manualRemove$linkID))
  
  #now we have all the links

  #2. FORMAT CONNECTOR LINKS####
  #Format MFN Links1####
  futureLinks_baseT <- nBaseMESO %>%               #MHN future links
    mutate(timau = NA) %>%
    rename(Length = SHAPE_Length, INODE = ANODE, JNODE = BNODE, Miles = MILES, lanes = THRULANES1, lanes2 = THRULANES2) %>%
    mutate(INODE = as.numeric(INODE), JNODE = as.numeric(JNODE)) 
  
  futureLinks_baseGeo <- in_MHN_hwynet_arc %>%
    select(ANODE, BNODE, SHAPE) %>%
    mutate(linkID = paste(ANODE, BNODE, sep = "-")) %>%
    full_join(futureLinks_baseT, by = c("linkID")) %>%
    filter(!is.na(flag)) %>%
    filter(ABB %in% futureLinks_baseT$ABB) %>%
    select(colnames(futureLinks_baseT), SHAPE) %>%
    distinct() %>%
    group_by(ABB) %>%
    mutate(count = n())
  
  tempNodes2 <- futureLinks_baseT %>%
    select(INODE, JNODE) %>%
    pivot_longer(cols = INODE:JNODE, names_to = "type", values_to = "NODE_ID") %>%
    select(NODE_ID) %>%
    distinct()

  #Format MFN Nodes1####
  #Identify potential nodes for connectors to attach to
  #from link, filter DIRECTIONS == 2 & TYPEMHN == 1
  tempNodes1 <- futureLinks_baseT %>%
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
    slice(which.min(distance))%>%
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
    mutate(count = NA, typeMHN = NA, ABB = paste(INODE, JNODE, type, sep = "-")) %>%
    select(colnames(futureLinks_baseGeo))
  #3. FINALIZE####
  #--Format final MFN link fields####
  
  #ADD Special Links TO BASE####
  finalLinks <- futureLinks_baseGeo %>% 
    filter(!(INODE %in% duplicateNodes$MHN_ID)) %>%         #remove links associated with duplicate nodes first
    filter(!(JNODE %in% duplicateNodes$MHN_ID)) %>%
    rbind(allConnectors_f) %>%                              #Add connectors to link df
    st_as_sf() %>% 
    st_cast("MULTILINESTRING") %>%
    #select(linkID:type, vdf, Miles:lanes2, SHAPE) %>%
    mutate(Type = case_when(
             INODE < 133 ~ 4,
             INODE >= 133 & INODE <=150 ~ 7,
             INODE > 150 ~ 1
           ),
           Meso = 1,
           lanes = ifelse(lanes < 2, 2, lanes),
           lanes2 = ifelse(lanes2 == 0 | is.na(lanes2), lanes, lanes2),
           Shape_Length = st_length(SHAPE),
           DIRECTIONS = as.character(DIRECTIONS)) %>%
    filter(!is.na(type)) %>%
    filter(!is.na(lanes)) %>%
    distinct() %>%
    mutate(lanes = ifelse(INODE <= 150, 1, lanes),
           lanes2 = ifelse(INODE <= 150, 1, lanes2)) %>%
    rename(VDF = vdf, LANES = lanes, LANES2 = lanes2)%>%
    distinct() %>%
    select(INODE, JNODE, Meso, DIRECTIONS, Type, VDF, Miles, Modes, LANES, LANES2, SHAPE, Shape_Length)
  
  qcLinks <- finalLinks %>%
    group_by(INODE, JNODE) %>%
    mutate(count = n()) %>%
    filter(count >1)
  if(nrow(qcLinks) > 0){stop("UH OH, MULTIPLE LINKS EXIST FOR IJ PAIRS")}

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
    filter(!is.na(NODE_ID)) %>%
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
  #arc.write(file.path(outputDir, paste("MFN/", outLinkFile, sep = "")), data = finalLinks, overwrite = TRUE)
  outNodeFile = paste("CMAP_HWY_NODE_", file, sep = "")
  st_write(obj =finalNodes, layer = outNodeFile, dsn = outputDir, append = FALSE)
  #arc.write(file.path(outputDir, paste("MFN/", outNodeFile, sep = "")), data = finalNodes, overwrite = TRUE)
  
  
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

