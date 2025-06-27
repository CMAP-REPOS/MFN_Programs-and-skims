#1. SET UP####
packages <- c("tidyverse", "readxl", "filesstrings")

## Now load or install&load all
package.check <- lapply(
  packages,
  FUN = function(x) {
    if (!require(x, character.only = TRUE)) {
      install.packages(x)
      library(x, character.only = TRUE)
    }
  }
)
#--Define paths and create folders####
args = commandArgs(trailingOnly=T)
newConf = args[1]
inBaseYr = as.integer(args[2])
inFirstYr = as.integer(args[3])
inLastYr = as.integer(args[4])
setupName = "../Skim_New/Model_Setups/Meso_Freight_Skim_Setup_"
newFolName = paste(setupName,newConf, "_", sep = "")

outDir = "../Skim_New/Skim_Output"
out100 = paste(outDir, "/No_LogNode140", sep = "")
out200 = paste(outDir, "/LogNode140", sep = "")
outReport = "../Output/QC"
report = paste(outReport, "/qc_finalSkimReport.txt", sep = "")

#--Delete Output Folder if it exists
if(file.exists(outDir) == TRUE){unlink(outDir, recursive = TRUE)}
if(file.exists(outReport) == TRUE){unlink(outReport, recursive = TRUE)}

#--Create Folders
dir.create(outDir)
dir.create(out100)
dir.create(out200)
dir.create(outReport)

#--Delete report if exists
if(file.exists(report) == TRUE){unlink(report, recursive = TRUE)}

#--Define Lists####
i = inFirstYr
while(i <= inLastYr){
  if(i == inFirstYr){
    years <- list(inBaseYr, inFirstYr)
  }else{
    years <-append(years, i)
  }
  i = i+5
}
scen = c(100, 200)
smFiles = c("cmap_data_truck_EE_poe", "cmap_data_zone_centroids", "data_mesozone_centroids",
            "data_mesozone_gcd", "data_modepath_airports")
yrFiles = c("cmap_data_zone_employment", "cmap_data_zone_skims", "data_mesozone_skims")
scFiles = c("cmap_data_truck_IE_poe", "data_modepath_miles", "data_modepath_skims", "data_modepath_ports")

#2. Compare within new run####
#--Confirm universal data is consistent across folders####
print("QA/QC CHECKING UNIVERSAL DATA")
cat("CHECKING UNIVERSAL DATA", file=report,append=TRUE)

i = 1
for(file in smFiles){
  cat(file, file =report,append=TRUE)
  cat("\n", file =report,append=TRUE)
  #close(report)
  for(year in years){
    cat(year, file =report,append=TRUE)
    cat("\n", file =report,append=TRUE)
    for(sc in scen){
      cat(sc, file =report,append=TRUE)  
      cat("\n", file =report,append=TRUE)
      inFile = paste(newFolName, year, "/Database/SAS/outputs/", sc, "/", file, "_", year, ".csv", sep = "")
      
      if(i == 1){
        in1 <- read.csv(inFile)
        i=i+1
      }else{
        in2 <- read.csv(inFile)
        
        resp = all.equal(in1, in2)
        if(resp != TRUE){stop()}
        i=i+1
        if(i > length(scen)*length(years)){
          i = 1
          }
        
      }
    }
  }
}

#--Confirm non-scenario specific data is consistent across scenarios (different years)####
print("QA/QC CHECKING YEAR SPECIFIC DATA")
cat("CHECKING YEAR SPECIFIC DATA \n", file =report,append=TRUE)

for(file in yrFiles){
  cat(file, file =report,append=TRUE)
  cat("\n", file =report,append=TRUE)
  for(year in years){
    cat(year, file =report,append=TRUE)
    cat("\n", file =report,append=TRUE)
    inFile1 = paste(newFolName, year, "/Database/SAS/outputs/100", "/", file, "_", year, ".csv", sep = "")
    inFile2 = paste(newFolName, year, "/Database/SAS/outputs/200", "/", file, "_", year, ".csv", sep = "")
    in1 <- read.csv(inFile1)
    in2 <- read.csv(inFile2)
    resp = all.equal(in1, in2)
    if(resp != TRUE){stop()}
  }
}

#3. Copy data to final location####
print("COPYING & RENNAMING DATA")
cat("COPYING & RENNAMING DATA \n", file=report,append=TRUE)

#--Move Files
#Files that are the same all years, all scenarios, go in 'Skim_Output' with amended name to remove year
year = inBaseYr
sc = 100
for(file in smFiles){
  inFile = paste(newFolName, year, "/Database/SAS/outputs/", sc, "/", file, "_", year, ".csv", sep = "")
  file.copy(inFile, outDir)
  
  currentName = paste(outDir,"/", file, "_", year, ".csv", sep = "")
  
  yrFlag = paste("_", year, sep = "")
  newName = str_split_i(file, yrFlag, 1)
  newFile = paste(outDir, "/",newName, ".csv", sep = "")
  
  file.rename(from = currentName, to = newFile)
  
}

#Files that are the same all scenarios, different years, go in 'Skim_Output'
for(file in yrFiles){
  for(year in years){
    inFile = paste(newFolName, year, "/Database/SAS/outputs/", sc, "/", file, "_", year, ".csv", sep = "")
    file.copy(inFile, outDir)
  }
  
  
}

for(file in scFiles){
  for(year in years){
    for(sc in scen){
      if(sc == 100){od = out100}else{od = out200}
      inFile = paste(newFolName, year, "/Database/SAS/outputs/", sc, "/", file, "_", year, ".csv", sep = "")
      file.copy(inFile, od)
    }
  }
  
  
}

