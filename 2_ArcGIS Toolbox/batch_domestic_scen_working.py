#################################################################################
# batch_domestic.py                                                             #
# sbuchhorn 12/10/2018    
# kcazzato 08/27/2024 pro syntax and paths updates                                #
# original batchin script by nrf    	       	                                #
#                                                                           	# 
#    This program creates Emme batchin files from the                       	#
#    Meso Freight Network.  The "path" variable is passed to the script     	#
#    as an argument from the tool and the script calls                      	#
#    create_emme_batchin_files_mfn.sas					        #
#    create_emme_batchin_files_mfn_cos.sas				        #
#    create_emme_batchin_files_mfn_NEC_ng_19.sas       	            		#
#    create_emme_batchin_files_mfn_Product_17_18.sas                            #
#                                                                           	#
#    The following files are created:                                           #
#    batchin folder:                                 	                        #
#         - base_ntwk.txt    (all links, nodes, and centroids)              	#
#         - lines.in    (rail headers and itineraries)         		        #
#         - cos_ntwk.txt (all crude oil system links, nodes, and centroids) 	#
#         - nec_19_ntwk.txt (all crude oil system links, nodes, and centroids)  # 	   
#         - p1718_ntwk.txt (all crude oil system links, nodes, and centroids)   #
#    domesticnetworks folder:                                                   #
#         - domesticnetwork.csv                                                 #
#               - info on domestic highway, rail, and water networks            #
#               - Note: all water networks given a domestic ratio of 1          #
#         -domesticpipelinenetwork.csv                                          #
#               - info on domestic ng, product, and cos pipeline networks       #
#                                                                           	#
#################################################################################

# ---------------------------------------------------------------
# Import System Modules
# ---------------------------------------------------------------
import sys, string, os, arcpy, subprocess, time, platform, fileinput, csv
from arcpy import env
import pandas as pd
arcpy.OverwriteOutput = 1

# ---------------------------------------------------------------
# Read Script Arguments
# ---------------------------------------------------------------
gdbDir = arcpy.GetParameterAsText(0)
outputPath_T = arcpy.GetParameterAsText(1)
years = str(arcpy.GetParameterAsText(2))
if years == 'all':
    years = ['2022', '2030', '2040', '2050', '2060']
else:
    years = years.replace(" ", "")
    years = years.split(",")
arcpy.AddMessage(years)

