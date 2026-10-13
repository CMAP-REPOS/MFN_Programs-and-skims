
## TO ADD CONTEXT ##
# ---------------------------------------------------------------
# Import Directories
# ---------------------------------------------------------------
import sys, os, shutil, math, yaml, io, random
import pandas as pd, numpy as np

# ---------------------------------------------------------------
# DEFINE PATHS AND CONSTANTS
# ---------------------------------------------------------------
##-- System inputs
year=sys.argv[1]     ##-- Skim yearv
scenario = sys.argv[2]

##-- File directories
databaseDir = os.getcwd()       ##-- Database     
inDir = os.path.join(databaseDir + '/input_data/post_processing')    ##-- Database/input_data/post_processing
outDir = os.path.join(databaseDir + '/output_data/post_processing' + "_" + scenario)        ##-- Database/output_data/post_processing
outTempDir = os.path.join(outDir + '/tempOut/')

##-- Inputs 
pth_frair= os.path.join(inDir + "/domestic_airports.csv")      ##-- Top 30 US airports for foreign trade (based on FAF4 2013 tonnage [imports+exports]) 
pth_nodeznmeso= os.path.join(databaseDir + "/input_data/constants/node_zone_meso.yaml")   ##-- Zone and node ranges by mode and region (CMAP, logistics, non-CMAP)
pth_charges= os.path.join(databaseDir + "/input_data/constants/charges.yaml")             ##-- Handling charges, linehaul charges, and surcharges constants
pth_sptime= os.path.join(databaseDir + "/input_data/constants/speeds_and_time.yaml")      ##-- Speeds (MPH), handling time (hours), and dwell time at interchanges (hours) as constants
pth_gcd= os.path.join(outDir + "/data_mesozone_gcd_" + year + ".csv")              ##-- GCD file created during STEP1
pth_skims = os.path.join(outTempDir + '/all_O-L-D_' + year + ".csv")

##-- Outputs
outAdjSkims= os.path.join(outTempDir + "/skims_adjAir_" + year + ".csv")        ##-- New output file of modepath skim costs and times 
outRailGCD= os.path.join(outTempDir + "/railGCD_" + year + ".csv")        ##-- New output file of modepath skim costs and times 

##-- Variables
ExtDrayDom=50      ##-- Assume fixed drayage at each U.S. zone outside CMAP 
ExtDrayFor=100     ##-- Assume fixed drayage at each foreign destination country 
seed=998          ##-- Seed value for random function to choose best port 

##-- Set Seed
random.seed(seed) 

# ---------------------------------------------------------------
# IMPORT DATA
# ---------------------------------------------------------------
in_frair= pd.read_csv(pth_frair)	   ##-- Top 30 US airports for foreign trade (based on FAF4 2013 tonnage [imports+exports]) 
in_gcd= pd.read_csv(pth_gcd)     ##-- Top 30 US ports for international shipping (based on 2013 tonnage, including total foreign tonnage [imports+exports])
in_skims = pd.read_csv(pth_skims)

with open(pth_nodeznmeso, 'r') as file:         ##-- Zone and node ranges by mode and region (CMAP, logistics, non-CMAP)
    in_nodeznmeso = yaml.safe_load(file)
with open(pth_charges, 'r') as file:            ##-- Handling charges, linehaul charges, and surcharges constants
    in_charges = yaml.safe_load(file)
with open(pth_sptime, 'r') as file:             ##-- Speeds (MPH), handling time (hours), and dwell time at interchanges (hours) as constants
    in_sptime = yaml.safe_load(file)

# ---------------------------------------------------------------
# CREATE AIRSKIM TEMPLATE
# ---------------------------------------------------------------
##-- Create template for CMAP zones to every non-CMAP zone 
#- CMAP origins
cmapo=in_gcd.loc[in_gcd['Production_zone'] <= in_nodeznmeso['LIZ']].copy().reset_index()     ##-- Filter to keep all production zones <= last internal zone
cmapo=cmapo[['Production_zone']]                                                             ##-- Select only Production_zone column
cmapo.columns=['origin']                                                                     ##-- Rename Production_zone 'origin'
cmapo=cmapo.drop_duplicates()                                                                ##-- Drop duplicates

#- Non-CMAP destinations
noncmapd=in_gcd.loc[in_gcd['Production_zone'] >= in_nodeznmeso['FEZ']].copy().reset_index()  ##-- Filter to keep only Production_zones >= first external zone
noncmapd=noncmapd[['Production_zone']]                                                       ##-- Select only Production_zone column
noncmapd.columns=['destination']                                                             ##-- Rename Production_zone 'destination'
noncmapd=noncmapd.drop_duplicates()                                                          ##-- Drop duplicates

