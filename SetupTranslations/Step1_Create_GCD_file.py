############################################################################################
# STEP1_CREATE_GCD_FILE.py                                                                 # 
# kcazzato 09/09/2025 updates                                                              #
# ----- Translated SAS processsing                                                         #
# Craig Heither, rev. 09-24-2015                                                           #
# revised 09-28-2017: Add code to create I-E and E-E POE files for Truck trips             # 
#       to be used in truck touring model. 	                                               #
#                                                                                          #
# This program creates the file "data_mesozone_gcd.csv"                                    #
#     - Contains Great Circle Distances between all pairs of Mesozones.                    #
#                                                                                          #
# The output file replaces the RSG version in the Meso model to address these issues:      #
#	  - The file RSG delivered measures GCD in Kilometers rather than Miles.               #
#     - The new file includes logistics nodes to be used to develop the modepath costs.    #
#	  - The new file will reflect the locations of US mesozones in the MFN (except Hawaii) #
#	  - The new file includes GCD values for intrazonal pairs (US mesozones only).         #
#                                                                                          #	
# This program also creates the file "data_mesozone_centroids.csv"                         #
#     - To ensure the data used in the Meso model is consistent with the MFN data.         #                                                               
#     - verifies all appropriate modes are available between zone pairs.                   #
#     - creates files to verify that the "best" domestic port logic is reasonable          #       
#                                                                                          #
#-- Input files needed (located in ..\input_data\):                                        #
#	  - base_ntwk.txt - highway node and link transaction file                             #
#	  - poe.in - Emme batchin file containing unique POE codes                             #
#	  - skim/mf40.in - Emme skim OD matrix with POE node IDs                               #
#	  - post_processing/data_mesozone_gcd.csv - original GCD file                          #
#	  - post_processing/mesozone_latlon.csv - mesozone locations                           #
#	  - post_processing/Mesozone_sqmi.csv - mesozone square mile area                      #
#
#-- Output (../output_data/post_processing/)	                                           #
#    - data_mesozone_gcd_YYYY.csv - GCD between national OD mesozone pairs                 #
#    - data_mesozone_centroids_YYYY.csv - (X,Y) coordinates of mesozone centroids          #
#    - cmap_data_truck_IE_poe_YYYY.csv - POE node IDs used by internal-external OD pair    #
#    - cmap_data_truck_EE_poe_YYYY.csv - POE node IDs used by external-external OD pair    #
#                                                                                          #
############################################################################################

# ---------------------------------------------------------------
# Import Directories
# ---------------------------------------------------------------
import sys, os, shutil, math
import pandas as pd, numpy as np

# ---------------------------------------------------------------
# Define paths and variables
# ---------------------------------------------------------------
##-- System inputs
year = '2022'       ##-- Model run year, used to label output files
programDir = 'S:/AdminGroups/ResearchAnalysis/kcc/FY26/FreightSkims/TranslateSAS/2_dev/Meso_Freight_Skim_Setup_c25q2_2022/Database/post_processing'
##-- File directories
databaseDir = os.path.abspath(os.path.join(programDir, "../"))   ##-- Database     
inDir = os.path.join(databaseDir + '/input_data')                ##-- Database/input_data
inDir2 = os.path.join(databaseDir + '/output_data')              ##-- Database/output_data/skims
outDir = os.path.join(inDir2 + '/post_processing')               ##-- Database/output_data/post_processing

# Delete output folder if it exists
if os.path.exists(outDir):
    shutil.rmtree(outDir)
# Create output folder
os.mkdir(outDir)

##-- Inputs 
pth_rsgdist= os.path.join(inDir + "/post_processing/data_mesozone_gcd.csv" )   ##-- Original RSG file of Great Circle Distances
pth_cmap= os.path.join(inDir + "/post_processing/mesozone_latlon.csv" )        ##-- File of mesozone locations from Master Freight Network
pth_sqmi= os.path.join(inDir + "/post_processing/Mesozone_sqmi.csv" )          ##-- File of U.S. mesozone area (sq miles), does not include logistics nodes 
pth_cent= os.path.join(inDir + "/base_ntwk.txt" )                              ##-- Emme network batchin file including POE coordinates
pth_poe= os.path.join(inDir + "/poe.in" )                                      ##-- Emme batchin file containing unique POE codes 
pth_mf40= os.path.join(inDir2 + "/skim/mf40.in" )                              ##-- Emme skim file containing POEs used 

