#this script updates the MFN logistic node locations
#KCazzato 1/7/2025
#library(scales)
#library(plotrix)
library(tidyverse)
library(sf)
library(openxlsx)
library(sfheaders)
library(sp)
library(geosphere)

baseDir = "S:/AdminGroups/ResearchAnalysis/kcc/FY25/MFN/SB_current/MFN.gdb"                               #Old Version of MFN
outputDir = "S:/AdminGroups/ResearchAnalysis/kcc/FY25/MFN/Current_copies/Output/MFN_currentFY25.gdb"

in_nodes <- data.frame(NODE_ID = c(133:150))
in_newNodes <- read.xlsx("../../Input/update_LogisticNodes.xlsx")

in_Railnodes <- read_sf(dsn = baseDir, layer = "CMAP_Rail_nodes", crs = 26771)
in_Raillinks <- read_sf(dsn = baseDir, layer = "CMAP_Rail", crs = 26771) 
in_mesoCentroids <- read_sf(dsn = baseDir, layer = "Meso_Ext_Int_Centroids", crs = 26771)
in_mesozones <- read_sf(dsn=outputDir, layer = "Meso_External_CMAP_Merge", crs = 26771)

#Update attributes and geography
update_att <- in_nodes %>%
  left_join(in_newNodes, by = "NODE_ID") %>%
  rename(LN_Type = newType, LN_descrp = newDescrp, POINT_X = newX, POINT_Y = newY) %>%
  mutate(xcoord = POINT_X, ycoord = POINT_Y) %>%
  st_as_sf(coords = c("xcoord", "ycoord"), crs = 26771) %>%
  rename(Shape = geometry) %>%
  mutate(Shape_Length = st_length(Shape))%>%
  select(-change2025) %>%
  rename(NODE_ID_T = NODE_ID)%>%
  st_intersection(in_mesozones) %>%
  select(NODE_ID_T:MESOZONE, Shape_Area, Shape) %>%
  ungroup()

update_Rail <- update_att %>%
  filter(LN_Type == "Rail terminal") %>%
  rename(NODE_ID = NODE_ID_T) %>%
  st_intersection(in_mesozones) %>%
  select(colnames(in_Railnodes))

#Update Rail Nodes####
cleanNodes <- in_Railnodes %>%
  filter(!(NODE_ID %in% update_Rail$NODE_ID)) 

newNodes <- in_Railnodes %>%
  filter(!(NODE_ID %in% update_Rail$NODE_ID)) %>%
  select(colnames(in_Railnodes)) %>%
  rbind(update_Rail) %>%
  rename(NODE_ID_T = NODE_ID)

#Update Rail Links####
#Link DF without the old linds
otherLinks <- in_Raillinks %>%
  filter(!(INODE %in% update_Rail$NODE_ID)) %>%
  filter(!(JNODE %in% update_Rail$NODE_ID)) %>%
  select(Miles:VDF, Shape_Length, Shape)

originalLog <- in_Raillinks %>%
  filter((INODE %in% update_Rail$NODE_ID) | (JNODE %in% update_Rail$NODE_ID)) %>%
  select(JNODE:VDF) %>%
  st_drop_geometry() %>%
  distinct()
#Attach special nodes to base nodes and find distance####
temp_dist1 <- update_Rail %>%
  rename(centroidX = POINT_X, centroidY = POINT_Y, logisticID = NODE_ID) %>%
  cross_join(cleanNodes) %>%
  mutate(distance = sqrt(((centroidX - POINT_X)^2) + ((centroidY - POINT_Y)^2)))

#Develop special links#### 
logisticNodes <- temp_dist1 %>%
  group_by(logisticID) %>%
  arrange(distance) %>%
  filter(row_number() == 1)%>%
  ungroup() %>%
  mutate(lineID = logisticID,
         lineID2 = NODE_ID) %>%
  select(lineID, lineID2, POINT_X, POINT_Y, centroidX, centroidY) %>%
  pivot_longer(cols = c(POINT_X, centroidX), names_to = "type", values_to = "coordX") %>%
  pivot_longer(cols = c(POINT_Y, centroidY), names_to = "typeY", values_to = "coordY") %>%
  mutate(retain_c = ifelse(type == "centroidX" & typeY == "centroidY", 1, 0),
         retain_n = ifelse(type == "POINT_X" & typeY == "POINT_Y", 1, 0)) %>%
  filter(retain_c == 1 | retain_n == 1) %>%
  select(lineID, lineID2, coordX, coordY) %>%
  distinct()

logisticNodes = st_as_sf(logisticNodes, coords = c("coordX", "coordY"), crs = 26771) #crs = 26771 this is the projection to be used for all shape files

allLogistic_f <- st_as_sf(logisticNodes, wkt = geometry) %>% 
  group_by(lineID, lineID2) %>%
  summarise(do_union = FALSE) %>%
  st_cast("MULTILINESTRING") %>%
  rename(specialID = lineID, NODE_ID = lineID2) %>%
  left_join(originalLog, by = c("specialID" = "JNODE")) %>%
  rename(JNODE = specialID, INODE = NODE_ID, Shape = geometry) %>%
  mutate(Shape_Length = st_length(Shape),
         Miles = Shape_Length/5280) %>%
  select(colnames(otherLinks))

allLinks <- rbind(allLogistic_f, otherLinks) %>%
  rename(INODE_T = INODE, JNODE_T = JNODE)

#Export####
st_write(obj = update_att, layer = "Meso_Logistic_Nodes", dsn = outputDir, append = FALSE)
st_write(obj = allLinks, layer = "CMAP_Rail", dsn = outputDir, append = FALSE)
st_write(obj = newNodes, layer = "CMAP_Rail_nodes", dsn = outputDir, append = FALSE)
