##############################################################################################
# build_full_MFN.py                                                                          #
# kcazzato 10/21/2025                                                                        #    
#    This program builds a full MFN GDB in a user specified output folder                    #
#    from the following user specified GDB Inputs:                                           # 
#       - CMAP Highway Mesozone Network from MFHRN processing                                #
#           * Stored in CMAP_Hwy feature dataset in output GDB                               #
#           * years specified in MFHRN processing                                            #
#           * final_links_YYYY for all years                                                 #
#           * final_nodes_YYYY for all years                                                 #
#       - Remaining Freight Components from existing MFN GDB                                 #
#           * National_Hwy feature dataset:                                                  #
#               - National_Highway: line fc of national highway network links                #
#               - National_Hwy_nodes: point fc of national highway network nodes             #
#           * pipeline_cos feature dataset:                                                  #
#               - Crude_Oil_System: line fc of crude oil pipeline network links              #
#               - Crude_Oil_System_nodes: point fc of crude oil pipeline network nodes       #
#           * pipeline_natgas feature dataset:                                               #
#               - NEC_NEG_19_System: line fc of natural gas pipeline network links           #
#               - NEC_NEG_19_nodes: point fc of natural gas pipeline network nodes           #
#           * pipeline_product feature dataset:                                              #
#               - Prod_17_18__System: line fc of petroleum pipeline network links            #
#               - Crude_Oil_System_nodes: point fc of petroleum pipeline network nodes       #
#           * Waterway feature dataset                                                       #
#               - Inland_Waterways: line fc of waterway network links                        #
#               - Inland_Waterways_nodes: point fc of waterway network nodes                 #
#           * Geography feature dataset:                                                     #
#               - Meso_Logistic_Nodes: point fc of CMAP region logistics nodes               #
#               - Meso_Ext_Int_Centroids: point fc of CMAP and external mesozone centroids   #
#               - Meso_CMAP_Zones: polygon fc of CMAP region mesozones                       #
#               - Meso_External_Zones: polygon fc of external (non-CMAP) mesozones           # 
#               - Meso_External_CMAP_merge: polygon fc of all CMAP and external mesozones    #    
#               - conus_ak: polygon fc of continuious US and Alaska (one polygon)            #
#           * Rail feature dataset                                                           #
#               - CMAP_Rail: line fc of CMAP region rail network links                       #
#               - CMAP_Rail_nodes: point fc of CMAP region rail network nodes                #
#               - CMAP_Rail_Routes: line fc of CMAP region rail network routes               #
#               - National_Rail: line fc of national rail network links                      #
#               - National_Rail_nodes: point fc of national rail network nodes               #
#               - National_Rail_Routes: line fc of national rail network routes              #
#           * Tables:
#               - CMAP_Rail_Itinerary: table itinerary for CMAP region rail lines            #
#               - National_Rail_Itinerary: table itinerary for national rail lines           #
#                                                                           		         #
#                                                                           		         #
#    This program also exports TXT files flagging links using logistics nodes                #
#    140 and 143 for use as emme batchin files for the freight skimming procedures           #
#                                                                           		         #
##############################################################################################

# ---------------------------------------------------------------
# Import System Modules
# ---------------------------------------------------------------
import sys, os, arcpy,  shutil, re
from arcpy import env
from datetime import datetime
from pathlib import Path
arcpy.OverwriteOutput = 1

# ---------------------------------------------------------------
# Read Script Arguments and Set Paths
# ---------------------------------------------------------------
###
nmGDB = arcpy.GetParameterAsText(0)         # Name for output folder label, suggest c##q#
MFNGDB = arcpy.GetParameterAsText(1)        # Take from the most recent/up to date MFN GDB
HWYGDB = arcpy.GetParameterAsText(2)        # Takes from recent run of MFN update tools from MFHRN processing

dateStr = str(datetime.now()) + '\n'

hwyFd=['final_links', 'final_nodes']        # List of layers to be copied from MFHRN processing
mfnFd='CMAP_Hwy'                            # Name of CMAP highway feature class in new updated GDB
logNodes = [140, 143]                       # List of logistics nodes to create unlink files for

# Create output folder
currentDir = os.getcwd()
outputDir = "../../Output_" + nmGDB
if not os.path.exists(outputDir):
    os.makedirs(outputDir)

# ---------------------------------------------------------------
# CREATE OUTPUT LOGNODE FOLDER AND GDB FOLDER FOR UPDATED MFN
# ---------------------------------------------------------------
#- Create Folder for new GDB
new_path = outputDir + "/MFN.gdb"             # Define path with full name for new GDB: MFN_%userinput%.gdb
new_lognod = outputDir + "/LogNodes"             # Define floder path for logistics node unline file output

