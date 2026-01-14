# KCazzato 3/25/2025
# Updated 1/14/2026 to accommodate translated SAS and toolbox structure
# Change this from a script that runs in batch to a stand alone script

# This script reviews the batchin files for the Freight network skimming by comparing 
# updated batchin files to the batchin files used in a previous conformity run

# Context -----------------------------------------------------------------
# Files produced by 
# batch_domestic_PIPELINE.py 
  # These files are static and do not change conformity to conformity
  # QC checks that the data has no difference from the previous conformity
  # If pipeline networks have been updated from the previous conformity, this script WILL THROW AN ERROR MESSAGE (but will keep running)
  # If conus_ak (continuous US and Alaska) polygon feature class has changed, the DomesticPipelineNetwork.csv file may change, and this script WILL THROW AN ERROR MESSAGE (but will keep running)
  # FILES:
    # - cos_ntwk.txt
    # - nec_19_ntwk.txt
    # - p1718_ntwk.txt
    # - DomesticPipelineNetwork.csv 
# batch_domestic_ITINERARIES.py
  # This file is static and does not change conformity to conformity
  # QC checks that the data has no difference from the previous conformity
  # If rail itineraries have been updated from the previous conformity, this script WILL THROW AN ERROR
  # FILE: 
    # - lines.in
# batch_domestic_SCENARIOS.py
  # These files will change with each conformity update
  # - FILES FOR EACH YEAR: 
    # - base_ntwk.txt
    # - DomesticNetwork.csv

# Set user parameters -----------------------------------------------------
# Provide folder name to updated/new batchin files:
updated_files_directory = 'test2_1.14.2025_c25q2' 

# Provide MHN conformity used to develop the updated MFN batchin files:
conformity_for_update = 'c25q2'

# Provide conformity (format: 'c##q#') to compare updated batchin files to:
comparison_files_conformity = 'c25q2_v1'

# Import Libraries & Set WD to current directory --------------------------
packages <- c("tidyverse", "readxl", "openxlsx", "sf", 'rstudioapi')

package.check <- lapply(
  packages,
  FUN = function(x) {
    if (!require(x, character.only = TRUE)) {
      install.packages(x, dependencies = TRUE)
      library(x, character.only = TRUE)
    }
  }
)
currentDir = dirname(rstudioapi::getActiveDocumentContext()$path)
setwd(currentDir)

# Set Paths ---------------------------------------------------------------
# Define path to updated/new batchin files
newBatchinDir = paste('../Output_', updated_files_directory, sep = '')

# Define path to comparison batchin files
compareBatchinDir = paste("V:/Secure/Master_Freight/Archive/", comparison_files_conformity, '/BatchinFiles', sep="")

# Define path to associated MHN GDB to check if changes in MFN correspond to network changes in the MHN
referenceMHN = paste("V:/Secure/Master_Highway/archive/gdb/conformity/mhn_", conformity_for_update, ".gdb", sep="")

# Define path to QC output directory and file
qc_out_dir = paste(newBatchinDir, '/QC_batchin_files',sep = '')
qc_out_years = paste(qc_out_dir, '/batchin_hwy_years.csv', sep="")
qc_out_file = paste(qc_out_dir, '/batchinTIPIDs.xlsx',sep = '')

# Create output folder if it does not exist
if (!dir.exists(file.path(qc_out_dir))) {
  dir.create(file.path(qc_out_dir))
}

# Define lists for file names ---------------------------------------------
# List all static files
static_files = c("cos_ntwk.txt", "DomesticPipelineNetwork.csv", "lines.in", "nec_19_ntwk.txt", "p1718_ntwk.txt")

# Find list of years - only compare highway data files for the same years and report if there's mismatched years in qc_out_years
folders_new = gsub(".*/scen_", "", list.dirs(newBatchinDir, recursive = TRUE)[-1])              # find year folders in new output folder
folders_compare =  gsub(".*/scen_", "", list.dirs(compareBatchinDir, recursive = TRUE)[-1])     # find year folders in comparison output folder

years_new = data.frame(years = folders_new, new_output =1) %>%                  # Format new data years
  mutate(years = as.numeric(years)) %>%
  filter(!is.na(years))

years_compare = data.frame(years = folders_compare, compare_output =1) %>%      # Format comparison data years
  mutate(years = as.numeric(years)) %>%
  filter(!is.na(years))

years_to_analyze <- years_new %>%            # Combine new and comparison available years
  full_join(years_compare, by = 'years')

write.csv(years_to_analyze, qc_out_years)    # Export QC file to use as reference if needed 

years_to_analyze <- years_to_analyze %>%
  filter(!is.na(new_output) & !is.na(compare_output))    # Filter to keep only years where data is available for both the new and comparison batchin file sets

