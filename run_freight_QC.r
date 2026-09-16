#--Load required packages
packages <- c("tidyverse", "readxl", "openxlsx", "terra","stringr")
package.check <- lapply(
  packages,
  FUN = function(x) {
    if (!require(x, character.only = TRUE)) {
      install.packages(x, dependencies = TRUE)
      library(x, character.only = TRUE)
    }
  }
)
TMPDIR='M:/proj1/kcc/FY27/freight_skim_output'
terraOptions(tempdir = TMPDIR)  

#-- Load functions file
source("M:/proj1/th/update_freight_skim_qc/freight_QC_functions.r")

#--Define paths and files
# args = commandArgs(trailingOnly=T)
oldConf = 'c25q2'

newDir = "M:/proj1/kcc/FY27/freight_skim_output/Skim_Output_c26q2_07222026"
currentDir = "M:/proj1/kcc/FY27/freight_skim_output/Skim_Out_c25q2"

# skim output paths
rpDir = "M:/proj1/th/update_freight_skim_qc/Skim_Output/" 
outXL = paste(rpDir, "finalSkim_compareQC.xlsx", sep = "")
report = paste(rpDir, "qc_CompareReport.txt", sep = "")
unmatched_path <- paste(rpDir, "qc_unmatched.txt", sep = "")

#--Manual variable definitions for QC
empUpdate = "yes"
skLim = 0.05  #mesozone skims print if percent difference > 5%

#--Delete report if exists
if(file.exists(outXL) == TRUE){unlink(outXL, recursive = TRUE)}
if(file.exists(report) == TRUE){unlink(report, recursive = TRUE)}
if(file.exists(unmatched_path) == TRUE){unlink(unmatched_path, recursive =TRUE)}

#--Import crosswalks
in_modePath <- read_xlsx("M:/proj1/kcc/FY27/freight_skim_output/Inputs/MFN_crosswalks.xlsx", sheet = "modePath")
in_ports <- read_xlsx("M:/proj1/kcc/FY27/freight_skim_output/Inputs/MFN_crosswalks.xlsx", sheet = "Ports")
in_POE <- read_xlsx("M:/proj1/kcc/FY27/freight_skim_output/Inputs/MFN_crosswalks.xlsx", sheet = "POE")
in_zones <- read_xlsx("M:/proj1/kcc/FY27/freight_skim_output/Inputs/MFN_crosswalks.xlsx", sheet = "zones")

#-- Execution of QC pipeline
results <- execution(
  newDir = newDir,
  currentDir = currentDir,
  empUpdate = empUpdate,         # can be manually set here, input as "yes" or "no"
  skLim = skLim,                 # can be manually set here, input as decimal (0.05 = 5%)
  in_POE = in_POE,               # crosswalk
  in_modePath = in_modePath,     # crosswalk
  in_ports = in_ports,           # crosswalk
  in_zones = in_zones,           # crosswalk
  unmatched = unmatched_path,    # report file
  report = report                # report file
)

#-- Write results to Excel
sheet_labels <- c(all_mesoSkim = "meso_skim", all_modeMi   = "mode_Mi",
                   all_modePort = "mode_Port", all_modeSkim = "mode_Skim",
                   all_znEmp    = "zn_Emp",    all_znSkim   = "zn_Skim",
                   all_TruckEE  = "truckEE",   all_TruckIE  = "truckIE")           
names(results) <- sheet_labels[names(results)]

write.xlsx(results, outXL)
