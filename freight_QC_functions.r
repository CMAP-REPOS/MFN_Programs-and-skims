# Author: Tyler Huang

# Date: 9/21/2026

# Description:
# This file contains functions for defining and executing QC for skim outputs based on file/skim type for the freight model.
# ALL execution will be done in run_freight_QC.r, which will call the functions defined in this file.

# This file is organized by the following sections:
# 1. QC Functions: Functions that define the QC for each skim output type. 
# Each function will take in the current and new skim output file data, as well as any additional arguments needed for the QC, and return a data frame containing the QC results.
# 2. File handling and QC routing functions: Functions that handle file pair matching, filename/year/scenario parsing, QC function identification,
# argument generation based on identified QC function, and QC function assembly.
# 3. Execution function: A function that executes the QC for all skim output files through iteration over the 
# current and new directories, using the architecture defined in the file handling and QC routing functions.

# Input Files (via run_freight_QC.r): 
# 2 file directories containing the current and new skim output files.
# MFN_crosswalks.xlsx: crosswalk  document for POE, mode path, ports, and zones.

# Output Files (via run_freight_QC.r):
# finalSkim_compareQC.xlsx: Excel file containing the QC compare results for all freight input files.
# qc_CompareReport.txt: Text file containing the QC report for all skim output files.
# qc_unmatched.txt: Text file containing the list of unmatched files between the current and new skim output directories.

# Adding New QC Functions:
# 1. To add a new QC function (for a new file type), define the function in this file, following the structure of the existing QC functions. Each QC function should 
# take in the current and new skim output file data, as well as any additional arguments needed for the QC, and return a data frame containing the QC results.
# 
# 2. In addition, edit the route_file() function to include the new QC function in the routing logic, based on the file name pattern.
# For example, if the new QC function is for a file type with a name pattern of "data_modepath_skims" in the directories and a QC function named "mode_path_skims", 
# the following line should be added to the route_file() function:
#     str_detect(file_name, "^data_truck_EE") ~ "truck_ee",
# NOTE: the key after ~ MUST match the name of the QC list in the qc_registry list. e.g. "truck_ee" corresponds to the qc_registry list name as shown in step 3.
# 
# If the new file type is a static file that does not require QC, the following line should be added instead:
#     str_detect(file_name, "^new_static_file") ~ "staticFile",
# 
# 3. Lastly, to work properly with the routing and execution pipeline for automated QC for the two directories, the new QC function 
# should be added to the qc_registry list.
# This qc_registry is a list of lists whose purpose is to create a centralized organized structure for executing the QC pipeline.
# The following elements for a new QC function should be included, using the truck_ee skim as an example:
#   truck_ee = list(
#     fn = truck_ee, # function to call
#     accumulator = "all_TruckEE", # accumulator name for the QC results
#     sheet = "truckEE", # sheet name for the QC results in the output Excel file
#     template = data.frame() # empty/template data frame for the QC results, with the same column names as the QC function output
#   )
# NOTE: If the new file type is a static file, no new QC function or qc_registry entry is needed, 
# but the new file type should be added to the route_file() function to be routed to "staticFile" for static file QC.


#-- QC FUNCTIONS
### CHANGE FILES #####
truck_ee <- function(inCurrent, inNew, year = NA_real_, scen = NA_character_, 
                     empUpdate = NA_character_, skLim = NA_real_, in_POE){
  #' This function: checks if all POE ID’s are in expected range, if not stops code; 
  #' Also compares current vs new: merge on ‘production_zone’ and ‘consumption_zone’; using crosswalk, flags direction of POE; 
  #' if POE directions from region are equal then data okay; filters to keep only differences; exports as supplemental data tab.
  #' 
  #' Args:
  #'  inCurrent (data.frame): The data frame containing the current directory's file.
  #'  inNew (data.frame): The data frame containing the new directory's file.
  #'  year (numeric): The year associated with the skim output data. (as an optional argument depending on file type;NA_real_ if not applicable)
  #'  scen (character): The scenario associated with the skim output data. (as an optional argument depending on file type; NA_character_ if not applicable)
  #'  empUpdate (character): A flag indicating whether employment updates are expected ("yes") or not ("no"). (as an optional argument depending on file type; NA_character_ if not applicable)
  #'  skLim (numeric): The threshold for percent difference in mesozone skims to trigger a printout. (as an optional argument depending on file type; NA_real_ if not applicable)
  #'  in_POE (data.frame): The data frame containing the crosswalk information.
  #' 
  #' Returns:
  #'  qcOut (data.frame): The data frame containing the QC output.
  
      inCurrent<- inCurrent %>% rename(C_poe = poe, C_poe2 = poe2)                                             #Load Current file and amend column names
      inNew<- inNew %>% rename(N_poe = poe, N_poe2 = poe2)                                                     #Load New file and amend column names
      qcOut <- full_join(inCurrent, inNew, by = join_by(Production_zone, Consumption_zone)) %>%                #Join data
        left_join(in_POE, by = c("C_poe2" = "POE")) %>%                                                       #Bind crosswalk
        rename(CState2 = State, CDirection2 = Direction) %>%
        left_join(in_POE, by = c("C_poe" = "POE")) %>%
        rename(CState = State, CDirection = Direction) %>%
        left_join(in_POE, by = c("N_poe2" = "POE")) %>%
        rename(NState2 = State, NDirection2 = Direction) %>%
        left_join(in_POE, by = c("N_poe" = "POE")) %>%
        rename(NState = State, NDirection = Direction) %>%
        filter((NDirection != CDirection) | (NDirection2 != CDirection2)) %>%
        select(all_of(colnames(qc_registry[['truck_ee']]$template)))
      
      #Confirm all POE ID's are in expected range; if not stop code
      check <- qcOut %>%
        filter((!(N_poe %in% in_POE$POE))|(!(C_poe %in% in_POE$POE))) %>%
        filter(!(is.na(N_poe) | is.na(C_poe)))
      if(nrow(check) != 0){
        print("ERROR, not all POEs in expected range")
        print(check)
        stop() }
      
return(qcOut)
}

