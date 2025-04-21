## Step5_determine_pipeline_costs.R
##  Craig Heither, rev. 05-17-2018
##
##   Calculate pipeline network costs and add them to data_modepath_miles.csv for final version.
##
##   revised 06-21-2017: Added code to truckDrayageEveryOrigin & truckDrayageEveryDest functions
##                       to remove false intrazonal pairs.
##
##   revised 09-07-2017: Added code to remove paths that do not actually use pipelines (distDms==0),
##                       remove unrealistic pipeline connections and add intrazonal pipeline.
##
##   revised 05-17-2018: Added QC code to end to verify all available mode paths in data_modepath_skims.csv
##                       are included in data_modepath_miles.csv.
## ---------------------------------------------------------------
args = commandArgs(trailingOnly=T)
#setwd('D://cmh_data//FY18_Meso_Freight_Skim_Setup//Database//SAS') 
source("../get_dir.R")  		## -- Intelligently create DirPath variable

scenario = args[1]
year = args[2]
InDir1 = file.path(DirPath, "emmemat")
InDir2 = file.path(DirPath, paste0("SAS/outputs/", scenario))
infile1 = paste0("data_mesozone_gcd_",year, ".csv", sep = "")
infile2 = paste0("data_modepath_miles1_",year, ".csv", sep = "")
infile3 = paste0("data_modepath_skims1_",year, ".csv", sep = "")
outfile1 = paste0("data_modepath_miles_",year, ".csv", sep = "")	
outfile2 = paste0("data_modepath_skims_",year, ".csv", sep = "")

maxZn <- 300					## -- number of zones Emmebank is dimensioned for
maxOb <- maxZn * maxZn
znUsed <- 272					## -- total number of highway zones actually used (includes 140) CSX Crete (zn 140) is included but not connected to network
pipeUsed <- 254					## -- total number of pipeline zones actually used (logistics nodes not included in pipeline network)
LastCmap <- 132					## -- Last CMAP zone
LastUS <- 273					## -- Last non-CMAP US zone

## -- Pipeline Transport Costs --
LhCharge = 0.010				## -- pipeline linehaul charge ($ per ton-mile)
PipeSpeed = 4					## -- speed in pipeline (MPH)
HandFeeCrude = 1.05				## -- handling fee - crude oil ($ per ton)
HandFeePetro = 0.92				## -- handling fee - petroleum products ($ per ton)
HandFeeCoal = 1.26				## -- handling fee - coal n.e.c. ($ per ton)
PipeHandTime = 4				## -- handling time (hours) -- truck loading time 
# --- Truck Drayage Costs ---
DrayCharge = 0.08				## -- drayage charge ($ per ton-mile) [LTL/FTL for 53' truck]
DrayIntraSpeed = 45				## -- intrazonal truck drayage speed (MPH)
DrayInterSpeed = 65				## -- interzonal truck drayage speed (MPH)


## ---------------------------------------------------------------

#loadPackage <- function (package) {
            #    if(!package %in% .packages(all = TRUE)) {
            #                    install.packages(package, repos = "http://cran.r-project.org")
            #    }
            #    eval(parse(text=paste("library(", package, ")", sep="")))
#}
#loadPackage("data.table")
#loadPackage("reshape2")
#loadPackage("stringr")
#loadPackage("tidyverse")
#install.packages(c("data.table", "reshape2", "stringr", "tidyverse"))
library(data.table)
library(reshape2)
library(stringr)
library(tidyverse)