# Define Functions for reading & formatting base_ntwk.txt -----------------
# Function to import the base_ntwk.txt file
readBaseNtwk <- function(file){
  in1 <- scan(file, what = character(), sep = "\n", skip = 2)
  
  sep1 <- data.frame(X = in1) %>%
    mutate(Index = 1:length(in1),
           FlagLinks = str_detect(X, "c i   j   mi"),
           RemVal = ifelse(FlagLinks == TRUE, Index, NA)) %>%
    fill(RemVal, .direction = "updown") 
}

# Function to format the nodes from base_ntwk.txt
fmtNodes <- function(df){
  nodes <- df %>%
    filter(Index < RemVal) %>%
    filter(Index > 2) %>%
    select(X) %>%
    separate(X, into = c("c", "node", "x",  "y",  "UI1"), sep = "  ")
  
}

# Function to format the links from base_ntwk.txt
fmtLinks <- function(df){
  links <- df %>%
    filter(Index > (RemVal + 1))%>%
    select(X) %>%
    separate(X, into = c("c", "i", "j", "mi", "modes", "type", "lanes", "vdf", "ul1", "ul2", "ul3"), sep = "  ")
  
}

# Import MHN reference data -----------------------------------------------
#MHN formatting data
in_MHN_hwyproj_coding <- read_sf(dsn = referenceMHN, layer = "hwyproj_coding", crs = 26771)
in_MHN_hwyproj <- read_sf(dsn = referenceMHN, layer = "hwyproj", crs = 26771)

# Format MHN Project Information####
TIPIDs <- in_MHN_hwyproj %>% select(TIPID:RSP_ID) %>% st_drop_geometry() %>% filter(COMPLETION_YEAR != 9999)

projCode <- in_MHN_hwyproj_coding %>%
  select(TIPID, ACTION_CODE, ABB) %>%
  left_join(TIPIDs, by = join_by(TIPID)) %>%
  separate(ABB, into = c('INODE', 'JNODE', 'Reverse'), sep = "-") %>%
  mutate(INODE = as.numeric(INODE), JNODE = as.numeric(JNODE), Reverse = as.numeric(Reverse), ACTION_CODE = as.numeric(ACTION_CODE), linkID = paste(INODE, JNODE, sep = "-"))

t1 <- projCode %>%
  select(-JNODE) %>%
  rename(NODE = INODE) %>%
  select(TIPID, NODE) 
t2 <- projCode %>%
  select(-INODE) %>%
  rename(NODE = JNODE)%>%
  select(TIPID, NODE) 

allNodes <- rbind(t1, t2) %>%
  distinct() %>%
  group_by(NODE) %>%
  mutate(count = n()) %>%
  ungroup()

confIDs <- in_MHN_hwyproj_coding %>%
  select(TIPID) %>%
  unique() %>%
  mutate(flag = "conformity") 

# Compare static data####
print("QA/QC STATIC DATA")
for(file in static_files){
  print(file)
  #Load current data
  fileC = paste(compareBatchinDir, "/", file, sep = "")
  in1 <- scan(fileC, what = character(), sep = "\n", skip = 2)
  
  #Load new data
  fileN = paste(newBatchinDir, "/", file, sep = "")
  in2 <- scan(fileN, what = character(), sep = "\n", skip = 2)
  
  #Compare
  resp = all.equal(in1, in2)
  if(resp != TRUE){
    errorM = paste('DISCREPANCIES IN ', file, " file", sep ="")
    print(errorM)
    #stop()
    } 
}


#Compare highway data####
#DomesticNetwork.csv
#base_ntwk.txt
loopNodes <- data.frame(c=as.character(), node=as.numeric(), x=as.numeric(), y=as.numeric(), 
                        flag.x=as.character(), flag.y=as.character())
loopLinks <- data.frame(c=as.character(), i=as.numeric(), j=as.numeric(), mi=as.numeric(), modes=as.character(),
                        type=as.numeric(),   lanes=as.numeric(),  vdf=as.numeric(),
                        flag.x=as.character(), flag.y=as.character(), modYear = as.numeric())
loopDistance <- data.frame(cINODE=as.numeric(), JNODE=as.numeric(), LENGTH=as.numeric(), 
                           dom_ratio=as.numeric(), DmstDist=as.numeric(), flag.x=as.character(), flag.y=as.character())

