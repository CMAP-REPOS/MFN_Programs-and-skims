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
#         - lines.in    (rail headers and itineraries)         		            #
#                                                                           	#
#################################################################################

# ---------------------------------------------------------------
# Import System Modules
# ---------------------------------------------------------------
import sys, string, os, arcpy, subprocess, time, platform, fileinput, csv, shutil
import pandas as pd
import geopandas as gpd
import numpy as np
from arcpy import env
from datetime import datetime
from pathlib import Path
arcpy.OverwriteOutput = 1

# ---------------------------------------------------------------
# Read Script Arguments and Set Paths
# ---------------------------------------------------------------
#for testing
inConf = "c25q2"
programDir = "S:/AdminGroups/ResearchAnalysis/kcc/FY26/MFN/Translate_SAS/1_create_emme_batchin/Scripts/2_ArcGIS_Processing"
mainDir = os.path.abspath(os.path.join(programDir, "../../"))

###
#inConf = str(sys.argv[1])
dateStr = str(datetime.now()) + '\n'
#programDir = os.path.dirname(__file__)
#mainDir = os.path.abspath(os.path.join(__file__, "../../../"))
gdbDir = os.path.join(mainDir + "/Output/MFN_updated_" + inConf + ".gdb")
outFolder = os.path.join(mainDir + "/Output/BatchinFiles")
tempPath = os.path.join(outFolder + "/Temp")
pOutLines = Path(outFolder + "/lines.in")

# Delete and recreate temporary folder
if os.path.exists(tempPath):
    shutil.rmtree(tempPath)
os.mkdir(tempPath)
arcpy.AddMessage("---> Directory created: " + tempPath)

# Paths for non-scenario specific layers
pRailRouteCMAP = tempPath + "/temp_CMAP_Rail_Routes.dbf"
pRailRouteNat = tempPath + "/temp_National_Rail_Routes.dbf"
pItinCMAP = tempPath + "/temp_railitin1.dbf"
pItinNat = tempPath + "/temp_railitin2.dbf"

# ---------------------------------------------------------------
# Prepare Data for File Generation
# ---------------------------------------------------------------
# Make temporary folder within Output/BatchinFiles to store temporary copies of the shapefiles
arcpy.env.workspace = gdbDir

# Define Lists, Dictionaries, and Paths
rail_itineraries = [gdbDir + "\\CMAP_Rail_Itinerary", gdbDir + "\\National_Rail_Itinerary"]
# Create temporary copies
for y in ["CMAP_Rail_Routes", "National_Rail_Routes"]:
    arcpy.management.SelectLayerByAttribute(y, "CLEAR_SELECTION")
    arcpy.management.AddField(y, "origLen", "DOUBLE")
    arcpy.management.CalculateField(y, 'origLen', "!shape.length!", "PYTHON")
    arcpy.conversion.ExportFeatures(y, tempPath + "\\temp_{}.shp".format(y))

arcpy.AddMessage("   * Obtaining Rail Itinerary Data...")
temp_itin_dbfs = [tempPath + "\\temp_railitin1.dbf", tempPath + "\\temp_railitin2.dbf"]
arcpy.analysis.TableSelect(rail_itineraries[0], temp_itin_dbfs[0], "\"OBJECTID\" >= 1")
arcpy.analysis.TableSelect(rail_itineraries[1], temp_itin_dbfs[1], "\"OBJECTID\" >= 1") 

# Read temporary data
inRailRouteCMAP = gpd.read_file(pRailRouteCMAP)
inRailRouteNat = gpd.read_file(pRailRouteNat)
inItinCMAP = gpd.read_file(pItinCMAP)
inItinNat = gpd.read_file(pItinNat)

# Select columns of interest only
railroute1 = inRailRouteCMAP[['DESC_', 'REV_DESC', 'START_NODE', 'END_NODE', 'Mode', 'VEHICLE', 'TOT_DIST', 'TOT_T_TIME', 'Speed', 'Headway']]
railroute2 = inRailRouteNat[['DESC_', 'REV_DESC', 'START_NODE', 'END_NODE', 'Mode', 'VEHICLE', 'TOT_DIST', 'TOT_T_TIME', 'Speed', 'Headway']  ]

railitin1 = inItinCMAP[['DESC_', "SEG_ORDER", 'INODE', 'JNODE', 'Mode', 'T_TIME', 'DIST']]
railitin2 = inItinNat[['DESC_', "SEG_ORDER", 'INODE', 'JNODE', 'MODE', 'T_TIME', 'DIST']]
railitin2 = railitin2.set_axis(['DESC_', "SEG_ORDER", 'INODE', 'JNODE', 'Mode', 'T_TIME', 'DIST'], axis = 1)         #Make Mode not capitalized

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

