#################################################################################
# batch_domestic_PIPELINE.py                                                    #
# kcazzato 07/2/2025 updates                                                    #
# ----- Removed SAS processsing                                                 #
# ----- Separated pipeline and highway/rail scenarios processing                #
# kcazzato 08/27/2024 pro syntax and paths updates                              #
# sbuchhorn 12/10/2018        	       	                                        #
# original batchin script by nrf    	       	                                #
#                                                                           	# 
#    This program creates Emme batchin files from the                       	#
#    Meso Freight Network for the Pipelie Networks.                     	    # 
#    The following files are created:                                           #
#    Output/BathinFiles folder:                                 	            #
#         - cos_ntwk.txt (all crude oil system links, nodes, and centroids) 	#
#         - nec_19_ntwk.txt (all crude oil system links, nodes, and centroids)  # 	   
#         - p1718_ntwk.txt (all crude oil system links, nodes, and centroids)   #
#         -domesticpipelinenetwork.csv                                          #
#               - info on domestic ng, product, and cos pipeline networks       #
#                                                                           	#
#################################################################################

# ---------------------------------------------------------------
# Import System Modules
# ---------------------------------------------------------------
import sys, string, os, arcpy, subprocess, time, platform, fileinput, csv, dbfread, shutil
import pandas as pd
import numpy as np
from arcpy import env
from dbfread import DBF
from datetime import datetime
from pathlib import Path

arcpy.OverwriteOutput = 1

# ---------------------------------------------------------------
# Read Script Arguments
# ---------------------------------------------------------------
#inConf = str(sys.argv[1])
#programDir = os.path.dirname(__file__)
#mainDir = os.path.abspath(os.path.join(__file__, "../../../"))

inConf = "c25q2"
programDir = "S:/AdminGroups/ResearchAnalysis/kcc/FY26/MFN/Translate_SAS/1_create_emme_batchin/Scripts/2_ArcGIS_Processing"
mainDir = os.path.abspath(os.path.join(programDir, "../../"))
gdbDir = os.path.join(mainDir + "/Output/MFN_updated_" + inConf + ".gdb")
outFolder = os.path.join(mainDir + "/Output/BatchinFiles")
tempPipePath = os.path.join(outFolder + "/Temp")


# Delete and recreate ouput folder
if os.path.exists(tempPipePath):
    shutil.rmtree(tempPipePath)
if os.path.exists(outFolder):
    shutil.rmtree(outFolder)
os.mkdir(outFolder)
arcpy.AddMessage("---> Directory created: " + outFolder)
os.mkdir(tempPipePath)
arcpy.AddMessage("---> Directory created: " + tempPipePath)

# ---------------------------------------------------------------
# Prepare Data for Pipeline File Generation
# ---------------------------------------------------------------
arcpy.env.workspace = gdbDir

# Define Lists, Dictionaries, and Variables
shapefiles_links = ["Crude_Oil_System", "NEC_NG_19_System", "Prod_17_18_System", "Inland_Waterways"]
shapefiles = ["Crude_Oil_System_nodes", "NEC_NG_19_nodes", "Prod_17_18_nodes", "Meso_Ext_Int_Centroids", "conus_ak"]

pipeDict = {
  "pNodes": ["/temp_Crude_Oil_System_nodes.dbf", "/temp_NEC_NG_19_nodes.dbf", "/temp_Prod_17_18_nodes.dbf"],
  "pLinks": ["/temp_Crude_Oil_System.dbf", "/temp_NEC_NG_19_System.dbf", "/temp_Prod_17_18_System.dbf"],
  "pOutput": ["/cos_ntwk.txt", "/nec_19_ntwk.txt", "/p1718_ntwk.txt"],
  "pMessage" : ["CRUDE OIL SYSTEM NETWORK", "NEC_ng_19 NETWORK", "PRODUCT_17_18 SYSTEM NETWORK"]
}

pCentroids = tempPipePath + "/temp_Meso_Ext_Int_Centroids.dbf"

# Create temporary copies
arcpy.AddMessage("   * Obtaining Pipeline Network Information and Creating Temporary Copies...")
for x in [shapefiles_links,shapefiles]:
    for y in x:
        arcpy.management.SelectLayerByAttribute(y, "CLEAR_SELECTION")
        arcpy.management.AddField(y, "origLen", "DOUBLE")
        arcpy.management.CalculateField(y, 'origLen', "!shape.length!", "PYTHON")
        arcpy.conversion.ExportFeatures(y, tempPipePath + "\\temp_{}.shp".format(y))

