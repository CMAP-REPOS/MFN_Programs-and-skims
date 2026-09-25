#-- QC FUNCTIONS
'''
Author: Tyler Huang

Date: 9/21/2026

Description:
This file contains functions for the QC process that 

Input Files: 


Output Files:

'''
### CHANGE FILES #####
truck_ee <- function(inCurrent, inNew, year = NA_real_, scen = NA_character_, 
                     empUpdate = NA_character_, skLim = NA_real_, in_POE){
  #' docstring
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
        select(Production_zone, Consumption_zone, C_poe2, C_poe, N_poe2, N_poe, CState, NState, 
          CDirection, NDirection, CState2, NState2, CDirection2, NDirection2)
      
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
                            empUpdate = NA_character_, skLim = NA_real_, report){
  #' docstring
    inCurrent<- inCurrent %>% rename(currentEmp = totalemp)                    #Amend Current file column names
    inNew<- inNew %>% rename(newEmp = totalemp)                                #Amed New file column names
        
        qcOut <- full_join(inCurrent, inNew, by = join_by(Zone, mesozone)) %>%     #Merge new and current data
          mutate(Difference = newEmp-currentEmp,                                   #Calculate employment difference
                 Percent = round(Difference/(currentEmp),3)) %>%            #Calculate employment percent difference, round 3 decimal places
          filter(abs(Percent) > 0.5)%>%                                     #Filter employment difference > 0
          mutate(Year = year) %>%                                                  #Assign year variable to different data
          select(Year, Zone, mesozone, currentEmp, newEmp, Difference, Percent)     #Select template column names
        
        #Employment only expected to change if update is associated with a plan update
        #If difference exists otherwise, stop code
        if(sum(qcOut$Difference) > 0 & empUpdate != "yes"){
          printOut = "ERROR: Employment unexpectedly changes!"
          cat(printOut, file =report,append=TRUE)
          #stop()
          }                
       
    return(qcOut)
}

zone_skims <- function(inCurrent, inNew, year = NA_real_, scen = NA_character_, 
                        empUpdate = NA_character_, skLim = NA_real_, in_zones){
  #' docstring
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
                 flagPeaks = ifelse(abs(perc_Peak) > .01 | abs(perc_OffPeak) > .01, 1, 0),
                 flagMi = ifelse(abs(perc_Mi) > 0.01, 1, 0),
                 Year = year) %>%       #Sum all differences
          filter(flagPeaks == 1 | flagMi == 1) %>%    #filter to keep only OD pairs with differences
          select(Year, OCounty, DCounty, flagPeaks, flagMi, CPeak, NPeak, perc_Peak, 
            COffPeak, NOffPeak, perc_OffPeak, CMiles, NMiles, perc_Mi)   #Select column names from target dataframe
        
    return(qcOut)
}

mesozone_skims <- function(inCurrent, inNew, year = NA_real_, scen = NA_character_, 
                            empUpdate = NA_character_, skLim = NA_real_){
  #' docstring
        #Amend Current and New file column names
        inCurrent <- inCurrent 
        colnames(inCurrent) <- c('Origin', 'Destination', 'currentTime')
        inNew <- inNew
        colnames(inNew) <- c('Origin', 'Destination', 'newTime')
        #Merge new and current data; calculate differencepercent difference in 
        qcOut <- full_join(inCurrent, inNew, by = join_by(Origin, Destination)) %>%   #Merge current and new data
          mutate(Year = year,                                                         #Flag current year of data
                 Difference = newTime - currentTime,                                  #Calculate difference in skim time
                 Percent = round(Difference/(newTime + currentTime),3)) %>%           #Calculate percent difference in skim time
          select(Year, Origin, Destination, currentTime, newTime, Difference, Percent) %>%   #Select column names of target dataframe
          filter(abs(Percent) >= skLim)%>%   #Filter to keep percent differences > |1%|
          arrange(Origin, Destination, Year)                                                  
  return(qcOut)
}

truck_ie <- function(inCurrent, inNew, year = NA_real_, scen = NA_character_, 
                     empUpdate = NA_character_, skLim = NA_real_, in_POE){
  #' docstring
  
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

mode_path_miles <- function(inCurrent, inNew, year = NA_real_, scen = NA_character_, 
                            empUpdate = NA_character_, skLim = NA_real_, in_modePath){
  #' docstring
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
          filter(abs(sumDiff) > 0.00) %>%           #Filter for total differences greater than |1%|
          select(Scenario, Year, Mode, LogNode, Perc_TotMi, Perc_DmsLh,
            Perc_DmsDray, Perc_IntlShip, Perc_PsTR, Perc_PsRL,
            Perc_RlDwlCode, Perc_RlTrnFr)                                                    #Select column names of target dataframe
    return(qcOut)
}

mode_path_ports <- function(inCurrent, inNew, year = NA_real_, scen = NA_character_, 
                            empUpdate = NA_character_, skLim = NA_real_, in_ports){
  #' docstring
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
          select(Scenario, Year, Production_zone, Consumption_zone,
            C_mesoNB, N_mesoNB, C_mesoB, N_mesoB,
            C_nameNB, N_nameNB, C_nameB, N_nameB,
            C_coastNB, N_coastNB, C_coastB, N_coastB)
    return(qcOut)
}

mode_path_skims <- function(inCurrent, inNew, year = NA_real_, scen = NA_character_, 
                            empUpdate = NA_character_, skLim = NA_real_, in_modePath, report){
  #' docstring
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
          filter((abs(perc_Cost) > 0.00) | (abs(perc_Time) > 0.00)) %>%         #Filter to keep any differences in data
          mutate(Path = as.numeric(Mode)) %>%
          select(-Mode) %>%
          left_join(in_modePath, by = c("Path")) %>%                            #Join mode path information for inclusion in export
          select(Scenario, Year, Mode, LogNode, C_Time, C_Cost,
            N_Time, N_Cost, perc_Time, perc_Cost)                                        #Select column names of target dataframe
        
  return(qcOut)
}
  
### STATIC FILE QC FUNCTION ###

staticFile <- function(inCurrent, inNew, year = NA_real_, scen = NA_character_, 
                        empUpdate = NA_character_, skLim = NA_real_, report, rel_path){
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
    }
  return()
}

