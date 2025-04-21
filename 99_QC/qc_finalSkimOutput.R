
#1. SET UP####
library(tidyverse)
library(readxl)
library(filesstrings)

#--Read input####
in1 <- suppressWarnings(read.table("../../Input/path_inputs.txt", header=TRUE, sep = "="))

#--Define paths and create folders####
inConf = str_replace_all(in1$value[1], " ", "")
newDir = str_replace_all(in1$value[2], " ", "")

setupName = "/Model_Setups/Meso_Freight_Skim_Setup_"

newFolName = paste(setupName,inConf, "_", sep = "")

outDir = paste(newDir, "/Skim_Output", sep = "")
out100 = paste(outDir, "/No_LogNode140", sep = "")
out200 = paste(outDir, "/LogNode140", sep = "")
outReport = paste(newDir, "/Reports", sep = "")
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
years = c(2022, 2030, 2040, 2050)
scen = c(100, 200)
smFiles = c("cmap_data_truck_EE_poe", "cmap_data_zone_centroids", "data_mesozone_centroids",
            "data_mesozone_gcd", "data_modepath_airports")
yrFiles = c("cmap_data_zone_employment", "cmap_data_zone_skims", "data_mesozone_skims")
scFiles = c("cmap_data_truck_IE_poe", "data_modepath_miles", "data_modepath_skims", "data_modepath_ports")

#2. Compare within new run####
#--Confirm universal data is consistent across folders####
print("CHECKING UNIVERSAL DATA")
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
      inFile = paste(newDir, newFolName, year, "/Database/SAS/outputs/", sc, "/", file, "_", year, ".csv", sep = "")
      
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
          print(paste(file, " completed", sep = ""))
          }
        
      }
    }
  }
}

#--Confirm non-scenario specific data is consistent across scenarios (different years)####
print("CHECKING YEAR SPECIFIC DATA")
cat("CHECKING YEAR SPECIFIC DATA \n", file =report,append=TRUE)

for(file in yrFiles){
  cat(file, file =report,append=TRUE)
  cat("\n", file =report,append=TRUE)
  for(year in years){
    cat(year, file =report,append=TRUE)
    cat("\n", file =report,append=TRUE)
    inFile1 = paste(newDir, newFolName, year, "/Database/SAS/outputs/100", "/", file, "_", year, ".csv", sep = "")
    inFile2 = paste(newDir, newFolName, year, "/Database/SAS/outputs/200", "/", file, "_", year, ".csv", sep = "")
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
year = 2022
sc = 100
for(file in smFiles){
  inFile = paste(newDir, newFolName, year, "/Database/SAS/outputs/", sc, "/", file, "_", year, ".csv", sep = "")
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
    inFile = paste(newDir, newFolName, year, "/Database/SAS/outputs/", sc, "/", file, "_", year, ".csv", sep = "")
    file.copy(inFile, outDir)
  }
  
  
}

for(file in scFiles){
  for(year in years){
    for(sc in scen){
      if(sc == 100){od = out100}else{od = out200}
      inFile = paste(newDir, newFolName, year, "/Database/SAS/outputs/", sc, "/", file, "_", year, ".csv", sep = "")
      file.copy(inFile, od)
    }
  }
  
  
}