## ------------------------------------------------------------------------------------
## ====================================
## -- FUNCTIONS --
## ====================================
## -- Function to read Emme binary matrix files and convert to usable data - highway
convertMatrix <- function(file1,maxnum,zones,zUsed) {
	a <- readBin(file1, numeric(), n=maxnum, size=4)
	a1 <- matrix(a, nrow=zones, ncol=zones)
	a2 <- as.data.table(melt(a1))
	setnames(a2, c("Var1","Var2"), c("q","p"))
	a2 <- a2[p<=zUsed & q<=zUsed]				## -- remove unused zones
	a2[p==zUsed, p:=399]						## -- re-label Mexico
	a2[q==zUsed, q:=399]
	a2[p==zUsed-1, p:=310]						## -- re-label Canada
	a2[q==zUsed-1, q:=310]	
	## -- skims don't include Honolulu (179), Hawaii remainder (180) or CMAP zone in original FAF data (182)
	a2[p>=zUsed-92 & p<=zUsed-2, p:=p+3L]
	a2[q>=zUsed-92 & q<=zUsed-2, q:=q+3L]
	a2[p==zUsed-93, p:=181]
	a2[q==zUsed-93, q:=181]
	a2 <- a2[p %in% c(1:132,151:178,181,183:273,310,399) & q %in% c(1:132,151:178,181,183:273,310,399)]
	a2 <- a2[value>0 & value<99999]
	a2[,value:=round(value, 1)]
	a2
}

## -- Function to read Emme binary matrix files and convert to usable data - pipeline
convertPipeMatrix <- function(file1,maxnum,zones,zUsed) {
    ## -- no logistics nodes included 
	a <- readBin(file1, numeric(), n=maxnum, size=4)
	a1 <- matrix(a, nrow=zones, ncol=zones)
	a2 <- as.data.table(melt(a1))
	setnames(a2, c("Var1","Var2"), c("q","p"))
	a2 <- a2[p<=zUsed & q<=zUsed]				## -- remove unused zones
	a2[p==zUsed, p:=399]						## -- re-label Mexico
	a2[q==zUsed, q:=399]
	a2[p==zUsed-1, p:=310]						## -- re-label Canada
	a2[q==zUsed-1, q:=310]	
	## -- skims don't include Honolulu (179), Hawaii remainder (180) or CMAP zone in original FAF data (182)
	a2[p>=zUsed-92 & p<=zUsed-2, p:=p+21L]
	a2[q>=zUsed-92 & q<=zUsed-2, q:=q+21L]
	a2[p==zUsed-93, p:=181]
	a2[q==zUsed-93, q:=181]
	a2[p>=zUsed-121 & p<=zUsed-94, p:=p+18L]
	a2[q>=zUsed-121 & q<=zUsed-94, q:=q+18L]
	a2 <- a2[p %in% c(1:132,151:178,181,183:273,310,399) & q %in% c(1:132,151:178,181,183:273,310,399)]
	a2 <- a2[value>0 & value<99999]
	a2[,value:=round(value, 1)]
	a2
}


## -- Merge skim distance and domestic distance matrices
joinPipeline_matrices <- function(dt1,dt2) {
	setkey(dt1,p,q)
	setkey(dt2,p,q)
	dt1 <- merge(dt1, dt2, by=c("p","q"), all.x=T)
	dt1[is.na(distDms), distDms:=0]
	dt1
}

## -- Add truck drayage from every zone to original skim origins
truckDrayageEveryOrigin <- function(dt1,dt2) {
	setkey(dt1,p)
	dt3 <- merge(dt1, dt2, by=c("p"), all.x=T, allow.cartesian=T)
	dt3 <- dt3[p1 != q]						##-- remove false intrazonal pairs
	dt3[,TotalNtwkMiles:=dist+Hdist]
	dt3[,LhMilesDms:=distDms]				## -- pipeline section
	dt3[,DrayMilesDms:=HdistDms]			## -- truck section 
	dt3[,c("p","TrDray","TrDrayDms"):=NULL]
	setnames(dt3, c("p1"), c("p"))
	dt3
}

## -- Add truck drayage from original skim destinations to every zone
truckDrayageEveryDest <- function(dt1,dt2) {
	setkey(dt1,q)
	dt3 <- merge(dt1, dt2, by=c("q"), all.x=T, allow.cartesian=T)
	dt3 <- dt3[p != q1]						##-- remove false intrazonal pairs
	dt3[,TotalNtwkMiles:=dist+Hdist]
	dt3[,LhMilesDms:=distDms]				## -- pipeline section
	dt3[,DrayMilesDms:=HdistDms]			## -- truck section 
	dt3[,c("q","TrDray","TrDrayDms"):=NULL]
	setnames(dt3, c("q1"), c("q"))
	dt3
}

