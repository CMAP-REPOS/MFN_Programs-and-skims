#filename: distr_m01_data.py
#description: Python script uses the EMME Modeler API to punch transit network and itinerary data for DISTR and M01 files creation
#author: Karly Cazzato, 9/20/2023

import os, sys, shutil, yaml
import inro.emme.desktop.app as _app
import inro.modeller as _m
import pandas as pd
    
def main():
    # Read input parameters
    scenario = sys.argv[1]
    year = sys.argv[2]
    flag140 = int(sys.argv[3])
    flag143 = int(sys.argv[4])

    # Define Input Paths
    input_dir =  os.path.join(os.getcwd(),"input_data")
    pth_dwlCode = os.path.join(input_dir + "/constants/speeds_and_time.yaml")   ##-- Zone and node ranges by mode and region (CMAP, logistics, non-CMAP)
    pth_modes =  os.path.join(input_dir, "modes.in")
    pth_vehicles =  os.path.join(input_dir, "vehicles.in")
    pth_base_ntwk =  os.path.join(input_dir, "base_ntwk.txt")
    pth_140 =  os.path.join(input_dir, "unlink_lognode140.txt")
    pth_143 =  os.path.join(input_dir, "unlink_lognode143.txt")
    pth_lines =  os.path.join(input_dir, "lines.in")
    pth_vdf =  os.path.join(input_dir, "vdf.in")
    pth_poe =  os.path.join(input_dir, "poe.in")
    pth_domdist =  os.path.join(input_dir, "DomesticNetwork.csv")
    pth_cos_ntwk =  os.path.join(input_dir, "cos_ntwk.txt")
    pth_p1718_ntwk =  os.path.join(input_dir, "p1718_ntwk.txt")
    pth_nec19_ntwk =  os.path.join(input_dir, "nec_19_ntwk.txt")
    pth_domdistPipe =  os.path.join(input_dir, "DomesticPipelineNetwork.csv")
    pth_matrices = os.path.join(input_dir, "matrix.in")

    with open(pth_dwlCode, 'r') as file:         ##-- Zone and node ranges by mode and region (CMAP, logistics, non-CMAP)
        in_dwlCode = yaml.safe_load(file)

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
    change_scenario = modeller.tool('inro.emme.data.scenario.change_primary_scenario')
    create_scenario = modeller.tool('inro.emme.data.scenario.create_scenario')
    delete_scenario = modeller.tool('inro.emme.data.scenario.delete_scenario')
    process_modes = modeller.tool('inro.emme.data.network.mode.mode_transaction')
    process_vehicles = modeller.tool('inro.emme.data.network.transit.vehicle_transaction')
    process_network = modeller.tool('inro.emme.data.network.base.base_network_transaction')
    process_lines = modeller.tool('inro.emme.data.network.transit.transit_line_transaction')
    process_VDF = modeller.tool('inro.emme.data.function.function_transaction')
    create_extra = modeller.tool('inro.emme.data.extra_attribute.create_extra_attribute')
    process_extra = modeller.tool('inro.emme.data.extra_attribute.import_extra_attributes')
    net_calc = modeller.tool('inro.emme.network_calculation.network_calculator')
    process_matrices = modeller.tool('inro.emme.data.matrix.matrix_transaction')

    ##-- SETUP HIGHWAY & RAIL NETWORK
    # Delete scenario if it exists
    try:
        delScen = emmebank.scenario(scenario)
        delete_scenario(scenario=delScen)
    except:
        None

    # Create scenario
    scenTitle = f'Base Meso Freight Network_{year}_{scenario}'
    hwyScen = create_scenario(scenario_id=scenario, scenario_title=scenTitle, overwrite = True)
    change_scenario(scenario=scenario)     # Set current scenario to empty scenario

    # Import Modes
    process_modes(transaction_file = pth_modes, revert_on_error = True, scenario = _m.Modeller().scenario)
    
    # Import Vehicles
    process_vehicles(transaction_file = pth_vehicles, revert_on_error = True, scenario = _m.Modeller().scenario)
    
    # Import base network
    process_network(transaction_file = pth_base_ntwk, revert_on_error=True, scenario=_m.Modeller().scenario)
    
    # Import logistics nodes files
    # Flag 140: Is extra logistics terminal (in Crete) active? 0 = no, 1 = yes
    if flag140 == 0:
        process_network(transaction_file = pth_140, revert_on_error=True, scenario=_m.Modeller().scenario)

    # Flag 143: Is extra logistics terminal (South Suburban Airport) active? 0 = no, 1 = yes
    if flag143 == 0:
        process_network(transaction_file = pth_143, revert_on_error=True, scenario=_m.Modeller().scenario)

    # Import Transit Lines
    process_lines(transaction_file=pth_lines, revert_on_error=True, scenario=_m.Modeller().scenario)

    # Import VDF
    process_VDF(transaction_file=pth_vdf, throw_on_error=True)
    
    # Create extra attribute
    extra_attributes = {
        '@poecd'    : ['NODE', 'poe code number'],
        '@mzone'    : ['NODE', 'mesozone in which node is located'],
        '@rdwell'   : ['NODE', 'rail dwell time code'],
        '@poe'      : ['LINK', 'poe code for skims'],
        '@domestic' : ['LINK', 'domestic distance'],
        '@lhdist'   : ['LINK', 'linehaul(ivtt) distance']
    }
    
    for extAtt in extra_attributes:
        create_extra_att= create_extra(extra_attribute_type=f'{extra_attributes[extAtt][0]}',
                        extra_attribute_name=f'{extAtt}',
                        extra_attribute_description=f'{extra_attributes[extAtt][1]}',
                        overwrite=True) 
    
    # Initialize extra attribute with poe.in
    process_extra(pth_poe,
              scenario=_m.Modeller().scenario,
              field_separator=" ",
              has_header = True,
              revert_on_error=True)

    # Import domestic distance
    # Forward
    process_extra(pth_domdist,
              scenario=_m.Modeller().scenario,
              has_header=False,
              field_separator=",",
              column_labels={0: "i_node", 
                             1: "j_node", 
                             5: "@domestic"},
              revert_on_error=False)              # False otherwise if 140 or 143 were removed, this will fail
    # Reverse
    process_extra(pth_domdist,
              scenario=_m.Modeller().scenario,
              has_header=False,
              field_separator=",",
              column_labels={0: "j_node", 
                             1: "i_node", 
                             5: "@domestic"},
              revert_on_error=False)              # False otherwise if 140 or 143 were removed, this will fail
    
    # Assign links node poe code
    poe_spec = {
        "result": "@poe",
        "expression": "@poecd",
        "selections": {
            "link": "all"},
        "type": "NETWORK_CALCULATION"
    }

    # Calculate US1 (minutes per mile)
    us1_spec = {
        "result": "us1",
        "expression": "60/speed",
        "selections": {
            "link": "all",
            "transit_line": "all"
        },
        "type": "NETWORK_CALCULATION"
    }

    # Assign mesozone from ui1
    mzone_spec = {
        "result": "@mzone",
        "expression": "ui1",
        "selections": {
            "node": "all"
        },
        "type": "NETWORK_CALCULATION"
    }
    
    # Calculate @lhdist
    lhdist_spec = {
        "result": "@lhdist",
        "expression": "(i.gt.399 .and. j.gt.399)*length",
        "selections": {
            "link": "all"
        },
        "type": "NETWORK_CALCULATION"
    }

    # Calculate rail dwell time
    rdwell_spec = {
        "result": "@poecd",
        "expression": f"(@mzone.eq.{str(in_dwlCode['stLouisMESO1'])} .or. @mzone.eq.{str(in_dwlCode['stLouisMESO2'])})*{str(in_dwlCode['stLouisDWL'])} + (@mzone.eq.{str(in_dwlCode['memphisMESO'])})*{str(in_dwlCode['memphisDWL'])} + (@mzone.eq.{str(in_dwlCode['newOrleansMESO'])})*{str(in_dwlCode['newOrleansDWL'])} + (@mzone.eq.{str(in_dwlCode['kansasCityMESO1'])} .or. @mzone.eq.{str(in_dwlCode['kansasCityMESO2'])})*{str(in_dwlCode['kansasCityDWL'])}",
        "selections": {
            "node": "all"
        },
        "type": "NETWORK_CALCULATION"
    }

    # Run network calculations
    report=net_calc([poe_spec, us1_spec, mzone_spec, lhdist_spec, rdwell_spec])

    ##-- SETUP PIPELINE NETWORKS
    pipelines = {
        'crude_oil' : [f'Crude Oil Pipeline Network_{year}_{scenario}', int(scenario)+10,pth_cos_ntwk],
        'petroleum': [f'Petroleum Products Pipeline Network_{year}_{scenario}', int(scenario)+11, pth_p1718_ntwk],
        'natural_gas':[f'Coal N.E.C. Pipeline Network_{year}_{scenario}', int(scenario)+12, pth_nec19_ntwk]
    }

    for pipe in pipelines:
        # Delete scenario if it exists
        try:
            delScen = emmebank.scenario(pipelines[pipe][1])
            delete_scenario(scenario=delScen)
        except:
            None

        # Create scenario
        scenTitle = f'Base Meso Freight Network_{year}_{str(pipelines[pipe][1])}'
        hwyScen = create_scenario(scenario_id=pipelines[pipe][1], scenario_title=scenTitle, overwrite = True)
        change_scenario(scenario=pipelines[pipe][1])     # Set current scenario to empty scenario

        # Import Modes
        process_modes(transaction_file = pth_modes, revert_on_error = True, scenario = _m.Modeller().scenario)

        # Import base network
        process_network(transaction_file = pipelines[pipe][2], revert_on_error=True, scenario=_m.Modeller().scenario)

        # Create mzone
        create_extra_att= create_extra(extra_attribute_type=extra_attributes['@mzone'][0],
                        extra_attribute_name='@mzone',
                        extra_attribute_description=extra_attributes['@mzone'][1],
                        overwrite=True) 
        report = net_calc(mzone_spec)

        # Create pipeline domestic distance
        create_extra_att= create_extra(extra_attribute_type=extra_attributes['@domestic'][0],
                        extra_attribute_name='@domestic',
                        extra_attribute_description=extra_attributes['@domestic'][1],
                        overwrite=True) 
        # Forward
        process_extra(pth_domdistPipe,
                scenario=_m.Modeller().scenario,
                field_separator=",",
                has_header=False,
                column_labels={0: "i_node", 
                                1: "j_node", 
                                5: "@domestic"},
                revert_on_error=False)              # False otherwise if 140 or 143 were removed, this will fail
        # Reverse
        process_extra(pth_domdistPipe,
                scenario=_m.Modeller().scenario,
                has_header=False,
                field_separator=",",
                column_labels={0: "j_node", 
                                1: "i_node", 
                                5: "@domestic"},
                revert_on_error=False)              # False otherwise if 140 or 143 were removed, this will fail
        
    ##-- PROCESS MATRICES
    process_matrices(transaction_file=pth_matrices,
        throw_on_error=True,
        scenario=_m.Modeller().scenario)
    
if __name__ == '__main__':
    main()