#- Combine df for template
cmapo['A'] = 1
noncmapd['A'] = 1
cmaptmplt = cmapo.merge(noncmapd, how='left', on='A', copy=False)
cmaptmplt=cmaptmplt.drop('A', axis=1)

##-- Create template for Non-CMAP US Zones to every Non-CMAP Zone 
#- CMAP origins
noncmapo=in_gcd.loc[in_gcd['Production_zone'] >= in_nodeznmeso['FEZ']].copy().reset_index()
noncmapo=noncmapo[['Production_zone']]
noncmapo.columns=['origin']
noncmapo=noncmapo.drop_duplicates()

#- Combine df for template
noncmapo['A'] = 1
ncmaptmplt = noncmapo.merge(noncmapd, how='left', on='A', copy=False)      ##-- Use Non-CMAP destinations from Group 1
ncmaptmplt=ncmaptmplt.drop('A', axis=1)

# -------------------------------------------------------------------
# FORMAT AIR SKIMS DFS FOR ALL ZONE PAIRS
# -------------------------------------------------------------------
##-- Purpose: develop template to merge data with GCD data so that Airport linehaul reflects GCD
##-- Isolate GCD for OD pairs with air travel -------------------------------------------------------------------
temp=in_gcd.loc[((in_gcd['Production_zone'] >= in_nodeznmeso['FAT']) & (in_gcd['Production_zone'] <= in_nodeznmeso['LAT']) & (in_gcd['Consumption_zone'] >= in_nodeznmeso['FEZ']) )].copy()
i=in_nodeznmeso['FAT']
airNames=['Consumption_zone']
while i <= in_nodeznmeso['LAT']:
        nstr='LineHaul'+str(i)
        airNames.append(nstr)
        i=i+1
airdist=temp.pivot(index='Consumption_zone', columns='Production_zone', values='GCD').reset_index()
airdist.columns=airNames

## Create Group 1: CMAP zones to every non-CMAP zone -------------------------------------------------------------------
##-- 1. Get internal drayage from CMAP origin to each airport
temp1=in_skims.loc[(in_skims['origin'] <= in_nodeznmeso['LIZ']) & (in_skims['destination'] >= in_nodeznmeso['FEZ'])].copy()
temp1=temp1[['origin', 'IntDray141', 'IntDray142', 'IntDray143', 'IntDray144']].copy()
temp1=temp1.drop_duplicates()
temp1=pd.merge(cmaptmplt, temp1, how='outer', on='origin')

##-- 2. Linehaul form each airport to destination zone form GCD file
temp2=airdist.loc[airdist['Consumption_zone']>= in_nodeznmeso['FEZ']].copy()     ##-- Filter airport GCD data for node ID > first external zone
temp2=temp2.rename(columns={'Consumption_zone': 'destination'})                  ##-- Rename columns
cmapair=pd.merge(temp1, temp2, how='outer', on='destination')                     ##-- Combine data from step 1 with data from step2
cmapair['ExtDray']=ExtDrayDom                                                     ##-- Assume fixed drayage at each destination 

## Create Group 2: Non-CMAP US Zones to every Non-CMAP Zone -----------------------------------------------------------------------
##-- 1. Use GCD data to populate fields
temp1=in_gcd.loc[((in_gcd['Production_zone'] >= in_nodeznmeso['FEZ']) & (in_gcd['Production_zone'] <= in_nodeznmeso['LEZ'])) & (in_gcd['Consumption_zone'] >= in_nodeznmeso['FEZ'])].copy()
temp1=temp1.rename(columns={'Production_zone':'origin', 'Consumption_zone':'destination'})
temp1=temp1[['origin', 'destination', 'GCD']].copy()

##-- 2. Use Intrazonal distance to represent drayage at appropriate end
intra=temp1.loc[temp1['origin']==temp1['destination']].copy()
drayo=intra[['origin', 'GCD']].copy()
drayo=drayo.rename(columns={'GCD':'IntDray'})
drayd=intra[['destination', 'GCD']].copy()
drayd=drayd.rename(columns={'GCD':'ExtDray'})

##-- 3. Merge temp1 with drayage origin and destination GCD
temp2=pd.merge(temp1, drayo, how='outer', on='origin')
temp3=pd.merge(temp2, drayd, how='outer', on='destination')
temp3['ExtDray']=np.where(temp3['destination'] >= in_nodeznmeso['LEZ'], ExtDrayFor, temp3['ExtDray'])

##-- QC: Verify all drayage is present
#- Check ExtDray
check=temp3.copy()
check= check.loc[(check['ExtDray'] <= 0) | (check['ExtDray'].isnull())].copy()
if check.shape[0] > 0:
    print('ERROR: missing "ExtDray" values for OD pairs')
    print(check)
    sys.stop()