#- Clear lostistics node unlink output if exists
if os.path.exists(new_lognod):
    shutil.rmtree(new_lognod)
os.makedirs(new_lognod)
arcpy.AddMessage("Output lognode folder cleared")

#- Clear GDB output if exists
if os.path.exists(new_path):
    shutil.rmtree(new_path)
    arcpy.AddMessage("Output GDB folder cleared")

# ---------------------------------------------------------------
# ADD DATA TO UPDATED MFN GDB
# ---------------------------------------------------------------
#- Copy data from current MFN GDB to new MFN path
shutil.copytree(MFNGDB, new_path)  # this line creates the new_path folder and populates it
arcpy.AddMessage("---> Directory created: " + new_path)

#- Remove old CMAP freight highway links and nodes
arcpy.env.workspace = new_path      # Set workspace to updated MFN GDB
arcpy.Delete_management(mfnFd)      # Remove FC
arcpy.AddMessage("---> Feature Dataset Removed: " + mfnFd)

#- Add new CMAP freight highway links and nodes
#i=1
#for fd in hwyFd:
arcpy.env.workspace = HWYGDB            # Set workspace to highway MFN GDB
#source_fd = os.path.join(HWYGDB, fd)    # Set path to source feature dataset

# Get feature classes within the feature dataset
#fcs = arcpy.ListFeatureClasses(feature_dataset=fd)        
fcs = arcpy.ListFeatureClasses()                  
if not fcs:
    raise Exception(f"No feature classes found in dataset") #{fd}

# Get spatial reference of feature dataset
#first_fc_path = os.path.join(source_fd, fcs[0])
first_fc_path = fcs[0]
spatial_ref = arcpy.Describe(first_fc_path).spatialReference
    
#if i == 1:
# Create the feature dataset in the updated MFN GDB
arcpy.CreateFeatureDataset_management(out_dataset_path=new_path,
                                out_name=mfnFd,              # Put nodes and links in the same feature dataset
                                spatial_reference=spatial_ref)
arcpy.AddMessage("---> Feature Dataset Added: " + mfnFd)

# Extract list of years
years =  [re.findall(r'\d+', s) for s in fcs]
years = list(set([item[0] for item in years]))
arcpy.AddMessage("Scenario Years: ")
arcpy.AddMessage(years)

# Copy each feature class to the new feature dataset
for fc in fcs:
    #source_fc_path = os.path.join(source_fd, fc)
    source_fc_path = os.path.join(HWYGDB,fc)
    fc_name = fc.split('.', 1)
    fc_name=fc_name[0]
    target_fc_path = os.path.join(new_path, mfnFd)
    arcpy.conversion.FeatureClassToFeatureClass(source_fc_path, target_fc_path, fc_name)
    arcpy.AddMessage(f"---> Copied: {fc_name}") 

#i=i+1

# ---------------------------------------------------------------
# GENERATE UNLINK_LOGNODE140.TXT AND UNLINK_LOGNODE143.TXT
# ---------------------------------------------------------------
# Header info
ln1 = "c MESO FREIGHT NETWORK BATCHIN FILE \n"
ln2 = "c " + dateStr
ln5 = "t lines init \n"
railLayer = 'CMAP_Rail'

# Loop through each year and each lognode
arcpy.env.workspace = new_path 
for yr in years:
    for node in logNodes:
        # Define highway layer
        hwyLayer = mfnFd+'/CMAP_HWY_LINK_y' + yr

        # Final header info
        ln3 = "c File to remove the highway and rail connector links for logistics node " + str(node) + "\n"
        ln4 = 'c Year: ' + str(yr) + '\n\n\n'

        # Output path
        outTXT = Path(new_lognod + "/unlink_lognode"+ str(node)+ "_" + str(yr) +".txt")
        
        # Write header
        with outTXT.open('w') as f:
            f.write(ln1)              #file title
            f.write(ln2)              #date/time
            f.write(ln3)              #info
            f.write(ln4)              #info
            f.write(ln5)              #node header line

        # Find rail and highway links attached to the node          
        findNode = f"INODE = {node} OR JNODE = {node}"

        # For highway layer
        with arcpy.da.SearchCursor(hwyLayer, ['INODE', 'JNODE'], findNode) as cursor:
            for row in cursor:
                INODE, JNODE = row
                with open(outTXT, mode = 'a') as f:
                    f.write(f"d= {INODE}   {JNODE} \n")
        
        # For rail layer
        with arcpy.da.SearchCursor(railLayer, ['INODE', 'JNODE'], findNode) as cursor:
            for row in cursor:
                INODE, JNODE = row
                with open(outTXT, mode = 'a') as f:
                    f.write(f"d= {INODE}   {JNODE} \n")

arcpy.AddMessage(f"COMPLETE {new_path}") 
