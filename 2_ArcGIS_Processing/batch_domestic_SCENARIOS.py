# batch_domestic_SCENARIOS.py                                                   #
# kcazzato 07/2/2025 updates                                                    #
# ----- Removed SAS processsing                                                 #
# ----- Separated pipeline and highway/rail scenarios processing                #
# kcazzato 08/27/2024 pro syntax and paths updates                              #
# sbuchhorn 12/10/2018        	       	                                        #
# original batchin script by nrf    	       	                                #
#                                                                           	# 
#    This program creates Emme batchin files from the                       	#
#    Meso Freight Network for the Rail and Highway Network.                	    # 
#    The following files are created:                                           #
#    Output/BathinFiles folder:                                 	            #
#         - base_ntwk.txt    (all links, nodes, and centroids)              	#
#         - lines.in    (rail headers and itineraries)         		            #
#         - domesticnetwork.csv                                                 #
#               - info on domestic highway, rail, and water networks            #
#               - Note: all water networks given a domestic ratio of 1          #
#                                                                           	#
#################################################################################

# ---------------------------------------------------------------
# Import System Modules
# ---------------------------------------------------------------
import sys, string, os, arcpy, subprocess, time, platform, fileinput, csv, shutil
import pandas as pd
import numpy as np
from arcpy import env
from datetime import datetime
from pathlib import Path
import geopandas as gpd
arcpy.OverwriteOutput = 1

# ---------------------------------------------------------------
# Read Script Arguments and Set Paths
# ---------------------------------------------------------------
#for testing
inConf = "c25q2"
inBaseYr = 2022
inFirstYr = 2025
inLastYr = 2050

programDir = "S:/AdminGroups/ResearchAnalysis/kcc/FY26/MFN/Translate_SAS/1_create_emme_batchin/Scripts/2_ArcGIS_Processing"
mainDir = os.path.abspath(os.path.join(programDir, "../../"))

###
#inConf = str(sys.argv[1])
#inBaseYr = int(sys.argv[2])
#inFirstYr = int(sys.argv[3])
#inLastYr = int(sys.argv[4])

dateStr = str(datetime.now()) + '\n'

#programDir = os.path.dirname(__file__)
#mainDir = os.path.abspath(os.path.join(__file__, "../../../"))
gdbDir = os.path.join(mainDir + "/Output/MFN_updated_" + inConf + ".gdb")
outFolder = os.path.join(mainDir + "/Output/BatchinFiles")
tempHWYPath = os.path.join(outFolder + "/Temp")
pOutLines = Path(outPath_scen + "/lines.in")

'''
# Delete and recreate temporary folder
if os.path.exists(tempHWYPath):
    shutil.rmtree(tempHWYPath)
os.mkdir(tempHWYPath)
arcpy.AddMessage("---> Directory created: " + tempHWYPath)

# Create list of years         
i = inFirstYr
while i <= inLastYr:
    if i == inFirstYr:
        years = [str(inBaseYr), str(inFirstYr)]
    else:
        years.append(str(i))
    i=i+5
arcpy.AddMessage("Scenario Years: ")
arcpy.AddMessage(years)
'''
years = ['2022']
# Paths for non-scenario specific layers
pRailRouteCMAP = tempHWYPath + "/temp_CMAP_Rail_Routes.dbf"
pRailRouteNat = tempHWYPath + "/temp_National_Rail_Routes.dbf"
pItinCMAP = tempHWYPath + "/temp_railitin1.dbf"
pItinNat = tempHWYPath + "/temp_railitin2.dbf"
pNodeRailCMAP = tempHWYPath + "/temp_CMAP_Rail_nodes.dbf"
pNodeRailNat = tempHWYPath + "/temp_National_Rail_nodes.dbf"
pNodeNat = tempHWYPath + "/temp_National_Hwy_nodes.dbf"
pNodeWater = tempHWYPath + "/temp_Inland_Waterway_nodes.dbf"
pNodeLog = tempHWYPath + "/temp_Meso_Logistic_Nodes.dbf"
pNodeCent = tempHWYPath + "/temp_Meso_Ext_Int_Centroids.dbf"
pLinkRailCMAP = tempHWYPath + "/temp_CMAP_Rail.dbf"
pLinkRailNat = tempHWYPath + "/temp_National_Rail.dbf"
pLinkNat = tempHWYPath + "/temp_National_Highway.dbf"
pLinkWater = tempHWYPath + "/temp_Inland_Waterways.dbf"