##-- Outputs
outMesoGCD= os.path.join(outDir + "/data_mesozone_gcd_" + year + ".csv")                 ##-- Outpath for mesozone GCD file
outMesoCentroids= os.path.join(outDir + "/data_mesozone_centroids_" + year + ".csv")     ##-- Outpath for mesozone centroid file
outTruckIE= os.path.join(outDir + "/cmap_data_truck_IE_poe_" + year + ".csv")            ##-- Outpath for truck internal-external trips POE used
outTruckEE= os.path.join(outDir + "/cmap_data_truck_EE_poe_" + year + ".csv")            ##-- Outpath for truck internal-external trips POE used

##-- Variables
maxMeso=273          ##-- Maximum U.S. mesozone number   *KC added to yaml so parse that logic
maxNatMeso = 491     ##-- Maximum National mesozone number*KC added to yaml so parse that logic
maxCMAPMeso = 150    ##-- Maximum CMAP mesozone number*KC added to yaml so parse that logic

# ---------------------------------------------------------------
# Import data
# ---------------------------------------------------------------
in_rsgdist=pd.read_csv(pth_rsgdist)                                                          ##-- Original RSG file of Great Circle Distances
in_cmap=pd.read_csv(pth_cmap)                                                                ##-- File of mesozone locations from Master Freight Network
in_sqmi=pd.read_csv(pth_sqmi)                                                                ##-- File of U.S. mesozone area (sq miles), does not include logistics nodes 
in_cent = pd.read_csv(pth_cent, sep = '/n', skiprows = 5, header=None, engine='python')      ##-- Emme network batchin file including POE coordinates
in_poe = pd.read_csv(pth_poe, sep = '\s+', skiprows = 5, header=None, engine='python')       ##-- Emme batchin file containing unique POE codes 
in_mf40 = pd.read_csv(pth_mf40, sep = '\s+', skiprows = 4, header=None, engine='python')     ##-- Emme skim file containing POEs used 

# ----------------------------------------------------------------------------
#  Create a template of all mesozonal interchanges
# ----------------------------------------------------------------------------
## -- Create matrix origins and destinations -- ##
maxZone = maxNatMeso		
mtxdest = np.arange(1,maxZone+1)								## -- array of consecutive numbers representing matrix destinations
dest = np.tile(mtxdest,maxZone)									## -- array of repeating destination zone pattern
orig = np.repeat(mtxdest,maxZone)								## -- repeated in ascending order for origins
origdf = pd.DataFrame(orig, columns = ['Production_zone'])
origdf.insert(loc=0, column='A',value=np.arange(len(origdf)))
destdf = pd.DataFrame(dest, columns = ['Consumption_zone'])
destdf.insert(loc=0, column='A',value=np.arange(len(destdf)))
tmplt = origdf.merge(destdf, how='left', on='A', copy=False)

# ---------------------------------------------------------------
# Calculate production-consumption mesozone GCD
# ---------------------------------------------------------------
##-- Format RSC GCD file
meso = in_rsgdist.copy()                                               ##-- Assign name to df
meso = meso[['Production_zone', 'Production_lon', 'Production_lat']]   ##-- Select columns

##-- Format CMAP mesozone locations
cmapmeso = in_cmap.copy()
cmapmeso['Production_lon'] = (cmapmeso['Production_lon']*np.pi)/180
cmapmeso['Production_lat'] = (cmapmeso['Production_lat']*np.pi)/180

##-- Antijoin cmap mesozone GCD data from rsg's mesozone GCD data
outer = meso.merge(cmapmeso, how='outer', indicator=True, on = ['Production_zone'])
anti_join = outer[(outer._merge=='left_only')].drop('_merge', axis=1)
anti_join=anti_join[['Production_zone', 'Production_lon_x', 'Production_lat_x']]
anti_join.columns=['Production_zone', 'Production_lon', 'Production_lat']

