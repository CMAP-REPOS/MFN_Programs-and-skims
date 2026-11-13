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

# run_freight_QC.r
# |
# +-- Load required R packages
# +-- Set input, output, and report paths
# +-- Source freight_QC_functions.r
# +-- Read crosswalk sheets
# +-- Clear existing output files
# +-- Set QC options (empUpdate, skLim, selection)
# |
# +-- Call execution(...)
#     |
#     +-- List files in currentDir and newDir
#     +-- Match files by relative path
#     +-- Write unmatched file paths to qc_unmatched.txt
#     +-- Keep only file types included in selection
#     |
#     +-- For each matched file pair
#     |   |
#     |   +-- Parse filename and relative path
#     |   |   +-- Extract filename
#     |   |   +-- Extract year, if present
#     |   |   +-- Extract scenario folder, if present
#     |   |
#     |   +-- Route filename to a QC type using route_file()
#     |   +-- Look up QC function and output definitions in qc_registry
#     |   +-- Read current and new CSV files
#     |   +-- Pass only the arguments required by that QC function
#     |   +-- Run the QC function
#     |   +-- Log processing/errors to qc_CompareReport.txt
#     |   +-- Add returned result(s) to the appropriate output sheet(s)
#     |
#     +-- Combine results for each sheet
#     +-- Sort sheets that define arrange_by columns
#     +-- Return QC results
# |
# +-- Write returned results to the dated Excel file (outXL)

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
        select(
          Production_zone, Consumption_zone,
          C_poe2, C_poe, N_poe2, N_poe,
          CState, NState, CDirection, NDirection,
          CState2, NState2, CDirection2, NDirection2
        )
      
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