#- Check IntDray
check=temp3.copy()
check= check.loc[(check['IntDray'] <= 0) | (check['IntDray'].isnull())].copy()
if check.shape[0] > 0:
    print('ERROR: missing "IntDray" values for OD pairs')
    print(check)
    sys.stop()

##-- 4. Merge with template
#- In order to allow air travel between origins & destination outside of CMAP, we will repurpose     
#- IntDray141 & LineHaul141 to represent air travel between these zones: between external zone pairs
#- this is general air cargo, not cargo using OHare. 
ncmapair=pd.merge(ncmaptmplt, temp3, how='right', on=['origin', 'destination'])                     ##-- Combine data from step 1 with data from step2
ncmapair['IntDray141']=np.where(ncmapair['origin']==ncmapair['destination'], ncmapair['IntDray']/2,ncmapair['IntDray']) 
ncmapair['LineHaul141']=ncmapair['GCD']
ncmapair=ncmapair.drop(['GCD', 'IntDray'], axis=1)

#- Combine AIR SKIMS -----------------------------------------------------------------------
allAir=pd.concat([cmapair, ncmapair])   ##-- Combine cmapair and ncmapair

##-- Set ExtDray with Emme data when available
condition = (
    (allAir['origin'] <= in_nodeznmeso['LIZ']) &
    ((allAir['destination'] <= in_nodeznmeso['LEZ']) | ((allAir['destination'] == in_nodeznmeso['Canada'])|(allAir['destination'] == in_nodeznmeso['Mexico']))) &
    ((allAir['destination'] != in_nodeznmeso['Hawaii1'])&(allAir['destination'] != in_nodeznmeso['Hawaii2']))
    )

allAir.loc[condition, 'ExtDray'] = np.nan

##-- Filter to keep only first direction; second direction will be added later
allAir=allAir.loc[allAir['origin'] <= allAir['destination']].copy()   

# -----------------------------------------------------------------------
# DETERMINE AIRPORTS FOR FOREIGN SHIPMENTS
# -----------------------------------------------------------------------
#- 1. Filter to keep CMAP to anywhere & non-CMAP U.S. to non-CMAP U.S.
air1=allAir.loc[(allAir['origin'] <= in_nodeznmeso['FEZ']) | ((allAir['origin'] <= in_nodeznmeso['LEZ'])&(allAir['destination'] <= in_nodeznmeso['LEZ']))].copy()

#- 2. Filter to keep foreign destinations only from non-CMAP U.S. origins (antijoin allAir and air1)
air1ODs=air1[['origin','destination']].copy()                              ##-- Create df of OD pairs in air1
air1ODs=air1ODs.drop_duplicates()                                          ##-- Drop duplicates
air1ODs['rmflg']=1                                                         ##-- Add flag to OD df
air2=pd.merge(allAir, air1ODs, how='left', on=['origin', 'destination'])   ##-- Merge allAir and OD flagged df
air2=air2.loc[air2['rmflg'] != 1].copy()                                   ##-- Filter to keep only instances where flag!=1
air2=air2.drop('rmflg', axis=1)                                            ##-- Remove flag column

#- 3. Attach All Imp-Exp Airport labels to each Zone Pair
in_frair['key']=1    ##-- Add key for merge
air2['key']=1        ##-- Add key for merge
fr_air=pd.merge(in_frair, air2, on='key').drop('key', axis=1)   ##-- Merge on key to create all pairs

#- 4. Foreign Air: Attach GCD between Imp-Exp Airport and Foreign Country
frgnair=in_gcd.rename(columns={'Production_zone': 'FrAir_mesozone', 'Consumption_zone': 'destination', 'GCD': 'frairGCD'}).copy()
frgnair=frgnair[['FrAir_mesozone', 'destination', 'frairGCD']].copy()
temp1=pd.merge(fr_air, frgnair, how='left', on=['FrAir_mesozone', 'destination'])

#- 5. Domestic Air: Attach Domestic Distance between Origin and Imp-Exp Airport
domsair=in_gcd.rename(columns={'Production_zone': 'origin', 'Consumption_zone': 'FrAir_mesozone', 'GCD': 'dmsairGCD'}).copy()
domsair=domsair[['origin', 'FrAir_mesozone', 'dmsairGCD']].copy()

#- Merge and format domestic and foreign air distances
fr_air2=pd.merge(temp1, domsair, how='left', on=['origin', 'FrAir_mesozone'])