##-- Combine CMAP and RSG mesozone GCD data, no duplicate data
allMeso = pd.concat([cmapmeso, anti_join])         ##-- Combine all cmap data and anything in rsg's data not in cmap's data
allProduction = allMeso.copy()                     ##-- Create named copy of all mesozone GCD data for production columns
allConsumption = allMeso.copy()                    ##-- Create named copy of all mesozone GCD data for consumption columns
allConsumption.columns = ['Consumption_zone', 'Consumption_lon', 'Consumption_lat']       ##-- Rename columns for consumption df
allProduction=allProduction.drop_duplicates()      ##-- Drop duplicates in production df
allConsumption=allConsumption.drop_duplicates()    ##-- Drop duplicates in consumption df

##-- Merge mesozone coordinates with cmap mesozone coordinates
allPC = pd.merge(tmplt, allProduction,how='left', on = 'Production_zone')      ##-- Merge Production coords with template
allPC=allPC.drop_duplicates()                                                  ##-- Drop duplicates if any
allPC2 = pd.merge(allPC, allConsumption,how='left', on = 'Consumption_zone')   ##-- Merge Consumption coords with production coords
allPC2=allPC2.astype({'Production_zone':int, 'Consumption_zone': int, 'Production_lon': float, 'Production_lat': float, 'Consumption_lon': float, 'Consumption_lat': float})   ##-- Set data types

##-- Calculate Great Circle Distance using Haversine formula
##-- see http://www.movable-type.co.uk/scripts/latlong.html for discussion/documentation
##-- or http://andrew.hedges.name/experiments/haversine/ 
allPC2['delta_lon'] = allPC2['Consumption_lon']-allPC2['Production_lon']       
allPC2['delta_lat'] = allPC2['Consumption_lat']-allPC2['Production_lat']       
allPC2['a'] = ((np.sin(allPC2['delta_lat']/2))**2) + np.cos(allPC2['Production_lat'])*np.cos(allPC2['Consumption_lat'])*(np.sin(allPC2['delta_lon']/2)**2)  
allPC2['b']=np.sqrt(allPC2['a'])
allPC2['bChoice'] = np.where(allPC2['b'] > 1, 1,allPC2['b'] )
allPC2['c1'] = 2*(np.arcsin(allPC2['bChoice']))
allPC2['GCD']=allPC2['c1']*3961                                         ##-- 3961 is radius of Earth in miles, about 39 degrees from equator (Washington DC)
allPC2 = allPC2[['Production_zone', 'Consumption_zone', 'Production_lon', 'Production_lat', 'Consumption_lon', 'Consumption_lat', 'GCD']] 

##-- QC ensure both directions are included in output
qcPC = allPC2.copy()                                                   ##-- Create copy df of final production-consumption OD GCD data
qcPC = qcPC.loc[qcPC['Production_zone'] != qcPC['Consumption_zone']]   ##-- Filter for pairs where production zone != consumption zone
qcPC=qcPC[['Production_zone', 'Consumption_zone']]                     ##-- Select columns to represent OD pairs
qcPCr = qcPC.copy()                                                    ##-- Create copy of OD pairs df
qcPCr.columns = ['Consumption_zone', 'Production_zone']                ##-- Rename/flip column names to reverse OD pair
qcPC2 = pd.concat([qcPC, qcPCr])                                       ##-- Concat forward and reverse dfs
qcPC2=qcPC2.groupby(['Consumption_zone','Production_zone']).size()     ##-- Group by consumption-production pair and count total number of rows that OD pair occurs in
qcPC2=qcPC2.to_frame().reset_index()                                   ##-- Make list into a df
qcPC2.columns=['Consumption_zone', 'Production_zone', 'CountR']        ##-- Name df columns
qcPC2=qcPC2.loc[qcPC2['CountR'] != 2]                                  ##-- Filter where instances of OD pair !=2 (if ==2, then forward and reverse both exist in allPC2 df)
if qcPC2.shape[0] > 0:                                                 ##-- Stop code if instances occur where reverse does not exist
    print('Mesozone pairs do not have reverse GCD values')
    print(qcPC2)
    sys.stop()
else:
    print('all mesozone pairs have reverse GCD values')