## -- Find minimum distance pipeline-truck path among all available options
minimumPath <- function(dt1,val) {
	dt1 <- rbindlist(l, use.names=T, fill=T)
	setorder(dt1,p,q,TotalNtwkMiles)
	setkey(dt1,p,q)
	dt1[,ID:=seq_len(.N), by=c("p","q")]
	dt1 <- dt1[ID==1]							## -- keep only shortest paths
	dt1[,MinPath:=val]
	dt1
}

## -- Get Intrazonal Pipeline Distances
pipeIntra <- function(dt1,dt2,val1,val2,val3) {
	dt1 <- dt1[!duplicated(p)]
	dt1 <- dt1[p > val2 & p <= val3]
	dt1[,q:=p]
	dt1[,MinPath:=val1]
	setnames(dt1, c("value"), c("dist"))
	setkey(dt1,p)
	setkey(dt2,p)
	dt1 <- merge(dt1, dt2, by=c("p"), all.x=T)
	## -- Assume dray is one-half of linehaul
	dt1[,dist:=TrDray]
	dt1[,TrDray:=TrDray/2]
	dt1[,TotalNtwkMiles:=dist+TrDray]
	dt1[,LhMilesDms:=dist]
	dt1[,DrayMilesDms:=TrDray]
	dt1
}

## ------------------------------------------------------------------------------------
setwd(InDir2)
## -- Intrazonal Drayage Highway --
intra <- fread(infile1)
intra <- intra[Production_zone==Consumption_zone]
intra <- intra[, list(Production_zone,GCD)]
setnames(intra, c("Production_zone","GCD"), c("p","TrDray"))
intra[, TrDray:=round(TrDray, 1)]
intra[, TrDrayDms:=TrDray]
intra[p>273, TrDrayDms:=0]
setkey(intra,p)

setwd(InDir1)
## -- Highway Network --
h1 <- convertMatrix("mf31.emx", maxOb, maxZn, znUsed)	
setnames(h1, c("value"), c("Hdist"))
h2 <- convertMatrix("mf41.emx", maxOb, maxZn, znUsed)	
setnames(h2, c("value"), c("HdistDms"))
h1 <- merge(h1, h2, by=c("p","q"), all.x=T)
h1[is.na(HdistDms), HdistDms:=0]
setnames(h1, c("p","q"), c("p1","p"))
setkey(h1,p)
h1b <- copy(h1)
setnames(h1b, c("p","p1"), c("q1","q"))
setkey(h1b,q)

## =======================================================
## -- Crude Oil Network (SCTG 16) --
## =======================================================
p1 <- convertPipeMatrix("mf71.emx", maxOb, maxZn, pipeUsed)	
setnames(p1, c("value"), c("dist"))
p2 <- convertPipeMatrix("mf72.emx", maxOb, maxZn, pipeUsed)	
setnames(p2, c("value"), c("distDms"))
p1 <- joinPipeline_matrices(p1,p2)

p1 <- merge(p1, intra, by=c("p"), all.x=T)				## -- Part 1: Add truck drayage at origin
base <- copy(p1)
p1[(p==310 & q==399) | (p==399 & q==310), distDms:=NA]	## -- no Canada-Mexico linkage
p1 <- p1[distDms>0]										## -- actual pipeline must be used
p1[, diff:=dist-distDms]
p1[abs(diff)<=1, distDms:=dist]							## -- adjust for small discrepancies between domestic and total LH
p1[,TotalNtwkMiles:=dist+TrDray]
p1[,LhMilesDms:=distDms]
p1[,DrayMilesDms:=TrDrayDms]
alt1 <- truckDrayageEveryOrigin(base,h1)				## -- Part 2: Add truck drayage from every zone to original skim origins
alt1 <- alt1[distDms>0]									## -- actual pipeline must be used	
alt2 <- truckDrayageEveryDest(base,h1b) 				## -- Part 3: Add truck drayage from original skim destinations to every zone
alt2 <- alt2[distDms>0]									## -- actual pipeline must be used	
l = list(p1,alt1,alt2)
CrudeOil <- minimumPath(l,55)							## -- combine all zonal options and find minimum path	

