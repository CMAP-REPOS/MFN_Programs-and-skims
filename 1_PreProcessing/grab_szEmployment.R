library(tidyverse)

conformity = "c25q2"
scenarios = c(200, 300, 400, 500, 700)
#where 200 = 2025, 300 = 2030, 400 = 2035, 500 = 2040, 700 = 2050
dates = c("20250409","20250410" , "20250409", "20250409","20250410")
#these are the dates the conformity model was ran

folder = "E:/kcc/FY25/MFN/develop_inputs/"
folder2 = "/cmap_trip-based_model/Database/tg/fortran/ATTR_IN.TXT"
outpath = paste("E:/kcc/FY25/MFN/develop_inputs/Outputs/", conformity, "/subzn_emp/", sep="")
ifelse(!dir.exists(file.path(outpath)),
       dir.create(file.path(outpath)),
       "Directory Exists")
in_crosswalk <- read.csv("S:/AdminGroups/ResearchAnalysis/CMH/FY25/freight model/truck_tours/new input files/subzone-mesozone.csv")

<<<<<<< Updated upstream
scenarios = c(200, 300, 400, 500, 700)
#where 200 = 2025, 300 = 2030, 400 = 2035, 500 = 2040, 700 = 2050

folder = "E:/kcc/FY25/MFN/develop_inputs/c24q4/c24q4_"
outpath = "E:/kcc/FY25/MFN/develop_inputs/Outputs/c24q4/subzn_emp/"

folder2 = "_20241031/cmap_trip-based_model/Database/tg/fortran/ATTR_IN.TXT"
folder3 = "_20241101/cmap_trip-based_model/Database/tg/fortran/ATTR_IN.TXT"
folder4 = "_20241106/cmap_trip-based_model/Database/tg/fortran/ATTR_IN.TXT"



=======
i = 1
>>>>>>> Stashed changes
for(scen in scenarios){
  inFile = paste(folder, conformity, "/", conformity, "_", scen, "_", dates[i], folder2, sep="")
  
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
  i=i+1
}