# ---------------------------------------------------------------
# Calculate Distance for Intrazonal Pairs (US Mesozones Only)
# ---------------------------------------------------------------
##-- Format sqmi dataset
sqmi = in_sqmi.copy()                                                               ##-- Create copy of input data named sqmi
sqmi = sqmi.astype({'mesozone': int, 'sqmi': float})                                ##-- Set data column types
sqmi['dist'] = np.sqrt(sqmi['sqmi'])/2                                              ##-- Calculate distance; Assume each mesozone is a square; the average trip distance = diagonal of the square
sqmi['Production_zone']=sqmi['mesozone']                                            ##-- Create new column called 'Production_zone' from mesozone ID
sqmi['Consumption_zone']=sqmi['mesozone']                                           ##-- Create new column called 'Consumption_zone' from mesozone ID
sqmi = sqmi[['Production_zone', 'Consumption_zone', 'sqmi', 'dist']]                ##-- Select columns

##-- Combine distances with production-consumption coordinate dataset
intraPC = allPC2.loc[allPC2['Production_zone'] == allPC2['Consumption_zone']]       ##-- Select rows where Production_zone == Consumption_zone
intraPC=intraPC[['Production_zone', 'Consumption_zone', 'Production_lon', 'Production_lat', 'Consumption_lon', 'Consumption_lat']]           ##-- Select columns for intrazonal production-consumption df  
intraPC=pd.merge(intraPC, sqmi, on=['Production_zone', 'Consumption_zone'])         ##-- Merge intrazonal production-consumption df with sqmi distances df
intraPC=intraPC[['Production_zone', 'Consumption_zone', 'Production_lon', 'Production_lat', 'Consumption_lon', 'Consumption_lat', 'dist']]   ##-- Select final columns

# ---------------------------------------------------------------
# Combine all mesozone GCD data and export
# ---------------------------------------------------------------
##-- Merge all production-consumption data with developed intrazonal distances
finalPC = pd.merge(allPC2, intraPC,how='left', on = ['Production_zone', 'Consumption_zone', 'Production_lon', 'Production_lat', 'Consumption_lon', 'Consumption_lat'])

##-- Final formatting for export
finalPC['dist']= np.where(finalPC['dist'].isnull(), finalPC['GCD'], finalPC['dist'])           ##-- If dist is na (all interzonal pairs), set dist=GCD
finalPC['GCD']= np.where(finalPC['GCD']>finalPC['dist'], finalPC['GCD'], finalPC['dist'])      ##-- Keep the higher value between GCD and dist
finalPC=finalPC.sort_values(['Consumption_zone', 'Production_zone'])                           ##-- Sort columns for export
finalPC=finalPC[['Production_zone',	'Production_lon',	'Production_lat',	'Consumption_zone',	'Consumption_lon',	'Consumption_lat',	'GCD']]   ##-- Select final columns
finalPC=finalPC.drop_duplicates()                                                              ##-- Drop duplicates
finalPC=finalPC.loc[finalPC['Production_zone'] != 182]
finalPC=finalPC.loc[finalPC['Consumption_zone'] != 182]                                        ##-- original Entire CMAP mesozone does not exist in meso model;
finalPC=finalPC.dropna()
finalPC.to_csv(outMesoGCD, index=False)                                                        ##-- Export as csv, outSkims

# ---------------------------------------------------------------
# Create new CMAP mesozone centroid coordinate file
# ---------------------------------------------------------------
##-- Format Centroid coordinates
in_cent = in_cent.reset_index()     ##-- Reset index             
in_cent.columns=['index','data']    ##-- Name columns

flagRow=in_cent.copy()                                             ##-- Create copy df of input centroid df
flagRow= flagRow.loc[flagRow['data'].str.contains('vdf   ul1')]    ##-- Find row index where the links begin
rowI = int(flagRow['index'].iloc[0])                               ##-- Convert row index to integer value

centroids = in_cent.copy()                                         ##-- Create copy df of input centroid df
centroids = centroids.loc[centroids['index'] < rowI]               ##-- Filter row index < the row index where the links begin

centroids['result'] = centroids['data'].str.replace('a', '')       ##-- Replace 'a' in line with ''
centroids['result2'] = centroids['result'].str.replace('*', '')    ##-- Replace 'a*' in line with ''

centroids[['skip1', 'node', 'xcoord', 'ycoord', 'skip']] = centroids['result2'].str.split('\s+', expand = True)  ##-- Create new columns deliminated by spaces
centroids=centroids[['node', 'xcoord', 'ycoord']]                                                                ##-- Select final centroid coordinate columns
centroids=centroids.astype({'node':int, 'xcoord': float, 'ycoord': float})                                       ##-- Format data types
centroids['xcoord']=(centroids['xcoord']/5280).round(3)       ##-- Convert xcoord from State Plane feet to miles
centroids['ycoord']=(centroids['ycoord']/5280).round(3)       ##-- Convert ycoord from State Plane feet to miles

