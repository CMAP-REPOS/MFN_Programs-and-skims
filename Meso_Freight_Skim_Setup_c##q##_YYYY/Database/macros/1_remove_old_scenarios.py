#filename: distr_m01_data.py
#description: Python script uses the EMME Modeler API to punch transit network and itinerary data for DISTR and M01 files creation
#author: Karly Cazzato, 9/20/2023

import os, sys, shutil
import inro.emme.desktop.app as _app
import inro.modeller as _m
import pandas as pd
    
def main():
    # Define the path to the Emme project (.emp file)
    empFl = 'MesoFreightNetwork.emp'
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
    emmebank = modeller.emmebank
    change_scenario = modeller.tool('inro.emme.data.scenario.change_primary_scenario')
    create_scenario = modeller.tool('inro.emme.data.scenario.create_scenario')
    delete_scenario = modeller.tool('inro.emme.data.scenario.delete_scenario')
    delete_matrix = modeller.tool('inro.emme.data.matrix.delete_matrix')

    # Obtain list of matrix values to be deleted
    inMatNames =  "input_data/matrix.in"
    in_MatNames = pd.read_csv(inMatNames, sep = '(\d+)', skiprows = 11, header=None, engine='python')
    in_MatNames.columns=['mfnm', 'mf', 'abbrev', 'skip', 'desc']
    matList = in_MatNames['mf'].values.tolist()

    # Create empty scenario if id does not exist
    sEmpty = create_scenario(scenario_id=1,
                        scenario_title="empty scenario",
                        overwrite = True)
    
    # Set current scenario to empty scenario
    change_scenario(scenario=1)

    # Delete all matrices
    for mat in matList:
        stMat = 'mf' + str(mat)
        try:
            delMat = emmebank.matrix(stMat)
            delete_matrix(matrix=delMat) 
        except:
            None

    # Delete Scenarios
    scen = 2
    while scen < 213:
        try:
            delScen = emmebank.scenario(scen)
            delete_scenario(scenario=delScen)
        except:
            None
        scen=scen+1

    
if __name__ == '__main__':
    main()