
#0. SET UP####
library(tidyverse)

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

#--Define Crosswalks####
zoneCrosswalk <- data.frame(Zone = c(1:3649)) %>%
  mutate(County = case_when(
    Zone %in% 1:717 ~ "Cook-Chicago",
    Zone %in% 718:1732 ~ "Cook-remaining",
    Zone %in% 1733:2111 ~ "DuPage",
    Zone %in% 2112:2304 ~ "Kane",
    Zone %in% 2305:2325 ~ "Kendall",
    Zone %in% 2326:2583 ~ "Lake",
    Zone %in% 2584:2702 ~ "McHenry",
    Zone %in% 2703:2926 ~ "Will",
    Zone %in% 2927:3247 ~ "Other IL",
    Zone %in% 3248:3467 ~ "Other IN",
    Zone %in% 3468:3632 ~ "Other WI",
    Zone %in% 3633:3649 ~ "POE"
  ))


mesoCrosswalk <- data.frame(Mesozone = c(1:399)) %>%
  mutate(Region = case_when(
    Mesozone %in% 1:132 ~ "CMAP",
    Mesozone %in% 133:299 ~ "National",
    Mesozone %in% 300:399 ~ "International"))
cmapMesoCross <- data.frame(Mesozone = (1:132))%>%
  mutate(County = case_when(
    Mesozone %in% 1:29 ~ "Cook",
    Mesozone %in% 30:45 ~ "McHenry",
    Mesozone %in% 46:61 ~ "Lake",
    Mesozone %in% 62:76 ~ "Kane",
    Mesozone %in% 77:86 ~ "DuPage",
    Mesozone %in% 87:109 ~ "Will",
    Mesozone %in% 110:118 ~ "Kendall",
    Mesozone %in% 118:132 ~ "Other CMAP",))

modeCrosswalk <- data.frame(Modepath = 1:57) %>%
  mutate(Path = case_when(
    Modepath %in% 1:2 ~ "Inland Water",
    Modepath %in% 3:12 ~ "Rail Carload",
    Modepath %in% 13:30 ~ "Rail Intermodal",
    Modepath %in% 31:46 ~ "Truck",
    Modepath %in% 47:50 ~ "Air",
    Modepath %in% 51:54 ~ "International Water",
    Modepath %in% 55:57 ~ "Pipeline"
  ))
#1. Compare within new run####
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