zone_employment <- function(inCurrent, inNew, year = NA_real_, scen = NA_character_, 
                            empUpdate = NA_character_, skLim = NA_real_, report, in_mesozones){
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

    inCurrent<- inCurrent %>% rename(currentEmp = totalemp) %>% mutate(current_present = TRUE) #Amend Current file column names
    inNew<- inNew %>% rename(newEmp = totalemp) %>% mutate(new_present = TRUE)    #Amend New file column names
        
        join <- full_join(inCurrent, inNew, by = join_by(Zone, mesozone)) %>% #Merge new and current data
          mutate(
              currentEmp = if_else(is.na(current_present), 0, currentEmp),
              newEmp = if_else(is.na(new_present), 0, newEmp)
            )

        qcOut <- join %>% 
          left_join(in_mesozones, by = join_by(mesozone == Mesozone)) %>%                      #Bind crosswalk
          summarize(
            currentEmpSum = sum(currentEmp),
            newEmpSum = sum(newEmp),
            .by = 'County'
          ) %>%
          mutate(Difference = newEmpSum - currentEmpSum,                           #Calculate employment difference
                 Percent = round(Difference/(currentEmpSum),3)) %>%          #Calculate employment percent difference, round 3 decimal places
          # filter(abs(Percent) > skLim)%>%                                     #Filter employment difference > skLim (used to be 0)
          mutate(Year = year) %>%                                                  #Assign year variable to different data
          select(Year, County, currentEmpSum, newEmpSum, Difference, Percent)     #Select template column names
        
        #Employment only expected to change if update is associated with a plan update
        #If difference exists otherwise, stop code
        # if(sum(qcOut$Difference) > 0 & empUpdate != "yes"){
        #   printOut = "ERROR: Employment unexpectedly changes!"
        #   cat(printOut, file=report, append=TRUE)
        #   # stop()
        #   }    
        employment_check <- join %>%    
          mutate(Difference = newEmp - currentEmp)
        if (any(abs(employment_check$Difference) > 0) && empUpdate != "yes") {
          cat("ERROR: Employment unexpectedly changes!\n", file = report, append = TRUE)
          # stop()
        }           
       
    return(qcOut)
}

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
 
    od_qc <- function(od_county){ # function arguments will be either 'OCounty' or 'DCounty'
    #Amend Current and New file column names
        inCurrent <- inCurrent %>% 
          rename(C_Peak = Peak, C_OffPeak = OffPeak, C_Miles = Miles) %>% mutate(current_present = TRUE)
        
        inNew <- inNew %>%
          rename(N_Peak = Peak, N_OffPeak = OffPeak, N_Miles = Miles) %>% mutate(new_present = TRUE)
        
        #Merge data, calculate differences
        #Peak and OffPeak Times; ussume time difference of 1 minute is okay
        #Distance
        qcOut <- full_join(inCurrent, inNew, by = join_by(Origin, Destination)) %>%
          mutate(
                C_Peak    = if_else(is.na(current_present), 0, C_Peak),
                C_OffPeak = if_else(is.na(current_present), 0, C_OffPeak),
                C_Miles   = if_else(is.na(current_present), 0, C_Miles),
                N_Peak    = if_else(is.na(new_present), 0, N_Peak),
                N_OffPeak = if_else(is.na(new_present), 0, N_OffPeak),
                N_Miles   = if_else(is.na(new_present), 0, N_Miles)) %>%
          left_join(in_zones, by = join_by(Origin == Zone17)) %>%
          rename(OCounty = County) %>%
          left_join(in_zones, by = join_by(Destination == Zone17)) %>%
          rename(DCounty = County)%>%
          mutate(OCounty = ifelse(is.na(OCounty), "POE", OCounty),
                 DCounty = ifelse(is.na(DCounty), "POE", DCounty)) %>%
          summarize(CPeak = sum(C_Peak),
                    NPeak = sum(N_Peak),
                    COffPeak = sum(C_OffPeak),
                    NOffPeak = sum(N_OffPeak),
                    CMiles = sum(C_Miles),
                    NMiles= sum(N_Miles),
                    .by = all_of(od_county)) %>%
          mutate(Year = year,
                 diff_Peak = NPeak - CPeak,
                 perc_Peak = round(diff_Peak/CPeak,3),
                 diff_OffPeak = NOffPeak - COffPeak,
                 perc_OffPeak = round(diff_OffPeak/COffPeak, 3),
                 diff_Mi = NMiles - CMiles,
                 perc_Mi = round(diff_Mi/CMiles, 3),
                 flagPeaks = ifelse(abs(perc_Peak) > skLim | abs(perc_OffPeak) > skLim, 1, 0),
                 flagMi = ifelse(abs(perc_Mi) > skLim, 1, 0)) %>% 
          # filter(flagPeaks == 1 | flagMi == 1) %>%    #filter to keep only OD pairs with differences
          select(
            Year, all_of(od_county),
            CPeak, NPeak, diff_Peak, perc_Peak,
            COffPeak, NOffPeak, diff_OffPeak, perc_OffPeak,
            CMiles, NMiles, diff_Mi, perc_Mi, flagPeaks, flagMi
          )   # to hardcode columns we want 
        
    return(qcOut)
  }
  return(list(
    by_origin = od_qc("OCounty"),
    by_destination = od_qc("DCounty")
  ))
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
   
  mz_qc <- function(od_county){ # function arguments will be either 'OCounty' or 'DCounty'
    inCurrent <- inCurrent %>% set_names(c("Origin", "Destination", "currentTime")) %>%
      mutate(current_present = TRUE) # added capitalization for origin and destination for consistency

    inNew <- inNew %>%
      set_names(c("Origin", "Destination", "newTime")) %>%
      mutate(new_present = TRUE)

    #Merge new and current data; calculate summary stats
    qcOut <- full_join(inCurrent, inNew, by = join_by(Origin, Destination)) %>%   #Merge current and new data
          mutate(currentTime = if_else(is.na(current_present), 0, currentTime),
               newTime = if_else(is.na(new_present), 0, newTime)) %>%
          left_join(in_mesozones, by = join_by(Origin == Mesozone)) %>%
          rename(OCounty = County, ORegion = Region) %>%
          left_join(in_mesozones, by = join_by(Destination == Mesozone)) %>%
          rename(DCounty = County, DRegion = Region)%>%
          summarize(
            currentTime = sum(currentTime), 
            newTime = sum(newTime), 
            .by = all_of(od_county)) %>%  #Sum all differences
          mutate(Year = year,                                                         #Flag current year of data
                 currentTime = currentTime,
                 newTime = newTime,
                 Difference = newTime - currentTime,                                  #Calculate difference in skim time
                 Percent = round(Difference/(currentTime),7)) %>%           #Calculate percent difference in skim time
          select(Year, all_of(od_county),
            currentTime, newTime, Difference, Percent)   #Select column names of target dataframe # added capitalization for origin and destination
          # filter(abs(Percent) >= skLim)%>%   #Filter to keep percent differences > |1%|
          # arrange(Origin, Destination, Year)                                                  
    return(qcOut)
    }

  return(list(
    by_origin = mz_qc("OCounty"),
    by_destination = mz_qc("DCounty")
  ))
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
    select(
      Scenario, Year, Production_zone, Consumption_zone,
      C_poe, N_poe, CState, NState, CDirection, NDirection
    )
  
  # Validate POE range
  check <- qcOut %>%
    filter(!(N_poe %in% in_POE$POE))
  
  if (nrow(check) != 0) {
    stop("ERROR: Invalid POE detected in output.")
  }
  
  return(qcOut)
}

