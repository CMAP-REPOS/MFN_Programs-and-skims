#this script updates the MFN national highway network from sz09 --> sz17 highway POE node IDs

#library(scales)
#library(plotrix)
library(tidyverse)
library(sf)
#library(openxlsx)
library(sfheaders)
library(sp)
library(geosphere)

#Set Directories and Data####
baseDir = "S:/AdminGroups/ResearchAnalysis/kcc/FY25/MFN/SB_current/MFN.gdb"                               #Old Version of MFN
outputDir = "S:/AdminGroups/ResearchAnalysis/kcc/FY25/MFN/Current_copies/Output/MFN_currentFY25.gdb"        #New Version of MFN

ID_crosswalk <- data.frame(old_ID = c(1946, 1948, 1951, 1952, 1953, 1954, 1955, 1956, 1959, 1960),        #Old IDs
                           new_ID = c(3634, 3636, 3639, 3640, 3641, 3642, 3643, 3644, 3647, 3648))        #New IDs

#special handling - need to move the location of this node in the national network to match the current MHN (c24q2 as of 1/9/2025)
new1955X = 617405.946526     
new1955Y = 1576236.419566

#national highway network from gdb to be updated
in_nodes <- read_sf(dsn = baseDir, layer = "National_Hwy_nodes", crs = 26771)
in_links <- read_sf(dsn = baseDir, layer = "National_Highway", crs = 26771) 
in_links$index <- 1:nrow(in_links)

#Move node 1955####
updatedLink <- in_links %>%
  st_drop_geometry() %>%
  select(-Shape_Length) %>%
  filter(INODE == 1955 | JNODE == 1955) %>%
  mutate(X_END = ifelse(JNODE == 1955, new1955X, X_END),
         Y_END = ifelse(JNODE == 1955, new1955Y, Y_END))

updatedLinks_att <- updatedLink %>% ungroup()

#--Link layer####
#format node pairs
updated2 <- updatedLink %>%
  mutate(lineID = INODE,
         lineID2 = JNODE) %>%
  select(lineID, lineID2, X_START, Y_START, X_END, Y_END) %>%
  pivot_longer(cols = c(X_START, X_END), names_to = "type", values_to = "coordX") %>%
  pivot_longer(cols = c(Y_START, Y_END), names_to = "typeY", values_to = "coordY") %>%
  filter((type == "X_START" & typeY == "Y_START") | (type == "X_END" & typeY == "Y_END")) %>%
  select(lineID, lineID2, coordX, coordY) %>%
  distinct()

updated2 = st_as_sf(updated2, coords = c("coordX", "coordY"), crs = 26771) #crs = 26771 this is the projection to be used for all shape files

#create lines from node pairs
updated_links <- st_as_sf(updated2, wkt = geometry) %>% 
  group_by(lineID, lineID2) %>%
  summarise(do_union = FALSE) %>%
  ungroup() %>%
  st_cast("MULTILINESTRING") %>%
  rename(INODE = lineID, JNODE = lineID2) %>%
  left_join(updatedLinks_att, by = c("INODE", "JNODE")) %>%   #add in attributes for consistency
  rename(Shape = geometry) %>%
  mutate(Shape_Length = st_length(Shape)) %>%
  select(colnames(in_links))

#add to all links - amending this way retains geometry of other links 
otherLinks <- in_links %>% 
  filter(!(index %in% updatedLink$index))

allLinks <- rbind(updated_links, otherLinks)

#--Node layer####
node_coords <- in_nodes %>%
  st_drop_geometry()  %>%
  mutate(POINT_X = ifelse(NODE_ID == 1955, new1955X, POINT_X),
         POINT_Y = ifelse(NODE_ID == 1955, new1955Y, POINT_Y)) 

node_coords2<- node_coords %>%
  st_as_sf(coords = c("POINT_X", "POINT_Y"), crs = 26771)  %>%
  distinct() %>%
  group_by(NODE_ID) %>%
  mutate(count = n()) %>%
  ungroup() %>%
  rename(Shape = geometry) %>%
  mutate(Shape_Length = st_length(Shape))

#Renumber####
final_links <- allLinks %>%
  left_join(ID_crosswalk, by = c("INODE" = "old_ID")) %>%
  mutate(INODE = ifelse(is.na(new_ID), INODE, new_ID)) %>%
  select(-new_ID)%>%
  left_join(ID_crosswalk, by = c("JNODE" = "old_ID")) %>%
  mutate(JNODE = ifelse(is.na(new_ID), JNODE, new_ID)) %>%
  select(colnames(in_links)) %>%
  rename(INODE_T = INODE, JNODE_T = JNODE, DIRECTIONS_T = DIRECTIONS)

final_nodes <- node_coords2 %>%
  select(-MESOZONE) %>%
  left_join(node_coords, by = "NODE_ID") %>%
  left_join(ID_crosswalk, by = c("NODE_ID" = "old_ID")) %>%
  mutate(NODE_ID = ifelse(is.na(new_ID), NODE_ID, new_ID)) %>%
  select(colnames(in_nodes)) %>%
  rename(NODE_ID_T = NODE_ID)

#Export####
st_write(obj = final_nodes, layer = "National_Hwy_nodes", dsn = outputDir, append = FALSE)
st_write(obj =final_links, layer = "National_Highway", dsn = outputDir, append = FALSE)