# ask Karly how to handle 0.5 value (was .5 in code and was 0 in documentation and comments)
zone_employment <- function(inCurrent, inNew, year = NA_real_, scen = NA_character_, 
                            empUpdate = NA_character_, skLim = NA_real_, report){
  #' This function: sets ‘empUpdate’ flag at beginning of script; Compares current vs new ‘totalEmp’; filters to keep any differences > skLim (used to be any differences i.e. 0); 
  #' if empUpdate flag == ‘no’ but there are differences detected, stops code; otherwise, exports as supplemental data tab.
  #' 
  #' Args:
  #'  inCurrent (data.frame): The data frame containing the current directory's file.
  #'  inNew (data.frame): The data frame containing the new directory's file.
  #'  year (numeric): The year associated with the skim output data. (as an optional argument depending on file type;NA_real_ if not applicable)
  #'  scen (character): The scenario associated with the skim output data. (as an optional argument depending on file type; NA_character_ if not applicable)
  #'  empUpdate (character): A flag indicating whether employment updates are expected ("yes") or not ("no"). (as an optional argument depending on file type; NA_character_ if not applicable)
  #'  skLim (numeric): The threshold for percent difference in mesozone skims to trigger a printout. (as an optional argument depending on file type; NA_real_ if not applicable)
  #'  report (character): The path to the report file where any errors or messages will be logged.
  #' 
  #' Returns:
  #'  qcOut (data.frame): The data frame containing the QC output.

    inCurrent<- inCurrent %>% rename(currentEmp = totalemp)                    #Amend Current file column names
    inNew<- inNew %>% rename(newEmp = totalemp)                                #Amed New file column names
        
        qcOut <- full_join(inCurrent, inNew, by = join_by(Zone, mesozone)) %>%     #Merge new and current data
          mutate(Difference = newEmp-currentEmp,                                   #Calculate employment difference
                 Percent = round(Difference/(currentEmp),3)) %>%            #Calculate employment percent difference, round 3 decimal places
          filter(abs(Percent) > skLim)%>%                                     #Filter employment difference > skLim (used to be 0)
          mutate(Year = year) %>%                                                  #Assign year variable to different data
          select(all_of(colnames(qc_registry[['zone_employment']]$template)))     #Select template column names
        
        #Employment only expected to change if update is associated with a plan update
        #If difference exists otherwise, stop code
        if(sum(qcOut$Difference) > 0 & empUpdate != "yes"){
          printOut = "ERROR: Employment unexpectedly changes!"
          cat(printOut, file =report,append=TRUE)
          # stop()
          }                
       
    return(qcOut)
}

# ask Karly how to handle skLim value (was .01 in code and was 0 in documentation and comments)
zone_skims <- function(inCurrent, inNew, year = NA_real_, scen = NA_character_, 
                        empUpdate = NA_character_, skLim = NA_real_, in_zones){
  #' This function: compares current vs new; filters to keep any differences > skLim (used to be 0 and 0.01); exports as supplemental data tab.
  #' 
  #' Args:
  #'  inCurrent (data.frame): The data frame containing the current directory's file.
  #'  inNew (data.frame): The data frame containing the new directory's file.
  #'  year (numeric): The year associated with the skim output data. (as an optional argument depending on file type;NA_real_ if not applicable)
  #'  scen (character): The scenario associated with the skim output data. (as an optional argument depending on file type; NA_character_ if not applicable)
  #'  empUpdate (character): A flag indicating whether employment updates are expected ("yes") or not ("no"). (as an optional argument depending on file type; NA_character_ if not applicable)
  #'  skLim (numeric): The threshold for percent difference in mesozone skims to trigger a printout. (as an optional argument depending on file type; NA_real_ if not applicable)
  #'  in_zones(data.frame): The data frame containing the crosswalk information.
  #' 
  #' Returns:
  #'  qcOut (data.frame): The data frame containing the QC output.
 
    #Amend Current and New file column names
        inCurrent <- inCurrent %>% 
          rename(C_Peak = Peak, C_OffPeak = OffPeak, C_Miles = Miles)
        
        inNew <- inNew %>%
          rename(N_Peak = Peak, N_OffPeak = OffPeak, N_Miles = Miles)
        
        #Merge data, calculate differences
        #Peak and OffPeak Times; ussume time difference of 1 minute is okay
        #Distance
        qcOut <- full_join(inCurrent, inNew, by = join_by(Origin, Destination)) %>%
          left_join(in_zones, by = join_by("Origin" == 'Zone17')) %>%
          rename(OCounty = County) %>%
          left_join(in_zones, by = join_by("Destination" == 'Zone17')) %>%
          rename(DCounty = County)%>%
          mutate(OCounty = ifelse(is.na(OCounty), "POE", OCounty),
                 DCounty = ifelse(is.na(DCounty), "POE", DCounty)) %>%
          summarize(CPeak = sum(C_Peak),
                    NPeak = sum(N_Peak),
                    COffPeak = sum(C_OffPeak),
                    NOffPeak = sum(N_OffPeak),
                    CMiles = sum(C_Miles),
                    NMiles= sum(N_Miles),
                    .by = c("OCounty", "DCounty")) %>%
          mutate(diff_Peak = NPeak - CPeak,
                 perc_Peak = round(diff_Peak/CPeak,3),
                 diff_OffPeak = NOffPeak - COffPeak,
                 perc_OffPeak = round(diff_OffPeak/COffPeak, 3),
                 diff_Mi = NMiles - CMiles,
                 perc_Mi = round(diff_Mi/CMiles, 3),
                 flagPeaks = ifelse(abs(perc_Peak) > skLim | abs(perc_OffPeak) > skLim, 1, 0),
                 flagMi = ifelse(abs(perc_Mi) > skLim, 1, 0),
                 Year = year) %>%       #Sum all differences
          filter(flagPeaks == 1 | flagMi == 1) %>%    #filter to keep only OD pairs with differences
          select(all_of(colnames(qc_registry[['zone_skims']]$template)))   #Select column names from target dataframe
        
    return(qcOut)
}