# ---------------------------------------------------------------
# Prepare Data for Highway and Rail File Generation
# ---------------------------------------------------------------
# Make temporary folder within Output/BatchinFiles to store temporary copies of the shapefiles
arcpy.env.workspace = gdbDir

# Define Lists, Dictionaries, and Paths
shapefiles_links = ["CMAP_Rail","National_Rail","National_Highway","Inland_Waterways"]
shapefiles_nodes = ["CMAP_Rail_nodes", "National_Rail_nodes", "National_Hwy_nodes", "Inland_Waterway_nodes"]
shapefiles_geo = ["Meso_Logistic_Nodes", "Meso_Ext_Int_Centroids", "conus_ak"]
shapefiles_railRoutes = ["CMAP_Rail_Routes", "National_Rail_Routes"]
rail_itineraries = [gdbDir + "\\CMAP_Rail_Itinerary", gdbDir + "\\National_Rail_Itinerary"]

tempLinks = ["temp_{}".format(x) for x in shapefiles_links]
'''
# Create temporary copies
for x in [shapefiles_links,shapefiles_nodes,shapefiles_geo,shapefiles_railRoutes]:
    for y in x:
        arcpy.management.SelectLayerByAttribute(y, "CLEAR_SELECTION")
        arcpy.management.AddField(y, "origLen", "DOUBLE")
        arcpy.management.CalculateField(y, 'origLen', "!shape.length!", "PYTHON")
        arcpy.conversion.ExportFeatures(y, tempHWYPath + "\\temp_{}.shp".format(y))

arcpy.AddMessage("   * Obtaining Rail Itinerary Data...")
temp_itin_dbfs = [tempHWYPath + "\\temp_railitin1.dbf", tempHWYPath + "\\temp_railitin2.dbf"]
arcpy.analysis.TableSelect(rail_itineraries[0], temp_itin_dbfs[0], "\"OBJECTID\" >= 1")
arcpy.analysis.TableSelect(rail_itineraries[1], temp_itin_dbfs[1], "\"OBJECTID\" >= 1") 
'''
# Read non-scenario specific data
inRailRouteCMAP = gpd.read_file(pRailRouteCMAP)
inRailRouteNat = gpd.read_file(pRailRouteNat)
inItinCMAP = gpd.read_file(pItinCMAP)
inItinNat = gpd.read_file(pItinNat)
inNodeRailCMAP = gpd.read_file(pNodeRailCMAP)
inNodeRailNat = gpd.read_file(pNodeRailNat)
inNodeNat = gpd.read_file(pNodeNat)
inNodeWater = gpd.read_file(pNodeWater)
inLognode = gpd.read_file(pNodeLog)
inNodeCent = gpd.read_file(pNodeCent)
inLinkRailCMAP = gpd.read_file(pLinkRailCMAP)
inLinkRailNat = gpd.read_file(pLinkRailNat)
inLinkNat = gpd.read_file(pLinkNat)
inLinkWater = gpd.read_file(pLinkWater)

# Convert to pandas DF
railroute1 = inRailRouteCMAP.drop(columns='geometry')
railroute2 = inRailRouteNat.drop(columns='geometry')
railitin1 = inItinCMAP.drop(columns='geometry')
railitin2 = inItinNat.drop(columns='geometry')
railnode1 = inNodeRailCMAP.drop(columns='geometry')
railnode2 = inNodeRailNat.drop(columns='geometry')
hwynode2 = inNodeNat.drop(columns='geometry')
waternode = inNodeWater.drop(columns='geometry')
lognode = inLognode.drop(columns='geometry')
centroid = inNodeCent.drop(columns='geometry')
railarc1 = inLinkRailCMAP.drop(columns='geometry')
railarc2 = inLinkRailNat.drop(columns='geometry')
hwyarc2 = inLinkNat.drop(columns='geometry')
waterarc = inLinkWater.drop(columns='geometry')