# ---------------------------------------------------------------
# Generate Pipeline Batchin Files
# ---------------------------------------------------------------
i=0
while i < 3:
    status = "   * Developing " + pipeDict['pOutput'][i] + " output"
    arcpy.AddMessage(status)
    pNodes = tempPipePath + pipeDict['pNodes'][i]
    pLinks = tempPipePath + pipeDict['pLinks'][i]
    pOutput = Path(outFolder + pipeDict['pOutput'][i])
    dateStr = str(datetime.now()) + '\n'

    # Read data
    inNodes = DBF(pNodes)
    inCentroids = DBF(pCentroids)
    inLinks = DBF(pLinks)

    # Convert to pandas DF
    nodes = pd.DataFrame(iter(inNodes))
    centroids = pd.DataFrame(iter(inCentroids))
    cosarc = pd.DataFrame(iter(inLinks))
    
    # Select columns of interest only
    nodes = nodes[["NODE_ID", "POINT_X", "POINT_Y", "MESOZONE"]]
    centroids = centroids[["NODE_ID", "POINT_X", "POINT_Y", "MESOZONE"]]
    cosarc = cosarc[["INODE", "JNODE", "Miles", "Modes", "Type", "LANES", "VDF"]]
    
    # Format Nodes
    allNodes = nodes.merge(centroids, how='outer', indicator=True)
    allNodes = allNodes.drop_duplicates(subset=['NODE_ID'])                                               #remove duplicates by node_id
    allNodes = allNodes.sort_values(by=['NODE_ID'])                                                       #sort by node_id
    antiNodes = allNodes[(allNodes._merge=='left_only')].drop('_merge', axis=1)                           #antijoin with centroids (remove centroids)
    antiNodes[['POINT_X', 'POINT_Y']] = antiNodes[['POINT_X', 'POINT_Y']].astype('float64')               #format as 15 character, 6 decimal string max
    antiNodes['POINT_X'] = antiNodes['POINT_X'].map('{:15.6f}'.format)
    antiNodes['POINT_Y'] = antiNodes['POINT_Y'].map('{:15.6f}'.format)
    antiNodes[['POINT_X', 'POINT_Y']] = antiNodes[['POINT_X', 'POINT_Y']].astype('str')

    # Format Centroids
    centroids = centroids.sort_values(by=['NODE_ID'])                                                     #sort by node_id
    centroids[['POINT_X', 'POINT_Y']] = centroids[['POINT_X', 'POINT_Y']].astype('float64')               #format as 15 character, 6 decimal string max
    centroids['POINT_X'] = centroids['POINT_X'].map('{:15.6f}'.format)
    centroids['POINT_Y'] = centroids['POINT_Y'].map('{:15.6f}'.format)
    centroids[['POINT_X', 'POINT_Y']] = centroids[['POINT_X', 'POINT_Y']].astype('str')

    # Format Links
    cosarcR = cosarc.set_axis(["JNODE", "INODE", "Miles", "Modes", "Type", "LANES", "VDF"], axis = 1)     #create df of the reverse links
    cosarcR = cosarcR[["INODE", "JNODE", "Miles", "Modes", "Type", "LANES", "VDF"]]                       #move columns to match cosarc
    allArc = pd.concat([cosarc, cosarcR])                                                                 #bind referese links to cosarc
    allArc = allArc.round({'Miles': 2})                                                                   #round 2 decimal places

    # QA/QC
    # Verify each link has a length (allArc, miles = 0) 
    errorM = pipeDict['pMessage'][i] + " LINKS WITHOUT A CODED LENGTH"
    check = (allArc['Miles'] == "0").any()
    if(check == 'True'): 
        sys.exit(print(errorM))

    # Verify each link has a mode (allArc, mode is NA) 
    errorM = pipeDict['pMessage'][i] + " LINKS WITHOUT A CODED MODE"
    check = (allArc['Modes'].isnull()).any()
    if(check == 'True'): 
        sys.exit(print(errorM))

    # Verify each node has coordinates (antiNodes, point_x='.' Or point_y='.') 
    errorM = pipeDict['pMessage'][i] + " NODES WITH NO X COORDINATES"
    check=(antiNodes['POINT_X'].isnull()).any() 
    if(check == 'True'): 
        sys.exit(print(errorM))

    errorM = pipeDict['pMessage'][i] + " NODES WITH NO Y COORDINATES"
    check=(antiNodes['POINT_Y'].isnull()).any() 
    if(check == 'True'): 
        sys.exit(print(errorM))

    # Verify each centroid has coordinates (centroids, point_x='.' Or point_y='.' 
    errorM = pipeDict['pMessage'][i] + " CENTROIDS WITH NO X COORDINATES"
    check=(centroids['POINT_X'].isnull()).any() 
    if(check == 'True'): 
        sys.exit(print(errorM))
    
    errorM = pipeDict['pMessage'][i] + " CENTROIDS WITH NO Y COORDINATES"
    check=(centroids['POINT_Y'].isnull()).any() 
    if(check == 'True'): 
        sys.exit(print(errorM))

    # Verify each node has a unique number (antiNodes, check count node_id not>1) 
    errorM = pipeDict['pMessage'][i] + " NODES WITH DUPLICATE NUMBERS"
    check=(antiNodes["NODE_ID"].is_unique)
    if(check == 'False'): 
        sys.exit(print(errorM))

    # Verify each centroid has a unique number (centroids, check count node_id not>1) 
    errorM = pipeDict['pMessage'][i] + " CENTROIDS WITH DUPLICATE NUMBERS"
    check=((centroids["NODE_ID"]).is_unique)
    if(check == 'False'): 
        sys.exit(print(errorM))

    # Finalize columns
    # Nodes
    antiNodes['first'] = 'a'
    antiNodes = antiNodes[['first', 'NODE_ID', "POINT_X", "POINT_Y", 'MESOZONE']]

    # Centroids
    centroids['first'] = 'a*'
    centroids = centroids[['first', 'NODE_ID', "POINT_X", "POINT_Y", 'MESOZONE']]
    
    # Links
    allArc['first'] = 'a'
    allArc['ul1'] = '0'
    allArc['ul2'] = '0'
    allArc['ul3'] = '0'
    allArc = allArc[['first', "INODE", "JNODE", "Miles", "Modes", "Type", "LANES", "VDF", 'ul1', 'ul2', 'ul3']]

    # Write to output txt
    outTitle = "c " + pipeDict['pMessage'][i] + " BATCHIN FILE \n"                       #file title
    with pOutput.open('w') as f:
        f.write(outTitle)                                                                #file title
        f.write(dateStr)                                                                 #date/time
        f.write('c node   x   y   UI1 \n')                                               #node column headers
        f.write('t nodes init \n')                                                       #node init line
        f.write(centroids.to_string(header = False, index = False))                      #write centroids
        f.write("\n")
        f.write(antiNodes.to_string(header = False, index = False))                      #write nodes
        f.write('\n c i   j   mi   modes   type   lanes   vdf   ul1   ul2   ul3 \n')     #link header
        f.write('t links init \n')                                                       #link init line
        f.write(allArc.to_string(header = False, index = False))                         #write arcs

    #increase increment
    i=i+1

