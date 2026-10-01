'''
Author: Tyler Huang

Date: 9/21/2026

Description:
This file is the main script to run the freight skim QC pipeline. 
It will load required packages and dependencies, load QC and execution functions from freight_QC_functions.r, set up input and output paths,
execute the QC of new and current freight skim outputs, and finally export the QC results to an Excel file.

Input Files: 
2 file directories containing the current and new skim output files (currentDir and newDir).
  Expected directory structure:
  - currentDir/
    - Subfolder: LogNode140
    - Subfolder: No_LogNode140
    - non-scenario files
  - newDir/
    - Subfolder: LogNode140
    - Subfolder: No_LogNode140
    - non-scenario files
MFN_crosswalks.xlsx: crosswalk  document for POE, mode path, ports, and zones.
freight_QC_functions.r: R script containing the QC and execution functions in order to fun the freight skim QC.

Output Files:
finalSkim_compareQC.xlsx: Excel file containing the QC compare results for all freight input files.
qc_CompareReport.txt: Text file containing the QC report for all skim output files.
qc_unmatched.txt: Text file containing the list of unmatched files between the current and new skim output directories.

Set Up Instructions:
1. Ensure that the required packages are installed and available in your R environment.
2. Update the newDir and currentDir variables to point to the directories containing the new and current skim output files, respectively.
3. Identify desired output file path and update the rpDir variable accordingly.
4. Ensure that the crosswalks file (MFN_crosswalks.xlsx) is available in the specified path.
5. Ensure that the freight_QC_functions.r script is available in the specified path.

Run Instructions:
1. Update empUpdate if this is an employment update run.
2. Adjust skLim if you want a different difference threshold for QC functions that use skLim.
3. Within the execution function, adjust the selection argument if you want to run QC for specific file types.
4. Run the script in RStudio or from an R command line:
source("M:/proj1/th/update_freight_skim_qc/MFN_Programs-and-skims/run_freight_QC.r")

Adding New QC Functions:
Adding new QC functions or modifying existing ones should be done in freight_QC_functions.r. If doing so, modify
the execution function arguments to accomodate the new QC function(s), dependenices, and update the execution function call in this script accordingly.
Documentation on how to add a new QC function can be found in freight_QC_functions.r.

'''
# SET UP
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
source("M:/proj1/th/update_freight_skim_qc/MFN_Programs-and-skims/freight_QC_functions.r")

#--Define paths and files
# args = commandArgs(trailingOnly=T)
oldConf = 'c25q2'

newDir = "M:/proj1/kcc/FY27/freight_skim_output/Skim_Output_c26q2_07222026"
currentDir = "M:/proj1/kcc/FY27/freight_skim_output/Skim_Out_c25q2"

# Output file paths
rpDir = "M:/proj1/th/update_freight_skim_qc/Skim_Output/" 
outXL = paste(rpDir, "finalSkim_compareQC.xlsx", sep = "")
report = paste(rpDir, "qc_CompareReport.txt", sep = "")
unmatched_path <- paste(rpDir, "qc_unmatched.txt", sep = "")

#--Import crosswalks
in_modePath <- read_xlsx("M:/proj1/kcc/FY27/freight_skim_output/Inputs/MFN_crosswalks.xlsx", sheet = "modePath")
in_ports <- read_xlsx("M:/proj1/kcc/FY27/freight_skim_output/Inputs/MFN_crosswalks.xlsx", sheet = "Ports")
in_POE <- read_xlsx("M:/proj1/kcc/FY27/freight_skim_output/Inputs/MFN_crosswalks.xlsx", sheet = "POE")
in_zones <- read_xlsx("M:/proj1/kcc/FY27/freight_skim_output/Inputs/MFN_crosswalks.xlsx", sheet = "zones")

#--Manual variable definitions for QC
empUpdate = "yes"
skLim = 0.05 

#--Delete report if exists
if(file.exists(outXL) == TRUE){unlink(outXL, recursive = TRUE)}
if(file.exists(report) == TRUE){unlink(report, recursive = TRUE)}
if(file.exists(unmatched_path) == TRUE){unlink(unmatched_path, recursive =TRUE)}

# EXECUTION
#-- Execution of QC pipeline
QC_results <- execution(
  newDir = newDir,
  currentDir = currentDir,
  empUpdate = empUpdate,         # can be manually set here, input as "yes" or "no"
  skLim = skLim,                 # can be manually set here, input as decimal (0.05 = 5%)
  in_POE = in_POE,               # crosswalk
  in_modePath = in_modePath,     # crosswalk
  in_ports = in_ports,           # crosswalk
  in_zones = in_zones,           # crosswalk
  unmatched = unmatched_path,    # report file
  report = report,               # report file
  selection = 'ALL'              # default selection is to run for all file types, but can choose to run for
                                 # specific file types (can accept one or a list):
                                 # use the following keys for argument(s), in quotes:
                                 # truck_ee, zone_skims, mesozone_skims,
                                 # zone_employment, truck_ie, mode_path_miles, mode_path_ports, mode_path_skims, staticFile
                                 # for multiple, use selection = c('','')
)

#-- Write results to Excel
sheet_labels <- c(all_mesoSkim = "meso_skim", all_modeMi   = "mode_Mi",
                   all_modePort = "mode_Port", all_modeSkim = "mode_Skim",
                   all_znEmp    = "zn_Emp",    all_znSkim   = "zn_Skim",
                   all_TruckEE  = "truckEE",   all_TruckIE  = "truckIE")           
names(QC_results) <- sheet_labels[names(QC_results)]

write.xlsx(QC_results, outXL)
