library(tidyverse)
in_crosswalk <- read.csv("S:/AdminGroups/ResearchAnalysis/CMH/FY25/freight model/truck_tours/new input files/subzone-mesozone.csv")

scenarios = c(200, 300, 400, 500, 700)
#where 200 = 2025, 300 = 2030, 400 = 2035, 500 = 2040, 700 = 2050

folder = "E:/kcc/FY25/MFN/develop_inputs/c24q4/c24q4_"
outpath = "E:/kcc/FY25/MFN/develop_inputs/Outputs/c24q4/subzn_emp/"

folder2 = "_20241031/cmap_trip-based_model/Database/tg/fortran/ATTR_IN.TXT"
folder3 = "_20241101/cmap_trip-based_model/Database/tg/fortran/ATTR_IN.TXT"
folder4 = "_20241106/cmap_trip-based_model/Database/tg/fortran/ATTR_IN.TXT"



for(scen in scenarios){
  if(scen == 100){
    inFile = paste(folder, scen, folder2, sep = "")
  }else if(scen == 200){
    inFile = paste(folder, scen, folder3, sep = "")
  }else{
    inFile = paste(folder, scen, folder4, sep = "")
  }
  
  outFile = paste(outpath, scen, "_subzn_emp.csv", sep="")
  
  in_att <- read.table(inFile, sep = ",")
  colnames(in_att) <- c("subzone", "retailEmp", "totalEmp", "fractionHighEarn")
  
  allATT <- in_att %>%
    select(subzone, totalEmp) %>%
    rename(subzone09 = subzone) %>%
    full_join(in_crosswalk) %>%
    group_by(subzone09) %>%
    rename(i18 = totalEmp) %>%
    select(subzone09, zone09, i18)
  
  write.csv(allATT, outFile, row.names = FALSE)
}