# ---------------------------------------------------------------
# Generate Pipeline Domestic Networks
# ---------------------------------------------------------------
arcpy.env.workspace = tempPipePath
tempfiles_pipe = ["temp_{}".format(x) for x in shapefiles_links]

arcpy.AddMessage("---> Clipping Pipeline Domestic Network")
pipe_list_get = []
for w in tempfiles_pipe:
    arcpy.analysis.Clip(w + ".shp", "temp_conus_ak.shp", "clip{}".format(w))
    pipe_list_get.append("clip{}".format(w))

arcpy.AddMessage("---> Adding new fields to pipeline")
pipefiles = []
for i in pipe_list_get:
    arcpy.management.AddField(i + ".shp", "newlen", "DOUBLE")
    arcpy.management.CalculateField(i + ".shp", 'newlen', "!shape.length!", "PYTHON")
    arcpy.management.AddField(i + ".shp","ratio","DOUBLE")
    arcpy.management.CalculateField(i + ".shp","ratio","!newlen!/!origLen!","PYTHON")
    arcpy.AddMessage("---> exporting pipeline domestic network data")
    arcpy.conversion.TableToTable(i + ".shp", tempPipePath, "export_{}.csv".format(i))
    pipefiles.append("export_{}.csv".format(i))

arcpy.AddMessage("---> preparing pipeline final files")
os.chdir(tempPipePath)

# Export final pipeline files
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
    df.to_csv(outFolder+"/DomesticPipelineNetwork.csv", index=False)
    arcpy.AddMessage("---> pipelinenetwork file saved")

# Cleanup pipeline temporary files
arcpy.AddMessage("---> Removing Temporary Pipeline Files")
toclean = [f for f in os.listdir(tempPipePath)]
for f in toclean:
    try:
        os.remove(os.path.join(tempPipePath, f))
    except RuntimeError:
        arcpy.management.Delete(os.path.join(tempPipePath, f))
    except WindowsError:
        print("WindowsError (probably access denied) for {}".format(f))
        continue