## =======================================================
## -- Petroleum Products Network (SCTG 17-18) --
## =======================================================
p1 <- convertPipeMatrix("mf73.emx", maxOb, maxZn, pipeUsed)	
setnames(p1, c("value"), c("dist"))
p2 <- convertPipeMatrix("mf74.emx", maxOb, maxZn, pipeUsed)	
setnames(p2, c("value"), c("distDms"))
p1 <- joinPipeline_matrices(p1,p2)

p1 <- merge(p1, intra, by=c("p"), all.x=T)				## -- Part 1: Add truck drayage at origin
base <- copy(p1)
p1[(p==310 & q==399) | (p==399 & q==310), distDms:=NA]	## -- no Canada-Mexico linkage
p1 <- p1[distDms>0]										## -- actual pipeline must be used
p1[, diff:=dist-distDms]
p1[abs(diff)<=1, distDms:=dist]							## -- adjust for small discrepancies between domestic and total LH
p1[,TotalNtwkMiles:=dist+TrDray]
p1[,LhMilesDms:=distDms]
p1[,DrayMilesDms:=TrDrayDms]

alt1 <- truckDrayageEveryOrigin(base,h1)				## -- Part 2: Add truck drayage from every zone to original skim origins
alt1 <- alt1[distDms>0]									## -- actual pipeline must be used	
alt2 <- truckDrayageEveryDest(base,h1b) 				## -- Part 3: Add truck drayage from original skim destinations to every zone
alt2 <- alt2[distDms>0]									## -- actual pipeline must be used	
l = list(p1,alt1,alt2)
Petrol <- minimumPath(l,56)								## -- combine all zonal options and find minimum path	

## =======================================================
## -- Coal n.e.c. Network (SCTG 19) --
## =======================================================
p1 <- convertPipeMatrix("mf75.emx", maxOb, maxZn, pipeUsed)	
setnames(p1, c("value"), c("dist"))
p2 <- convertPipeMatrix("mf76.emx", maxOb, maxZn, pipeUsed)	
setnames(p2, c("value"), c("distDms"))
p1 <- joinPipeline_matrices(p1,p2)

p1 <- merge(p1, intra, by=c("p"), all.x=T)				## -- Part 1: Add truck drayage at origin
base <- copy(p1)
p1[(p==310 & q==399) | (p==399 & q==310), distDms:=NA]	## -- no Canada-Mexico linkage
p1 <- p1[distDms>0]										## -- actual pipeline must be used
p1[, diff:=dist-distDms]
p1[abs(diff)<=1, distDms:=dist]							## -- adjust for small discrepancies between domestic and total LH
p1[,TotalNtwkMiles:=dist+TrDray]
p1[,LhMilesDms:=distDms]
p1[,DrayMilesDms:=TrDrayDms]

alt1 <- truckDrayageEveryOrigin(base,h1)				## -- Part 2: Add truck drayage from every zone to original skim origins
alt1 <- alt1[distDms>0]									## -- actual pipeline must be used	
alt2 <- truckDrayageEveryDest(base,h1b) 				## -- Part 3: Add truck drayage from original skim destinations to every zone
alt2 <- alt2[distDms>0]									## -- actual pipeline must be used
l = list(p1,alt1,alt2)
CoalNec <- minimumPath(l,57)							## -- combine all zonal options and find minimum path	

l = list(CrudeOil,Petrol,CoalNec)
pipelines <- rbindlist(l, use.names=T, fill=T)
## We have been generous in creating pipeline connections - now introduce some realism by limiting to interchanges where LhMilesDms >= 50% of TotalNtwkDms
pipelines <- pipelines[LhMilesDms/TotalNtwkMiles >= 0.5 & DrayMilesDms <= 200]

## =======================================================
## -- Allow Intrazonal Pipeline Movements (Outside CMAP) --
## =======================================================
sc16 <- convertPipeMatrix("mf71.emx", maxOb, maxZn, pipeUsed)	
sc16 <- pipeIntra(sc16,intra,55,LastCmap,LastUS)
sc17 <- convertPipeMatrix("mf73.emx", maxOb, maxZn, pipeUsed)	
sc17 <- pipeIntra(sc17,intra,56,LastCmap,LastUS)
sc19 <- convertPipeMatrix("mf75.emx", maxOb, maxZn, pipeUsed)	
sc19 <- pipeIntra(sc19,intra,57,LastCmap,LastUS)
l = list(pipelines,sc16,sc17,sc19)
pipelines <- rbindlist(l, use.names=T, fill=T)	