##-- Format only CMAP mesozones
mesoCoords=centroids.loc[centroids['node']<=maxMeso]              ##-- Filter out non-centroid nodes and Mexico and Canada (310 and 399)
mesoCoords.rename(columns={'node': 'stop_zone', 'xcoord':'x_coord', 'ycoord':'y_coord'}, inplace=True)   ##-- Rename 'node' column to 'stop_zone'
mesoCoords=mesoCoords[['stop_zone', 'x_coord', 'y_coord']]         ##-- Select final columns
mesoCoords=mesoCoords.sort_values(['stop_zone'])                 ##-- Sort final data by stop_zone
mesoCoords=mesoCoords.drop_duplicates()                          ##-- Remove duplicates
mesoCoords.to_csv(outMesoCentroids, index=False)                 ##-- Export mesozone centroid coordinates

# ---------------------------------------------------------------
# Format data for POE files
# ---------------------------------------------------------------
##-- Format POE node ID's
in_poe.columns = ['node', 'poeCode', 'type']                    ##-- Rename columns
poes=in_poe.astype({'node':int, 'poeCode': int, 'type': str})   ##-- Format data types
trkpoe=poes.loc[poes['type'] == 'T']                            ##-- Keep only truck modes
trkpoe=trkpoe[['node', 'poeCode']]                              ##-- Rename columns

##-- Create df of all possible POE combinations and summed code value
numPOE =trkpoe.shape[0]
i=1
while i <= numPOE:
    if i == 1:
        lstAllPOE = trkpoe.copy()
    else:
        lstAllPOE = pd.concat([lstAllPOE, trkpoe])
    i=i+1

lstAllPOE.sort_values('node')
lstAllPOEO=lstAllPOE.copy()
lstAllPOEO=lstAllPOEO.sort_values(['node'])
lstAllPOEO.rename(columns={'node': 'poe2', 'poeCode':'poeCode2'}, inplace=True)   ##-- Rename 'node' column to 'stop_zone'
lstAllPOEO=lstAllPOEO.reset_index()

lstAllPOE=lstAllPOE.reset_index()
lstAllPOE.rename(columns={'node': 'poe', 'poeCode':'poeCode1'}, inplace=True)   ##-- Rename 'node' column to 'stop_zone'
allPOEPair=pd.concat([lstAllPOEO, lstAllPOE], axis=1)
allPOEPair['poeCode'] = allPOEPair['poeCode1']+ allPOEPair['poeCode2']
allPOEPair=allPOEPair[['poe', 'poe2', 'poeCode']]
allPOEPair=allPOEPair.loc[allPOEPair['poe'] !=allPOEPair['poe2']]
test=allPOEPair.groupby('poeCode')
test2=test.first()
allPOEPair=pd.merge(test2, allPOEPair, how='left', on=['poe','poe2'])

##-- POE ID matrix (mf40)
mat40 = in_mf40.copy()                                                         ##-- Assign df name
mat40.columns=['origin', 'dest1', 'val1', 'dest2', 'val2', 'dest3', 'val3']    ##-- Rename columns
mat40['dest1'] = mat40['dest1'].str.replace(':', '')                           ##-- Replace 'a' in line with ''
mat40['dest2'] = mat40['dest2'].str.replace(':', '')                           ##-- Replace 'a' in line with ''
mat40['dest3'] = mat40['dest3'].str.replace(':', '')                           ##-- Replace 'a' in line with ''

##-- Create temporary df for each set of OD-Value column pairs
tmp1=mat40[['origin', 'dest1','val1']]
tmp1.columns=['origin', 'dest', 'value']
tmp2=mat40[['origin', 'dest2','val2']]
tmp2.columns=['origin', 'dest', 'value']
tmp3=mat40[['origin', 'dest3','val3']]
tmp3.columns=['origin', 'dest', 'value']
p_mat40 = pd.concat([tmp1, tmp2, tmp3])                                ##-- Row bind temporary dfs for final df: origin, destination, value

