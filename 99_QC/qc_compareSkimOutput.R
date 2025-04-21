
#1. SET UP####
library(tidyverse)
library(readxl)
library(openxlsx)

#--Read Input####
in1 <- suppressWarnings(read.table("../../Input/path_inputs.txt", header=TRUE, sep = "="))

#--Define paths####
inConf = str_replace_all(in1$value[1], " ", "")
newDir = paste(str_replace_all(in1$value[2], " ", ""), "/Skim_Output/", sep = "")
currentDir =  paste(str_replace_all(in1$value[3], " ", ""), "/Skim_Output/", sep = "")

empUpdate = "no"

rpDir = paste(str_replace_all(in1$value[2], " ", ""), "/Reports/", sep = "")
outXL = paste(rpDir, "finalSkim_compareQC.xlsx", sep = "")
report = paste(rpDir, "qc_CompareReport.txt", sep = "")

#--Delete report if exists
if(file.exists(outXL) == TRUE){unlink(outXL, recursive = TRUE)}
if(file.exists(report) == TRUE){unlink(report, recursive = TRUE)}

#--Import crosswalks####
in_modePath <- read_xlsx("S:/AdminGroups/ResearchAnalysis/kcc/FY25/MFN/Current_copies/Input/MFN_crosswalks.xlsx", sheet = "modePath")
in_ports <- read_xlsx("S:/AdminGroups/ResearchAnalysis/kcc/FY25/MFN/Current_copies/Input/MFN_crosswalks.xlsx", sheet = "Ports")
in_POE <- read_xlsx("S:/AdminGroups/ResearchAnalysis/kcc/FY25/MFN/Current_copies/Input/MFN_crosswalks.xlsx", sheet = "POE")

#--Define Lists & Variables####
allFiles = list.files(newDir, include.dirs = FALSE, recursive=TRUE)

chFiles = c("cmap_data_truck_EE_poe.csv", "cmap_data_zone_employment", "cmap_data_zone_skims", "data_mesozone_skims",
            "cmap_data_truck_IE_poe", "data_modepath_miles", "data_modepath_skims", "data_modepath_ports")
stFiles = c("cmap_data_zone_centroids.csv", "data_mesozone_centroids.csv", "data_mesozone_gcd.csv", "data_modepath_airports.csv")

skLim = 0.05  #mesozone skims print if percent difference > 5%

#--Define Empty Template DF for Comparison####
#depending on format, amend to full df then export as tab in xlsx, or just export
all_TruckEE <- data.frame(Year = as.numeric(), Production_zone = as.integer(), Consumption_zone = as.integer(),
                          C_poe2 = as.integer(), C_poe = as.integer(), N_poe2 = as.integer(), N_poe = as.integer(), 
                          CState = as.character(), NState = as.character(), CDirection = as.character(), NDirection = as.character(),
                          CState2 = as.character(), NState2 = as.character(), CDirection2 = as.character(), NDirection2 = as.character())

all_TruckIE <- data.frame(Scenario = as.numeric(), Year = as.numeric(), Production_zone = as.integer(), Consumption_zone = as.integer(),
                          C_poe = as.integer(), N_poe = as.integer(), CState = as.character(), NState = as.character(), CDirection = as.character(), NDirection = as.character())

all_znEmp <- data.frame(Year = as.numeric(), currentEmp = as.integer(),
                        newEmp = as.integer(), Difference = as.integer(), Percent = as.numeric())

all_modePort <- data.frame(Scenario = as.numeric(), Year = as.numeric(), Production_zone = as.integer(), Consumption_zone = as.integer(),
                           C_mesoNB = as.integer(),  N_mesoNB = as.integer(), C_mesoB = as.integer(),  N_mesoB = as.integer(), 
                           C_nameNB = as.character(), N_nameNB = as.character(),  C_nameB = as.character(), N_nameB = as.character(), 
                           C_coastNB = as.character(), N_coastNB = as.character(),C_coastB = as.character(), N_coastB = as.character())