## =======================================================
## -- Pipeline Costs and Times --
## =======================================================
#pipelines[,TotalNtwkMiles:=round(TotalNtwkMiles, digits=2)]
#pipelines[,LhMilesDms:=round(LhMilesDms, digits=2)]
#pipelines[,DrayMilesDms:=round(DrayMilesDms, digits=2)]
pipelines[MinPath==55 & is.na(TrDray), tm55:=dist/PipeSpeed + Hdist/DrayInterSpeed + PipeHandTime]			## -- Mode 55, time using interzonal drayage
pipelines[MinPath==55 & !is.na(TrDray), tm55:=dist/PipeSpeed + TrDray/DrayIntraSpeed + PipeHandTime]		## -- Mode 55, time using intrazonal drayage
pipelines[MinPath==55 & is.na(TrDray), cst55:=dist*LhCharge + Hdist*DrayCharge + HandFeeCrude]				## -- Mode 55, cost using interzonal drayage
pipelines[MinPath==55 & !is.na(TrDray), cst55:=dist*LhCharge + TrDray*DrayCharge + HandFeeCrude]			## -- Mode 55, cost using intrazonal drayage

pipelines[MinPath==56 & is.na(TrDray), tm56:=dist/PipeSpeed + Hdist/DrayInterSpeed + PipeHandTime]			## -- Mode 56, time using interzonal drayage
pipelines[MinPath==56 & !is.na(TrDray), tm56:=dist/PipeSpeed + TrDray/DrayIntraSpeed + PipeHandTime]		## -- Mode 56, time using intrazonal drayage
pipelines[MinPath==56 & is.na(TrDray), cst56:=dist*LhCharge + Hdist*DrayCharge + HandFeePetro]				## -- Mode 56, cost using interzonal drayage
pipelines[MinPath==56 & !is.na(TrDray), cst56:=dist*LhCharge + TrDray*DrayCharge + HandFeePetro]			## -- Mode 56, cost using intrazonal drayage

pipelines[MinPath==57 & is.na(TrDray), tm57:=dist/PipeSpeed + Hdist/DrayInterSpeed + PipeHandTime]			## -- Mode 57, time using interzonal drayage
pipelines[MinPath==57 & !is.na(TrDray), tm57:=dist/PipeSpeed + TrDray/DrayIntraSpeed + PipeHandTime]		## -- Mode 57, time using intrazonal drayage
pipelines[MinPath==57 & is.na(TrDray), cst57:=dist*LhCharge + Hdist*DrayCharge + HandFeeCoal]				## -- Mode 57, cost using interzonal drayage
pipelines[MinPath==57 & !is.na(TrDray), cst57:=dist*LhCharge + TrDray*DrayCharge + HandFeeCoal]				## -- Mode 57, cost using intrazonal drayage

## -- verify
x <- pipelines[MinPath==55 & (is.na(cst55) | is.na(tm55))]
if(nrow(x)>0) {cat("ERROR: SCTG 16 mode entries with missing costs or times:", nrow(x), fill=T)}
x <- pipelines[MinPath==56 & (is.na(cst56) | is.na(tm56))]
if(nrow(x)>0) {cat("ERROR: SCTG 17-18 mode entries with missing costs or times:", nrow(x), fill=T)}
x <- pipelines[MinPath==57 & (is.na(cst57) | is.na(tm57))]
if(nrow(x)>0) {cat("ERROR: SCTG 19 mode entries with missing costs or times:", nrow(x), fill=T)}

## =======================================================
## -- Final Files --
## =======================================================
setwd(InDir2)
pipeMiles <- pipelines[, list(p,q,MinPath,TotalNtwkMiles,LhMilesDms,DrayMilesDms)]
pipeMiles[, temp:=TotalNtwkMiles-(LhMilesDms+DrayMilesDms)]
pipeMiles[, IntlShipMiles:=mapply(max, temp, 0)]	
pipeMiles[, c("CmapPsTR","CmapPsRL","RlDwlCode","RlTrnfr"):=0]
setnames(pipeMiles, c("p","q","LhMilesDms","DrayMilesDms"), c("Origin","Destination","DmsLhMiles","DmsDrayMiles"))
pipeMiles[, temp:=NULL]


