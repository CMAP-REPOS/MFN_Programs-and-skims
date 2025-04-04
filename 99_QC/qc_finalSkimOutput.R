
#1. SET UP####
library(tidyverse)
library(readxl)

in_modePath <- read_xlsx("S:/AdminGroups/ResearchAnalysis/kcc/FY25/MFN/Current_copies/Input/MFN_crosswalks.xlsx", sheet = "modePath")
in_ports <- read_xlsx("S:/AdminGroups/ResearchAnalysis/kcc/FY25/MFN/Current_copies/Input/MFN_crosswalks.xlsx", sheet = "Ports")
in_zones <- read_xlsx("S:/AdminGroups/ResearchAnalysis/kcc/FY25/MFN/Current_copies/Input/MFN_crosswalks.xlsx", sheet = "zones")
in_mesozones <- read_xlsx("S:/AdminGroups/ResearchAnalysis/kcc/FY25/MFN/Current_copies/Input/MFN_crosswalks.xlsx", sheet = "mesozones")
in_POE <- read_xlsx("S:/AdminGroups/ResearchAnalysis/kcc/FY25/MFN/Current_copies/Input/MFN_crosswalks.xlsx", sheet = "POE")

#--Define paths####
currentDir = "S:/AdminGroups/ResearchAnalysis/kcc/FY25/MFN/Current_copies/Skims_Current/Scenario2_wLogistics140"
newDir = "S:/AdminGroups/ResearchAnalysis/kcc/FY25/MFN/Current_copies/Skims_New/Scenario2_wLogistics140"
newFolName = "/Meso_Freight_Skim_Setup_c24q4_"
currentFolName = "/Meso_Freight_Skim_Setup_FY19_"

planUpdate = "no"

#--Define Lists####
years = c(2022, 2030, 2040, 2050)
scen = c(100, 200)
poeIDs <- c(3634:3648)
smFiles = c("cmap_data_truck_EE_poe", "cmap_data_zone_centroids", "data_mesozone_centroids",
            "data_mesozone_gcd", "data_modepath_airports")
yrFiles = c("cmap_data_zone_employment", "cmap_data_zone_skims", "data_mesozone_skims")

chFiles = c("cmap_data_truck_EE_poe", "cmap_data_zone_employment", "cmap_data_zone_skims", "data_mesozone_skims",
            "cmap_data_truck_IE_poe", "data_modepath_miles", "data_modepath_skims", "data_modepath_ports")
stFiles = c("cmap_data_zone_centroids", "data_mesozone_centroids", "data_mesozone_gcd", "data_modepath_airports")
allFiles = c("cmap_data_truck_EE_poe", "cmap_data_zone_employment", "cmap_data_zone_skims", "data_mesozone_skims",
             "cmap_data_truck_IE_poe", "data_modepath_miles", "data_modepath_skims", "data_modepath_ports", 
             "cmap_data_zone_centroids", "data_mesozone_centroids", "data_mesozone_gcd", "data_modepath_airports")

#--Define Empty DF for Comparison####
#depending on format, amend to full df then export as tab in xlsx, or just export
#truckEE as supplemental tab
all_TruckEE <- data.frame(Scenario = as.numeric(), Year = as.numeric(), Production_zone = as.integer(), Consumption_zone = as.integer(),
                          C_poe2 = as.integer(), C_poe = as.integer(), N_poe2 = as.integer(), N_poe = as.integer(), flag_Poe = as.logical(), flag_Poe2 = as.logical())
#truckIE as supplemental tab
all_TruckIE <- data.frame(Scenario = as.numeric(), Year = as.numeric(), Production_zone = as.integer(), Consumption_zone = as.integer(),
                          C_poe = as.integer(), N_poe = as.integer())

#znEmp as supplemental tab
all_znEmp <- data.frame(Scenario = as.numeric(), Year = as.numeric(), County = as.character(), currentEmp = as.integer(),
                        newEmp = as.integer(), Difference = as.integer(), Percent = as.numeric())

#modePort - visual QC; can try to build a geography crosswalk based on nearby ports
all_modePort <- data.frame(Scenario = as.numeric(), Year = as.numeric(), Production_zone = as.integer(), Consumption_zone = as.integer(),
                          Port_mesozoneNB = as.integer(), Port_NameNB = as.character(), Port_mesozoneB = as.numeric(), Port_NameB = as.character(),
                          flagC = as.numeric(), flagN = as.numeric())

