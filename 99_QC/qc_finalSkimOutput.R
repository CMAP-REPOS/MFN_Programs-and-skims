
#Define paths and libraries
currentDir = "S:/AdminGroups/ResearchAnalysis/kcc/FY25/MFN/Current_copies/Skims_Current/Scenario2_wLogistics140"
newDir = "S:/AdminGroups/ResearchAnalysis/kcc/FY25/MFN/Current_copies/Skims_New/Scenario2_wLogistics140"

currentFol = paste("Meso_Freight_Skim_Setup_FY19_", year, "\Database\SAS\outputs")


library(tidyverse)

years = c(2022, 2030, 2040, 2050)
scen = c(100, 200)
smFiles = c("cmap_data_truck_EE_poe", "cmap_data_zone_centroids", "data_mesozone_centroids",
            "data_mesozone_gcd", "data_modepath_airports")
yrFiles = c("cmap_data_zone_employment", "cmap_data_zone_skims", "data_mesozone_skims")
chFiles = c("cmap_data_truck_IE_poe", "data_modepath_miles", "data_modepath_ports", "data_modepath_skims")

#Compare within new run####
#--Confirm universal data is consistent across folders####
#Cmap_data_truck_EE_poe.csv 
#cmap_data_zone_centroids.csv 
#data_mesozone_centroids.csv 
#data_mesozone_gcd.csv 
#data_modepath_airports.csv 
i = 1
setwd(newDir)
for(file in smFiles){
  print(file)
  for(year in years){
    for(sc in scen){
      inFile = paste(newDir, "/Meso_Freight_Skim_Setup_c24q4_", year, "/Database/SAS/outputs/", sc, "/", file, "_", year, ".csv", sep = "")
      
      if(i == 1){
        print(paste(year, sc, sep = "-"))
        in1 <- read.csv(inFile)
        i=i+1
      }else{
        print(paste(year, sc, sep = "-"))
        in2 <- read.csv(inFile)
        
        resp = all.equal(in1, in2)
        if(resp != TRUE){stop()}
        i=i+1
        if(i > length(scen)*length(years)){
          i = 1
          print("i reset")
          }
        
      }
    }
  }
}

#--Confirm non-scenario specific data is consistent across scenarios (different years)####
for(file in yrFiles){
  print(file)
  for(year in years){
    inFile1 = paste(newDir, "/Meso_Freight_Skim_Setup_c24q4_", year, "/Database/SAS/outputs/100", "/", file, "_", year, ".csv", sep = "")
    inFile2 = paste(newDir, "/Meso_Freight_Skim_Setup_c24q4_", year, "/Database/SAS/outputs/200", "/", file, "_", year, ".csv", sep = "")
    in1 <- read.csv(inFile1)
    in2 <- read.csv(inFile2)
    resp = all.equal(in1, in2)
    if(resp != TRUE){stop()}
  }
}

#Compare against previous version####
#Make sure things haven't changed that shouldn't change
#need to understand the universe of what's changing and how first

#Should be no change from current --> new