#-- QC ROUTING FUNCTIONS

print("QA/QC COMPARING NEW DATA TO V DRIVE CURRENT DATA")

build_file_pairs <- function(newDir, currentDir, unmatched_path){
  #' docstring
  n <- list.files(newDir, recursive = TRUE, full.names = FALSE, include.dirs = FALSE)
  c <- list.files(currentDir, recursive = TRUE, full.names = FALSE,include.dirs = FALSE)

  # maybe find another way to match common files that logs nonintersecting files
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
  #' docstring
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
  #' docstring
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
    TRUE ~ "staticFile"
  )
}

routing_list <- list(
  truck_ee = list(fn = truck_ee),
  zone_skims = list(fn = zone_skims),
  mesozone_skims = list(fn = mesozone_skims),
  zone_employment = list( fn = zone_employment),
  truck_ie = list(fn = truck_ie),
  mode_path_miles = list(fn = mode_path_miles),
  mode_path_ports = list(fn = mode_path_ports),
  mode_path_skims = list(fn = mode_path_skims),
  staticFile = list(fn = staticFile)
)

identify_function_routing <- function(parsed_data){
  #' docstring
  kind <- route_file(parsed_data)
  route <- routing_list[[kind]]
  print('identified QC function to route to for file pair:')
  print(kind)
  return(route)
}

# helper function to be used within build_route arguments:
read_file_pair <- function(pair_list, rel_path){
  #' docstring
  pair_args <- list(
    inCurrent = read.csv(pair_list[[rel_path]]$current),
    inNew = read.csv(pair_list[[rel_path]]$new)
  )
  return(pair_args)
}

build_route_arguments <- function(rel_path, parsed_data, route, pair_list, empUpdate, skLim, 
                                  in_POE, in_modePath, in_ports, in_zones, report){
  #' docstring
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
  print(args)
  return(args)
}

# handle local/global stuff
mapping <- list(
  truck_ee = "all_TruckEE",
  zone_employment = "all_znEmp",
  zone_skims = "all_znSkim",
  mesozone_skims = "all_mesoSkim",
  truck_ie = "all_TruckIE",
  mode_path_miles = "all_modeMi",
  mode_path_ports = "all_modePort",
  mode_path_skims = "all_modeSkim"
)

make_accumulators <- function() {
  #' docstring
  list(
    all_TruckEE = data.frame(
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
    ),
    all_TruckIE = data.frame(
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
    ),
    all_znEmp = data.frame(
      Year = numeric(),
      Zone = integer(),
      mesozone = integer(),
      currentEmp = integer(),
      newEmp = integer(),
      Difference = integer(),
      Percent = numeric()
    ),
    all_modePort = data.frame(
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
    ),
    all_znSkim = data.frame(
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
    ),
    all_mesoSkim = data.frame(
      Year = numeric(),
      Origin = integer(),
      Destination = integer(),
      currentTime = numeric(),
      newTime = numeric(),
      Difference = numeric(),
      Percent = numeric()
    ),
    all_modeMi = data.frame(
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
    ),
    all_modeSkim = data.frame(
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
}

assemble_QC <- function(rel_path, pair_list, empUpdate, skLim,
  in_POE, in_modePath, in_ports, in_zones, report){
  #' docstring
  print('assembling QC function and arguments for file pair')
  parsed_data <- parse_file_name(rel_path)
  route <- identify_function_routing(parsed_data)
  arguments <- build_route_arguments(rel_path, parsed_data, route, pair_list, empUpdate, 
                                    skLim, in_POE, in_modePath, in_ports, in_zones, report)
  do.call(route$fn, arguments)
}

#4. EXECUTION FUNCTION
execution <- function(newDir, currentDir, empUpdate, skLim, in_POE, in_modePath,
  in_ports, in_zones, report, unmatched){

  print("executing...")

  # is having unmatched here correct? make sure from exec function run
  pair_list <- build_file_pairs(newDir, currentDir, unmatched)
  accumulators <- make_accumulators()

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
        msg <- paste0(
          "Error processing ", pair$rp, ": ",
          conditionMessage(e), "\n")
        cat(msg, file = report, append = TRUE)
        NULL
      }
    )

    if (is.null(res)) {
      next
    }

    kind <- route_file(parse_file_name(pair$rp)) # identify the appropriate function
    accumulator_name <- mapping[[kind]] # identify appropriate dataframe to populate

    if (!is.null(accumulator_name)) {
      print('APPENDING:')
      print(pair$rp)
      accumulators[[accumulator_name]] <- dplyr::bind_rows(accumulators[[accumulator_name]], res)
    }
    print(paste("FINISHED PROCESSING:", pair$rp))
  }

  print("finished running all files")

  return(accumulators)
}