# mode_path_miles <- function(inCurrent, inNew, year = NA_real_, scen = NA_character_, 
#                             empUpdate = NA_character_, skLim = NA_real_, in_modePath){
#   #' This function: Attaches modepath crosswalk with ‘minpath’; Summarizes variables by ‘minpath’ and ‘lognode’ ID; Merges current and new data by ‘minpath’ 
#   #' and ‘lognode’ ID; compares miles by variable and flags for the rail dwell code and transfer fractions; filters to keep only differences; exports as supplemental data tab. 
#   #' 
#   #' Args:
#   #'  inCurrent (data.frame): The data frame containing the current directory's file.
#   #'  inNew (data.frame): The data frame containing the new directory's file.
#   #'  year (numeric): The year associated with the skim output data. (as an optional argument depending on file type;NA_real_ if not applicable)
#   #'  scen (character): The scenario associated with the skim output data. (as an optional argument depending on file type; NA_character_ if not applicable)
#   #'  empUpdate (character): A flag indicating whether employment updates are expected ("yes") or not ("no"). (as an optional argument depending on file type; NA_character_ if not applicable)
#   #'  skLim (numeric): The threshold for percent difference in mesozone skims to trigger a printout. (as an optional argument depending on file type; NA_real_ if not applicable)
#   #'  in_modePath (data.frame): The data frame containing the crosswalk information.
#   #' 
#   #' Returns:
#   #'  qcOut (data.frame): The data frame containing the QC output.