#ZnSkim - filter to keep only OD pairs with differences
all_znSkim <- data.frame(Scenario = as.numeric(), Year = as.numeric(), OCounty= as.character(), DCounty= as.character(),
                         C_avPeak= as.numeric(), C_avOffPeak= as.numeric(), C_avMiles= as.numeric(), C_totMiles= as.numeric(), 
                         N_avPeak= as.numeric(),     N_avOffPeak= as.numeric(), N_avMiles= as.numeric(), N_totMiles= as.numeric(),  
                         diff_Peak= as.numeric(), diff_OffPeak= as.numeric(), diff_avMi= as.numeric(), diff_totMi= as.numeric())

#MesSkim - filter to keep only OD pairs with differences >= 1%
all_mesoSkim <- data.frame(Scenario = as.numeric(), Year = as.numeric(), OCounty= as.character(), DCounty= as.character(), currentTime= as.numeric(), 
                           newTime= as.numeric(), Difference= as.numeric(), Percent= as.numeric())

#modeMi  - find a filter; 
all_modeMi <- data.frame(Scenario = as.numeric(), Year = as.numeric(), Mode= as.character(), LogNode = as.numeric(), Perc_TotMi= as.numeric(),     
                         Perc_DmsLh= as.numeric(), Perc_DmsDray= as.numeric(), Perc_IntlShip= as.numeric(), Perc_PsTR= as.numeric(),      
                         Perc_PsRL= as.numeric(), Perc_NATrnFr= as.numeric(), Perc_NoZeroCode= as.numeric())
#modeSkim
all_modeSkim <- data.frame(Scenario = as.numeric(), Year = as.numeric(), Mode=as.character(), LogNode=as.numeric(), C_Time= as.numeric(), C_Cost= as.numeric(),    
                           N_Time= as.numeric(), N_Cost= as.numeric(), perc_Time= as.numeric(), perc_Cost= as.numeric())