mesozone_skims <- function(inCurrent, inNew, year = NA_real_, scen = NA_character_, 
                            empUpdate = NA_character_, skLim = NA_real_){
  #' This function: compares current vs new; filters to keep any differences greater than skLim; exports as supplemental data tab. (Filter used to be |1%|, now set to skLim)
  #' 
  #' Args:
  #'  inCurrent (data.frame): The data frame containing the current directory's file.
  #'  inNew (data.frame): The data frame containing the new directory's file.
  #'  year (numeric): The year associated with the skim output data. (as an optional argument depending on file type;NA_real_ if not applicable)
  #'  scen (character): The scenario associated with the skim output data. (as an optional argument depending on file type; NA_character_ if not applicable)
  #'  empUpdate (character): A flag indicating whether employment updates are expected ("yes") or not ("no"). (as an optional argument depending on file type; NA_character_ if not applicable)
  #'  skLim (numeric): The threshold for percent difference in mesozone skims to trigger a printout. (as an optional argument depending on file type; NA_real_ if not applicable)
  #' 
  #' Returns:
  #'  qcOut (data.frame): The data frame containing the QC output.
 
  #Amend Current and New file column names
        inCurrent <- inCurrent 
        colnames(inCurrent) <- c('Origin', 'Destination', 'currentTime') # added capitalization for origin and destination
        inNew <- inNew
        colnames(inNew) <- c('Origin', 'Destination', 'newTime') # added capitalization for origin and destination
        #Merge new and current data; calculate differencepercent difference in 
        qcOut <- full_join(inCurrent, inNew, by = join_by(Origin, Destination)) %>%   #Merge current and new data
          mutate(Year = year,                                                         #Flag current year of data
                 Difference = newTime - currentTime,                                  #Calculate difference in skim time
                 Percent = round(Difference/(newTime + currentTime),3)) %>%           #Calculate percent difference in skim time
          select(all_of(colnames(qc_registry[['mesozone_skims']]$template))) %>%   #Select column names of target dataframe # added capitalization for origin and destination
          filter(abs(Percent) >= skLim)%>%   #Filter to keep percent differences > |1%|
          arrange(Origin, Destination, Year)                                                  
  return(qcOut)
}

truck_ie <- function(inCurrent, inNew, year = NA_real_, scen = NA_character_, 
                     empUpdate = NA_character_, skLim = NA_real_, in_POE){
  #' This function: checks all POE ID’s are in expected range, if not stop code; 
  #' Also compares current vs new: merges on ‘production_zone’ and ‘consumption_zone’; filters to keep only differences; if difference is from switching to 
  #' a nearby node (same state or same flagged direction in crosswalk), then filter out as this is no issue; exports as supplemental data tab. 
  #' 
  #' Args:
  #'  inCurrent (data.frame): The data frame containing the current directory's file.
  #'  inNew (data.frame): The data frame containing the new directory's file.
  #'  year (numeric): The year associated with the skim output data. (as an optional argument depending on file type;NA_real_ if not applicable)
  #'  scen (character): The scenario associated with the skim output data. (as an optional argument depending on file type; NA_character_ if not applicable)
  #'  empUpdate (character): A flag indicating whether employment updates are expected ("yes") or not ("no"). (as an optional argument depending on file type; NA_character_ if not applicable)
  #'  skLim (numeric): The threshold for percent difference in mesozone skims to trigger a printout. (as an optional argument depending on file type; NA_real_ if not applicable)
  #'  in_POE (data.frame): The data frame containing the crosswalk information.
  #' 
  #' Returns:
  #'  qcOut (data.frame): The data frame containing the QC output.
   
  # Amend column names
  inCurrent <- inCurrent %>% rename(C_poe = poe)
  inNew     <- inNew %>% rename(N_poe = poe)
  
  # Process and join data
  qcOut <- full_join(inCurrent, inNew, by = join_by(Production_zone, Consumption_zone)) %>%
    left_join(in_POE, by = c("C_poe" = "POE")) %>%
    rename(CState = State, CDirection = Direction) %>%
    left_join(in_POE, by = c("N_poe" = "POE")) %>%
    rename(NState = State, NDirection = Direction) %>%
    filter(N_poe != C_poe) %>%
    filter(NDirection != CDirection) %>%
    filter(NState != CState) %>%
    mutate(Year = year, Scenario = scen) %>%
    # Explicitly select and order columns locally without 
    # calling all_truckIE to avoid potential issues with variable scope
    select(all_of(colnames(qc_registry[['truck_ie']]$template)))
  
  # Validate POE range
  check <- qcOut %>%
    filter(!(N_poe %in% in_POE$POE))
  
  if (nrow(check) != 0) {
    stop("ERROR: Invalid POE detected in output.")
  }
  
  return(qcOut)
}

