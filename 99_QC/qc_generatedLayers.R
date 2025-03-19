#Compares output from XXX to previous version
#KCazzato 1/9/2025

library(tidyverse)
library(sf)


#SET PARAMETERS & VARIABLES####
oldDir = "V:\Secure\Master_Freight\working_pro\MFN_currentFY25.gdb"
newDir = "S:/AdminGroups/ResearchAnalysis/kcc/FY25/MFN/Current_copies/Output/MFN_tempFY25.gdb"
outDir = "../../../Output/QC"
year = '2022'

#create names
links = paste("CMAP_HWY_LINK_y", year, sep = "")
nodes = paste("CMAP_HWY_NODE_y", year, sep = "")

setwd(outDir)
#LOAD DATA: New Version####
in_new_links_cmap <- read_sf(dsn = newDir, layer =links, crs = 26771) 
in_new_nodes_cmap <- read_sf(dsn = newDir, layer =nodes, crs = 26771)
in_new_links_nation <- read_sf(dsn = newDir, layer ="National_Highway", crs = 26771) 
in_new_nodes_nation <- read_sf(dsn = newDir, layer ="National_Hwy_nodes", crs = 26771) 
in_new_logistic <- read_sf(dsn = newDir, layer ="Meso_Logistic_nodes", crs = 26771)
in_new_links_rail <- read_sf(dsn = newDir, layer ="CMAP_Rail", crs = 26771) 
in_new_nodes_rail <- read_sf(dsn = newDir, layer ="CMAP_Rail_nodes", crs = 26771)

#LOAD DATA: Old Version####
in_old_links_cmap <- read_sf(dsn = oldDir, layer ="CMAP_Highway", crs = 26771) 
in_old_nodes_cmap <- read_sf(dsn = oldDir, layer ="CMAP_Hwy_nodes", crs = 26771)
in_old_links_rail <- read_sf(dsn = oldDir, layer ="CMAP_Rail", crs = 26771) 
in_old_nodes_rail <- read_sf(dsn = oldDir, layer ="CMAP_Rail_nodes", crs = 26771)
in_old_links_nation <- read_sf(dsn = oldDir, layer ="National_Highway", crs = 26771) 
in_old_nodes_nation <- read_sf(dsn = oldDir, layer ="National_Hwy_nodes", crs = 26771)
in_old_logistic <- read_sf(dsn = oldDir, layer ="Meso_Logistic_nodes", crs = 26771)

#QC Logistic Nodes####
#--Prep old nodes
old_logistic <- in_old_logistic %>%
  st_drop_geometry() %>%
  group_by(NODE_ID) %>%
  mutate(count = n(),
         flag = "old",
         MESOZONE = as.numeric(MESOZONE),
         NODE_ID = as.numeric(NODE_ID)) %>%
  ungroup()

unique(old_logistic$count) #check for duplicates; expect = 1

old_logistic <- as.data.frame(old_logistic)

#--Prep new nodes
new_logistic <- in_new_logistic %>%
  st_drop_geometry() %>%
  group_by(NODE_ID_T) %>%
  mutate(count = n(),
         flag = "new")%>%
  ungroup()%>%
  rename(NODE_ID = NODE_ID_T) %>%
  select(colnames(old_logistic))

new_logistic <- as.data.frame(new_logistic)

sink("qc_layers.txt", append = FALSE)  #set append = FALSE first time to clear file
print(paste("Unique instances of logistic node ID in new layer (expect '1') = ", unique(new_logistic$count), sep = ""))
sink()

#--Compare
#for logistic nodes, SAS looks for NODE_ID, POINT_X, POINT_Y
#we change point locations, so the most important part is that each NODE_ID expected is represented
qc_allLogistic <- new_logistic %>%
  rename(flagNew = flag) %>%
  full_join(old_logistic, by = c("NODE_ID")) %>%
  select(NODE_ID, flag, flagNew) %>%
  filter(is.na(flag) | is.na(flagNew))

sink("qc_layers.txt", append = TRUE)  
print("Logistic nodes with issues (expect no output):")
qc_allLogistic
sink()