# Select columns of interest only
railroute1 = railroute1[['DESC_', 'REV_DESC', 'START_NODE', 'END_NODE', 'Mode', 'VEHICLE', 'TOT_DIST', 'TOT_T_TIME', 'Speed', 'Headway']]
railroute2 = railroute2[['DESC_', 'REV_DESC', 'START_NODE', 'END_NODE', 'Mode', 'VEHICLE', 'TOT_DIST', 'TOT_T_TIME', 'Speed', 'Headway']  ]
railarc1 = railarc1[["INODE", "JNODE", "Miles", "Modes", "Type", "LANES", "VDF"]]
railarc2 = railarc2[["INODE", "JNODE", "Miles", "Modes", "Type", "LANES", "VDF"]]
hwyarc2 = hwyarc2[["INODE", "JNODE", "Miles", "Modes", "Type", "LANES", "VDF"]]
waterarc = waterarc[["INODE", "JNODE", "Miles", "Modes", "Type", "LANES", "VDF"]]
railnode1 = railnode1[["NODE_ID", "POINT_X", "POINT_Y", "MESOZONE"]]
railnode2 = railnode2[["NODE_ID", "POINT_X", "POINT_Y", "MESOZONE"]]
hwynode2 = hwynode2[["NODE_ID", "POINT_X", "POINT_Y", "MESOZONE"]]
waternode = waternode[["NODE_ID", "POINT_X", "POINT_Y", "MESOZONE"]]
lognode = lognode[["NODE_ID", "POINT_X", "POINT_Y", "MESOZONE"]]
centroid = centroid[["NODE_ID", "POINT_X", "POINT_Y", "MESOZONE"]]

# Format Rail Routes
# add reverse routes to each df
rev_railroute1 = railroute1.set_axis(['REV_DESC', 'DESC_', 'END_NODE', 'START_NODE', 'Mode', 'VEHICLE', 'TOT_DIST', 'TOT_T_TIME', 'Speed', 'Headway'], axis = 1)         #Flip Direction
rev_railroute1 = rev_railroute1[['DESC_', 'REV_DESC', 'START_NODE', 'END_NODE', 'Mode', 'VEHICLE', 'TOT_DIST', 'TOT_T_TIME', 'Speed', 'Headway']]                        #reorder columns

rev_railroute2 = railroute2.set_axis(['REV_DESC', 'DESC_', 'END_NODE', 'START_NODE', 'Mode', 'VEHICLE', 'TOT_DIST', 'TOT_T_TIME', 'Speed', 'Headway'], axis = 1)         #Flip Direction
rev_railroute2 = rev_railroute2[['DESC_', 'REV_DESC', 'START_NODE', 'END_NODE', 'Mode', 'VEHICLE', 'TOT_DIST', 'TOT_T_TIME', 'Speed', 'Headway']]                        #reorder columns

routes = pd.concat([railroute1, railroute2, rev_railroute1, rev_railroute2])                         #combine forward and reverse routes
routes = routes.sort_values(by=['DESC_'])                                                            #sort by DESC_

# Format Rail Itineraries
itins = pd.concat([railitin1, railitin2])                                                             #combine itineraries
itins = itins.sort_values(by=['DESC_', 'SEG_ORDER'])                                                  #sort by DESC_ and SEG_ORDER

# Format Nodes
lognode = lognode.sort_values(by=['NODE_ID'])                                                         #sort by node_id
centroid = centroid.sort_values(by=['NODE_ID'])                                                       #sort by node_id

centroids = pd.concat([lognode, centroid])
centroids[['POINT_X', 'POINT_Y']] = centroids[['POINT_X', 'POINT_Y']].astype('float64')               #format as 15 character, 6 decimal string max
centroids['POINT_X'] = centroids['POINT_X'].map('{:15.6f}'.format)
centroids['POINT_Y'] = centroids['POINT_Y'].map('{:15.6f}'.format)
centroids[['POINT_X', 'POINT_Y']] = centroids[['POINT_X', 'POINT_Y']].astype('str')
centroids = centroids.sort_values(by=['NODE_ID'])                                                     #sort by node_id

# Create Reverse CMAP Rail Arcs
rev_railarc1 = railarc1.set_axis(["JNODE", "INODE", "Miles", "Modes", "Type", "LANES", "VDF"], axis = 1)         #Flip Direction
rev_railarc1 = rev_railarc1[["INODE", "JNODE", "Miles", "Modes", "Type", "LANES", "VDF"]]                        #reorder columns
for idx, row in rev_railarc1.iterrows():
    if (row.Modes == 'a'):
        rev_railarc1.at[idx,'Modes'] = 'e'
    if (row.Modes == 'e'):
        rev_railarc1.at[idx,'Modes'] = 'a'