p_mat40=p_mat40.dropna()                                               ##-- Remove NAs
p_mat40=p_mat40.astype({'origin':int, 'dest': int, 'value': float})    ##-- Format data types
p_mat40.columns=['origin', 'destination', 'poeCode']                   ##-- Rename columns
allPOEPair.columns=['poe2', 'poe', 'poeCode']

# ---------------------------------------------------------------
# Create IE POE file for truck touring model
# ---------------------------------------------------------------
ie40 = pd.merge(p_mat40, trkpoe, how='inner', on='poeCode')
ie40.rename(columns={'origin': 'Production_zone', 'destination':'Consumption_zone', 'node':'poe'}, inplace=True)   ##-- Rename 'node' column to 'stop_zone'
ie40=ie40[['Production_zone', 'Consumption_zone', 'poe']]
ie40=ie40.sort_values(['poe', 'Production_zone', 'Consumption_zone'])
ie40=ie40.drop_duplicates() 
ie40.to_csv(outTruckIE, index=False)

# ---------------------------------------------------------------
# Create EE (passthrough) POE file for truck touring model
# ---------------------------------------------------------------
##-- Combine mf40 poe codes with paired poe node df
ee40 = pd.merge(p_mat40, allPOEPair, how='inner', on='poeCode')
ee40.rename(columns={'origin': 'Production_zone', 'destination':'Consumption_zone'}, inplace=True)   ##-- Rename 'node' column to 'stop_zone'

##-- Grab coordinates for POE
poeCoords=pd.merge(trkpoe, centroids, how='inner', on='node')   ##-- Merge POE node Ids and node coordinates
poeCoords.columns=['poeNode', 'poeCode', 'poe_x', 'poe_y']    ##-- Rename columns

##-- Add POE coordinates to poe ID's
ee40xy = pd.merge(ee40, centroids, how='left', left_on='Production_zone', right_on='node')   ##-- Merge ee40 production-consumption paires with mesozone centroid coordinates
ee40xy=ee40xy[['Production_zone', 'Consumption_zone', 'poe', 'poe2', 'xcoord', 'ycoord']]
ee40xy1 = pd.merge(ee40xy, poeCoords, how='left', right_on='poeNode',left_on='poe')                ##-- Merge ee40 production-consumption poe id with node coordinates

poeCoords2=poeCoords.copy()                                                                        ##-- Create copy of poe coordinate df
poeCoords2.columns=['poeNode2', 'poeCode', 'poe_x2', 'poe_y2']                                      ##-- Rename columns
ee40xy2 = pd.merge(ee40xy1, poeCoords2, how='left', right_on='poeNode2',left_on='poe2')             ##-- Merge ee40 production-consumption poe id with node coordinates

##-- Use mesozone coordinates to determine order of POE's for passthrough (in-out CMAP region)
ee40xy2['dist1']=np.sqrt(((ee40xy2['xcoord']-ee40xy2['poe_x'])**2) + ((ee40xy2['ycoord']-ee40xy2['poe_y'])**2))
ee40xy2['dist2']=np.sqrt(((ee40xy2['xcoord']-ee40xy2['poe_x2'])**2) + ((ee40xy2['ycoord']-ee40xy2['poe_y2'])**2))
ee40xy2['poe1f']= np.where(ee40xy2['dist1'] < ee40xy2['dist2'], ee40xy2['poe'],ee40xy2['poe2'] )
ee40xy2['poe2f']= np.where(ee40xy2['dist1'] > ee40xy2['dist2'], ee40xy2['poe'],ee40xy2['poe2'] )
ee40xy2=ee40xy2[['Production_zone', 'Consumption_zone','poe2f', 'poe1f']]
ee40xy2.columns=['Production_zone', 'Consumption_zone', 'poe2', 'poe']
ee40xy2=ee40xy2.sort_values(['Production_zone', 'Consumption_zone'])

##-- Confirm all unique poe's are used
checkEE=ee40xy2.copy()
checkEE['check0']=checkEE['poe']-checkEE['poe2']
checkEE=checkEE.loc[checkEE['check0'] == 0]
if checkEE.shape[0] > 0:                                                 ##-- Stop code if instances occur where reverse does not exist
    print('EE POEs entering and exiting the same node')
    print(checkEE)
    sys.stop()
else:
    print('all EE POE trips enter and exit from distinct nodes')

##-- Export EE data
ee40xy2=ee40xy2.drop_duplicates() 
ee40xy2.to_csv(outTruckEE, index=False)