all_znSkim <- data.frame(Year = as.numeric(), Origin= as.integer(), Destination= as.integer(),
                         C_Peak= as.numeric(), C_OffPeak= as.numeric(), C_Miles= as.numeric(),  
                         N_Peak= as.numeric(),  N_OffPeak= as.numeric(), N_Miles= as.numeric(),  
                         diff_Peak= as.numeric(), diff_OffPeak= as.numeric(), diff_Mi= as.numeric())

all_mesoSkim <- data.frame(Year = as.numeric(), Origin= as.integer(), Destination= as.integer(), currentTime= as.numeric(), 
                           newTime= as.numeric(), Difference= as.numeric(), Percent= as.numeric())


all_modeMi <- data.frame(Scenario = as.numeric(), Year = as.numeric(), Mode = as.character(), LogNode = as.numeric(), Perc_TotMi= as.numeric(),     
                         Perc_DmsLh= as.numeric(), Perc_DmsDray= as.numeric(), Perc_IntlShip= as.numeric(), Perc_PsTR= as.numeric(),      
                         Perc_PsRL= as.numeric(), Perc_RlDwlCode= as.numeric(), Perc_RlTrnFr= as.numeric())

all_modeSkim <- data.frame(Scenario = as.numeric(), Year = as.numeric(), Mode=as.character(), LogNode = as.numeric(), C_Time= as.numeric(), C_Cost= as.numeric(),    
                           N_Time= as.numeric(), N_Cost= as.numeric(), perc_Time= as.numeric(), perc_Cost= as.numeric())