#QC CMAP Highway Nodes####
#--Prep old nodes
old_nodes <- in_old_nodes_cmap %>%
  st_drop_geometry() %>%
  group_by(NODE_ID) %>%
  mutate(count = n(),
         flag = "old",
         MESOZONE = as.numeric(MESOZONE),
         NODE_ID = as.numeric(NODE_ID)) %>%
  ungroup()

unique(old_nodes$count) #check for duplicates; expect = 1

old_nodes <- as.data.frame(old_nodes)

#--Prep new nodes
new_nodes <- in_new_nodes_cmap %>%
  st_drop_geometry() %>%
  rename(NODE_ID = NODE_ID_T) %>%
  group_by(NODE_ID) %>%
  mutate(count = n(),
         flag = "new")%>%
  ungroup()%>%
  select(colnames(old_nodes))

duplicateCoords <- new_nodes %>%
  group_by(POINT_X, POINT_Y) %>%
  mutate(count = n()) %>%
  filter(count > 1)

sink("qc_layers.txt", append = TRUE)
print(paste("Unique instances of new CMAP nodes (expect '1') = ", unique(new_nodes$count), sep = ""))
sink()
new_nodes <- as.data.frame(new_nodes)

#--Compare
qc_allNodes <- full_join(new_nodes, old_nodes, by = c("MESOZONE", "NODE_ID", "POINT_X", "POINT_Y")) %>%
  select(-count.x, -count.y) %>%
  group_by(NODE_ID) %>%
  mutate(count2 = n()) %>%
  ungroup() %>%
  arrange(NODE_ID)

same_nodes <- qc_allNodes %>% filter(count2 == 1 & (!is.na(flag.y) & !is.na(flag.x)))
different_nodes <- qc_allNodes %>% filter(!(NODE_ID %in% same_nodes$NODE_ID)) %>%
  filter(NODE_ID < 5000)

different_nodes_dup <- different_nodes %>%
  filter(count2 == 2)

different_nodes_single <- different_nodes %>%
  filter(count2 == 1)

sink("qc_layers.txt", append = TRUE)
print(paste("The first NODEID with different coordinates from the previous version = ", min(different_nodes$NODE_ID), sep = ""))
print(paste("Duplicate node range = ", range(different_nodes_dup$NODE_ID), sep = ""))
print("**expect this value to be 133 and a range of 133-150; these are the logistic nodes; we expect some of these to be in a different location)")
print(paste("The first NODEID with different coordinates, that's not a logistic node, from the previous version = ", min(different_nodes_single$NODE_ID), sep = ""))
print(paste("Single node range = ", range(different_nodes_single$NODE_ID), sep = ""))
print("**expect this value to be 1945 and a range of ending with 3649; these are the update POE nodes; we expect all of these to have a different NODE_ID")
sink()


#QC CMAP Highway Links####
#qc links
old_links <- in_old_links_cmap %>%
  st_drop_geometry() %>%
  select("INODE", "JNODE", "Miles", "Modes", "Type", "LANES", "VDF", "DIRECTIONS") %>%
  mutate(flag = "old")
summary(old_links)
new_links <- in_new_links_cmap %>%
  st_drop_geometry() %>%
  mutate(flag = "new") %>%
  select(colnames(old_links))
summary(new_links)

#--Compare
#SAS looks for mode, type, vdf, and directions
#expect JNODES to be different so join just on INODE and reconcile later
qc_allLinks <- full_join(new_links, old_links, by = c("INODE", "Modes", "Type", "VDF", "DIRECTIONS"), relationship = "many-to-many") %>%
  group_by(INODE, Modes, Type) %>%
  mutate(count2 = n()) %>%
  ungroup() %>%
  arrange(INODE) %>%
  select(INODE, JNODE.x, JNODE.y, Modes, Type, VDF, DIRECTIONS, flag.x, flag.y, count2) %>%
  rename(oldJNODE = JNODE.y, newJNODE = JNODE.x)