#- 6. Determine the 'Best' Imp-Exp Airport to use
# for simplicity, start by assuming it is the one that minimizes overall travel time 
# overall travel time: time on plane (o to Imp-Exp Airport) plus time on plane (Imp-Exp Airport to foreign dest) 
fr_air2['IntDray141']=fr_air2['dmsairGCD']
fr_air2['LineHaul141']=fr_air2['frairGCD']
fr_air2['AirFrgnTime']=(fr_air2['IntDray141']+fr_air2['LineHaul141'])/in_sptime['AirMPH'] + fr_air2['ExtDray']/in_sptime['DrayTruckMPH']
fr_air2['AirFrgnCost']=(fr_air2['IntDray141']+fr_air2['LineHaul141'])*in_charges['AirRate'] + fr_air2['ExtDray']*in_charges['FTL53rate']
fr_air2['adjAir']=random.random()*0.15-0.075  							##-- random cost variance between -0.075 & 0.075 	
fr_air2['GenCostAir']=((0.8*fr_air2['AirFrgnTime']) + (0.2*fr_air2['AirFrgnCost']))*(1+fr_air2['adjAir']) ##-- assume high-value goods are time sensitive, which is why AIr is used between o & Imp-Exp Airport -- ***;	
fr_air2=fr_air2.drop(['dmsairGCD', 'frairGCD'], axis=1)       ##-- Remove GCD distances

temp=fr_air2.loc[fr_air2['GenCostAir'].notnull()]
temp = temp[temp.groupby(['origin','destination'])['GenCostAir'].rank() <= 5].reset_index(drop=True)   ##-- Group by OD and select Top 5 ports by lowest cost

# Define function to select path by based on probability
def pps_sample(group):
    probs = group['FrgnAirTons'] / group['FrgnAirTons'].sum()       ##-- Normalize FrgnAirTons to sum to 1 to get sampling probabilities  
    sampled_index = np.random.choice(group.index, size=1, p=probs)  ##-- Randomly choose 1 row index using probabilities
    return group.loc[sampled_index]
print("---> Selecting the best airport path by OD")
air1 = temp.groupby(['origin', 'destination'], group_keys=False).apply(pps_sample).copy()  ##-- Perform stratified PPS sampling: group by (o, dest) and sample 1 row per group
view=air1.copy()
air1.reset_index(drop=True, inplace=True)
air1=air1.drop(['FAF4_Rank', 'AirFrgnTime', 'AirFrgnCost', 'adjAir', 'GenCostAir', 'FrgnAirTons'], axis=1)

#- 7. Merge Best airport with data
finAir = pd.merge(allAir, air1, on=['origin', 'destination'], how='left', suffixes=('', '_test1'))

replaceCols = [
    'IntDray141', 'IntDray142', 'IntDray143', 'IntDray144',
    'LineHaul141', 'LineHaul142', 'LineHaul143', 'LineHaul144',
    'ExtDray'
]

for col in replaceCols:
    finAir[col] = finAir[f'{col}_test1'].combine_first(finAir[col])
    finAir.drop(columns=[f'{col}_test1'], inplace=True)

# -----------------------------------------------------------------------
# UPDATE WITH ALL LOGISTICS NODE DATAFRAME
# -----------------------------------------------------------------------
# update in_skims with the airport skim data
# Set index to the key columns
i_indexed=in_skims.copy()
i_indexed['ODp']=i_indexed['origin'].astype(str) + '_' + i_indexed['destination'].astype(str)
finAir_indexed=finAir.copy()
finAir_indexed['ODp']=finAir_indexed['origin'].astype(str) + '_' + finAir_indexed['destination'].astype(str)
i_indexed.set_index('ODp', inplace=True)
finAir_indexed.set_index(['ODp'], inplace=True)

# Update 'i' with non-NaN values from 'allair'
i_indexed.update(finAir_indexed)

# Find rows in allair not in i
new_rows = finAir_indexed[~finAir_indexed.index.isin(i_indexed.index)]

# Append them to i
i_updated2 = pd.concat([i_indexed, new_rows])

i_updated2.reset_index(inplace=True)

# Export
i_updated2.to_csv(outAdjSkims, index=False)

# -----------------------------------------------------------------------
# OBTAIN RAIL GCD 
# -----------------------------------------------------------------------
railGCD = in_gcd.loc[(in_gcd['Production_zone']==in_gcd['Consumption_zone']) & ((in_gcd['Production_zone'] <= in_nodeznmeso['LEZ'])&(in_gcd['Production_zone'] >= in_nodeznmeso['FEZ']))].copy()
railGCD.rename(columns={'Production_zone':'origin', 'Consumption_zone':'destination', 'GCD':'RailWtr'}, inplace=True)
railGCD=railGCD[['destination', 'RailWtr']]
railGCD.to_csv(outRailGCD, index=False)