mode_path_miles <- function(inCurrent, inNew, year = NA_real_, scen = NA_character_,
                            empUpdate = NA_character_, skLim = NA_real_, in_modePath) {
  #' docstring
  milescols_qc <- function(group) {
    bind_rows(
      Current = inCurrent,
      New = inNew,
      .id = "Version"
    ) %>%
    mutate(RlTrnfr = ifelse(is.na(RlTrnfr), 1, 0)) %>% # not changing dwell stuff yet 
    left_join(in_modePath, by = c("MinPath" = "Path")) %>%
    pivot_longer(
        cols = all_of(c(
          "TotalNtwkMiles", 'DmsLhMiles', "DmsDrayMiles", "IntlShipMiles",
          "CmapPsTR", "CmapPsRL", "RlDwlCode", "RlTrnfr"
        )),
        names_to = 'Attribute',
        values_to = "Value"
      ) %>%
    summarize(
        Sum = sum(Value, na.rm = TRUE),
        .by = c(all_of(group), Version, Attribute)
      ) %>%
    pivot_wider(names_from = Version, values_from = Sum, names_glue = "{Version}Sum") %>%
    mutate(
        Difference = NewSum - CurrentSum,
        PercentChange = round(Difference / (CurrentSum), 3),
        Year = year,
        Scenario = scen,
        QCvalue = case_when(
          Attribute %in% c("TotalNtwkMiles", "DmsLhMiles", "DmsDrayMiles", "IntlShipMiles") ~ PercentChange,
          TRUE ~ Difference
        )
      ) %>%
    pivot_wider(id_cols = c(Scenario, Year, all_of(group)), names_from = Attribute,
        values_from = QCvalue) %>%
      # pivot_longer(cols = all_of(c('CurrentSum','NewSum','Difference', 'PercentChange')),
      #   names_to = 'QCoperation',
      #   values_to = 'QCvalue') %>%
      # filter((QCoperation == 'PercentChange' & abs(QCvalue) > skLim) | 
      # (QCoperation == 'Difference') |
      # (QCoperation == 'CurrentSum') |
      # (QCoperation == 'NewSum')
      # ) %>%
      # # filter(abs(PercentDifference) > skLim) %>%
    select(all_of(names(
        qc_registry[["mode_path_miles"]]$outputs[[if (group == "Mode") "by_mode" else "by_log_node"]]$template
      )))
  }

  dwellcode_qc <- function(){
    qc <- bind_rows(
        Current = inCurrent,
        New = inNew,
        .id = "Version"
      ) %>%
      left_join(in_modePath, by = c("MinPath" = "Path")) %>%
      mutate(
        rail_interchange = case_when(
          is.na(RlDwlCode) ~ NA_character_,
          RlDwlCode == 0 ~ "No passthrough",
          RlDwlCode > 0 & RlDwlCode <= 1 ~ "Memphis",
          RlDwlCode > 1 & RlDwlCode <= 2 ~ "New Orleans",
          RlDwlCode > 2 & RlDwlCode <= 3 ~ "St Louis",
          RlDwlCode > 3 & RlDwlCode <= 4 ~ "Kansas City",
          TRUE ~ "No match"
        ),
        rail_interchange = if_else(
          !is.na(RlDwlCode) & !near(RlDwlCode, round(RlDwlCode)),
          paste0(rail_interchange, " (", format(RlDwlCode, trim = TRUE), ")"),
          rail_interchange
        )
      ) %>%
      filter(!is.na(rail_interchange)) %>%
      summarize(
          Count = n(), # count
          .by = c(Mode, Version, rail_interchange)
        ) %>%
      pivot_wider(names_from = Version, values_from = Count, names_glue = "{Version}Count") %>% 
      # what to do about mismatch if current or new dont have a value
      mutate(
          CurrentCount = coalesce(CurrentCount, 0L),
          NewCount = coalesce(NewCount, 0L),
          Difference = NewCount - CurrentCount,
          PercentChange = round(Difference / CurrentCount, 3),
          Year = year,
          Scenario = scen
        )
    qc
  }

  cmapcols_qc <- function(col){ #col = CmapPsRL or CmapPsTR
    current <- inCurrent %>%
      select(Origin, Destination, MinPath, all_of(col)) %>%
      rename(Path = MinPath, current = all_of(col)) %>%
      left_join(in_modePath, by = join_by(Path)) %>%
      summarize(count_current = sum(current),
                .by = c('Path', 'Mode')) %>%
      filter(count_current != 0)
    
    new <- inNew %>%
      select(Origin, Destination, MinPath, all_of(col))%>%
      rename(Path = MinPath, new = all_of(col)) %>%
      left_join(in_modePath, by = join_by(Path)) %>%
      filter(!is.na(new)) %>%
      summarize(count_new = sum(new),
                .by = c('Path', 'Mode')) %>%
      filter(count_new != 0)
  
    compare <- current %>%
      full_join(new, by = join_by(Path, Mode)) %>%
      mutate(
        count_current = count_current, # took out coalesce function
        count_new = count_new, # took out coalesce function
        Difference = count_new - count_current,
        PercDiff = round(Difference / (count_current), 3),
        Year = year,
        Scenario = scen) %>%
      filter(Difference != 0)
    
    compare
  }

  return(list(
    by_mode = milescols_qc("Mode"),
    by_log_node = milescols_qc("LogNode"),
    RlDwlCode_sheet = dwellcode_qc(),
    CmapPsTR_sheet = cmapcols_qc("CmapPsTR"),
    CmapPsRL_sheet = cmapcols_qc("CmapPsRL")
  ))
}

mode_path_ports <- function(inCurrent, inNew, year = NA_real_, scen = NA_character_, 
                            empUpdate = NA_character_, skLim = NA_real_, in_ports){
  #' This function: compares current vs new; filters to keep any differences greater than skLim; exports as supplemental data tab.
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
 
    pivbybulkstatus <-function(df){
      output <- df %>% pivot_longer(cols=c('Port_NameB','Port_NameNB'), names_to='Bulk_Status', names_prefix='Port_Name', values_to='Port_Name')
      return(output)
    }

    qcOut <- bind_rows(
      Current = pivbybulkstatus(inCurrent),
      New = pivbybulkstatus(inNew),
      .id = "Version"
    ) %>% 
    mutate(
      Year = year,
      Scenario = scen
    ) %>%
    summarize(
      Count = n(),
      .by = c('Year','Scenario','Version','Port_Name','Bulk_Status')
    ) %>%
    pivot_wider(names_from = Version, values_from = Count, names_glue = "{Version}Count", values_fill = 0) %>%
    select(Year, Scenario, Port_Name, Bulk_Status, CurrentCount, NewCount)

  return(qcOut)
}