qc_JLinks <- full_join(new_links, old_links, by = c("INODE","JNODE", "Modes", "Type", "VDF", "DIRECTIONS"), relationship = "many-to-many") %>%
  group_by(INODE, Modes, Type) %>%
  mutate(count2 = n()) %>%
  ungroup() %>%
  arrange(INODE) %>%
  select(INODE, JNODE, Modes, Type, VDF, DIRECTIONS, flag.x, flag.y, count2)

qc_JLinks_dif <- qc_JLinks %>% filter(is.na(flag.x) | is.na(flag.y)) %>%
  group_by(INODE, JNODE) %>%
  mutate(pairCount = n())

differentOld <- qc_JLinks_dif %>%
  filter(flag.y == "old")

differentNew <- qc_JLinks_dif %>%
  filter(flag.x == "new")


write.csv(differentOld, "differentOld.csv")
write.csv(differentNew, "differentNew.csv")

qc_allConnect <- full_join(new_links, old_links, by = c("INODE", "Modes", "Type", "VDF", "DIRECTIONS"), relationship = "many-to-many") %>%
  filter(INODE <= 150) %>%
  rename(newMi = Miles.x, oldMi = Miles.y, newJ = JNODE.x, oldJ = JNODE.y) %>%
  select(INODE, newJ, oldJ, Modes, newMi, oldMi) %>%
  mutate(difference = round(newMi - oldMi, 4))

write.csv(qc_allConnect, "S:/AdminGroups/ResearchAnalysis/kcc/FY25/MFN/proUpdate/finalGDB/0_generate_future_networks/out_qc/differentMiles.csv")

#Centroid connector links (1-132)
qc_connectors <- qc_allLinks %>%
  filter(INODE <= 132 | (oldJNODE <= 132 | newJNODE <= 132)) %>%
  filter(!(INODE == 52 & oldJNODE == 11132)) %>%  #old version has 2 links connected to this centroid; for QC only want to check 1
  filter(!(INODE == 83 & oldJNODE == 8119)) %>%   #old version has 2 links connected to this centroid; for QC only want to check 1
  group_by(INODE, Modes, Type) %>%
  mutate(count = n()) %>%
  filter(count > 1)

#Logistic node connector links (133-150)
qc_logisticLinks <- qc_allLinks %>%
  filter(INODE <= 150 | (oldJNODE <= 150 | newJNODE <= 150))%>%
  filter(INODE >= 133 & (oldJNODE >= 133 | newJNODE >= 133)) %>%
  filter(!(INODE == 141 & oldJNODE == 11414)) %>% #old version has 2 1-way links connected to this centroid; for QC only want to check 1
  group_by(INODE, Modes, Type)%>%
  mutate(count = n()) %>%
  filter(count > 1)

#POE (3634-3648)
qc_cmapPOELinks <- qc_allLinks %>%
  filter((INODE > 150 & INODE < 4000))


sink("qc_layers.txt", append = TRUE)
print("############QC CMAP Centroid Connectors############")
print(paste("Duplicate or missmatched centroid connectors:"))
qc_connectors
print(paste("Duplicate or missmatched logistic connectors:"))
qc_logisticLinks
print(paste("Duplicate or missmatched POE connectors:"))
qc_logisticLinks
sink()


#QC National network####
#only thing that should be different are POE so isolate and confirm that
#Nodes
old_nodes <- in_old_nodes_nation %>%
  st_drop_geometry() %>%
  group_by(NODE_ID) %>%
  mutate(count = n(),
         flag = "old",
         MESOZONE = as.numeric(MESOZONE),
         NODE_ID = as.numeric(NODE_ID)) %>%
  ungroup()

unique(old_nodes$count) #check for duplicates; expect = 1

old_nodes <- as.data.frame(old_nodes)

#--Prep new nodes
new_nodes <- in_new_nodes_nation %>%
  st_drop_geometry() %>%
  group_by(NODE_ID) %>%
  mutate(count = n(),
         flag = "new")%>%
  ungroup()%>%
  select(colnames(old_nodes))