#2. Compare against previous version####
#Make sure things haven't changed that shouldn't change
#need to understand the universe of what's changing and how first
#Build Loop####
#for testing:
#sc = 100
#yr = 2022
###
for(file in chFiles){
  for(yr in years){
    for(sc in scen){
      #LOAD DATA
      inCurrent = read.csv(paste(currentDir, currentFolName, yr, "/Database/SAS/outputs/", sc, "/", "data_modepath_skims", "_", yr, ".csv", sep = ""))
      inNew = read.csv(paste(newDir, newFolName, yr, "/Database/SAS/outputs/", sc, "/", "data_modepath_skims", "_", yr, ".csv", sep = ""))
      
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
          
          truckEE <- full_join(inCurrent, inNew, by = join_by(Production_zone, Consumption_zone)) %>%
            mutate(flag1 = ifelse(C_poe == N_poe & (!is.na(N_poe) & !is.na(C_poe)), TRUE, FALSE),
                   flag2 = ifelse(C_poe2 == N_poe2 & (!is.na(N_poe2) & !is.na(C_poe2)), TRUE, FALSE)) %>%
            filter(flag1 != TRUE | flag2 != TRUE) %>%
            mutate(Year = yr, Scenario = sc) %>%
            select(Scenario, Year, Production_zone:flag2)
          
          check <- truckEE %>%
            filter((!(N_poe %in% poeIDs))|(!(C_poe %in% poeIDs)))
          #if(nrow(check) != 0){stop()}
          
        }else if(file == "cmap_data_zone_employment"){
          print(paste(file, yr, sc, sep = "-"))
          
          inCurrent<- inCurrent %>% rename(currentEmp = totalemp)
          inNew<- inNew %>% rename(newEmp = totalemp)
          
          znEmp <- full_join(inCurrent, inNew, by = join_by(Zone, mesozone)) %>%
            left_join(zoneCrosswalk, by = join_by(Zone)) %>%
            summarize(currentEmp = sum(currentEmp),
                      newEmp = sum(newEmp),
                      .by = "County") %>%
            mutate(Year = yr,
                   Scenario = sc,
                   Difference = newEmp - currentEmp,
                   Percent = Difference/(newEmp + currentEmp)) %>%
            select(Scenario, Year, County, currentEmp, newEmp, Difference, Percent)
          
          if(sum(znEmp$Difference) > 0 & planUpdate != "yes"){stop()}
          
        }else if(file == "cmap_data_zone_skims"){
          print(paste(file, yr, sc, sep = "-"))
          inCurrent <- inCurrent %>%
            left_join(zoneCrosswalk, by = c("Origin" = "Zone")) %>%
            rename(OCounty = County) %>%
            left_join(zoneCrosswalk, by = c("Destination" = "Zone")) %>%
            rename(DCounty = County) %>%
            summarize(C_avPeak = mean(Peak, weight = Miles),
                      C_avOffPeak = mean(OffPeak, weight = Miles),
                      C_avMiles = mean(Miles),
                      C_totMiles = sum(Miles),
                      .by = c("OCounty", "DCounty"))
          
          inNew <- inNew %>%
            left_join(zoneCrosswalk, by = c("Origin" = "Zone")) %>%
            rename(OCounty = County) %>%
            left_join(zoneCrosswalk, by = c("Destination" = "Zone")) %>%
            rename(DCounty = County) %>%
            summarize(N_avPeak = mean(Peak, weight = Miles),
                      N_avOffPeak = mean(OffPeak, weight = Miles),
                      N_avMiles = mean(Miles),
                      N_totMiles = sum(Miles),
                      .by = c("OCounty", "DCounty")) 

          ZnSkim <- full_join(inCurrent, inNew, by = join_by(OCounty, DCounty)) %>%
            mutate(diff_Peak = N_avPeak - C_avPeak,
                   diff_OffPeak = N_avOffPeak - C_avOffPeak,
                   diff_avMi = N_avMiles - C_avMiles,
                   diff_totMi = N_totMiles - C_totMiles,
                   Year = yr,
                   Scenario = sc,
                   difSum = abs(diff_Peak) + abs(diff_OffPeak) + abs(diff_avMi) + abs(diff_totMi)) %>%
            filter(difSum > 0) %>%
            select(-difSum)
          
          
        }else if(file == "data_mesozone_skims"){
          print(paste(file, yr, sc, sep = "-"))

          inCurrent<- inCurrent %>% rename(currentTime = Time)
          inNew<- inNew %>% rename(newTime = Time)
          
          MesSkim <- full_join(inCurrent, inNew, by = join_by(Origin, Destination)) %>%
            left_join(cmapMesoCross, by = c("Origin" = "Mesozone")) %>%
            rename(OCounty = County) %>%
            left_join(cmapMesoCross, by = c("Destination" = "Mesozone")) %>%
            rename(DCounty = County) %>%
            summarize(currentTime = sum(currentTime),
                      newTime = sum(newTime),
                      .by = c("OCounty", "DCounty")) %>%
            mutate(Year = yr,
                   Scenario = sc,
                   Difference = newTime - currentTime,
                   Percent = round(Difference/(newTime + currentTime),3)) %>%
            select(Scenario, Year, OCounty, DCounty, currentTime, newTime, Difference, Percent) %>%
            filter(abs(Percent) >= 0.01)
          
        }else if(file == "cmap_data_truck_IE_poe"){
          print(paste(file, yr, sc, sep = "-"))
          
          inCurrent<- inCurrent %>% rename(C_poe = poe)
          inNew<- inNew %>% rename(N_poe = poe)
          
          truckIE <- full_join(inCurrent, inNew, by = join_by(Production_zone, Consumption_zone)) %>%
            filter(N_poe != C_poe)%>%
            mutate(Year = yr, Scenario = sc) %>%
            select(Scenario, Year, Production_zone:N_poe)
          
          check <- truckIE %>%
            filter(!(N_poe %in% poeIDs))
          if(nrow(check) != 0){stop()}
          
        }else if(file == "data_modepath_skims"){
          print(paste(file, yr, sc, sep = "-"))
          
          T_inNew <- inNew %>%
            pivot_longer(cols = time1:time57, names_to = "timeMode", values_to = "time") %>%
            pivot_longer(cols = cost1:cost57, names_to = "costMode", values_to = "cost") %>%
            summarize(Time = sum(time, na.rm = TRUE),
                      Cost = sum(cost, na.rm = TRUE),
                      .by = c("timeMode","costMode"))
            
        }else if(file == "data_modepath_miles"){
          print(paste(file, yr, sc, sep = "-"))
          
          inCurrent<- inCurrent %>%
            left_join(modeCrosswalk, by = c("MinPath" = "Modepath")) %>%
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
                   .by = "Path")
          inNew<- inNew %>%
            left_join(modeCrosswalk, by = c("MinPath" = "Modepath")) %>%
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
                      .by = "Path")
          

          modeMi <- full_join(inCurrent, inNew, by = join_by(Path)) %>%
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
            select(Scenario, Year, Path, Perc_TotMi:Perc_NoZeroCode)
          
        }else if(file == "data_modepath_ports"){
          print(paste(file, yr, sc, sep = "-"))
          
          inCurrent<- inCurrent %>% mutate(flagC = 1)
          inNew<- inNew %>% mutate(flagN = 1)
          
          modePort <- full_join(inCurrent, inNew, by = join_by(Production_zone, Consumption_zone, Port_mesozoneNB, Port_NameNB, Port_mesozoneB, Port_NameB)) %>%
            mutate(flags = flagC + flagN) %>%
            filter(is.na(flags))
        }
      }
      
      #depending on format, amend to full df then export as tab in xlsx, or just export
      #truckIE as supplemental tab
      #truckEE as supplemental tab
      #znEmp as supplemental tab
      #modePort - visual QC; can try to build a geography crosswalk based on nearby ports
      #ZnSkim - filter to keep only OD pairs with differences
      #MesSkim - filter to keep only OD pairs with differences >= 1%
      #modeMi  - find a filter; 
      #
    }
  }
}