# Create Reverse National Rail Arcs 
rev_railarc2 = railarc2.set_axis(["JNODE", "INODE", "Miles", "Modes", "Type", "LANES", "VDF"], axis = 1)         #Flip Direction
rev_railarc2 = rev_railarc2[["INODE", "JNODE", "Miles", "Modes", "Type", "LANES", "VDF"]]                        #reorder columns
for idx, row in rev_railarc2.iterrows():
    if (row.Modes == 'a'):
        rev_railarc2.at[idx,'Modes'] = 'e'
    if (row.Modes == 'e'):
        rev_railarc2.at[idx,'Modes'] = 'a'

# Create Reverse National Highway Arc
rev_hwyarc2 = hwyarc2.set_axis(["JNODE", "INODE", "Miles", "Modes", "Type", "LANES", "VDF"], axis = 1)         #Flip Direction
rev_hwyarc2 = rev_hwyarc2[["INODE", "JNODE", "Miles", "Modes", "Type", "LANES", "VDF"]]                        #reorder columns

# Create Reverse Waterway Arcs
rev_waterarc = waterarc.set_axis(["JNODE", "INODE", "Miles", "Modes", "Type", "LANES", "VDF"], axis = 1)         #Flip Direction
rev_waterarc = rev_waterarc[["INODE", "JNODE", "Miles", "Modes", "Type", "LANES", "VDF"]]                        #reorder columns