#2. Compare within new run####
#--Confirm universal data is consistent across folders####
i = 1
for(file in smFiles){
  print(file)
  for(year in years){
    for(sc in scen){
      inFile = paste(newDir, newFolName, year, "/Database/SAS/outputs/", sc, "/", file, "_", year, ".csv", sep = "")
      
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
    inFile1 = paste(newDir, newFolName, year, "/Database/SAS/outputs/100", "/", file, "_", year, ".csv", sep = "")
    inFile2 = paste(newDir, newFolName, year, "/Database/SAS/outputs/200", "/", file, "_", year, ".csv", sep = "")
    in1 <- read.csv(inFile1)
    in2 <- read.csv(inFile2)
    resp = all.equal(in1, in2)
    if(resp != TRUE){stop()}
  }
}

#3. Compare against previous version####
#Make sure things haven't changed that shouldn't change
#need to understand the universe of what's changing and how first
#Build Loop####
#for testing:
#sc = 200
#yr = 2022
#years = c(2022)
#scen = c(100)
###
for(file in allFiles){
  for(yr in years){
    for(sc in scen){
      #LOAD DATA
      inCurrent = read.csv(paste(currentDir, currentFolName, yr, "/Database/SAS/outputs/", sc, "/", file, "_", yr, ".csv", sep = ""))
      inNew = read.csv(paste(newDir, newFolName, yr, "/Database/SAS/outputs/", sc, "/", file, "_", yr, ".csv", sep = ""))
      
      #STATIC FILE QC
      if(file %in% stFiles){ 
        print(paste(file, yr, sc, sep = "-"))
        resp = all.equal(inCurrent, inNew)
        if(resp != TRUE){stop()}
      }
      
      #DYNAMIC FILE QC
      if(file %in% chFiles){ 
        if(file == "cmap_data_truck_EE_poe"){
          print(paste(file, yr, sc, sep = "-"))
          
          inCurrent<- inCurrent %>% rename(C_poe = poe, C_poe2 = poe2)
          inNew<- inNew %>% rename(N_poe = poe, N_poe2 = poe2)
          
          qcOut <- full_join(inCurrent, inNew, by = join_by(Production_zone, Consumption_zone)) %>%
            mutate(flag_Poe = ifelse(C_poe == N_poe & (!is.na(N_poe) & !is.na(C_poe)), TRUE, FALSE),
                   flag_Poe2 = ifelse(C_poe2 == N_poe2 & (!is.na(N_poe2) & !is.na(C_poe2)), TRUE, FALSE)) %>%
            filter(flag_Poe != TRUE | flag_Poe2 != TRUE) %>%
            mutate(Year = yr, Scenario = sc) %>%
            select(colnames(all_TruckEE))
          
          check <- qcOut %>%
            filter((!(N_poe %in% poeIDs))|(!(C_poe %in% poeIDs)))
          #if(nrow(check) != 0){stop()}
          
          all_TruckEE <- rbind(all_TruckEE, qcOut)
          
        }else if(file == "cmap_data_zone_employment"){
          print(paste(file, yr, sc, sep = "-"))
          
          inCurrent<- inCurrent %>% rename(currentEmp = totalemp)
          inNew<- inNew %>% rename(newEmp = totalemp)
          
          qcOut <- full_join(inCurrent, inNew, by = join_by(Zone, mesozone)) %>%
            left_join(in_zones, by = c("Zone" = "Zone17")) %>%
            summarize(currentEmp = sum(currentEmp),
                      newEmp = sum(newEmp),
                      .by = "County") %>%
            mutate(Year = yr,
                   Scenario = sc,
                   Difference = newEmp - currentEmp,
                   Percent = Difference/(newEmp + currentEmp)) %>%
            select(colnames(all_znEmp)) %>%
            filter(Difference != 0)
          
          if(sum(qcOut$Difference) > 0 & planUpdate != "yes"){stop()}
          
          all_znEmp <- rbind(all_znEmp, qcOut)        #Building export because if there is a plan update we'd like to see results
          
        }else if(file == "cmap_data_zone_skims"){
          print(paste(file, yr, sc, sep = "-"))
          inCurrent <- inCurrent %>%
            left_join(in_zones, by = c("Origin" = "Zone17")) %>%
            rename(OCounty = County) %>%
            left_join(in_zones, by = c("Destination" = "Zone17")) %>%
            rename(DCounty = County) %>%
            summarize(C_avPeak = mean(Peak, weight = Miles),
                      C_avOffPeak = mean(OffPeak, weight = Miles),
                      C_avMiles = mean(Miles),
                      C_totMiles = sum(Miles),
                      .by = c("OCounty", "DCounty"))
          
          inNew <- inNew %>%
            left_join(in_zones, by = c("Origin" = "Zone17")) %>%
            rename(OCounty = County) %>%
            left_join(in_zones, by = c("Destination" = "Zone17")) %>%
            rename(DCounty = County) %>%
            summarize(N_avPeak = mean(Peak, weight = Miles),
                      N_avOffPeak = mean(OffPeak, weight = Miles),
                      N_avMiles = mean(Miles),
                      N_totMiles = sum(Miles),
                      .by = c("OCounty", "DCounty")) 

          qcOut <- full_join(inCurrent, inNew, by = join_by(OCounty, DCounty)) %>%
            mutate(diff_Peak = N_avPeak - C_avPeak,
                   diff_OffPeak = N_avOffPeak - C_avOffPeak,
                   diff_avMi = N_avMiles - C_avMiles,
                   diff_totMi = N_totMiles - C_totMiles,
                   Year = yr,
                   Scenario = sc,
                   difSum = abs(diff_Peak) + abs(diff_OffPeak) + abs(diff_avMi) + abs(diff_totMi)) %>%
            filter(difSum > 0) %>%
            select(-difSum) %>%
            select(colnames(all_znSkim))
          
          all_znSkim <- rbind(all_znSkim, qcOut)
          
        }else if(file == "data_mesozone_skims"){
          print(paste(file, yr, sc, sep = "-"))

          inCurrent<- inCurrent %>% rename(currentTime = Time)
          inNew<- inNew %>% rename(newTime = Time)
          
          qcOut <- full_join(inCurrent, inNew, by = join_by(Origin, Destination)) %>%
            left_join(in_mesozones, by = c("Origin" = "Mesozone")) %>%
            rename(OCounty = County) %>%
            left_join(in_mesozones, by = c("Destination" = "Mesozone")) %>%
            rename(DCounty = County) %>%
            summarize(currentTime = sum(currentTime),
                      newTime = sum(newTime),
                      .by = c("OCounty", "DCounty")) %>%
            mutate(Year = yr,
                   Scenario = sc,
                   Difference = newTime - currentTime,
                   Percent = round(Difference/(newTime + currentTime),3)) %>%
            select(colnames(all_mesoSkim)) %>%
            filter(abs(Percent) >= 0.01)
          
          all_mesoSkim <- rbind(all_mesoSkim, qcOut)
          
        }else if(file == "cmap_data_truck_IE_poe"){
          print(paste(file, yr, sc, sep = "-"))
          
          inCurrent<- inCurrent %>% rename(C_poe = poe)
          inNew<- inNew %>% rename(N_poe = poe)
          
          qcOut <- full_join(inCurrent, inNew, by = join_by(Production_zone, Consumption_zone)) %>%
            filter(N_poe != C_poe)%>%
            mutate(Year = yr, Scenario = sc) %>%
            select(colnames(all_TruckIE))
          
          check <- qcOut %>%
            filter(!(N_poe %in% poeIDs))
          if(nrow(check) != 0){stop()}
          
          all_TruckIE<- rbind(all_TruckIE, qcOut)
          
        }else if(file == "data_modepath_skims"){
          print(paste(file, yr, sc, sep = "-"))
          
          T_New <- inNew %>%
            select(-(cost1:cost57)) %>%
            pivot_longer(cols = time1:time57, names_to = "timeMode", values_to = "time") %>%
            summarize(N_Time = sum(time, na.rm = TRUE),
                      .by = "timeMode") %>%
            mutate(Modepath = as.numeric(str_split_i(timeMode, "time", 2))) %>%
            left_join(in_modePath, by = join_by("Modepath" == "Path")) %>%
            select(Mode, LogNode,  N_Time) %>%
            summarize(N_Time = sum(N_Time), .by = c("Mode", "LogNode"))
          C_New <- inNew %>%
            select(-(time1:time57)) %>%
            pivot_longer(cols = cost1:cost57, names_to = "costMode", values_to = "cost") %>%
            summarize(N_Cost = sum(cost, na.rm = TRUE),
                      .by = "costMode") %>%
            mutate(Modepath = as.numeric(str_split_i(costMode, "cost", 2))) %>%
            left_join(in_modePath, by = join_by("Modepath" == "Path")) %>%
            select(Mode, LogNode,  N_Cost)%>%
            summarize(N_Cost = sum(N_Cost), .by = c("Mode", "LogNode"))
          
          T_inNew <- full_join(T_New, C_New, by = join_by(Mode, LogNode))
          
          T_Current <- inCurrent %>%
            select(-(cost1:cost57)) %>%
            pivot_longer(cols = time1:time57, names_to = "timeMode", values_to = "time") %>%
            summarize(C_Time = sum(time, na.rm = TRUE),
                      .by = "timeMode") %>%
            mutate(Modepath = as.numeric(str_split_i(timeMode, "time", 2))) %>%
            left_join(in_modePath, by = join_by("Modepath" == "Path")) %>%
            select(Mode, LogNode, C_Time)%>%
            summarize(C_Time = sum(C_Time), .by = c("Mode", "LogNode"))
          C_Current <- inCurrent %>%
            select(-(time1:time57)) %>%
            pivot_longer(cols = cost1:cost57, names_to = "costMode", values_to = "cost") %>%
            summarize(C_Cost = sum(cost, na.rm = TRUE),
                      .by = "costMode") %>%
            mutate(Modepath = as.numeric(str_split_i(costMode, "cost", 2))) %>%
            left_join(in_modePath, by = join_by("Modepath" == "Path")) %>%
            select(Mode, LogNode, C_Cost)%>%
            summarize(C_Cost = sum(C_Cost), .by = c("Mode", "LogNode"))
          
          T_inCurrent <- full_join(T_Current, C_Current, by = join_by(Mode, LogNode))
          
          qcOut <- full_join(T_inCurrent, T_inNew, by = join_by(Mode, LogNode)) %>%
            mutate(diff_Time = N_Time - C_Time,
                   diff_Cost = N_Cost - C_Cost,
                   perc_Time = round(diff_Time/(N_Time+C_Time),3),
                   perc_Cost = round(diff_Cost/(N_Cost+C_Cost),3),
                   Scenario = sc, Year = yr) %>%
            filter(perc_Cost >= 0.01 | perc_Cost >= 0.01) %>%
            select(colnames(all_modeSkim)) 

          all_modeSkim <- rbind(all_modeSkim, qcOut)
          
        }else if(file == "data_modepath_miles"){
          print(paste(file, yr, sc, sep = "-"))
          
          inCurrent<- inCurrent %>%
            left_join(in_modePath, by = c("MinPath" = "Path")) %>%
            mutate(NARail = ifelse(is.na(RlTrnfr), 1, 0),
                   codeZero = ifelse(RlDwlCode != 0, 1, 0)) %>%
            summarize(C_TotMi = sum(TotalNtwkMiles),
                   C_DmsLh = sum(DmsLhMiles),
                   C_DmsDray = sum(DmsDrayMiles),
                   C_IntlShip = sum(IntlShipMiles),
                   C_PsTR = sum(CmapPsTR),
                   C_PsRL = sum(CmapPsRL),
                   C_NATrnFr = sum(NARail),
                   C_NoZeroCode = sum(codeZero),
                   .by = c("LogNode", "Mode"))
          inNew<- inNew %>%
            left_join(in_modePath, by = c("MinPath" = "Path")) %>%
            mutate(NARail = ifelse(is.na(RlTrnfr), 1, 0),
                   codeZero = ifelse(RlDwlCode != 0, 1, 0)) %>%
            summarize(N_TotMi = sum(TotalNtwkMiles),
                      N_DmsLh = sum(DmsLhMiles),
                      N_DmsDray = sum(DmsDrayMiles),
                      N_IntlShip = sum(IntlShipMiles),
                      N_PsTR = sum(CmapPsTR),
                      N_PsRL = sum(CmapPsRL),
                      N_NATrnFr = sum(NARail),
                      N_NoZeroCode = sum(codeZero),
                      .by = c("LogNode", "Mode"))          

          qcOut <- full_join(inCurrent, inNew, by = join_by(LogNode, Mode)) %>%
            mutate(diff_TotMi = N_TotMi - C_TotMi,
                   diff_DmsLh = N_DmsLh - C_DmsLh,
                   diff_DmsDray = N_DmsDray- C_DmsDray,
                   diff_IntlShip = N_IntlShip- C_IntlShip,
                   diff_PsTR = N_PsTR-C_PsTR, 
                   diff_PsRL = N_PsRL-C_PsRL, 
                   diff_NATrnFr =N_NATrnFr - C_NATrnFr,
                   diff_NoZeroCode =N_NoZeroCode - C_NoZeroCode,
                   Perc_TotMi = round(diff_TotMi/(N_TotMi + C_TotMi),3),
                   Perc_DmsLh = round(diff_DmsLh/(N_DmsLh + C_DmsLh),3),
                   Perc_DmsDray = round(diff_DmsDray/(N_DmsDray + C_DmsDray),3),
                   Perc_IntlShip = round(diff_IntlShip/(N_IntlShip + C_IntlShip),3),
                   Perc_PsTR = round(diff_PsTR/(N_PsTR + C_PsTR),3),
                   Perc_PsRL = round(diff_PsRL/(N_PsRL + C_PsRL),3),
                   Perc_NATrnFr = round(diff_NATrnFr/(N_NATrnFr + C_NATrnFr),3),
                   Perc_NoZeroCode = round(diff_NoZeroCode/(N_NoZeroCode + C_NoZeroCode),3),
                   Year = yr,
                   Scenario = sc) %>%
            rowwise() %>%
            mutate(sumDiff = sum(c_across(Perc_TotMi:Perc_NoZeroCode), na.rm = TRUE)) %>%
            filter(sumDiff >= 0.01) %>%
            select(colnames(all_modeMi))
          
          all_modeMi<- rbind(all_modeMi, qcOut)
          
        }else if(file == "data_modepath_ports"){
          print(paste(file, yr, sc, sep = "-"))
          
          inCurrent<- inCurrent %>% mutate(flagC = 1)
          inNew<- inNew %>% mutate(flagN = 1)
          
          qcOut <- full_join(inCurrent, inNew, by = join_by(Production_zone, Consumption_zone, Port_mesozoneNB, Port_NameNB, Port_mesozoneB, Port_NameB)) %>%
            mutate(flags = flagC + flagN, Scenario = sc, Year = yr) %>%
            filter(is.na(flags)) %>%
            select(colnames(all_modePort))
          
          all_modePort<- rbind(all_modePort, qcOut)
          
        }
      }
    }
  }
}

#Final Output Formatting####
#--Modepath Port --> amend with crosswalk and check any that dramatically changes coast
#--Truck EE --> edit with crosswalk to ensure changes aren't dramatic
##--Truck IE --> edit with crosswalk to ensure changes aren't dramatic


#Output: Any differences in modepath greater than 1%
#Export as tab
#--Mesozone Skims
#--Modepath Miles
#--Modepath Skims
#--Zone Employment
#--Zone Skim

