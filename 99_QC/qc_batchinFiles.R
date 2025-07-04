#KCazzato 3/25/2025
#This script reviews the batchin files for the Freight network skimming
#Files produced by batch_domestic_scen_working.py
args = commandArgs(trailingOnly=T)
oldconf = as.character(args[1])
inBaseYr = as.integer(args[2])
inFirstYr = as.integer(args[3])
inLastYr = as.integer(args[4])
i = inFirstYr
while(i <= inLastYr){
  if(i == inFirstYr){
    years <- list(inBaseYr, inFirstYr)
  }else{
    years <-append(years, i)
  }
  i = i+5
}


oldconfMFN = paste("../Input/MFN_", oldconf, ".gdb", sep="")
currentDir = paste("../Input/BatchinFiles_", oldconf, sep="")
MHN_Dir = paste("../Input/MHN_", oldconf, ".gdb", sep="")
newDir = "../Output/BatchinFiles"
outputDir = "../Output/QC"
outFile = "../Output/QC/batchinTIPIDs.xlsx"

#LOAD LIBRARIES, DATA, AND VARIABLES####
packages <- c("tidyverse", "readxl", "openxlsx", "sf")

package.check <- lapply(
  packages,
  FUN = function(x) {
    if (!require(x, character.only = TRUE)) {
      install.packages(x, dependencies = TRUE)
      library(x, character.only = TRUE)
    }
  }
)

files = c("cos_ntwk.txt", "DomesticPipelineNetwork.csv", "lines.in", "nec_19_ntwk.txt", "p1718_ntwk.txt")

#MHN formatting data
in_MHN_hwyproj_coding <- read_sf(dsn = MHN_Dir, layer = "hwyproj_coding", crs = 26771)
in_MHN_hwyproj <- read_sf(dsn = MHN_Dir, layer = "hwyproj", crs = 26771)

#Define function for reading base_ntwk.txt and formatting####
readBaseNtwk <- function(file){
  in1 <- scan(file, what = character(), sep = "\n", skip = 2)
  
  sep1 <- data.frame(X = in1) %>%
    mutate(Index = 1:length(in1),
           FlagLinks = str_detect(X, "c i   j   mi"),
           RemVal = ifelse(FlagLinks == TRUE, Index, NA)) %>%
    fill(RemVal, .direction = "updown") 
}

fmtNodes <- function(df){
  nodes <- df %>%
    filter(Index < RemVal) %>%
    filter(Index > 2) %>%
    select(X) %>%
    separate(X, into = c("c", "node", "x",  "y",  "UI1"), sep = "  ")
  
}

fmtLinks <- function(df){
  links <- df %>%
    filter(Index > (RemVal + 1))%>%
    select(X) %>%
    separate(X, into = c("c", "i", "j", "mi", "modes", "type", "lanes", "vdf", "ul1", "ul2", "ul3"), sep = "  ")
  
}

#Format MHN Project Information####
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

#Compare static data####
print("QA/QC STATIC DATA")
for(yr in years){
  for(file in files){
    #Load current data
    fileC = paste(currentDir, "/scen_", yr, "/", file, sep = "")
    in1 <- scan(fileC, what = character(), sep = "\n", skip = 2)
    
    #Load new data
    fileN = paste(newDir, "/scen_", yr, "/", file, sep = "")
    in2 <- scan(fileN, what = character(), sep = "\n", skip = 2)
    
    #Compare
    resp = all.equal(in1, in2)
    if(resp != TRUE){stop()} 
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
for(yr in years){
  #LOAD DATA####
  #Load current data
  fileC = paste(currentDir, "/scen_", yr, "/base_ntwk.txt", sep = "")
  c1 <- readBaseNtwk(fileC)
  cNodes <- fmtNodes(c1) %>% mutate(flag = "current")
  cLinks <- fmtLinks(c1) %>% mutate(flag = "current")

  fileC = paste(currentDir, "/scen_", yr, "/DomesticNetwork.csv", sep = "")
  cDist <- read.csv(fileC) %>% mutate(flag = "current")
  
  #Load new data
  fileN = paste(newDir, "/scen_", yr, "/base_ntwk.txt", sep = "")
  n1 <- readBaseNtwk(fileN)
  nNodes <- fmtNodes(n1) %>% mutate(flag = "new")
  nLinks <- fmtLinks(n1) %>% mutate(flag = "new")
  
  fileN = paste(newDir, "/scen_", yr, "/DomesticNetwork.csv", sep = "")
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
  filter(is.na(flag))

#Removed Nodes and Links####
t1 <- loopNodes %>%
  filter(is.na(flag.y)) %>%
  select(-modYear) %>%
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
  filter(is.na(flag))

#Export####
if(nrow(add_chTIPID) > 1 | nrow(rem_chTIPID) > 1){
  print("UH OH, there's changes here attributed to features that aren't associated with an expected TIPID")
  exportList <- list(added = add_chTIPID, removed = rem_chTIPID)
  write.xlsx(exportList, outFile)
  stop("REVIEW ../Output/QC/batchinTIPIDs.xlsx")
}else{
  print("all good to go")
}