mode_path_airports <- function(inCurrent, inNew, year = NA_real_, scen = NA_character_, 
                            empUpdate = NA_character_, skLim = NA_real_){
    
    pivbybulkstatus <-function(df){
      output <- df %>% pivot_longer(cols=c('Port_NameB','Port_NameNB'), names_to='Bulk_Status', names_prefix='Port_Name', values_to='Port_Name')
      return(output)
    }

    qcOut <- bind_rows(
      Current = pivbybulkstatus(inCurrent),
      New = pivbybulkstatus(inNew),
      .id = "Version"
    ) %>%
    mutate(
      Year = year,
      Scenario = scen
    ) %>%
    summarize(
      Count = n(),
      .by = c('Year','Scenario','Version','Port_Name','Bulk_Status')
    ) %>%
    pivot_wider(names_from = Version, values_from = Count, names_glue = "{Version}Count", values_fill = 0) %>%
    select(Year, Scenario, Port_Name, Bulk_Status, CurrentCount, NewCount)

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
          select(Scenario, Year, Mode, LogNode,
            C_Time, C_Cost, N_Time, N_Cost, perc_Time, perc_Cost)         #Select column names of target dataframe
        
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

# Registry of QC functions, their associated accumulators, output sheets, and templates. 
# This registry is used to route the appropriate QC function based on the file type being processed.
qc_registry <- list(
  truck_ee = list(
    fn = truck_ee,
    outputs = list(
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
    )
  ),

  zone_employment = list(
    fn = zone_employment,
    outputs = list(
      sheet = "zn_Emp",
      arrange_by = c("County",'Year'),
      template = data.frame(
        Year = numeric(),
        County = character(),
        currentEmpSum = integer(),
        newEmpSum = integer(),
        Difference = integer(),
        Percent = numeric()
      )
    )
  ),

  zone_skims = list(
    fn = zone_skims,
    outputs = list(
      by_origin = list(
        sheet = "zn_Skim_byOriginCounty",
        arrange_by = c("OCounty",'Year'),
        template = data.frame(
          Year = numeric(),
          OCounty = character(),
          CPeak = numeric(),
          NPeak = numeric(),
          diff_Peak = numeric(),
          perc_Peak = numeric(),
          COffPeak = numeric(),
          NOffPeak = numeric(),
          diff_OffPeak = numeric(),
          perc_OffPeak = numeric(),
          CMiles = numeric(),
          NMiles= numeric(),
          diff_Mi = numeric(),
          perc_Mi = numeric(),
          flagPeaks = integer(),
          flagMi = integer()
        )
      ),
      by_destination = list(
        sheet = "zn_Skim_byDestinationCounty",
        arrange_by = c("DCounty",'Year'),
        template = data.frame(
          Year = numeric(),
          DCounty = character(),
          CPeak = numeric(),
          NPeak = numeric(),
          diff_Peak = numeric(),
          perc_Peak = numeric(),
          COffPeak = numeric(),
          NOffPeak = numeric(),
          diff_OffPeak = numeric(),
          perc_OffPeak = numeric(),
          CMiles = numeric(),
          NMiles= numeric(),
          diff_Mi = numeric(),
          perc_Mi = numeric(),
          flagPeaks = integer(),
          flagMi = integer()
        )
      )
    )
  ),

  mesozone_skims = list(
    fn = mesozone_skims,
    outputs = list(
      by_origin = list(
        sheet = "meso_skim_byOriginCounty",
        arrange_by = c("OCounty",'Year'),
        template = data.frame(
          Year = numeric(),
          OCounty = character(),
          currentTime = numeric(),
          newTime = numeric(), 
          Difference = numeric(),
          Percent = numeric()
        )
      ),
      by_destination = list(
        sheet = "meso_skim_byDestinationCounty",
        arrange_by = c("DCounty",'Year'),
        template = data.frame(
          Year = numeric(),
          DCounty = character(),
          currentTime = numeric(),
          newTime = numeric(),
          Difference = numeric(),
          Percent = numeric()
        )
      )
    )
  ),

  truck_ie = list(
    fn = truck_ie,
    outputs = list(
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
    )
  ),

  mode_path_miles = list(
    fn = mode_path_miles,
    outputs = list(
      by_mode = list(
          sheet = "modeMi_byMode",
          arrange_by = c("Scenario", "Year", "Mode"),
          template = data.frame(
            Scenario = character(),
            Year = numeric(),
            Mode = character(),
            TotalNtwkMiles = numeric(),
            DmsLhMiles = numeric(),
            DmsDrayMiles = numeric(),
            IntlShipMiles = numeric()
            # CmapPsTR = numeric(),
            # CmapPsRL = numeric(),
            # RlDwlCode = numeric(),
            # RlTrnfr = numeric()
          )
      ),
        by_log_node = list(
          sheet = "modeMi_byLogNode",
          arrange_by = c("Scenario", "Year", "LogNode"),
          template = data.frame(
            Scenario = character(),
            Year = numeric(),
            LogNode = numeric(),
            TotalNtwkMiles = numeric(),
            DmsLhMiles = numeric(),
            DmsDrayMiles = numeric(),
            IntlShipMiles = numeric()
            # CmapPsTR = numeric(),
            # CmapPsRL = numeric(),
            # RlDwlCode = numeric(),
            # RlTrnfr = numeric()
          )
        ),
          RlDwlCode_sheet = list(
          sheet = "modeMi_RlDwlCode",
          arrange_by = "rail_interchange",
          template = data.frame(
            Scenario = character(),
            Year = numeric(),
            Mode = character(),
            rail_interchange = character(),
            CurrentCount = numeric(),
            NewCount = numeric(),
            Difference = numeric(),
            PercentChange = numeric()
          )
        ),
        CmapPsTR_sheet = list(
          sheet = "modeMi_CmapPsTR",
          arrange_by = c("Path", "Mode"),
          template = data.frame(
            Scenario = character(),
            Year = numeric(),
            Path = numeric(),
            Mode = character(),
            count_current = numeric(),
            count_new = numeric(),
            Difference = numeric(),
            PercDiff = numeric()
          )
        ),
        CmapPsRL_sheet = list(
          sheet = "modeMi_CmapPsRL",
          arrange_by = c("Path", "Mode"),
          template = data.frame(
            Scenario = character(),
            Year = numeric(),
            Path = numeric(),
            Mode = character(),
            count_current = numeric(),
            count_new = numeric(),
            Difference = numeric(),
            PercDiff = numeric()
          )
        )
    )
),

  mode_path_ports = list(
    fn = mode_path_ports,
    outputs = list(
      sheet = "mode_Port",
      template = data.frame(
        Scenario = character(),
        Year = numeric(),
        Port_Name = character(),
        Bulk_Status = character(),
        CurrentCount = numeric(),
        NewCount = numeric()
      )
    )
  ),

  mode_path_airports = list( 
    fn = mode_path_airports,
    outputs = list(
      sheet = "mode_Airport",
      template = data.frame(
        Scenario = character(),
        Year = numeric(),
        Port_Name = character(),
        Bulk_Status = character(),
        CurrentCount = numeric(),
        NewCount = numeric()
      )
    )
  ),

  mode_path_skims = list(
    fn = mode_path_skims,
    outputs = list(
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
    str_detect(file_name, "^data_modepath_miles") ~ "mode_path_miles",
    str_detect(file_name, "^data_modepath_ports") ~ "mode_path_ports",
    str_detect(file_name, "^data_modepath_skims") ~ "mode_path_skims",
    str_detect(file_name, "^data_modepath_airports") ~ "mode_path_airports",
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
                                  in_POE, in_modePath, in_ports, in_zones,
                                  in_lognodes, in_mesozones, report) {
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
                    in_modePath = in_modePath, in_ports = in_ports, in_zones = in_zones, 
                    in_lognodes = in_lognodes, in_mesozones = in_mesozones, report = report, rel_path = rel_path)

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

registry_outputs <- function(entry) {
  outputs <- entry$outputs

  if (is.null(outputs)) {
    return(list())
  }

  # Normalize a single-sheet output to the same shape as multi-sheet outputs.
  if (!is.null(outputs$sheet) && !is.null(outputs$template)) {
    return(list(result = outputs))
  }

  outputs
}

make_accumulators <- function() {
  accumulators <- list()

  for (entry in qc_registry) {
    outputs <- registry_outputs(entry)

    if (length(outputs) > 0) {
      for (output in outputs) {
        accumulators[[output$sheet]] <- output$template
      }
    } else if (!is.null(entry$sheet)) {
      accumulators[[entry$sheet]] <- entry$template
    }
  }

  accumulators
}

assemble_QC <- function(rel_path, pair_list, empUpdate, skLim,
  in_POE, in_modePath, in_ports, in_zones, in_lognodes, in_mesozones, report){
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
  #'  in_lognodes (data.frame): The lognodes crosswalk data.
  #'  in_mesozones (data.frame): The mesozones crosswalk data.
  #'  report (character): The report file path for logging QC run and issues.
  #' 
  #' Returns:
  #'  A data.frame result of the identified QC function for the given file pair

  print('assembling QC function and arguments for file pair')
  parsed_data <- parse_file_name(rel_path)
  route <- identify_function_routing(parsed_data)
  arguments <- build_route_arguments(rel_path, parsed_data, route, pair_list, empUpdate, 
                                    skLim, in_POE, in_modePath, in_ports, in_zones, in_lognodes, in_mesozones, report)
  do.call(route$fn, arguments)
}

execution <- function(newDir, currentDir, empUpdate, skLim, in_POE, in_modePath,
  in_ports, in_zones, in_lognodes, in_mesozones, report, unmatched, selection = 'ALL'){
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
  #'  in_lognodes (data.frame): The lognodes crosswalk data.
  #'  in_mesozones (data.frame): The mesozones crosswalk data.
  #'  report (character): The report file path for logging QC run and issues.
  #'  unmatched (character): Path to the report file where filenames found in only one directory are appended.
  #'  selection (character): A character or character vector specifying which QC functions to run, if specified using the keys from the routing list. Defaults to 'ALL'.
  #' 
  #' Returns:
  #'  A list of data.frames containing the accumulated QC results for all matched files within both the new and current directories.
  
  print("executing...")

  # is having unmatched here correct? make sure from exec function run
  pair_list <- build_file_pairs(newDir, currentDir, unmatched)
  
  if (!identical(selection, 'ALL')) { # code to allow for running for file types based on user selection
    valid_types <- names(qc_registry)
    invalid_types <- setdiff(selection, valid_types)

    if (length(invalid_types) > 0) {
      stop(
        "Unknown QC selection: ", paste(invalid_types, collapse = ", "),
        ". Valid selections are: ", paste(valid_types, collapse = ", ")
      )
    }

    keep <- vapply(
      pair_list,
      function(pair) {route_file(parse_file_name(pair$rp)) %in% selection},
      logical(1)
    )
    pair_list <- pair_list[keep]
  }

  sheets <- make_accumulators()
  result_chunks <- lapply(sheets, function(template) list())

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
        in_lognodes = in_lognodes,
        in_mesozones = in_mesozones,
        report = report
      ),
      error = function(e) {
        msg <- paste0("Error processing ", pair$rp, ": ", conditionMessage(e), "\n")
        cat(msg, file = report, append = TRUE)
        stop(e)
      }
    )

    if (is.null(res)) { # handling expected NULL returns from staticFile QC 
      next
    } 

    kind <- route_file(parse_file_name(pair$rp))
    route <- qc_registry[[kind]]

    outputs <- registry_outputs(route)

    if (length(outputs) > 0) {
      for (output_name in names(outputs)) {
        sheet_name <- outputs[[output_name]]$sheet
        output_result <- if (is.data.frame(res)) res else res[[output_name]]

        result_chunks[[sheet_name]][[length(result_chunks[[sheet_name]]) + 1L]] <-
          output_result
      }
    } else if (!is.null(route$sheet)) {
      sheet_name <- route$sheet
      result_chunks[[sheet_name]][[length(result_chunks[[sheet_name]]) + 1L]] <- res
    }

    print(paste("FINISHED PROCESSING:", pair$rp))
    cat("\n")
  }

  for (sheet_name in names(sheets)) {
  sheets[[sheet_name]] <- bind_rows(c(list(sheets[[sheet_name]]), result_chunks[[sheet_name]]))
  }

  for (entry in qc_registry) {
    for (output in registry_outputs(entry)) {
      if (is.null(output$arrange_by)) {next}

      sheet_name <- output$sheet
      sheets[[sheet_name]] <- arrange(sheets[[sheet_name]], !!!syms(output$arrange_by))
    }
  }

  print("finished running all files")

  return(sheets)
}