programDir = os.path.dirname(__file__)
for yr in years:
# ---------------------------------------------------------------
# Local variables
# ---------------------------------------------------------------
    outputPath = outputPath_T + "\\batchin_" + yr
    arcpy.AddMessage(outputPath)
    os.mkdir(outputPath)

    arcpy.env.workspace = outputPath
    Temp = arcpy.CreateScratchName(prefix='Temp',data_type='Folder')
    os.mkdir(Temp)
    arcpy.AddMessage("--> Created temp folder at {}".format(Temp))

    hwyLinks = "CMAP_HWY_LINK_y" + yr
    hwyNodes = "CMAP_HWY_NODE_y" + yr

    arcpy.env.workspace = gdbDir

    shapefiles_links = ["CMAP_Rail","National_Rail", hwyLinks,"National_Highway","Inland_Waterways",
                        "Crude_Oil_System", "NEC_NG_19_System", "Prod_17_18_System"]
    shapefiles_nodes = ["CMAP_Rail_nodes", "National_Rail_nodes", hwyNodes, "National_Hwy_nodes", "Inland_Waterway_nodes",
                        "Crude_Oil_System_nodes", "NEC_NG_19_nodes", "Prod_17_18_nodes"]
    shapefiles_geo = ["Meso_Logistic_Nodes", "Meso_Ext_Int_Centroids", "conus_ak"]
    shapefiles_railRoutes = ["CMAP_Rail_Routes", "National_Rail_Routes"]
    rail_itineraries = [gdbDir + "\\CMAP_Rail_Itinerary", gdbDir + "\\National_Rail_Itinerary"]

    # ---------------------------------------------------------------
    # Clear selection
    # ---------------------------------------------------------------
    for x in [shapefiles_links,shapefiles_nodes,shapefiles_geo,shapefiles_railRoutes]:
        for y in x:
            arcpy.management.SelectLayerByAttribute(y, "CLEAR_SELECTION")
            arcpy.management.AddField(y, "origLen", "DOUBLE")
            arcpy.management.CalculateField(y, 'origLen', "!shape.length!", "PYTHON")

    # ---------------------------------------------------------------
    # Update Field types
    # ---------------------------------------------------------------
    for x in [hwyNodes, "National_Hwy_nodes", "Meso_Logistic_Nodes", "Meso_Ext_Int_Centroids", "CMAP_Rail_nodes"]:
        arcpy.management.AddField(x, 'NODE_ID', 'LONG')
        arcpy.management.CalculateField(x, 'NODE_ID', "!NODE_ID_T!", "PYTHON3")

    for x in ["National_Highway", "CMAP_Rail"]:
        arcpy.management.AddField(x, 'INODE', 'LONG')
        arcpy.management.CalculateField(x, 'INODE', "!INODE_T!", "PYTHON3")
        arcpy.management.AddField(x, 'JNODE', 'LONG')
        arcpy.management.CalculateField(x, 'JNODE', "!JNODE_T!", "PYTHON3")
        if x == "National_Highway":
            arcpy.management.AddField("National_Highway", 'DIRECTIONS', 'SHORT')
            arcpy.management.CalculateField("National_Highway", 'DIRECTIONS', "!DIRECTIONS_T!", "PYTHON3")

    # ---------------------------------------------------------------
    # Extract Data for Scenario Network
    # ---------------------------------------------------------------
    ## select all network components
    arcpy.AddMessage("   * Obtaining Network Information...")
    for x in [shapefiles_links,shapefiles_nodes,shapefiles_geo,shapefiles_railRoutes]:
        for y in x:
            arcpy.conversion.ExportFeatures(y, Temp + "\\temp_{}.shp".format(y))

    ## make a copy of the MFN rail itinerary coding to use
    arcpy.AddMessage("   * Obtaining Rail Itinerary Data...")
    temp_itin_dbfs = [Temp + "\\temp_railitin1.dbf", Temp + "\\temp_railitin2.dbf"]
    arcpy.analysis.TableSelect(rail_itineraries[0], temp_itin_dbfs[0], "\"OBJECTID\" >= 1")
    arcpy.analysis.TableSelect(rail_itineraries[1], temp_itin_dbfs[1], "\"OBJECTID\" >= 1")

    ## create storage folder if it does not exist
    if not os.path.exists(outputPath_T):
        arcpy.AddMessage("---> Directory created: " + outputPath_T)
        os.mkdir(outputPath_T)

    if not os.path.exists(outputPath_T):
        arcpy.AddMessage("---> Directory created: " + outputPath_T)
        os.mkdir(outputPath_T)
        
    # ---------------------------------------------------------------
    # Create Emme Batchin Files
    # ---------------------------------------------------------------
    temp_hwyNODES = "temp_" + hwyNodes + ".dbf"
    temp_hwyLINKS = "temp_" + hwyLinks + ".dbf"

    y1 = Temp + "$" + outputPath + '$' +temp_hwyNODES + '$' +temp_hwyLINKS

    ##set up to run SAS
    bat1 = programDir + "/" + "sasrun.bat"    # batch file name
    fl = "create_emme_batchin_files_mfn_scen_working"    # SAS file name
    z1 = programDir + "/" + fl + ".sas"
    sas_log_file1 = Temp + "\\" + fl + ".log"
    sas_list_file1 =  Temp + "\\" + fl + ".lst"
    arcpy.AddMessage(y1)
    cmd1 = [ bat1, z1, y1, sas_log_file1, sas_list_file1 ]

    y1 = Temp + "$" + outputPath

    f2 = "create_emme_batchin_files_mfn_cos"    # SAS file name
    z2 = programDir + "/" + f2 + ".sas"
    sas_log_file2 = Temp + "\\" + f2 + ".log"
    sas_list_file2 = Temp + "\\" + f2 + ".lst"
    cmd2 = [ bat1, z2, y1, sas_log_file2, sas_list_file2 ]

    f3 = "create_emme_batchin_files_mfn_NEC_ng_19"    # SAS file name
    z3 = programDir + "/" + f3 + ".sas"
    sas_log_file3 = Temp + "\\" + f3 + ".log"
    sas_list_file3 = Temp + "\\" + f3 + ".lst"
    cmd3 = [ bat1, z3, y1, sas_log_file3, sas_list_file3 ]

    f4 = "create_emme_batchin_files_mfn_Product_17_18"    # SAS file name
    z4 = programDir + "/" + f4 + ".sas"
    sas_log_file4 = Temp + "\\" + f4 + ".log"
    sas_list_file4 = Temp + "\\" + f4 + ".lst"
    cmd4 = [ bat1, z4, y1, sas_log_file4, sas_list_file4 ]

    for x in [sas_list_file1,sas_list_file2,sas_list_file3,sas_list_file4]:
        if os.path.exists(x):
            os.remove(x)

    ## run SAS to create files
    arcpy.AddMessage("---> Creating Emme batchin files")
    subprocess.call(cmd1)
    if os.path.exists(sas_list_file1):
        arcpy.AddMessage("---> SAS Processing Error!! Review the List File: " + sas_list_file1)
        arcpy.AddMessage("---> If there is an Errorlevel Message, Review the Log File: " + sas_log_file1)
        arcpy.AddMessage("-------------------------------------------------------------------")
        sys.exit([1])
    subprocess.call(cmd2)
    if os.path.exists(sas_list_file2):
        arcpy.AddMessage("---> SAS Processing Error!! Review the List File: " + sas_list_file2)
        arcpy.AddMessage("---> If there is an Errorlevel Message, Review the Log File: " + sas_log_file2)
        arcpy.AddMessage("-------------------------------------------------------------------")
        sys.exit([1])
    subprocess.call(cmd3)
    if os.path.exists(sas_list_file3):
        arcpy.AddMessage("---> SAS Processing Error!! Review the List File: " + sas_list_file3)
        arcpy.AddMessage("---> If there is an Errorlevel Message, Review the Log File: " + sas_log_file3)
        arcpy.AddMessage("-------------------------------------------------------------------")
        sys.exit([1])
    subprocess.call(cmd4)
    if os.path.exists(sas_list_file4):
        arcpy.AddMessage("---> SAS Processing Error!! Review the List File: " + sas_list_file4)
        arcpy.AddMessage("---> If there is an Errorlevel Message, Review the Log File: " + sas_log_file4)
        arcpy.AddMessage("-------------------------------------------------------------------")
        sys.exit([1])


    # ---------------------------------------------------------------
    # DOMESTIC NETWORKS
    # ---------------------------------------------------------------
    arcpy.env.workspace = Temp

    tempshapefiles = ["temp_{}".format(x) for x in shapefiles_links[0:5]]
    tempfiles_pipe = ["temp_{}".format(x) for x in shapefiles_links[5:8]]

    # we'll consider the inland waterways as all domestic
    tempshapefiles.remove("temp_Inland_Waterways")

    arcpy.AddMessage("---> Clipping")
    list_get = []
    for w in tempshapefiles:
        arcpy.analysis.Clip(w + ".shp", "temp_conus_ak.shp", "clip{}".format(w))
        list_get.append("clip{}".format(w))

    pipe_list_get = []
    for w in tempfiles_pipe:
        arcpy.analysis.Clip(w + ".shp", "temp_conus_ak.shp", "clip{}".format(w))
        pipe_list_get.append("clip{}".format(w))

    arcpy.AddMessage("---> Adding new fields")
    for i in list_get:
        arcpy.management.AddField(i + ".shp", "newlen", "DOUBLE")
        arcpy.management.CalculateField(i + ".shp", 'newlen', "!shape.length!", "PYTHON")

    for i in pipe_list_get:
        arcpy.management.AddField(i + ".shp", "newlen", "DOUBLE")
        arcpy.management.CalculateField(i + ".shp", 'newlen', "!shape.length!", "PYTHON")

    for i in list_get:
        arcpy.management.AddField(i + ".shp","ratio","DOUBLE")
        arcpy.management.CalculateField(i + ".shp","ratio","!newlen!/!origLen!","PYTHON")

    for i in pipe_list_get:
        arcpy.management.AddField(i + ".shp","ratio","DOUBLE")
        arcpy.management.CalculateField(i + ".shp","ratio","!newlen!/!origLen!","PYTHON")

    arcpy.AddMessage("---> exporting data")
    files = []
    for i in list_get:
        arcpy.conversion.TableToTable(i + ".shp",Temp,"export_{}.csv".format(i))
        files.append("export_{}.csv".format(i))

    # Inland waterways
    arcpy.conversion.TableToTable("temp_Inland_Waterways.shp", Temp, "export_temp_Inland_Waterways.csv")
    files.append("export_temp_Inland_Waterways.csv")
    # add expected attributes
    waterway = pd.read_csv(Temp + "\\export_temp_Inland_Waterways.csv")
    waterway['ratio'] = 1
    waterway.to_csv(Temp + "\\export_temp_Inland_Waterways.csv")

    pipefiles = []
    for i in pipe_list_get:
        arcpy.conversion.TableToTable(i + ".shp", Temp, "export_{}.csv".format(i))
        pipefiles.append("export_{}.csv".format(i))

    arcpy.AddMessage("---> preparing final files")

    os.chdir(Temp)

    dflist = []
    for file in files:
        df = pd.read_csv(file)

        try:
            df['directions'] = df['DIRECTIONS']        
        except KeyError:
            df['directions'] = 2
        try:
            df = df[['INODE','JNODE','Miles','ratio']]
        except:
            df = df[['inode','jnode','miles','ratio']]
        dflist.append(df)

    df = pd.concat([x for x in dflist])
    df['DmstDist'] = df['ratio'] * df['Miles']
    df.rename(columns={'Miles':'LENGTH','ratio':'dom_ratio','INODE':'cINODE'},inplace=True)
    df.to_csv(outputPath_T + "DomesticNetwork.csv", index=False)
    arcpy.AddMessage("---> domesticnetwork file saved")


    pipedflist = []
    for file in pipefiles:
        df = pd.read_csv(file)
        try:
            df['directions'] = df['DIRECTIONS']

        except:
            df['directions'] = 2
        try:
            df = df[['INODE','JNODE','Miles','ratio']]
        except:
            df = df[['inode','jnode','miles','ratio']]    
        pipedflist.append(df)

    df = pd.concat([x for x in pipedflist])
    df['DmstDist'] = df['ratio'] * df['Miles']
    df.rename(columns={'Miles':'LENGTH','ratio':'dom_ratio','INODE':'cINODE'},inplace=True)
    df.to_csv(outputPath_T + "DomesticPipelineNetwork.csv", index=False)
    arcpy.AddMessage("---> pipelinenetwork file saved")

    # ---------------------------------------------------------------
    # Cleanup files
    # ---------------------------------------------------------------
    arcpy.AddMessage("---> Removing Temporary Files")

    toclean = [f for f in os.listdir(Temp)]

    for f in toclean:
        try:
            os.remove(os.path.join(Temp, f))
        except RuntimeError:
            arcpy.management.Delete(os.path.join(Temp, f))
        except WindowsError:
            print("WindowsError (probably access denied) for {}".format(f))
            continue