#3. Compare against previous version####
for(file in allFiles){
  #Load data
  inCurrent <- read.csv(paste(currentDir, file, sep = ""))
  inNew <- read.csv(paste(newDir, file, sep = ""))
  
  #Determine file name to send it to the correct loop
  if(grepl("140/", file)){
    name = str_split_i(file, "140/", 2)
    name = str_split_i(name, "_2", 1)
    
    scen = str_split_i(file, "140/", 1)
    temp = str_split_i(file, "_20", 2)
    temp = str_split_i(temp, ".csv", 1)
    year = as.numeric(paste("20", temp, sep = ""))
    
  }else{
    name = str_split_i(file, "_2", 1)
    scen = NA
    temp = str_split_i(file, "_20", 2)
    temp = str_split_i(temp, ".csv", 1)
    year = as.numeric(paste("20", temp, sep = ""))
  }

  if(name %in% chFiles){
    printOut = paste("chFiles: ", file, sep = "")
    cat(printOut, file =report,append=TRUE)
    cat("\n", file =report,append=TRUE)
    if(name == "cmap_data_truck_EE_poe.csv"){
      inCurrent<- inCurrent %>% rename(C_poe = poe, C_poe2 = poe2)                                             #Load Current file and amend column names
      inNew<- inNew %>% rename(N_poe = poe, N_poe2 = poe2)                                                     #Load New file and amend column names
      
      qcOut <- full_join(inCurrent, inNew, by = join_by(Production_zone, Consumption_zone)) %>%                #Join data
        left_join(in_POE, by = c("C_poe2" = "POE")) %>%                                                        #Bind crosswalk
        rename(CState2 = State, CDirection2 = Direction) %>%
        left_join(in_POE, by = c("C_poe" = "POE")) %>%
        rename(CState = State, CDirection = Direction) %>%
        left_join(in_POE, by = c("N_poe2" = "POE")) %>%
        rename(NState2 = State, NDirection2 = Direction) %>%
        left_join(in_POE, by = c("N_poe" = "POE")) %>%
        rename(NState = State, NDirection = Direction) %>%
        filter((NDirection != CDirection) | (NDirection2 != CDirection2)) %>%
        mutate(Year = year) %>%
        select(colnames(all_TruckEE))
      
      #Confirm all POE ID's are in expected range; if not stop code
      check <- qcOut %>%
        filter((!(N_poe %in% in_POE$POE))|(!(C_poe %in% in_POE$POE))) %>%
        filter(!(is.na(N_poe) | is.na(C_poe)))
      if(nrow(check) != 0){stop()}
      
      #Combine all year &/or scenario data from file
      all_TruckEE <- rbind(all_TruckEE, qcOut)
      
    }else{
      if(name == "cmap_data_truck_IE_poe"){
        #Amend column names
        inCurrent<- inCurrent %>% rename(C_poe = poe)                                                  
        inNew<- inNew %>% rename(N_poe = poe)                                                          
        
        qcOut <- full_join(inCurrent, inNew, by = join_by(Production_zone, Consumption_zone)) %>%      #Merge data
          left_join(in_POE, by = c("C_poe" = "POE")) %>%                                               #Join POE crosswalk
          rename(CState = State, CDirection = Direction) %>%
          left_join(in_POE, by = c("N_poe" = "POE")) %>%
          rename(NState = State, NDirection = Direction) %>%
          filter(N_poe != C_poe)%>%
          filter((NDirection != CDirection)) %>%
          filter(NState != CState) %>%
          mutate(Year = year, Scenario = scen) %>%
          select(colnames(all_TruckIE))
        
        check <- qcOut %>%
          filter(!(N_poe %in% in_POE$POE))
        if(nrow(check) != 0){stop()}
        
        all_TruckIE<- rbind(all_TruckIE, qcOut)
        
      }else if(name == "cmap_data_zone_employment"){
        inCurrent<- inCurrent %>% rename(currentEmp = totalemp)                    #Amend Current file column names
        inNew<- inNew %>% rename(newEmp = totalemp)                                #Amed New file column names
        
        qcOut <- full_join(inCurrent, inNew, by = join_by(Zone, mesozone)) %>%     #Merge new and current data
          mutate(Difference = newEmp-currentEmp,                                   #Calculate employment difference
                 Percent = round(Difference/(newEmp-currentEmp),3)) %>%            #Calculate employment percent difference, round 3 decimal places
          filter(Difference > 0)%>%                                                #Filter employment difference > 0
          mutate(Year = year) %>%                                                  #Assign year variable to different data
          select(colnames(all_znEmp))                                              #Select template column names
        
        #Employment only expected to change if update is associated with a plan update
        #If difference exists otherwise, stop code
        if(sum(qcOut$Difference) > 0 & empUpdate != "yes"){
          printOut = "ERROR: Employment unexpectedly changes!"
          cat(printOut, file =report,append=TRUE)
          stop()
          }                
        
        #Combine with template dataframe
        all_znEmp <- rbind(all_znEmp, qcOut)                                       #Building export because if there is a plan update we'd like to see results
        
      }else if(name == "cmap_data_zone_skims"){
        #Amend Current and New file column names
        inCurrent <- inCurrent %>% 
          rename(C_Peak = Peak, C_OffPeak = OffPeak, C_Miles = Miles)
        
        inNew <- inNew %>%
          rename(N_Peak = Peak, N_OffPeak = OffPeak, N_Miles = Miles)
        
        #Merge data, calculate differences
        qcOut <- full_join(inCurrent, inNew, by = join_by(Origin, Destination)) %>%
          mutate(diff_Peak = N_Peak - C_Peak,
                 diff_OffPeak = N_OffPeak - C_OffPeak,
                 diff_Mi = N_Miles - C_Miles,
                 Year = year,
                 difSum = abs(diff_Peak) + abs(diff_OffPeak) + abs(diff_Mi)) %>%       #Sum all differences
          filter(difSum > 0) %>%                                                       #filter to keep only OD pairs with differences
          select(colnames(all_znSkim))                                                 #Select column names from target dataframe
        
        #Combine with template dataframe
        all_znSkim <- rbind(all_znSkim, qcOut)
        
      }else if(name == "data_mesozone_skims"){
        #Amend Current and New file column names
        inCurrent <- inCurrent %>% rename(currentTime = Time)
        inNew <- inNew %>% rename(newTime = Time)
        
        #Merge new and current data; calculate differencepercent difference in 
        qcOut <- full_join(inCurrent, inNew, by = join_by(Origin, Destination)) %>%   #Merge current and new data
          mutate(Year = year,                                                         #Flag current year of data
                 Difference = newTime - currentTime,                                  #Calculate difference in skim time
                 Percent = round(Difference/(newTime + currentTime),3)) %>%           #Calculate percent difference in skim time
          select(colnames(all_mesoSkim)) %>%                                          #Select column names of target dataframe
          filter(abs(Percent) >= skLim)                                                #Filter to keep percent differences > |1%|
        
        #Combine with template dataframe
        all_mesoSkim <- rbind(all_mesoSkim, qcOut) %>%
          arrange(Origin, Destination, Year)
        
      }else if(name == "data_modepath_skims"){
        
        #Check for 0 in 2022 and not in other years
        ch140 <- inNew %>%
          select(Origin, Destination, time49, cost49) %>%
          filter(!is.na(time49) | !is.na(cost49))
        if(year == 2022 & nrow(ch140) > 0){
          printOut = "ERROR: Values for modepath 49, logistics  node 140 shouldn't be active, it's only 2022!"
          cat(printOut, file =report,append=TRUE)
          stop()
          
        }else if(year != 2022 & nrow(ch140) == 0){
          printOut = "ERROR: No values for modepath 49, logistics  node 140 should be active, it's after 2022!"
          cat(printOut, file =report,append=TRUE)
          printOut = paste("Year = ", year, "\n", sep = "")
          cat(printOut, file =report,append=TRUE)
          stop()
        }else{
          printOut = "No modepath skim issues with logistics node 140"
          cat(printOut, file =report,append=TRUE)
          cat("\n", file =report,append=TRUE)
        }
        
        #Format new input files
        #New Time
        T_New <- inNew %>%
          select(-(cost1:cost57)) %>%
          pivot_longer(cols = time1:time57, names_to = "timeMode", values_to = "time") %>%
          summarize(N_Time = sum(time, na.rm = TRUE),
                    .by = "timeMode") %>%
          mutate(Mode = str_split_i(timeMode, "time", 2))
        #New Cost
        C_New <- inNew %>%
          select(-(time1:time57)) %>%
          pivot_longer(cols = cost1:cost57, names_to = "costMode", values_to = "cost") %>%
          summarize(N_Cost = sum(cost, na.rm = TRUE),
                    .by = "costMode") %>%
          mutate(Mode = str_split_i(costMode, "cost", 2))
        
        #Join new data time and cost data
        T_inNew <- full_join(T_New, C_New, by = join_by(Mode))
        
        #Format current input files 
        #Current time
        T_Current <- inCurrent %>%
          select(-(cost1:cost57)) %>%
          pivot_longer(cols = time1:time57, names_to = "timeMode", values_to = "time") %>%
          summarize(C_Time = sum(time, na.rm = TRUE),
                    .by = "timeMode") %>%
          mutate(Mode = str_split_i(timeMode, "time", 2))
        #Current cost
        C_Current <- inCurrent %>%
          select(-(time1:time57)) %>%
          pivot_longer(cols = cost1:cost57, names_to = "costMode", values_to = "cost") %>%
          summarize(C_Cost = sum(cost, na.rm = TRUE),
                    .by = "costMode") %>%
          mutate(Mode = str_split_i(costMode, "cost", 2))
        
        #Join current data time and costs
        T_inCurrent <- full_join(T_Current, C_Current, by = join_by(Mode))
        
        #Join current and new time and costs
        qcOut <- full_join(T_inCurrent, T_inNew, by = join_by(Mode)) %>%
          mutate(diff_Time = N_Time - C_Time,                                   #Calculate time and cost differences
                 diff_Cost = N_Cost - C_Cost,
                 perc_Time = round(diff_Time/(N_Time+C_Time),3),                #Calculate time and cost percent differences
                 perc_Cost = round(diff_Cost/(N_Cost+C_Cost),3),
                 Scenario = scen, Year = year) %>%                              #Flag year and scenario in dataframe
          ungroup() %>%
          filter((abs(perc_Cost) > 0.00) | (abs(perc_Time) > 0.00)) %>%         #Filter to keep any differences in data
          mutate(Path = as.numeric(Mode)) %>%
          select(-Mode) %>%
          left_join(in_modePath, by = c("Path")) %>%                            #Join mode path information for inclusion in export
          select(colnames(all_modeSkim))                                        #Select column names of target dataframe
        
        #Combine with template dataframe
        all_modeSkim <- rbind(all_modeSkim, qcOut)
        
      }else if(name == "data_modepath_miles"){
        #Amend Column names of new and current file
        inCurrent<- inCurrent %>%
          mutate(C_NATrnFr = ifelse(is.na(RlTrnfr), 1, 0))%>%                          #Flag if current rail transfer code is NA
          left_join(in_modePath, by = c("MinPath" = "Path"))%>%
          summarize(C_TotalNtwkMiles=sum(TotalNtwkMiles), C_DmsLhMiles=sum(DmsLhMiles), C_DmsDrayMiles=sum(DmsDrayMiles), 
                    C_IntlShipMiles=sum(IntlShipMiles), C_CmapPsTR=sum(CmapPsTR), C_CmapPsRL=sum(CmapPsRL), 
                    C_RlDwlCode=mean(RlDwlCode), C_RlTrnfr=sum(C_NATrnFr),
                    .by = c("Mode", "LogNode"))
        
        inNew<- inNew %>%
          mutate(N_NATrnFr = ifelse(is.na(RlTrnfr), 1, 0))%>%                          #Flag if new rail transfer code is NA
          left_join(in_modePath, by = c("MinPath" = "Path"))%>%
          summarize(N_TotalNtwkMiles=sum(TotalNtwkMiles), N_DmsLhMiles=sum(DmsLhMiles), N_DmsDrayMiles=sum(DmsDrayMiles), 
                    N_IntlShipMiles=sum(IntlShipMiles), N_CmapPsTR=sum(CmapPsTR), N_CmapPsRL=sum(CmapPsRL), 
                    N_RlDwlCode=mean(RlDwlCode), N_RlTrnfr=sum(N_NATrnFr),
                    .by = c("Mode", "LogNode"))
        
        #Merge and compare current and new data
        qcOut <- full_join(inCurrent, inNew, by = join_by(Mode, LogNode)) %>%
          mutate(diff_TotMi = N_TotalNtwkMiles - C_TotalNtwkMiles,                            #Calculate differences in distances
                 diff_DmsLh = N_DmsLhMiles - C_DmsLhMiles,
                 diff_DmsDray = N_DmsDrayMiles- C_DmsDrayMiles,
                 diff_IntlShip = N_IntlShipMiles- C_IntlShipMiles,
                 diff_PsTR = N_CmapPsTR-C_CmapPsTR, 
                 diff_PsRL = N_CmapPsRL-C_CmapPsRL, 
                 diff_RlTrnFr =N_RlTrnfr - C_RlTrnfr,                                         #Calculate change in rail transfer fraction
                 diff_RlDwlCode =N_RlDwlCode - C_RlDwlCode,                                #Calculate change in rail dwell code
                 Perc_TotMi = round(diff_TotMi/(N_TotalNtwkMiles + C_TotalNtwkMiles),3),      #Calculate percent differences
                 Perc_DmsLh = round(diff_DmsLh/(N_DmsLhMiles + C_DmsLhMiles),3),
                 Perc_DmsDray = round(diff_DmsDray/(N_DmsDrayMiles + C_DmsDrayMiles),3),
                 Perc_IntlShip = round(diff_IntlShip/(N_IntlShipMiles + C_IntlShipMiles),3),
                 Perc_PsTR = round(diff_PsTR/(N_CmapPsTR + C_CmapPsTR),3),
                 Perc_PsRL = round(diff_PsRL/(N_CmapPsRL + C_CmapPsRL),3),
                 Perc_RlTrnFr = round(diff_RlTrnFr/(N_RlTrnfr + C_RlTrnfr),3),
                 Perc_RlDwlCode = round(diff_RlDwlCode/(N_RlDwlCode + C_RlDwlCode),3),
                 Year = year,                                                                 #Flag data year
                 Scenario = scen) %>%                                                         #Flag data scenario
          rowwise() %>%
          mutate(sumDiff = sum(c_across((Perc_TotMi:Perc_RlDwlCode)), na.rm = TRUE)) %>%     #Total all differences
          filter(abs(sumDiff) > 0.00) %>%                                                     #Filter for total differences greater than |1%|
          select(colnames(all_modeMi))                                                        #Select column names of target dataframe
        
        #Combine with template dataframe
        all_modeMi<- rbind(all_modeMi, qcOut)
        
      }else if(name == "data_modepath_ports"){
        
        #Flag current and new data
        inCurrent<- inCurrent %>% rename(C_mesoNB = Port_mesozoneNB, C_nameNB = Port_NameNB, C_mesoB = Port_mesozoneB, C_nameB = Port_NameB)
        inNew<- inNew %>% rename(N_mesoNB = Port_mesozoneNB, N_nameNB = Port_NameNB, N_mesoB = Port_mesozoneB, N_nameB = Port_NameB)
        
        #Join current and new data by all fields
        qcOut <- full_join(inCurrent, inNew, by = join_by(Production_zone, Consumption_zone)) %>%
          mutate(flagB = ifelse(N_mesoB == C_mesoB, 1, 0),
                 flagNB = ifelse(N_mesoNB == C_mesoNB, 1, 0),
                 flagSum = flagB + flagNB,
                 Scenario = scen, Year = year) %>%        #Sum flags and flag scenario and year
          filter(flagSum != 2) %>%                                  #Filter to keep differences
          left_join(in_ports, by = c("C_nameNB" = "Port")) %>%                #Merge 'B' = bulk goods port name with port crosswalk
          rename(C_coastNB = Coast) %>%
          left_join(in_ports, by = c("N_nameNB" = "Port")) %>%                 #Merge 'NB' = nonbulk goods with port crosswalk
          rename(N_coastNB = Coast) %>%
          left_join(in_ports, by = c("C_nameB" = "Port")) %>%                #Merge 'B' = bulk goods port name with port crosswalk
          rename(C_coastB = Coast) %>%
          left_join(in_ports, by = c("N_nameB" = "Port")) %>%                 #Merge 'NB' = nonbulk goods with port crosswalk
          rename(N_coastB = Coast) %>%
          filter((C_coastNB != N_coastNB) | (C_coastB != N_coastB)) %>%
          select(colnames(all_modePort))
        
        #Combine with template dataframe
        all_modePort<- rbind(all_modePort, qcOut) %>%
          arrange(Scenario, Year, Production_zone, Consumption_zone)
      }
      
    }

  }else if(name %in% stFiles){
    #Check static files not expected to change with udpate
    printOut = paste("stFiles: ", file, sep = "")
    cat(printOut, file =report,append=TRUE)
    cat("\n", file =report,append=TRUE)
    #Compare files and stop code if condition not met
    equ = all.equal(inCurrent, inNew)
    if(equ != TRUE){
      printOut = "uh oh! These files are not equal"
      cat(printOut, file =report,append=TRUE)
      stop()
      }
    
  }else{
    #Stop code if a file exists in the folder that is not accounted for in the 'stFiles' or 'chFiles' lists
    printOut = paste("uh oh: ", file," isn't supposed to be here!", sep = "")
    cat(printOut, file =report,append=TRUE)
    stop()
  }
}


#Final Output Formatting####
outSheets <- list(meso_skim = all_mesoSkim, mode_Mi = all_modeMi, mode_Port = all_modePort, mode_Skim = all_modeSkim,
                  zn_Emp = all_znEmp, zn_Skim = all_znSkim, truckEE = all_TruckEE, truckIE = all_TruckIE)
write.xlsx(outSheets, outXL)