qc_allNodes_nation <- full_join(new_nodes, old_nodes, by = c("MESOZONE", "NODE_ID", "POINT_X", "POINT_Y")) %>%
  select(-count.x, -count.y) %>%
  group_by(NODE_ID) %>%
  mutate(count2 = n()) %>%
  ungroup() %>%
  arrange(NODE_ID)

#Links
#qc links
old_links <- in_old_links_nation %>%
  st_drop_geometry() %>%
  select("INODE", "JNODE", "Miles", "Modes", "Type", "LANES", "VDF", "DIRECTIONS") %>%
  mutate(flag = "old")
summary(old_links)
new_links <- in_new_links_nation %>%
  st_drop_geometry() %>%
  mutate(flag = "new") %>%
  select(colnames(old_links))
summary(new_links)

#--Compare
#SAS looks for mode, type, vdf, and directions
#expect JNODES to be different so join just on INODE and reconcile later
qc_allLinks_nation <- full_join(new_links, old_links, by = c("INODE", "JNODE","Miles", "Modes", "LANES", "Type", "VDF", "DIRECTIONS"), relationship = "many-to-many") %>%
  group_by(INODE, JNODE) %>%
  mutate(count2 = n()) %>%
  ungroup() %>%
  filter(is.na(flag.x) | is.na(flag.y)) %>%
  arrange(INODE) %>%
  select(INODE, JNODE, Miles, Modes, Type, VDF, DIRECTIONS, flag.x, flag.y, count2) %>%
  filter(INODE >=1945 | JNODE >= 1945)

#QC CMAP Highway Nodes####
#--Prep old nodes
old_nodes <- in_old_nodes_rail %>%
  st_drop_geometry() %>%
  group_by(NODE_ID) %>%
  mutate(count = n(),
         flag = "old",
         MESOZONE = as.numeric(MESOZONE),
         NODE_ID = as.numeric(NODE_ID)) %>%
  ungroup()

unique(old_nodes$count) #check for duplicates; expect = 1

old_nodes <- as.data.frame(old_nodes)

#--Prep new nodes
new_nodes <- in_new_nodes_rail %>%
  st_drop_geometry() %>%
  rename(NODE_ID = NODE_ID_T) %>%
  group_by(NODE_ID) %>%
  mutate(count = n(),
         flag = "new")%>%
  ungroup()%>%
  select(colnames(old_nodes))

duplicateCoords <- new_nodes %>%
  group_by(POINT_X, POINT_Y) %>%
  mutate(count = n()) %>%
  filter(count > 1)

#--Compare
qc_allNodes <- full_join(new_nodes, old_nodes, by = c("MESOZONE", "NODE_ID", "POINT_X", "POINT_Y")) %>%
  select(-count.x, -count.y) %>%
  group_by(NODE_ID) %>%
  mutate(count2 = n()) %>%
  ungroup() %>%
  arrange(NODE_ID)

same_nodes <- qc_allNodes %>% filter(count2 == 1 & (!is.na(flag.y) & !is.na(flag.x)))
different_nodes <- qc_allNodes %>% filter(!(NODE_ID %in% same_nodes$NODE_ID)) %>%
  filter(NODE_ID < 5000)

different_nodes_dup <- different_nodes %>%
  filter(count2 == 2)

different_nodes_single <- different_nodes %>%
  filter(count2 == 1)

sink("qc_layers.txt", append = TRUE)
print(paste("The first NODEID with different coordinates from the previous version = ", min(different_nodes$NODE_ID), sep = ""))
print(paste("Duplicate node range = ", range(different_nodes_dup$NODE_ID), sep = ""))
print("**expect this value to be 133 and a range of 133-150; these are the logistic nodes; we expect some of these to be in a different location)")
print(paste("The first NODEID with different coordinates, that's not a logistic node, from the previous version = ", first(different_nodes_single$NODE_ID), sep = ""))
print(paste("Single node range = ", range(different_nodes_single$NODE_ID), sep = ""))
print("**expect this value to be 1945 and a range of ending with 3649; these are the update POE nodes; we expect all of these to have a different NODE_ID")
sink()
