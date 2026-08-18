#filename: distr_m01_data.py
#description: Python script uses the EMME Modeler API to punch transit network and itinerary data for DISTR and M01 files creation
#author: Karly Cazzato, 9/20/2023

import os, sys, shutil
import inro.emme.desktop.app as _app
import inro.modeller as _m
import pandas as pd
    
def main():
    scenario = sys.argv[1]
    output_dir = os.getcwd() + f"\\output_data\\{scenario}"

    # Define the path to the Emme project (.emp file)
    empFl = 'MesoFreightNetwork.emp'
    directory = os.getcwd().replace('\\Database','')
    empFile = os.path.join(directory,empFl)
    # start a dedicated instance of Emme Desktop connected to the specified project
    desktop = _app.start_dedicated(
        visible=True,
        user_initials='KCC',
        project= empFile
    )
    
    # Connect to the Modeller
    modeller = _m.Modeller(desktop=desktop)
    emmebank = modeller.emmebank
    scenario = modeller.scenario
    data_explorer = desktop.data_explorer()
    database = data_explorer.active_database()
    change_scenario = modeller.tool('inro.emme.data.scenario.change_primary_scenario')
    create_scenario = modeller.tool('inro.emme.data.scenario.create_scenario')
    delete_scenario = modeller.tool('inro.emme.data.scenario.delete_scenario')
    delete_matrix = modeller.tool('inro.emme.data.matrix.delete_matrix')
    
    try:
        # Create empty scenario if id does not exist
        sEmpty = create_scenario(scenario_id=1,
                            scenario_title="empty scenario",
                            overwrite = True)
        print('Empty Scenario 1 created')
        # Set current scenario to empty scenario
        change_scenario(scenario=1)
        print('Current scenario changed to 1')
    except:
        change_scenario(scenario=1)
        print('Current scenario changed to 1')
    
    # Delete all matrices 
    for matrix in emmebank.matrices():
        stMat = str(matrix.id)
        try:
            delMat = emmebank.matrix(stMat)
            delete_matrix(matrix=delMat) 
            print(f'matrix {stMat} deleted')
        except:
            print(f'matrix {stMat} NOT DELETED')

    # Delete Scenarios
    for scenario in database.scenarios():
        if scenario.number() != 1:
            try:
                delScen = emmebank.scenario(scenario.number())
                delete_scenario(scenario=delScen)
                print(f'Scenario {scenario.number()} deleted')
            except:
                print(f'DID NOT DELETE SCENARIO {scenario.number()}')
        else:
            print("Skip deleting scenario 1")

    # Remove output folder and reports 
    if os.path.isdir(output_dir): 
        shutil.rmtree(output_dir)
        print(f"Removed folder {output_dir}")


if __name__ == '__main__':
    main()