# ---------------------------------------------------------------
# Generate Highway Batchin Files
# ---------------------------------------------------------------
for yr in years:
    arcpy.AddMessage("---> Generating Batchin Files for: " + yr)
    
    # Create output and temporary folder if it does not exist
    outPath_scen = outFolder + "\\scen_" + yr
    if not os.path.exists(outPath_scen):
        os.mkdir(outPath_scen)
        arcpy.AddMessage("---> Directory created: " + outPath_scen)

    # Define Paths and Variables
    hwyLinks = "CMAP_HWY_LINK_y" + yr
    hwyNodes = "CMAP_HWY_NODE_y" + yr
    pNodeCMAP = tempHWYPath + "/temp_" + hwyNodes + ".dbf"
    pLinkCMAP = tempHWYPath + "/temp_" + hwyLinks + ".dbf"
    pOutNTWK = Path(outPath_scen + "/base_ntwk.txt")
    dateStr = str(datetime.now()) + '\n'
    '''
    # Create Temporary Copies of HWY network
    arcpy.env.workspace = gdbDir
    for x in [hwyLinks, hwyNodes]:
        arcpy.AddMessage("---> creating temporary: " + x)
        arcpy.management.SelectLayerByAttribute(x, "CLEAR_SELECTION")
        arcpy.management.AddField(x, "origLen", "DOUBLE")
        arcpy.management.CalculateField(x, 'origLen', "!shape.length!", "PYTHON")
        arcpy.conversion.ExportFeatures(x, tempHWYPath + "\\temp_{}.shp".format(x))
    '''
    # Read and Format Highway Data
    inLinkCMAP = gpd.read_file(pLinkCMAP)
    inNodeCMAP = gpd.read_file(pNodeCMAP)

    hwynode1 = inNodeCMAP.drop(columns='geometry')
    hwyarc1 = inLinkCMAP.drop(columns='geometry')

    hwynode1 = hwynode1[["NODE_ID", "POINT_X", "POINT_Y", "MESOZONE"]]
    hwyarc1 = hwyarc1[["INODE", "JNODE", "Miles", "Modes", "Type", "LANES", "VDF", 'LANES2', 'DIRECTIONS']]

    # Combine HWY Nodes with other nodes
    nodes = pd.concat([railnode1, railnode2, hwynode1, hwynode2, waternode])               #combine all network nodes
    nodes = nodes.merge(lognode, how='outer', indicator=True)                              #combine with lognodes 
    nodes = nodes.merge(centroid, how='outer', indicator="_merge2")                        #combine with centroids
    nodes = nodes.drop_duplicates(subset=['NODE_ID'])                                      #remove duplicates by node_id
    nodes[['POINT_X', 'POINT_Y']] = nodes[['POINT_X', 'POINT_Y']].astype('float64')        #format as 15 character, 6 decimal string max
    nodes['POINT_X'] = nodes['POINT_X'].map('{:15.6f}'.format)
    nodes['POINT_Y'] = nodes['POINT_Y'].map('{:15.6f}'.format)
    nodes = nodes.sort_values(by=['NODE_ID']) 
    nodes[['POINT_X', 'POINT_Y']] = nodes[['POINT_X', 'POINT_Y']].astype('str')
    nodes = nodes[(nodes._merge=='left_only')].drop('_merge', axis=1)                      #antijoin with lognodes (remove lognodes)
    nodes = nodes[(nodes._merge2=='left_only')].drop('_merge2', axis=1)                    #antijoin with centroids (remove centroids)

    # Create Reverse CMAP Highway Arcs
    rev_hwyarc1 = hwyarc1.set_axis(["JNODE", "INODE", "Miles", "Modes", "Type", "LANES", "VDF", 'LANES2', 'DIRECTIONS'], axis = 1)         #Flip Direction
    rev_hwyarc1 = rev_hwyarc1[["INODE", "JNODE", "Miles", "Modes", "Type", "LANES", "VDF", 'LANES2', 'DIRECTIONS']]   
    for idx, row in rev_hwyarc1.iterrows():               #switch lanes
        if (row.DIRECTIONS == 3):
            rev_hwyarc1.at[idx,'LANES'] = rev_hwyarc1.at[idx,'LANES2']

    hwyarc1 = hwyarc1.drop(columns = ['LANES2', 'DIRECTIONS'])
    rev_hwyarc1 = rev_hwyarc1.drop(columns = ['LANES2', 'DIRECTIONS'])

    # Combine rail arcs, highway arcs, and waterway arcs and all reverse arcs
    allLinks = pd.concat([railarc1, rev_railarc1, railarc2, rev_railarc2, 
                          hwyarc1, rev_hwyarc1, hwyarc2, rev_hwyarc2, 
                          waterarc, rev_waterarc])
    allLinks = allLinks.sort_values(by=['INODE', 'JNODE'])                       #sort by inode and jnode

    # QA/QC
    # #Verify each link has a length (allLinks, miles = 0) 
    errorM = "CRUDE OIL SYSTEM NETWORK LINKS WITHOUT A CODED LENGTH"
    check = (allLinks['Miles'] == "0").any()
    if(check == 'True'): 
        print(sys.exit(print(errorM)))

    #Verify each link has a mode (allLinks, mode is NA) 
    errorM = "CRUDE OIL SYSTEM NETWORK LINKS WITHOUT A CODED MODE"
    check = (allLinks['Modes'].isnull()).any()
    if(check == 'True'): 
        print(sys.exit(print(errorM)))

    #Verify each node has coordinates (nodes, point_x='.' Or point_y='.') 
    errorM = "CRUDE OIL SYSTEM NETWORK NODES WITH NO X COORDINATES"
    check=(nodes['POINT_X'].isnull()).any() 
    if(check == 'True'): 
        sys.exit(print(errorM))

    errorM = "CRUDE OIL SYSTEM NETWORK NODES WITH NO Y COORDINATES"
    check=(nodes['POINT_Y'].isnull()).any() 
    if(check == 'True'): 
        sys.exit(print(errorM))

    #Verify each centroid has coordinates (centroids, point_x='.' Or point_y='.' 
    errorM = "MESO FREIGHT NETWORK CENTROIDS WITH NO X COORDINATES"
    check=(centroids['POINT_X'].isnull()).any() 
    if(check == 'True'): 
        sys.exit(print(errorM))
    
    errorM = "MESO FREIGHT NETWORK CENTROIDS WITH NO Y COORDINATES"
    check=(centroids['POINT_Y'].isnull()).any() 
    if(check == 'True'): 
        sys.exit(print(errorM))

    #Verify each node has a unique number (nodes, check count node_id not>1) 
    errorM = "CRUDE OIL SYSTEM NETWORK NODES WITH DUPLICATE NUMBERS"
    check=(nodes["NODE_ID"].is_unique)
    if(check == 'False'): 
        sys.exit(print(errorM))

    #Verify each centroid has a unique number (centroids, check count node_id not>1) 
    errorM = "MESO FREIGHT NETWORK CENTROIDS WITH DUPLICATE NUMBERS"
    check=((centroids["NODE_ID"]).is_unique)
    if(check == 'False'): 
        sys.exit(print(errorM))

    # Output
    #Add a* column to each df
    nodes['first'] = 'a'
    nodes = nodes[['first', 'NODE_ID', "POINT_X", "POINT_Y", 'MESOZONE']]
    centroids['first'] = 'a*'
    centroids = centroids[['first', 'NODE_ID', "POINT_X", "POINT_Y", 'MESOZONE']]
    allLinks['first'] = 'a'
    allLinks['ul1'] = '0'
    allLinks['ul2'] = '0'
    allLinks['ul3'] = '0'
    allLinks = allLinks[['first', "INODE", "JNODE", "Miles", "Modes", "Type", "LANES", "VDF", 'ul1', 'ul2', 'ul3']]
    '''
    #all written to the same txt
    #f = open(outpath, 'x')
    with pOutNTWK.open('w') as f:
        f.write("c MESO FREIGHT NETWORK BATCHIN FILE \n")                        #file title
        f.write(dateStr)                                                             #date/time
        f.write('c node   x   y   UI1 \n')                                           #node column headers
        f.write('t nodes init \n')                                                   #node init line
        f.write(centroids.to_string(header = False, index = False))               #write centroids
        f.write("\n")
        f.write(nodes.to_string(header = False, index = False))               #write nodes
        f.write('\n c i   j   mi   modes   type   lanes   vdf   ul1   ul2   ul3 \n')    #link header
        f.write('t links init \n')                                                   #link init line
        f.write(allLinks.to_string(header = False, index = False))                  #write arcs
    '''
    # Create DOMESTIC NETWORKS file
    arcpy.env.workspace = tempHWYPath

    # Create list of all temporary links
    ap = "temp_" + hwyLinks
    tempLinks.append(ap)
    tempLinks.remove("temp_Inland_Waterways")            

    arcpy.AddMessage("---> Clipping")
    list_get = []
    for w in tempLinks:
        arcpy.analysis.Clip(w + ".shp", "temp_conus_ak.shp", "clip{}".format(w))
        list_get.append("clip{}".format(w))

    arcpy.AddMessage("---> Adding new fields")
    files = []
    for i in list_get:
        arcpy.management.AddField(i + ".shp", "newlen", "DOUBLE")
        arcpy.management.CalculateField(i + ".shp", 'newlen', "!shape.length!", "PYTHON")
        arcpy.management.AddField(i + ".shp","ratio","DOUBLE")
        arcpy.management.CalculateField(i + ".shp","ratio","!newlen!/!origLen!","PYTHON")
        arcpy.AddMessage("---> exporting data")
        arcpy.conversion.TableToTable(i + ".shp",tempHWYPath,"export_{}.csv".format(i))
        files.append("export_{}.csv".format(i))

    # Inland waterways
    arcpy.conversion.TableToTable("temp_Inland_Waterways.shp", tempHWYPath, "export_temp_Inland_Waterways.csv")
    files.append("export_temp_Inland_Waterways.csv")
    # add expected attributes
    waterway = pd.read_csv(tempHWYPath + "\\export_temp_Inland_Waterways.csv")
    waterway['ratio'] = 1
    waterway.to_csv(tempHWYPath + "\\export_temp_Inland_Waterways.csv")

    arcpy.AddMessage("---> preparing final files")
    os.chdir(tempHWYPath)
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
    df.to_csv(outPath_scen+"/DomesticNetwork.csv", index=False)
    arcpy.AddMessage("---> domesticnetwork file saved")








# ---------------------------------------------------------------
# QA/QC Rail Itinerary Data and Export
# ---------------------------------------------------------------

##########add QA/QC of rail itinerary info
# report routes wihtout an itinerary
# report itinerary gaps
######ADD EXPORTING OF ITINERARY BATCHIN FILE

# ---------------------------------------------------------------
# Cleanup final non-scenario specific temporary files
# ---------------------------------------------------------------
#fix this to work with new file structure
arcpy.AddMessage("---> Removing Temporary Files")
toclean = [f for f in os.listdir(tempFolder)]
for f in toclean:
    try:
        os.remove(os.path.join(tempFolder, f))
    except RuntimeError:
        arcpy.management.Delete(os.path.join(tempFolder, f))
    except WindowsError:
        print("WindowsError (probably access denied) for {}".format(f))
        continue