print("QA/QC HIGHWAY DATA")
for(yr in years_to_analyze$years){
  #LOAD DATA####
  #Load current data
  fileC = paste(compareBatchinDir, "/scen_", yr, "/base_ntwk.txt", sep = "")
  c1 <- readBaseNtwk(fileC)
  cNodes <- fmtNodes(c1) %>% mutate(flag = "current")
  cLinks <- fmtLinks(c1) %>% mutate(flag = "current")

  fileC = paste(compareBatchinDir, "/scen_", yr, "/DomesticNetwork.csv", sep = "")
  cDist <- read.csv(fileC) %>% mutate(flag = "current")
  
  #Load new data
  fileN = paste(newBatchinDir, "/Batchin//scen_", yr, "/base_ntwk.txt", sep = "")
  n1 <- readBaseNtwk(fileN)
  nNodes <- fmtNodes(n1) %>% mutate(flag = "new")
  nLinks <- fmtLinks(n1) %>% mutate(flag = "new")
  
  fileN = paste(newBatchinDir, "/Batchin/scen_", yr, "/DomesticNetwork.csv", sep = "")
  nDist <- read.csv(fileN) %>% mutate(flag = "new")
  
  #COMPARE####
  #Compare base_ntwk.txt Nodes
  compNodes <- full_join(cNodes, nNodes, by = join_by(c, node, x, y)) %>%
    select(-UI1.x, -UI1.y) %>%
    filter(is.na(flag.x) | is.na(flag.y)) %>%
    mutate(node = as.numeric(node),
           x = as.numeric(x),
           y = as.numeric(y),
           modYear = as.numeric(yr)) 

  #Compare base_ntwk.txt Links
  compLinks <- full_join(cLinks, nLinks, by = join_by(c, i, j, mi, modes, type, lanes, vdf)) %>%
    select(-ul1.x, -ul2.x, -ul3.x, -ul1.y, -ul2.y, -ul3.y) %>%
    filter(is.na(flag.x) | is.na(flag.y)) %>%
    mutate(i = as.numeric(i),
           j = as.numeric(j),
           mi = as.numeric(mi),
           type = as.numeric(type),
           lanes = as.numeric(lanes),
           vdf = as.numeric(vdf),
           modYear = as.numeric(yr))
  
  #Compare DomesticNetwork.csv
  compDist <- full_join(cDist, nDist, by = join_by(cINODE, JNODE, LENGTH, dom_ratio, DmstDist)) %>%
    filter(is.na(flag.x) | is.na(flag.y)) %>%
    mutate(modYear = as.numeric(yr))
  
  #APPEND for full list####
  loopNodes <- loopNodes %>% rbind(compNodes)
  loopLinks <- loopLinks %>% rbind(compLinks)
  loopDistance <- loopDistance %>% rbind(compDist)
  
}

#Added Nodes and Links####
t1 <- loopNodes %>%
  filter(!is.na(flag.y)) %>%
  select(-modYear) %>%
  distinct() %>%
  rename(NODE = node) %>%
  left_join(allNodes, by = "NODE") %>%
  select(TIPID) %>%
  distinct()

t2 <- loopLinks %>%
  filter(!is.na(flag.y)) %>%
  mutate(linkID = paste(i, j, sep = "-")) %>%
  select(linkID) %>%
  distinct() %>%
  left_join(projCode, by = c("linkID")) %>%
  select(TIPID) %>%
  unique()

t3 <- loopDistance%>%
  filter(!is.na(flag.y)) %>%
  mutate(linkID = paste(cINODE, JNODE, sep = "-")) %>%
  select(linkID) %>%
  distinct() %>%
  left_join(projCode, by = c("linkID")) %>%
  select(TIPID) %>%
  unique()

add_chTIPID <- rbind(t1, t2, t3) %>%
  left_join(in_MHN_hwyproj, by = "TIPID") %>%
  select(TIPID:RSP_ID) %>%
  distinct() %>%
  left_join(confIDs, by = "TIPID") %>%
  filter(is.na(flag))%>%
  filter(!is.na(TIPID))

#Removed Nodes and Links####
t1 <- loopNodes %>%
  filter(is.na(flag.y)) %>%
  distinct() %>%
  rename(NODE = node) %>%
  left_join(allNodes, by = "NODE") %>%
  select(TIPID) %>%
  distinct()

t2 <- loopLinks %>%
  filter(is.na(flag.y)) %>%
  mutate(linkID = paste(i, j, sep = "-")) %>%
  select(linkID) %>%
  distinct() %>%
  left_join(projCode, by = c("linkID")) %>%
  select(TIPID) %>%
  unique()

t3 <- loopDistance%>%
  filter(is.na(flag.y)) %>%
  mutate(linkID = paste(cINODE, JNODE, sep = "-")) %>%
  select(linkID) %>%
  distinct() %>%
  left_join(projCode, by = c("linkID")) %>%
  select(TIPID) %>%
  unique()

rem_chTIPID <- rbind(t1, t2, t3) %>%
  left_join(in_MHN_hwyproj, by = "TIPID") %>%
  select(TIPID:RSP_ID) %>%
  distinct() %>%
  left_join(confIDs, by = "TIPID") %>%
  filter(is.na(flag)) %>%
  filter(!is.na(TIPID))

#Export####
if(nrow(add_chTIPID) > 1 | nrow(rem_chTIPID) > 1){
  print("UH OH, there's changes here attributed to features that aren't associated with an expected TIPID")
  exportList <- list(added = add_chTIPID, removed = rem_chTIPID)
  write.xlsx(exportList, qc_out_file)
  stop("REVIEW ../Output/QC/batchinTIPIDs.xlsx")
}else{
  print("all good to go")
}