Miles <- fread(infile2)
l = list(Miles,pipeMiles)
Miles <- rbindlist(l, use.names=T, fill=T)
setorder(Miles,Origin,Destination,MinPath)
write.csv(Miles, outfile1, row.names=F)
if(file.exists(infile2)){file.remove(infile2)} 
## -- QC
x <- Miles[TotalNtwkMiles==0]
if(nrow(x)>0) {cat("ERROR: Instances where TotalNtwkMiles is missing:", nrow(x), fill=T)}
x <- Miles[DmsLhMiles==0 & Origin<=LastUS & Destination<=LastUS & !MinPath %in% c(51:54)]
if(nrow(x)>0) {cat("ERROR: Instances where DmsLhMiles is missing:", nrow(x), fill=T)}
x <- Miles[DmsDrayMiles==0 & !MinPath %in% c(3,13,31,46) & Origin<=LastUS & Destination<=LastUS]
if(nrow(x)>0) {cat("ERROR: Instances where DmsDrayMiles is missing:", nrow(x), fill=T)}


Costs <- fread(infile3)
Costs[Origin==1 & Destination==1, c("time55","time56","time57","cost55","cost56","cost57"):=NA]		## -- reset to missing
setnames(pipelines, c("p","q"), c("Origin","Destination"))
pt1 <- pipelines[tm55>0, list(Origin,Destination,tm55,cst55)]
pt2 <- pipelines[tm56>0, list(Origin,Destination,tm56,cst56)]
pt3 <- pipelines[tm57>0, list(Origin,Destination,tm57,cst57)]
setkey(pt1,Origin,Destination)
setkey(pt2,Origin,Destination)
setkey(pt3,Origin,Destination)
pt1 <- merge(pt1, pt2, by=c("Origin","Destination"), all.x=T, all.y=T)
pt1 <- merge(pt1, pt3, by=c("Origin","Destination"), all.x=T, all.y=T)
setkey(Costs,Origin,Destination)
newCost <- pt1[Costs]	
newCost[tm55>0, time55:=tm55]
newCost[cst55>0, cost55:=cst55]
newCost[tm56>0, time56:=tm56]
newCost[cst56>0, cost56:=cst56]
newCost[tm57>0, time57:=tm57]
newCost[cst57>0, cost57:=cst57]
newCost[,c("tm55","cst55","tm56","cst56","tm57","cst57"):=NULL]
write.csv(newCost, outfile2, row.names=F)
if(file.exists(infile3)){file.remove(infile3)} 

## =======================================================
## -- QC data_modepath_skims & data_modepath_miles --
## =======================================================
modes1 <- melt(newCost, id.vars=c("Origin","Destination"), measure.vars=paste0("time",1:57), variable.name="timepath", value.name="time", na.rm=T)
modes1 <- modes1 %>%
  mutate(MinPath = as.integer(str_replace(timepath, "time", ""))) %>%
  select(Origin, Destination, MinPath) %>%
  arrange(Origin, Destination, MinPath)
#modes1[,timepath:=str_replace(timepath, "time", "")]
#modes1[,MinPath:=as.integer(timepath)]
#modes1 <- modes1[,list(Origin,Destination,MinPath)]
#setkey(modes1,Origin,Destination,MinPath)

miles <- Miles[,list(Origin,Destination,MinPath,TotalNtwkMiles)]
setkey(miles,Origin,Destination,MinPath)
cat(nrow(modes1), "records in modepath file", fill=T)
cat(nrow(miles), "records in miles file", fill=T)
modes1 <- merge(modes1, miles, by=c("Origin","Destination","MinPath"), all.x=T)
chk <- modes1 %>% filter(is.na(TotalNtwkMiles))
if(nrow(chk)>0) {
  cat("*********************************************************",fill=T)
  cat("  ERROR:", nrow(chk), "records with missing miles", fill=T)
  cat("*********************************************************",fill=T)
}