# CHECK WITH KARLY IF WE WANT ONLY DIFFERENCES OR SET TO SKLIM (documentation doc said 0, code comment said 1%)
mode_path_miles <- function(inCurrent, inNew, year = NA_real_, scen = NA_character_, 
                            empUpdate = NA_character_, skLim = NA_real_, in_modePath){
  #' This function: Attaches modepath crosswalk with ‘minpath’; Summarizes variables by ‘minpath’ and ‘lognode’ ID; Merges current and new data by ‘minpath’ 
  #' and ‘lognode’ ID; compares miles by variable and flags for the rail dwell code and transfer fractions; filters to keep only differences; exports as supplemental data tab. 
  #' 
  #' Args:
  #'  inCurrent (data.frame): The data frame containing the current directory's file.
  #'  inNew (data.frame): The data frame containing the new directory's file.
  #'  year (numeric): The year associated with the skim output data. (as an optional argument depending on file type;NA_real_ if not applicable)
  #'  scen (character): The scenario associated with the skim output data. (as an optional argument depending on file type; NA_character_ if not applicable)
  #'  empUpdate (character): A flag indicating whether employment updates are expected ("yes") or not ("no"). (as an optional argument depending on file type; NA_character_ if not applicable)
  #'  skLim (numeric): The threshold for percent difference in mesozone skims to trigger a printout. (as an optional argument depending on file type; NA_real_ if not applicable)
  #'  in_modePath (data.frame): The data frame containing the crosswalk information.
  #' 
  #' Returns:
  #'  qcOut (data.frame): The data frame containing the QC output.
 
  #Amend Column names of new and current file
        inCurrent<- inCurrent %>%
          mutate(C_NATrnFr = ifelse(is.na(RlTrnfr), 1, 0))%>%      #Flag if current rail transfer code is NA
          left_join(in_modePath, by = c("MinPath" = "Path"))%>%
          summarize(C_TotalNtwkMiles=sum(TotalNtwkMiles), C_DmsLhMiles=sum(DmsLhMiles), C_DmsDrayMiles=sum(DmsDrayMiles), 
                    C_IntlShipMiles=sum(IntlShipMiles), C_CmapPsTR=sum(CmapPsTR), C_CmapPsRL=sum(CmapPsRL), 
                    C_RlDwlCode=mean(RlDwlCode), C_RlTrnfr=sum(C_NATrnFr),
                    .by = c("Mode", "LogNode"))
        
        inNew<- inNew %>%
          mutate(N_NATrnFr = ifelse(is.na(RlTrnfr), 1, 0))%>%      #Flag if new rail transfer code is NA
          left_join(in_modePath, by = c("MinPath" = "Path"))%>%
          summarize(N_TotalNtwkMiles=sum(TotalNtwkMiles), N_DmsLhMiles=sum(DmsLhMiles), N_DmsDrayMiles=sum(DmsDrayMiles), 
                    N_IntlShipMiles=sum(IntlShipMiles), N_CmapPsTR=sum(CmapPsTR), N_CmapPsRL=sum(CmapPsRL), 
                    N_RlDwlCode=mean(RlDwlCode), N_RlTrnfr=sum(N_NATrnFr),
                    .by = c("Mode", "LogNode"))
        
        #Merge and compare current and new data
        qcOut <- full_join(inCurrent, inNew, by = join_by(Mode, LogNode)) %>%
          mutate(diff_TotMi = N_TotalNtwkMiles - C_TotalNtwkMiles,                       #Calculate differences in distances
                 diff_DmsLh = N_DmsLhMiles - C_DmsLhMiles,
                 diff_DmsDray = N_DmsDrayMiles- C_DmsDrayMiles,
                 diff_IntlShip = N_IntlShipMiles- C_IntlShipMiles,
                 diff_PsTR = N_CmapPsTR-C_CmapPsTR, 
                 diff_PsRL = N_CmapPsRL-C_CmapPsRL, 
                 diff_RlTrnFr =N_RlTrnfr - C_RlTrnfr,                                      #Calculate change in rail transfer fraction
                 diff_RlDwlCode =N_RlDwlCode - C_RlDwlCode,                                #Calculate change in rail dwell code
                 Perc_TotMi = round(diff_TotMi/(N_TotalNtwkMiles + C_TotalNtwkMiles),3),   #Calculate percent differences
                 Perc_DmsLh = round(diff_DmsLh/(N_DmsLhMiles + C_DmsLhMiles),3),
                 Perc_DmsDray = round(diff_DmsDray/(N_DmsDrayMiles + C_DmsDrayMiles),3),
                 Perc_IntlShip = round(diff_IntlShip/(N_IntlShipMiles + C_IntlShipMiles),3),
                 Perc_PsTR = round(diff_PsTR/(N_CmapPsTR + C_CmapPsTR),3),
                 Perc_PsRL = round(diff_PsRL/(N_CmapPsRL + C_CmapPsRL),3),
                 Perc_RlTrnFr = round(diff_RlTrnFr/(N_RlTrnfr + C_RlTrnfr),3),
                 Perc_RlDwlCode = round(diff_RlDwlCode/(N_RlDwlCode + C_RlDwlCode),3),
                 Year = year,                                                               #Flag data year
                 Scenario = scen) %>%                                                       #Flag data scenario
          rowwise() %>%
          mutate(sumDiff = sum(c_across((Perc_TotMi:Perc_RlDwlCode)), na.rm = TRUE)) %>%     #Total all differences
          filter(abs(sumDiff) > skLim) %>%           #Filter for total differences greater than |1%|
          select(all_of(colnames(qc_registry[['mode_path_miles']]$template)))                                                    #Select column names of target dataframe
    return(qcOut)
}

mode_path_ports <- function(inCurrent, inNew, year = NA_real_, scen = NA_character_, 
                            empUpdate = NA_character_, skLim = NA_real_, in_ports){
  #' This function: merges current and new by production_zone and consumption_zone; keeps any differences where a port 
  #' used for OD pair changes coasts; exports as supplemental dataset 
  #' 
  #' Args:
  #'  inCurrent (data.frame): The data frame containing the current directory's file.
  #'  inNew (data.frame): The data frame containing the new directory's file.
  #'  year (numeric): The year associated with the skim output data. (as an optional argument depending on file type;NA_real_ if not applicable)
  #'  scen (character): The scenario associated with the skim output data. (as an optional argument depending on file type; NA_character_ if not applicable)
  #'  empUpdate (character): A flag indicating whether employment updates are expected ("yes") or not ("no"). (as an optional argument depending on file type; NA_character_ if not applicable)
  #'  skLim (numeric): The threshold for percent difference in mesozone skims to trigger a printout. (as an optional argument depending on file type; NA_real_ if not applicable)
  #'  in_ports (data.frame): The data frame containing the crosswalk information.
  #' 
  #' Returns:
  #'  qcOut (data.frame): The data frame containing the QC output.
 
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
          select(all_of(colnames(qc_registry[['mode_path_ports']]$template)))
    return(qcOut)
}