# ---------------------------------------------------------------
# QA/QC Rail Itinerary Data and Export
# ---------------------------------------------------------------
# Report Routes Without an Itinerary
checkDF = itins.merge(routes, how='outer', indicator=True, on = "DESC_")      #combine itineraries and routes 
print("merged checkDF")
checkDF = checkDF[(checkDF._merge!='both')].drop('_merge', axis=1)      #keep rows in routes only
checkDF = checkDF.sort_values(by=['DESC_'])                                   #sort by DESC_                       

errorM = "RAIL ROUTES WITHOUT ITINERARIES"
check=checkDF.shape[0]
if(check != 0): 
    sys.exit(print(errorM + "\n" + checkDF))

# Report Itinerary Gaps
checkDF = itins.sort_values(by=['DESC_', 'SEG_ORDER'])
checkDF['lagJ'] = checkDF['JNODE'].shift(1)
checkDF['lagLN'] = checkDF['DESC_'].shift(1)

for index, row in checkDF.iterrows():
    if (row['DESC_'] == row['lagLN']) & (row['INODE'] != row['lagJ']):
        errorM = 'GAP IN ITINERARY:' + row['lagJ'] + " IS JNODE OF PREVIOUS SEGMENT"
        sys.exit(print(errorM + "\n" + row))

# ---------------------------------------------------------------
# Combine Route and Itinerary Data for Export
# ---------------------------------------------------------------
# Merge itineraries and routes
combineData = itins.merge(routes, how = "inner", on = ["DESC_", 'Mode'])
combineData.sort_values(by=['SEG_ORDER'])

# If row is the last segment in a line, set layover = 3, otherwise layover = 0
combineData['maxSEG'] = combineData.groupby('DESC_')['SEG_ORDER'].transform('max')
combineData['layover'] = 0

combineData.loc[combineData['maxSEG'] == combineData['SEG_ORDER'], 'layover'] = 3
combineData.sort_values(by=['layover'], ascending=False)

# Create trav_time by rounding t_time to 0.01 decimal places and formatting 
combineData['T_TIME'] = combineData['T_TIME'].round(decimals=2)
combineData['trav_time'] = combineData['T_TIME'].map(lambda x: f"{x:<5}")
combineData['name'] = "'" + combineData['DESC_'].str.strip() + "'"

# Force Speed to string with 0 decimal places
combineData['Speed'] = combineData['Speed'].map('{:.0f}'.format)

# ---------------------------------------------------------------
# Export Route and Itinerary Batchin File
# ---------------------------------------------------------------
# Header info
ln1 = "c MESO FREIGHT RAIL ITINERARY BATCHIN FILE \n"
ln2 = "c" + dateStr
ln3 = "c us1 holds segment travel time, us2 holds zone fare \n"
ln4 = "t lines init \n"

# Write header
with pOutLines.open('w') as f:
    f.write(ln1)                                                                #file title
    f.write(ln2)                                                                 #date/time
    f.write(ln3)                                               #node column headers
    f.write(ln4)                                                       #node init line

# Find last segment of the line
combineData['maxSEG'] = combineData.groupby('DESC_')['SEG_ORDER'].transform('max')

for index, row in combineData.iterrows():
    print(index)
    firstDESC = "a " + row['name'] + "   " + row['Mode'] + "   " + str(row['VEHICLE']) + "   " + str(row['Headway']) + "   " + str(row['Speed']) + "   " + row['DESC_'] + "  \n"
    pathln = "  path=no \n"
    yesLayover = "    dwt=0.01" + "   " + str(row['INODE']) + "   ttf=10   us1=" + str(row['trav_time']) + "  us2=0" + "\n               " + str(row['JNODE'] )+ "   lay="  + str(row['layover']) + "\n"
    noLayover = "    dwt=0.01" + "   " + str(row['INODE']) + "   ttf=10   us1=" + str(row['trav_time']) + "  us2=0" + "\n" 
    if (row['SEG_ORDER'] == 1):
        with open(pOutLines, mode = 'a') as f:
            f.write(firstDESC)
            f.write(pathln)
            if(row['layover'] == 3):
               f.write(yesLayover)
            else:
                f.write(noLayover)
    elif (row['maxSEG'] == row['SEG_ORDER']):
        with open(pOutLines, mode = 'a') as f:
            f.write(yesLayover)
    else:
        with open(pOutLines, mode = 'a') as f:
            f.write(noLayover)

# ---------------------------------------------------------------
# Cleanup final non-scenario specific temporary files
# ---------------------------------------------------------------
#fix this to work with new file structure
arcpy.AddMessage("---> Removing Temporary Files")
toclean = [f for f in os.listdir(tempPath)]
for f in toclean:
    try:
        os.remove(os.path.join(tempPath, f))
    except RuntimeError:
        arcpy.management.Delete(os.path.join(tempPath, f))
    except WindowsError:
        print("WindowsError (probably access denied) for {}".format(f))
        continue
