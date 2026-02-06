###############################################################################################################################################
# filename: grab_TBM_data.py                                                                                                                  #
# author: Karly Cazzato, 1/14/2026                                                                                                            #
# Description: Python script uses the EMME Modeler API to obtain the following data to be used as inputs for the fregith forecasting skims    #
# 1. AM Peak and Midday skim times and AM Peak distance                                                                                       #
#       - hwytime_op                                                                                                                          #
#       - hwytime_pk                                                                                                                          #
#       - hwydist_pk                                                                                                                          #
# 2. Subzone employment                                                                                                                       #
#       - subzn_emp_YYYY.csv                                                                                                                  #
#                                                                                                                                             #
# TBM scenario number correspondance to MFN scenario years                                                                                    #
#       200 = 2022 (MFN only) and 2025 (TBM and MFN)                                                                                          #
#       300 = 2030 (TBM and MFN)                                                                                                              #
#       400 = 2035 (TBM and MFN)                                                                                                              #
#       500 = 2040 (TBM and MFN) and 2045 (MFN only)                                                                                          #
#       700 = 2050 (TBM and MFN), 2060 (MFN only)                                                                                             #
#                                                                                                                                             #
# TO RUN:                                                                                                                                     #
#   1. Paste this script into the 'Database' folder of a TBM setup                                                                            #
#   2. Open command prompt or anaconda prompt to run the script                                                                               #
#   3. Navigate to the 'Database' folder in the prompt                                                                                        #
#   4. Activate the EMME-PLUS environment                                                                                                     #
#   5. enter 'python grab_TBM_data.py ### cXXqY' to execute the script,                                                                       #
#         where ### is the scenario number and cXXqY is the conformity number of the TBM model copy                                           #
#                                                                                                                                             #
# Output should be stored in Meso_Freight_Skim_Setup_c##q##_YYYY\Database\input_data\post_processing                                          #
###############################################################################################################################################
import os, sys, shutil
import inro.emme.desktop.app as _app
import inro.modeller as _m
import pandas as pd
    
def main():
    # Get user inputs
    scenario = int(sys.argv[1])
    conformity = sys.argv[2]

    # Define Inputs
    pth_ATTR = os.getcwd() +'/tg/fortran/ATTR_IN.TXT'
    in_ATTR = pd.read_csv(pth_ATTR, header=None, names=["subzone", "retailEmp", "totalEmp", "fractionHighEarn"])
    in_crosswalk = pd.read_csv("S:/AdminGroups/ResearchAnalysis/CMH/FY25/freight model/truck_tours/new input files/subzone-mesozone.csv")   # Zone17 crosswalk between subzones, zones, and mesozones
    # NOTE: I know this references zone system 09 but it IS zone system 17

    # Define Output Path
    outputDir = os.path.join(os.getcwd(),f'Freight_Skim_Inputs_{conformity}_{scenario}')

    # Delete and recreate output folder
    if os.path.exists(outputDir):
        shutil.rmtree(outputDir)
    os.mkdir(outputDir)

    # Define the path to the Emme project (.emp file)
    empFl = conformity + "_" + str(scenario) + '.emp'
    directory = os.getcwd().replace('\\Database','')
    empFile = os.path.join(directory,empFl)
    print(empFile)

    # start a dedicated instance of Emme Desktop connected to the specified project
    desktop = _app.start_dedicated(
        visible=True,
        user_initials='KCC',
        project= empFile
    )
    
    # Connect to the Modeller
    modeller = _m.Modeller(desktop=desktop)
    export_matrix = modeller.tool('inro.emme.data.matrix.export_matrices')

    # 1. EXPORT AM PEAK AND MIDDAY TIME AND AM PEAK DISTANCES FROM EMME
    matrices_file = os.path.join(outputDir, "hwytime_pk")
    export_matrix(matrices='mf44',
                    export_file=matrices_file, 
                    field_separator=',',
                    export_format="PROMPT_DATA_FORMAT",
                    skip_default_values=True,
                    full_matrix_line_format="ONE_ENTRY_PER_LINE")
    
    matrices_file = os.path.join(outputDir, "hwydist_pk")
    export_matrix(matrices='mf45',
                    export_file=matrices_file, 
                    field_separator=',',
                    export_format="PROMPT_DATA_FORMAT",
                    skip_default_values=True,
                    full_matrix_line_format="ONE_ENTRY_PER_LINE")
    
    matrices_file = os.path.join(outputDir, "hwytime_op")
    export_matrix(matrices='mf46',
                    export_file=matrices_file, 
                    field_separator=',',
                    export_format="PROMPT_DATA_FORMAT",
                    skip_default_values=True,
                    full_matrix_line_format="ONE_ENTRY_PER_LINE")

    # 2. OBTAIN SUBZONE EMPLOYMENT FROM cmap_trip-based_model/Database/tg/fortran/ATTR_IN.TXT
    # Create dictionary to define correspondance between TBM scenarios and Freight Skim years
    scen_year_corr = {100:[2019],200: [2022, 2025], 300: [2030], 400: [2035], 500: [2040, 2045], 700: [2050, 2060]}
    output_years = scen_year_corr[scenario]

    # Format subzone employment by attaching zone
    out_emp = pd.merge(in_ATTR, in_crosswalk, left_on='subzone', right_on='subzone09', how='left')
    out_emp = out_emp[['zone09', 'subzone09', 'totalEmp']].copy()
    out_emp.rename(columns={'totalEmp':'i18'}, inplace=True)

    # Export subzone employment
    for yr in output_years:
        output_nm = outputDir + "/subzn_emp_" + str(yr) + ".csv" 
        out_emp.to_csv(output_nm)  

    
if __name__ == '__main__':
    main()