mode_path_skims <- function(inCurrent, inNew, year = NA_real_, scen = NA_character_, 
                            empUpdate = NA_character_, skLim = NA_real_, in_modePath, report){
  #' This function: Checks cost49 and time49 ==0 in 2022 and !=0 other years; stops code if condition not met;
  #' Also compares current vs new cost and times by mode path; filter to keep only differences > skLim. (Filter used to be |1%|, now set to skLim)
  #' 
  #' Args:
  #'  inCurrent (data.frame): The data frame containing the current directory's file.
  #'  inNew (data.frame): The data frame containing the new directory's file.
  #'  year (numeric): The year associated with the skim output data. (as an optional argument depending on file type;NA_real_ if not applicable)
  #'  scen (character): The scenario associated with the skim output data. (as an optional argument depending on file type; NA_character_ if not applicable)
  #'  empUpdate (character): A flag indicating whether employment updates are expected ("yes") or not ("no"). (as an optional argument depending on file type; NA_character_ if not applicable)
  #'  skLim (numeric): The threshold for percent difference in mesozone skims to trigger a printout. (as an optional argument depending on file type; NA_real_ if not applicable)
  #'  in_modePath (data.frame): The data frame containing the crosswalk information.
  #'  report (character): The path to the report file where any errors or messages will be logged.
  #' 
  #' Returns:
  #'  qcOut (data.frame): The data frame containing the QC output.

  #Check for 0 in 2022 and not in other years
        ch140 <- inNew %>%
          select(origin, destination, time49, cost49) %>%
          filter(!is.na(time49) | !is.na(cost49))
        if((year < 2035) & (nrow(ch140) > 0)){
          print(head(ch140))
          printOut = "ERROR: Values for modepath 49, logistics  node 140 shouldn't be active, it's not 2035 yet!"
          cat(printOut, file =report,append=TRUE)
          stop()
          
        }else if((year >= 2035) & (nrow(ch140) == 0)){
          print(head(ch140))
          printOut = "ERROR: No values for modepath 49, logistics  node 140 should be active, it's after 2035!"
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
          filter((abs(perc_Cost) > skLim) | (abs(perc_Time) > skLim)) %>%         #Filter to keep any differences in data
          mutate(Path = as.numeric(Mode)) %>%
          select(-Mode) %>%
          left_join(in_modePath, by = c("Path")) %>%                            #Join mode path information for inclusion in export
          select(all_of(colnames(qc_registry[['mode_path_skims']]$template)))                                        #Select column names of target dataframe
        
  return(qcOut)
}
  
### STATIC FILE QC FUNCTION ###

staticFile <- function(inCurrent, inNew, year = NA_real_, scen = NA_character_, 
                        empUpdate = NA_character_, skLim = NA_real_, report, rel_path){
  #' This function: compares current vs new; stop code if difference detected. These files are not expected to change with updates, so any difference is flagged as an error.
  #' These files are: zone centroids, mesozone centroids, mesozone GCD, mode path airports.
  #' 
  #' Args:
  #'  inCurrent (data.frame): The data frame containing the current directory's file.
  #'  inNew (data.frame): The data frame containing the new directory's file.
  #'  year (numeric): The year associated with the skim output data. (as an optional argument depending on file type;NA_real_ if not applicable)
  #'  scen (character): The scenario associated with the skim output data. (as an optional argument depending on file type; NA_character_ if not applicable)
  #'  empUpdate (character): A flag indicating whether employment updates are expected ("yes") or not ("no"). (as an optional argument depending on file type; NA_character_ if not applicable)
  #'  skLim (numeric): The threshold for percent difference in mesozone skims to trigger a printout. (as an optional argument depending on file type; NA_real_ if not applicable)
  #'  report (character): The path to the report file where any errors or messages will be logged.
  #'  rel_path (character): The relative path to the file being checked.
  #' 
  #' Returns:
  #'  qcOut (data.frame): The data frame containing the QC output.

  #Check static files not expected to change with udpate
    printOut = paste("Checking static file: ", rel_path, sep = "")
    cat(printOut, file =report,append=TRUE)
    cat("\n", file =report,append=TRUE)
    #Compare files and stop code if condition not met
    equ <- all.equal(inCurrent, inNew)
    if (!isTRUE(equ)) {
      printOut <- "uh oh! These files are not equal"
      cat(printOut, file = report, append = TRUE)
      cat("\n", file = report, append = TRUE)

      cat(paste(equ, collapse = "\n"), file = report, append = TRUE)
      cat("\n", file = report, append = TRUE)

      # stop(paste("Static file mismatch:", rel_path))
    }
  return()
}

#-- QC ROUTING FUNCTIONS

qc_registry <- list(
  truck_ee = list(
    fn = truck_ee,
    accumulator = "all_TruckEE",
    sheet = "truckEE",
    template = data.frame(
      Production_zone = integer(),
      Consumption_zone = integer(),
      C_poe2 = integer(),
      C_poe = integer(),
      N_poe2 = integer(),
      N_poe = integer(),
      CState = character(),
      NState = character(),
      CDirection = character(),
      NDirection = character(),
      CState2 = character(),
      NState2 = character(),
      CDirection2 = character(),
      NDirection2 = character()
    )
  ),

  zone_employment = list(
    fn = zone_employment,
    accumulator = "all_znEmp",
    sheet = "zn_Emp",
    template = data.frame(
      Year = numeric(),
      Zone = integer(),
      mesozone = integer(),
      currentEmp = integer(),
      newEmp = integer(),
      Difference = integer(),
      Percent = numeric()
    )
  ),

  zone_skims = list(
    fn = zone_skims,
    accumulator = "all_znSkim",
    sheet = "zn_Skim",
    template = data.frame(
      Year = numeric(),
      OCounty = character(),
      DCounty = character(),
      flagPeaks = numeric(),
      flagMi = numeric(),
      CPeak = numeric(),
      NPeak = numeric(),
      perc_Peak = numeric(),
      COffPeak = numeric(),
      NOffPeak = numeric(),
      perc_OffPeak = numeric(),
      CMiles = numeric(),
      NMiles = numeric(),
      perc_Mi = numeric()
    )
  ),

  mesozone_skims = list(
    fn = mesozone_skims,
    accumulator = "all_mesoSkim",
    sheet = "meso_skim",
    template = data.frame(
      Year = numeric(),
      Origin = integer(),
      Destination = integer(),
      currentTime = numeric(),
      newTime = numeric(),
      Difference = numeric(),
      Percent = numeric()
    )
  ),

  truck_ie = list(
    fn = truck_ie,
    accumulator = "all_TruckIE",
    sheet = "truckIE",
    template = data.frame(
      Scenario = character(),
      Year = numeric(),
      Production_zone = integer(),
      Consumption_zone = integer(),
      C_poe = integer(),
      N_poe = integer(),
      CState = character(),
      NState = character(),
      CDirection = character(),
      NDirection = character()
    )
  ),

  mode_path_miles = list(
    fn = mode_path_miles,
    accumulator = "all_modeMi",
    sheet = "mode_Mi",
    template = data.frame(
      Scenario = character(),
      Year = numeric(),
      Mode = character(),
      LogNode = numeric(),
      Perc_TotMi = numeric(),
      Perc_DmsLh = numeric(),
      Perc_DmsDray = numeric(),
      Perc_IntlShip = numeric(),
      Perc_PsTR = numeric(),
      Perc_PsRL = numeric(),
      Perc_RlDwlCode = numeric(),
      Perc_RlTrnFr = numeric()
    )
  ),

  mode_path_ports = list(
    fn = mode_path_ports,
    accumulator = "all_modePort",
    sheet = "mode_Port",
    template = data.frame(
      Scenario = character(),
      Year = numeric(),
      Production_zone = integer(),
      Consumption_zone = integer(),
      C_mesoNB = integer(),
      N_mesoNB = integer(),
      C_mesoB = integer(),
      N_mesoB = integer(),
      C_nameNB = character(),
      N_nameNB = character(),
      C_nameB = character(),
      N_nameB = character(),
      C_coastNB = character(),
      N_coastNB = character(),
      C_coastB = character(),
      N_coastB = character()
    )
  ),

  mode_path_skims = list(
    fn = mode_path_skims,
    accumulator = "all_modeSkim",
    sheet = "mode_Skim",
    template = data.frame(
      Scenario = character(),
      Year = numeric(),
      Mode = character(),
      LogNode = numeric(),
      C_Time = numeric(),
      C_Cost = numeric(),
      N_Time = numeric(),
      N_Cost = numeric(),
      perc_Time = numeric(),
      perc_Cost = numeric()
    )
  ),

  staticFile = list(
    fn = staticFile,
    accumulator = NULL,
    sheet = NULL,
    template = NULL
  )
)

build_file_pairs <- function(newDir, currentDir, unmatched_path){
  #' This function builds a list of file pairs for comparison between the new and current skim output directories. 
  #' It identifies common files and creates a list with matches. 
  #' It logs any unmatched files as a .txt file to a specified path.
  #' 
  #' Note: In run_freight_QC.r, these arguments are pre-defined and then passed to the execution function.
  #' 
  #' Args: 
  #'  newDir (character): Path to the new directory containing files to compare.
  #'  currentDir (character): Path to the current directory containing files to compare.
  #'  unmatched_path (character): Path to the file where unmatched files will be logged.
  #' 
  #' Returns:
  #'  A list of lists, where each inner list contains the relative path (character), current file path (character), 
  #'  and new file path (character) for each matched file.

  n <- list.files(newDir, recursive = TRUE, full.names = FALSE, include.dirs = FALSE)
  c <- list.files(currentDir, recursive = TRUE, full.names = FALSE,include.dirs = FALSE)

  common <- intersect(c, n)

  unmatched_files <- setdiff(union(c,n),intersect(c,n))

  if (length(unmatched_files)>0){
    cat(
      paste0(unmatched_files, ", "),
      file = unmatched_path,
      append = TRUE
    )
  }

  pair_list <- lapply(common, function(rel_path) {
    list(
      rp = rel_path,
      current = file.path(currentDir, rel_path),
      new = file.path(newDir, rel_path)
    )
  })
  names(pair_list) <- common

  return(pair_list)
}

parse_file_name <- function(rel_path){
  #' This function parses the relative file path to extract file name, year, and scenario information.
  #' 
  #' Note: if year or scenario change from the strict current naming convention in file names, this function may need to be 
  #' updated to accommodate new regex patterns.
  #' 
  #' Args:
  #'  rel_path (character): The relative path to a file.
  #' 
  #' Returns:
  #'  A list containing the file name (character), year (numeric), and scenario (character). 
  #'  If the year or scenario cannot be parsed, they will be returned as NA.
  
  file_name <- basename(rel_path)

  # regex for parsing year in filenames
  year_match <- str_match(
    file_name,
    "(?:^|[_-])((?:20)\\d{2})(?:[_-]|\\.|$)"
  )[, 2]

  # regex for parsing scenarios is only for parsing filename data for subfolder names 
  # LogNode140 and No_LogNode140 only currently
  scen_match <- str_match(
    rel_path,
    "(?:^|[/\\\\])(LogNode140|No_LogNode140)(?:[/\\\\]|$)"
  )[, 2]

  parsed_data <- list(
    file_name = file_name,
    year = if (is.na(year_match)) NA_real_ else as.numeric(year_match),
    scen = if (is.na(scen_match)) NA_character_ else scen_match
  )

  return(parsed_data)
}

route_file <- function(parsed_data){
  #' This function determines the appropriate QC function to route to based on the parsed file name.
  #' 
  #' Note: if file name formats change from the current naming conventions in file names, this function may need to be 
  #' updated to accommodate new patterns in case_when().
  #' 
  #' Args:
  #'  parsed_data (list): A list containing the parsed file name (character), year (numeric), and scenario (character).
  #' 
  #' Returns:
  #'  String indicating the type of QC function to route to. If no match is found, it defaults to NA_character_.
  
  file_name = parsed_data$file_name
  case_when(
    str_detect(file_name, "^cmap_data_truck_EE_poe") ~ "truck_ee",
    str_detect(file_name, "^cmap_data_zone_employment") ~ "zone_employment",
    str_detect(file_name, "^cmap_data_zone_skims") ~ "zone_skims",
    str_detect(file_name, "^data_mesozone_skims") ~ "mesozone_skims",
    str_detect(file_name, "^cmap_data_truck_IE_poe") ~ "truck_ie",
    str_detect(file_name, "^data_modepath_miles") ~ "mode_path_miles", #update
    str_detect(file_name, "^data_modepath_ports") ~ "mode_path_ports",
    str_detect(file_name, "^data_modepath_skims") ~ "mode_path_skims",
    str_detect(file_name, "^data_modepath_airports") ~ "staticFile",
    str_detect(file_name, "^data_mesozone_centroids") ~ "staticFile",
    str_detect(file_name, "^data_mesozone_gcd") ~ "staticFile",
    str_detect(file_name, "^cmap_data_zone_centroids") ~ "staticFile",
    TRUE ~ NA_character_
  )
}

identify_function_routing <- function(parsed_data){
  #' This function determines the appropriate QC function to route to based on the parsed file name using the route_file function and
  #' the routing_list.
  #' 
  #' Args:
  #'  parsed_data (list): A list containing the parsed file name (character), year (numeric), and scenario (character).
  #' 
  #' Returns:
  #' The identified file type's list from qc_registry (containing the QC function, accumulator, sheet, and data.frame template.). 
  #' If no match is found for a file, it stops execution and returns an error message.
  
  kind <- route_file(parsed_data)

  if (is.na(kind) || !kind %in% names(qc_registry)) {
    stop("No QC route configured for file: ", parsed_data$file_name)
  }

  route <- qc_registry[[kind]]
  print(kind)
  return(route)
}

# helper function to be used within build_route arguments:
read_file_pair <- function(pair_list, rel_path){
  #' This function reads the current and new files for a given file pair from the specified relative path within the pair_list created in build_file_pairs().
  #' 
  #' Args:
  #'  pair_list (list): A list of lists, where each inner list contains the relative path (character), current file path (character), 
  #'  and new file path (character) for each matched file.
  #'  rel_path (character): The relative path to the file pair.
  #' 
  #' Returns:
  #' A list containing the full dataframes for the current file and the new file.
  
  pair_args <- list(
    inCurrent = read.csv(pair_list[[rel_path]]$current),
    inNew = read.csv(pair_list[[rel_path]]$new)
  )
  return(pair_args)
}

build_route_arguments <- function(rel_path, parsed_data, route, pair_list, empUpdate, skLim, 
                                  in_POE, in_modePath, in_ports, in_zones, report){
  #' This function builds the arguments to be passed to the QC function based on the parsed file name, the routing information, and the available inputs.
  #' 
  #' Note: The arguments from empUpdate and onwards are set to be defined in run_freight_QC.r. 
  #' If additional inputs are needed for a specific QC function, they should be added to the available list within this function and
  #  added to the function signature of the specific QC function. They should also be added as a parameter to this function, the assemble_QC() function, the execution() function,
  #  and the run_freight_QC.r script.
  #' 
  #' Args:
  #'  rel_path (character): The relative path to the file pair.
  #'  parsed_data (list): A list containing the parsed file name (character), year (numeric), and scenario (character).
  #'  route (list): The identified file type's list from qc_registry, containing the QC function, accumulator, sheet, and template.
  #'  pair_list (list): A list of lists, where each inner list contains the relative path (character), current file path (character), 
  #'    and new file path (character) for each matched file.
  #'  empUpdate (character): 'Yes' or 'No' indicating change in employement data.
  #'  skLim (numeric): The skLim numeric threshold for filtering differences in skims.
  #'  in_POE (data.frame): The POE crosswalk data.
  #'  in_modePath (data.frame): The mode path crosswalk data.
  #'  in_ports (data.frame): The ports crosswalk data.
  #'  in_zones (data.frame): The zones crosswalk data.
  #'  report (character): The report file path for logging QC run and issues.
  #' 
  #' Returns:
  #'  A list of arguments to be passed to the identified QC function, including the current and new dataframes, year, scenario, and any other relevant inputs.

  inputs <- read_file_pair(pair_list, rel_path)

  available <- list(year = parsed_data$year, scen = parsed_data$scen, empUpdate = empUpdate, skLim = skLim, in_POE = in_POE,
                    in_modePath = in_modePath, in_ports = in_ports, in_zones = in_zones, report = report, rel_path = rel_path)

  fn_params <- names(formals(route$fn))

  args <- list()

  for (parameter in names(inputs)) {
    if (parameter %in% fn_params) {
      args[[parameter]] <- inputs[[parameter]]
    }
  }

  for (parameter in names(available)) {
    if (parameter %in% fn_params) {
      args[[parameter]] <- available[[parameter]]
    }
  }

  if (!all(c("inCurrent", "inNew") %in% names(args))) {
      stop("Missing required QC inputs for this file type")
  }

  print("ARGUMENTS:")
  print(names(args))
  return(args)
}

make_accumulators <- function() {
  accumulators <- list()

  for (entry in qc_registry) {
    if (!is.null(entry$accumulator)) {
      accumulators[[entry$accumulator]] <- entry$template
    }
  }

  return(accumulators)
}

assemble_QC <- function(rel_path, pair_list, empUpdate, skLim,
  in_POE, in_modePath, in_ports, in_zones, report){
  #' This function assembles the QC function and its arguments for a given file pair based on the relative path, the pair list, and the available inputs. 
  #' 
  #' Note: The arguments from empUpdate and onwards are set to be defined in run_freight_QC.r. 
  #' If additional inputs are needed for a specific QC function, they should be added to the available list within this function and
  #  added to the function signature of the specific QC function. They should also be added as a parameter to this function, the build_route_arguments() function, the execution() function,
  #  and the run_freight_QC.r script.
  #' 
  #' Args:
  #'  rel_path (character): The relative path to the file pair.
  #'  pair_list (list): A list of lists, where each inner list contains the relative path (character), current file path (character), and new file path (character) for each matched file.
  #'  empUpdate (character): 'Yes' or 'No' indicating change in employement data.
  #'  skLim (numeric): The skLim numeric threshold for filtering differences in skims.
  #'  in_POE (data.frame): The POE crosswalk data.
  #'  in_modePath (data.frame): The mode path crosswalk data.
  #'  in_ports (data.frame): The ports crosswalk data.
  #'  in_zones (data.frame): The zones crosswalk data.
  #'  report (character): The report file path for logging QC run and issues.
  #' 
  #' Returns:
  #'  A data.frame result of the identified QC function for the given file pair

  print('assembling QC function and arguments for file pair')
  parsed_data <- parse_file_name(rel_path)
  route <- identify_function_routing(parsed_data)
  arguments <- build_route_arguments(rel_path, parsed_data, route, pair_list, empUpdate, 
                                    skLim, in_POE, in_modePath, in_ports, in_zones, report)
  do.call(route$fn, arguments)
}

execution <- function(newDir, currentDir, empUpdate, skLim, in_POE, in_modePath,
  in_ports, in_zones, report, unmatched, selection = 'ALL'){
  #' This function executes the QC process by building file pairs, routing to the appropriate QC functions, and accumulating results.
  #' 
  #' Args:
  #'  newDir (character): Path to the new directory containing files to compare.
  #'  currentDir (character): Path to the current directory containing files to compare.
  #'  empUpdate (character): 'Yes' or 'No' indicating change in employment data.
  #'  skLim (numeric): The skLim numeric threshold for filtering differences in skims.
  #'  in_POE (data.frame): The POE crosswalk data.
  #'  in_modePath (data.frame): The mode path crosswalk data.
  #'  in_ports (data.frame): The ports crosswalk data.
  #'  in_zones (data.frame): The zones crosswalk data.
  #'  report (character): The report file path for logging QC run and issues.
  #'  unmatched (logical): A logical vector indicating which files are unmatched.
  #'  selection (character): A character or character vector specifying which QC functions to run, if specified using the keys from the routing list. Defaults to 'ALL'.
  #' 
  #' Returns:
  #'  A list of data.frames containing the accumulated QC results for all matched files within both the new and current directories.
  
  print("executing...")

  # is having unmatched here correct? make sure from exec function run
  pair_list <- build_file_pairs(newDir, currentDir, unmatched)
  
  if (!identical(selection, 'ALL')) {
    valid_types <- names(qc_registry)
    invalid_types <- setdiff(selection, valid_types)

    if (length(invalid_types) > 0) {
      stop(
        "Unknown QC selection: ",
        paste(invalid_types, collapse = ", "),
        ". Valid selections are: ",
        paste(valid_types, collapse = ", ")
      )
    }

    keep <- vapply(
      pair_list,
      function(pair) {
        route_file(parse_file_name(pair$rp)) %in% selection
      },
      logical(1)
    )

    pair_list <- pair_list[keep]
  }
  accumulators <- make_accumulators()
  result_chunks <- lapply(accumulators, function(template) list())

  for (pair in pair_list) {
    print(paste("NOW PROCESSING:", pair$rp))
    cat(
      paste0("Processing: ", pair$rp, ", "),
      file = report,
      append = TRUE
    )

    res <- tryCatch(
      assemble_QC(
        rel_path = pair$rp,
        pair_list = pair_list,
        empUpdate = empUpdate,
        skLim = skLim,
        in_POE = in_POE,
        in_modePath = in_modePath,
        in_ports = in_ports,
        in_zones = in_zones,
        report = report
      ),
      error = function(e) {
        msg <- paste0("Error processing ", pair$rp, ": ", conditionMessage(e), "\n")
        cat(msg, file = report, append = TRUE)
        stop(e)
      }
    )

    if (is.null(res)) {
      next
    }

    kind <- route_file(parse_file_name(pair$rp)) # identify the appropriate function
    accumulator_name <- qc_registry[[kind]]$accumulator # identify appropriate dataframe to populate

    if (!is.null(accumulator_name)) {
      print('APPENDING:')
      print(pair$rp)
      result_chunks[[accumulator_name]][[length(result_chunks[[accumulator_name]]) + 1L]] <- res
    }
    print(paste("FINISHED PROCESSING:", pair$rp))
  }

  for (accumulator_name in names(accumulators)) {
  accumulators[[accumulator_name]] <- dplyr::bind_rows(c(list(accumulators[[accumulator_name]]), result_chunks[[accumulator_name]]))
}

  print("finished running all files")

  return(accumulators)
}
