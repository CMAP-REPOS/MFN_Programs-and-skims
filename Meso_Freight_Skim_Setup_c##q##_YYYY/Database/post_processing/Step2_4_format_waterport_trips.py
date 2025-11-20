
## to add context ##
# ---------------------------------------------------------------
# Import Directories
# ---------------------------------------------------------------
import sys, os, shutil, math, yaml, io, random
import pandas as pd, numpy as np

# ---------------------------------------------------------------
# SET PATHS
# ---------------------------------------------------------------
##-- System inputs
year=sys.argv[1]     ##-- Skim year
scenario = sys.argv[2]

##-- File directories
databaseDir = os.getcwd()       ##-- Database     
inDir = os.path.join(databaseDir + '/input_data/post_processing')    ##-- Database/input_data/post_processing
inDir2 = os.path.join(databaseDir + '/output_data/' + scenario)             ##-- Database/output_data/skim
outDir = os.path.join(databaseDir + '/output_data/post_processing' + "_" + scenario)        ##-- Database/output_data/post_processing
outTempDir = os.path.join(outDir + '/tempOut/')

##-- Inputs 
pth_dports= os.path.join(inDir + "/domestic_ports.csv")        ##-- Top 30 US ports for international shipping (based on 2013 tonnage, including total foreign tonnage [imports+exports])
pth_fports= os.path.join(inDir + "/foreign_ports.csv")         ##-- Ocean used for each foreign port for international shipping 
pth_nodeznmeso= os.path.join(inDir + "/node_zone_meso.yaml")   ##-- Zone and node ranges by mode and region (CMAP, logistics, non-CMAP)
pth_sptime= os.path.join(inDir + "/speeds_and_time.yaml")      ##-- Speeds (MPH), handling time (hours), and dwell time at interchanges (hours) as constants
pth_charges= os.path.join(inDir + "/charges.yaml")             ##-- Handling charges, linehaul charges, and surcharges constants
pth_gcd= os.path.join(outDir + "/data_mesozone_gcd_" + year + ".csv")              ##-- GCD file created during STEP1
pth_mf32=os.path.join(outTempDir + "/mf32_formatted_" + year+".csv")
pth_OLD= os.path.join(outTempDir + "/all_O-L-D_" + year + ".csv")        ##-- New output file of modepath skim costs and times 
pth_airSkims=os.path.join(outTempDir+ "/skims_adjAir_" + year + ".csv")
pth_waterlinks=os.path.join(inDir2 + "/waterlinks.txt")

##-- Outputs
outI= os.path.join(outTempDir + "/skims_adjWater_"+year + ".csv")        ##-- New output file of modepath skim costs and times 
outIntdr = os.path.join(outTempDir + "/outWaterintdr_"+year + ".csv")  
outInland= os.path.join(outTempDir + "/waterInland_" +year+ ".csv")        ##-- New output file of modepath skim costs and times 

##-- Constants
ExtDrayFor=100     ##-- Assume fixed drayage at each foreign destination country 
seed=8768          ##-- Seed value for random function to choose best port 

##-- Set Seed
random.seed(seed) 

# ---------------------------------------------------------------
# IMPORT DATA
# ---------------------------------------------------------------
in_dports= pd.read_csv(pth_dports)     ##-- Top 30 US ports for international shipping (based on 2013 tonnage, including total foreign tonnage [imports+exports])
in_fports= pd.read_csv(pth_fports)     ##-- Ocean used for each foreign port for international shipping 
in_gcd= pd.read_csv(pth_gcd)     ##-- Top 30 US ports for international shipping (based on 2013 tonnage, including total foreign tonnage [imports+exports])
in_mf32=pd.read_csv(pth_mf32)
allOLD=pd.read_csv(pth_OLD)
allAirSkim=pd.read_csv(pth_airSkims, low_memory=False)
in_waterLinks=pd.read_csv(pth_waterlinks, sep = '\s+', engine='python', skiprows = 6, header=None)
with open(pth_nodeznmeso, 'r') as file:         ##-- Zone and node ranges by mode and region (CMAP, logistics, non-CMAP)
    in_nodeznmeso = yaml.safe_load(file)
with open(pth_sptime, 'r') as file:             ##-- Speeds (MPH), handling time (hours), and dwell time at interchanges (hours) as constants
    in_sptime = yaml.safe_load(file)
with open(pth_charges, 'r') as file:            ##-- Handling charges, linehaul charges, and surcharges constants
    in_charges = yaml.safe_load(file)

# ---------------------------------------------------------------
# CREATE TEMPLATES
# ---------------------------------------------------------------
##-- Create template for all US Mesozones to Alaska/Hawaii/all foreign counties
#- Create df of US mesozones excluding logistics nodes
us = in_gcd.loc[(in_gcd['Production_zone'] <= in_nodeznmeso['LIZ']) | ((in_gcd['Production_zone'] >= in_nodeznmeso['FEZ']) & (in_gcd['Production_zone'] <= in_nodeznmeso['LEZ']))].copy()
us=us[['Production_zone']].copy()
us=us.drop_duplicates()
us.columns=['origin']                                                                     ##-- Rename Production_zone 'origin'

#- Create df of foreign mesozones, include Alaska/Hawaii as destinations
foreign = in_gcd.loc[((in_gcd['Production_zone'] > in_nodeznmeso['LEZ']) | (in_gcd['Production_zone'] == in_nodeznmeso['Alaska'])) | 
    ((in_gcd['Production_zone'] == in_nodeznmeso['Hawaii1']) | (in_gcd['Production_zone'] == in_nodeznmeso['Hawaii2']))].copy()
foreign=foreign[['Production_zone']].copy()
foreign=foreign.drop_duplicates()
foreign.columns=['destination']                                                                     ##-- Rename Production_zone 'destination'

#- Cross merge dataframes
us['A']=1
foreign['A']=1
intship = us.merge(foreign, how='left', on='A', copy=False)      ##-- Use Non-CMAP destinations from Group 1
intship=intship.drop('A', axis=1)

# ---------------------------------------------------------------
# FORMAT INTERNATIONAL WATER SKIMS FOR ALL ZONE PAIRS
# ---------------------------------------------------------------
##-- Format foreign port dataframe to attach ocean to the foreign port
fport=in_fports.copy()
fport = fport.rename(columns={'Mesozone': 'destination', 'Port_Ocean': 'Port_d'})
fport = fport.drop(['Region', 'Continent'], axis=1)

#- Create distinct Atlantic and Pacific rows for 'AP' port destinations (Port_d= 'AP')
APs = fport.loc[fport['Port_d']=='AP'].copy()
pAPs=APs.copy()
pAPs['Port_d']='Pacific'

aAPs=APs.copy()
aAPs['Port_d']='Atlantic'

fport = fport.loc[fport['Port_d']!='AP'].copy()
fport=pd.concat([fport, aAPs, pAPs])
fport.sort_values('destination')

#- Add Alaska and two Hawaiian zones as destinations for international shipping
AHdata = {
    "destination": [in_nodeznmeso['Alaska'], in_nodeznmeso['Hawaii1'], in_nodeznmeso['Hawaii2']],
    "Location": ['Alaska', 'Honolulu', 'Hawaii Rem'],
    "Port_d": ['Pacific', 'Pacific', 'Pacific']
}

# Create DataFrame
AHdata = pd.DataFrame(AHdata)

# Combine 
fport=pd.concat([fport, AHdata]).reset_index()
fport=fport.drop('index', axis=1)

##-- Intersect foreign ports with Foreign-Domestic port template
intship2=pd.merge(intship, fport, how='left', on='destination')

##-- Atach all domestic ports to each zone pair
intship2['A']=1
dports=in_dports.copy()
dports['A']=1
intship3=pd.merge(intship2, dports, how='outer', on='A')
intship3=intship3.drop('A', axis=1)
intship3=intship3.sort_values(['origin', 'destination'])

# ---------------------------------------------------------------
# DETERMINE PORT FOR FOREIGN SHIPMENTS
# ---------------------------------------------------------------
##-- Part 1: Attach GDC between Port and Foreign County
#- For Port-Country pairs on different oceans, add extra distance for using the Panama Canal
intship4=intship3.copy()
intship4['Port_d'] = intship4['Port_d'].str.strip()
intship4['Ocean'] = intship4['Ocean'].str.strip()

#- Use port at Honolulu for shipments between Hawaii-Foreign Countries and Hawaii-Alaska
cond_hawaii = (
    (intship4['origin'].isin([in_nodeznmeso['Hawaii1'], in_nodeznmeso['Hawaii2']])) & 
    ((intship4['destination'].isin([in_nodeznmeso['Alaska'], in_nodeznmeso['Hawaii1'], in_nodeznmeso['Hawaii2']])) | (intship4['destination'] > in_nodeznmeso['LEZ']))
)

intship4.loc[cond_hawaii, 'Port_mesozone'] = in_nodeznmeso['Hawaii1']
intship4.loc[cond_hawaii, 'Port_name'] = "Honolulu, HI"
intship4.loc[cond_hawaii, 'Ocean'] = "Pacific"

# Alaska shipment logic
cond_alaska = (
    ((intship4['origin'] == in_nodeznmeso['Alaska'])) &
    ((intship4['destination'].isin([in_nodeznmeso['Alaska'], in_nodeznmeso['Hawaii1'], in_nodeznmeso['Hawaii2']])) | 
     (intship4['destination'] > in_nodeznmeso['LEZ']))
)

intship4.loc[cond_alaska, 'Port_mesozone'] = in_nodeznmeso['Alaska']
intship4.loc[cond_alaska, 'Port_name'] = "Anchorage, AK"
intship4.loc[cond_alaska, 'Ocean'] = "Pacific"

# Select ocean used for AP access ports
count4 = intship4.groupby(['origin', 'destination', 'Port_mesozone']).size().reset_index(name='count')   # Count number of instances of each origin-destination-port mesozone combo
intship4 = pd.merge(count4, intship4, how='right', on = ['origin', 'destination', 'Port_mesozone'])
intship4['filtFlag'] = np.where(((intship4['count'] == 1) | ((intship4['count'] > 1) & (intship4['Port_d'] == intship4['Ocean']))), 1, 0)  # flag if it's a preferred candidate to keep for filtering
intship4=intship4.sort_values('filtFlag', ascending=False)     # sort by filtFlag highest to lowest, so instances where filtFlag == 1 will be the first row in the group 

intship4 = intship4.groupby(['origin', 'destination', 'Port_mesozone']).nth(0).reset_index()   #- Filter out duplicates
intship4=intship4.drop(['filtFlag', 'count'], axis=1)

#- Assign origin and destination
intship4['Pan_flag']=np.where(intship4['Port_d']==intship4['Ocean'], 0, 1)   #- Flag if transporation crosses oceans and therefore uses the Panama Canal
intship4['Production_zone']=intship4['Port_mesozone']                        #- Assign port as origin for GCD
intship4['Consumption_zone']=intship4['destination']                         #- Assign foreign country as destination for GCD

nonPan=intship4.loc[intship4['Pan_flag']==0].copy()
yesPan=intship4.loc[intship4['Pan_flag']==1].copy()

#- Adjust for transportation through Panama Canal
#- Format first half of Panama trip
pan1=yesPan.copy()
pan1['Consumption_zone']=in_nodeznmeso['Panama']     #- Assign Panama as intermediate destination for GCD (port to Panama)

#- Get second half of Panama trip
pan2=yesPan.copy()
pan2['flag2']=1
pan2['Production_zone']=in_nodeznmeso['Panama']     #- Assign Panama as intermediate destination for GCD (Panama to destination)
pan2['Consumption_zone']=pan2['destination']

#- Add second half of Panama trips to all trips
intship5=pd.concat([nonPan,pan1, pan2], ignore_index=True)

#- Add GCD to all trips
intship5= intship5.sort_values(by=['Production_zone', 'Consumption_zone']).reset_index(drop=True)
intship_gcd = pd.merge(in_gcd, intship5, how='right', on=['Production_zone', 'Consumption_zone'])

#- Calculate total GCD by O-L-D (this will sum legs of Panama trips for total distance)
sumGCD = intship_gcd.copy()
sumGCD=sumGCD.groupby(['origin', 'destination', 'Port_mesozone', 'Pan_flag'])
sumGCD=sumGCD[["GCD"]].sum().reset_index()

#- Collapse Panama trips into one distance 
oldAir=intship_gcd[['origin', 'destination', 'Port_mesozone', 'Pan_flag', 'Location', 'Port_name', 'FrgnTons']].copy() #- For all O-L-D pairs, select unique Location-Port_name-FrgnTons observations
oldAir=oldAir.drop_duplicates()                #- Calculate total number of O-L-D observations with unique Location-Port_name-FrgnTons observations
oldAir= oldAir.sort_values(['origin', 'destination', 'Port_mesozone'])
oldAir = oldAir.groupby(['origin', 'destination', 'Port_mesozone', 'Pan_flag']).nth(0).reset_index()   #- Filter out second ocean calculation from Panama connection

oldAir['counter']=1
oldAir['tot']=oldAir.groupby(['origin', 'destination', 'Port_mesozone', 'Pan_flag'])['counter'].transform('sum')
sumOldAir=oldAir.loc[oldAir['tot']==1].copy() #- Keep only unique Location-Port_name-FrgnTons observations where count=1
sumOldAir=sumOldAir.drop(['counter', 'tot'], axis=1)

allAirGCD = pd.merge(sumGCD, sumOldAir, how='left', on=['origin', 'destination', 'Port_mesozone', 'Pan_flag'])  #- Add unique observations to summed GCD dataframe
allAirGCD= allAirGCD.sort_values(['origin', 'destination', 'Port_mesozone', 'GCD'])
allAirGCD = allAirGCD.groupby(['origin', 'destination', 'Port_mesozone']).nth(0).reset_index()   #- Filter out second ocean calculation from Panama connection

##-- Part 2: Attach Inland Waterway and Truck/Rail LH between the Origin and Port
##-- Part 2a: Attach Inland Waterway LH between Origin and Port
#- Create inland waterway skim data for non-CMAP U.S. mesozones
mf32=in_mf32[['origin', 'destination', 'Wtt']].copy()
mf32.rename(columns={'destination':'Port_mesozone', 'Wtt':'Wtrway'}, inplace=True)
intwtr1=mf32.loc[(mf32['origin'] >= in_nodeznmeso['FEZ']) & (mf32['Port_mesozone'] >= in_nodeznmeso['FEZ'])].copy()

#- Create inland waterway skim data for CMAP U.S. mesozones
# create an array LineHaul FWT-LWT
colNms = ['origin', 'destination']
i=in_nodeznmeso['FWT']
while i <= in_nodeznmeso['LWT']:
    nstr='LineHaul'+str(i)
    colNms.append(nstr)
    i=i+1

intwtr2=allOLD.loc[allOLD['origin'] <= in_nodeznmeso['LIZ']].copy()
intwtr2=intwtr2.filter(colNms)

intwtr2['tmp'] = 9999           #- Define column with maximum Wtrway as 9999
#- Isolate LineHaul columns and tmp column in colNms
colNms.remove('origin')         
colNms.remove('destination')
colNms.append('tmp')
intwtr2['Wtrway'] = intwtr2[colNms].min(axis=1)         #- Find minimum LineHaul and set to WtrWay, or set to 9999 if no LineHaul values exist
intwtr2=intwtr2.loc[intwtr2['Wtrway'] < intwtr2['tmp']] #- Filter all Wtrway < 9999
intwtr2=intwtr2.drop(colNms, axis=1)
intwtr2.rename(columns={'destination': 'Port_mesozone'}, inplace=True)

##-- Part 2B: 
#- Attach Truck/Rail LH between Origin and Port
toport=allAirSkim.loc[(allAirSkim['origin'] <= in_nodeznmeso['LEZ']) & ((allAirSkim['destination'] <= in_nodeznmeso['LEZ']) | 
                                                                  ((allAirSkim['destination'] == in_nodeznmeso['Canada'])|(allAirSkim['destination'] == in_nodeznmeso['Mexico'])))].copy()
toport=toport[['origin', 'destination', 'Tdist00', 'Tdsml00', 'Rdist00']]
toport.rename(columns={'destination':'Port_mesozone', 'Tdist00':'Tdist', 'Tdsml00':'Tdsml', 'Rdist00':'Rdist'}, inplace=True)

toport['zero']=0
toport['Tdist']=np.where(toport['origin']==toport['Port_mesozone'], toport[['Tdist', 'zero']].max(axis=1), toport['Tdist'])

rtoport=toport.copy()
rtoport.rename(columns={'origin':'Port_mesozone', 'Port_mesozone':'origin'}, inplace=True)
toport=pd.concat([toport, rtoport])
toport=toport.drop_duplicates(subset=['origin', 'Port_mesozone'])
toport=toport.drop(['zero'], axis=1)         

#- Create Linehaul value between Hawaiian zones
hawaii=in_gcd.loc[(in_gcd['Production_zone'].isin(
    [in_nodeznmeso['Hawaii1'],in_nodeznmeso['Hawaii2']])) & (in_gcd['Consumption_zone'].isin(
    [in_nodeznmeso['Hawaii1'],in_nodeznmeso['Hawaii2']]))].copy()
hawaii.rename(columns={'Production_zone':'origin', 'Consumption_zone':'Port_mesozone', 'GCD':'DrayFix'}, inplace = True)
hawaii=hawaii[['origin', 'Port_mesozone', 'DrayFix']]
hawaii=hawaii.drop_duplicates(subset=['origin', 'Port_mesozone'])

#- Combine all water options with air skims
allWater=pd.merge(allAirGCD, toport, how="left", on=['origin', 'Port_mesozone'])
allWater=pd.merge(allWater, hawaii, how="left", on=['origin', 'Port_mesozone'])
allWater=pd.merge(allWater, intwtr1, how="left", on=['origin', 'Port_mesozone'])
allWater=pd.merge(allWater, intwtr2, how="left", on=['origin', 'Port_mesozone'])

allWater['Wtrway']=np.where(allWater['Wtrway_x'].isnull(), allWater['Wtrway_y'], allWater['Wtrway_x'])
allWater=allWater.drop(['Wtrway_x', 'Wtrway_y'], axis=1)
allWater['Tdist']=np.where((allWater['Tdist'].isnull()) & (allWater['DrayFix'] > 0), allWater['DrayFix'], allWater['Tdist'])
allWater['Tdsml']=np.where((allWater['Tdsml'].isnull()) & (allWater['DrayFix'] > 0), allWater['DrayFix'], allWater['Tdsml'])

#- format internal drayage, add external drayage
intdr=in_gcd.loc[(in_gcd['Production_zone']==in_gcd['Consumption_zone']) & (in_gcd['Production_zone'] <= in_nodeznmeso['LEZ'])].copy()
intdr.rename(columns={'Production_zone':'origin', 'GCD':'InDray'}, inplace=True)
intdr=intdr[['origin', 'InDray']]

#- Combine all water skim OD and port options
allWater=pd.merge(allWater, intdr, how='left', on='origin')
allWater['ExDray']=ExtDrayFor
allWater['zero']=0
allWater['Tdsml']=np.where(allWater['origin']==allWater['Port_mesozone'],allWater[['Tdsml', 'zero']].max(axis=1) ,allWater['Tdsml'] )
allWater['Tdist']=np.where(allWater['origin']==allWater['Port_mesozone'],allWater[['Tdist', 'zero']].max(axis=1) ,allWater['Tdist'] )

##-- PART 3. Determine 'Best' Domestic Port to Use
#- Calculate costs
allWater['Rdist']=np.where(allWater['origin']==allWater['Port_mesozone'], allWater[['Rdist', 'zero']].max(axis=1), allWater['Rdist'])
allWater['haul_toPortNB']=allWater['Tdist']/in_sptime['LHTruckMPH']
allWater['MinShipTimeNB']=allWater['GCD']/in_sptime['WaterMPH'] + allWater['haul_toPortNB'] + (allWater['InDray']+allWater['ExDray'])/in_sptime['DrayTruckMPH'] 
allWater['cost_toPortNB']=allWater['Tdist']*in_charges['FTL53rate']        #- Cost: assume no transloading
allWater['MinShipCostNB']=(allWater['InDray']+allWater['ExDray'])*in_charges['FTL53rate'] + allWater['cost_toPortNB'] + allWater['GCD']*in_charges['WaterRate']  #- ignore transload handling fee
allWater['adjNB']=random.random()*0.15-0.075;  #- random cost variance between -0.075 & 0.075 
allWater['GenCostNB']=((0.6*allWater['MinShipTimeNB']) + (0.4*allWater['MinShipCostNB']))*(1+allWater['adjNB']);	#- assume non-bulk items value time more than cost 	
allWater['haul_toPortB']=allWater['Rdist']/in_sptime['RailMPH']  						#- haul_toPortB=mean(Rdist/&RailMPH,Wtrway/&WaterMPH); 
allWater['MinShipTimeB']=allWater['GCD']/in_sptime['WaterMPH'] + allWater['haul_toPortB'] + (allWater['InDray']+allWater['ExDray'])/in_sptime['DrayTruckMPH']  
allWater['cost_toPortB']=allWater['Rdist']*in_charges['CarloadRate']  					#- Cost: assume no transloading -- **; ****** -- cost_toPortB=mean(Rdist*&CarloadRate,Wtrway*&WaterRate2);
allWater['MinShipCostB']=(allWater['InDray']+allWater['ExDray'])*in_charges['FTL53rate'] + allWater['cost_toPortB'] + allWater['GCD']*in_charges['WaterRate']  #- ignore transload handling fee 
allWater['adjB']=random.random()*0.15-0.075;  #- random cost variance between -0.075 & 0.075   
allWater['GenCostB']=((0.4*allWater['MinShipCostB']) + (0.6*allWater['MinShipCostB']))*(1+allWater['adjB']);  #- assume bulk items value cost more than time 

#- Reverse OD to get both directions
rallWater=allWater.copy()
rallWater.rename(columns={'origin':'destination', 'destination':'origin'}, inplace=True)
allWater=pd.concat([allWater, rallWater])

#- Select best choice based on probability 
def pps_sample(group):
    probs = group['FrgnTons'] / group['FrgnTons'].sum()       ##-- Normalize FrgnTons to sum to 1 to get sampling probabilities  
    sampled_index = np.random.choice(group.index, size=1, p=probs)  ##-- Randomly choose 1 row index using probabilities
    return group.loc[sampled_index]

# NonBulk Goods
nonBulk = allWater.copy()
nonBulk = nonBulk.drop(['haul_toPortB', 'MinShipTimeB', 'cost_toPortB', 'MinShipCostB', 'GenCostB'], axis=1)
nonBulk = nonBulk.loc[nonBulk['GenCostNB'].notnull()]     # filter where GenCostNB is not null
nonBulk = nonBulk[nonBulk.groupby(['origin','destination'])['GenCostNB'].rank() <= 5].reset_index(drop=True)   ##-- Group by OD and select Top 5 ports by lowest cost
nonBulk=nonBulk.sort_values(['origin', 'destination', 'Port_mesozone'])

print("---> Selecting the best water port path by OD")
nonBulk = nonBulk.groupby(['origin', 'destination'], group_keys=False).apply(pps_sample).copy()  ##-- Perform stratified PPS sampling: group by (o, dest) and sample 1 row per group
nonBulk.reset_index(drop=True, inplace=True)
nonBulk=nonBulk[['origin', 'destination', 'Port_mesozone', 'Port_name']]
nonBulk=nonBulk.sort_values(['origin', 'destination', 'Port_mesozone'])

# Bulk Goods
bulk = allWater.copy()
bulk = bulk.drop(['haul_toPortNB', 'MinShipTimeNB', 'cost_toPortNB', 'MinShipCostNB', 'GenCostNB'], axis=1)
bulk = bulk.loc[bulk['GenCostB'].notnull()]     # filter where GenCostNB is not null
bulk = bulk[bulk.groupby(['origin','destination'])['GenCostB'].rank() <= 5].reset_index(drop=True)   ##-- Group by OD and select Top 5 ports by lowest cost
bulk=bulk.sort_values(['origin', 'destination', 'Port_mesozone'])

bulk = bulk.groupby(['origin', 'destination'], group_keys=False).apply(pps_sample).copy()  ##-- Perform stratified PPS sampling: group by (o, dest) and sample 1 row per group
bulk.reset_index(drop=True, inplace=True)

bulk=bulk[['origin', 'destination', 'Port_mesozone', 'Port_name']]
bulk.rename(columns={'Port_mesozone': 'Port_mesozoneB', 'Port_name':'Port_nameB'}, inplace=True)
bulk=bulk.sort_values(['origin', 'destination', 'Port_mesozoneB'])

#- Combine Bulk and nonBulk selected port with data
allWater2=pd.merge(allWater, nonBulk, how="right", on=['origin', 'destination', 'Port_mesozone'])
allWater2['Port_name'] = np.where(allWater2['Port_name_x'].isnull(), allWater2['Port_name_y'], allWater2['Port_name_x'])
allWater2.rename(columns={'Port_mesozone': 'Port_mesozoneNB', 'Port_name':'Port_nameNB'}, inplace=True)
allWater2 = allWater2.drop(['haul_toPortNB', 'MinShipTimeNB', 'cost_toPortNB', 'MinShipCostNB', 
                         'haul_toPortB', 'MinShipTimeB', 'cost_toPortB', 'MinShipCostB', 'adjNB', 'adjB', 'Port_name_x', 'Port_name_y'], axis=1)


allWater3=pd.merge(allWater2, bulk, how="left", on=['origin', 'destination'])
allWater3['Port_mesozoneB']=np.where(allWater3['Port_mesozoneB'].isnull(), allWater3['Port_mesozoneNB'], allWater3['Port_mesozoneB'])
allWater3['Port_nameB']=np.where(allWater3['Port_nameB'].isnull(), allWater3['Port_nameNB'], allWater3['Port_nameB'])
allWater3.rename(columns={'Port_nameB': 'Port_NameB', 'Port_nameNB':'Port_NameNB'}, inplace=True)

# -------------------------------------------------------------------
# COMBINE [ORIGINAL AND ADJUSTED AIR SKIMS] AND UPDATED WATER PORTS
# -------------------------------------------------------------------
# Merge allWater3 into allAirSkim
updatedi = pd.merge(allAirSkim, allWater3, on=['origin', 'destination'], how='left')
updatedi['filtFlag']=np.where((updatedi['origin'] > in_nodeznmeso['LEZ']) & (updatedi['destination'] > in_nodeznmeso['LEZ']),1,0)  # Filter out foreign-foregin movements to keep only domestic-domestic or domestic-foreign
updatedi=updatedi.loc[updatedi['filtFlag'] == 0]
updatedi=updatedi.drop(['filtFlag', 'ODp', 'zero'], axis=1)

#- Export
updatedi.to_csv(outI, index=False)

# ---------------------------------------------------------------
# Create intrazonal skim data for US mesozones
# ---------------------------------------------------------------
intdr = intdr.loc[(intdr['origin'] < in_nodeznmeso['FLN']) | (intdr['origin'] > in_nodeznmeso['LLN'])]
intdr['destination'] = intdr['origin']
intdr['Tdist00'] = intdr['InDray']
intdr['IntraDray'] = intdr['InDray']/2
intdr['RAvail00'] = np.where((intdr['origin'] > in_nodeznmeso['LIZ']), 1, np.nan)
intdr['Rdist00'] = np.where((intdr['origin'] > in_nodeznmeso['LIZ']), (intdr['Tdist00']*1.25), np.nan)
intdr['Rdsml00'] = np.where((intdr['origin'] > in_nodeznmeso['LIZ']), intdr['Rdist00'], np.nan)
intdr['Tdsml00'] = np.where((intdr['origin'] > in_nodeznmeso['LIZ']), intdr['Tdist00'], np.nan)

#- Export
intdr.to_csv(outIntdr, index=False)

# ---------------------------------------------------------------
# Create inland waterway skim data for non-CMAP US mesozones
# ---------------------------------------------------------------
#- Isolate OD pairs to and from all external zones
inland = in_mf32.loc[(in_mf32['origin'] >= in_nodeznmeso['FEZ']) & (in_mf32['destination'] >= in_nodeznmeso['FEZ'])].copy()
inland.rename(columns={'Wtt':'Waterway'}, inplace=True)

#- Isolate intrazonal waterway skims for non-CMAP zones
wtrintra = in_mf32.loc[(in_mf32['origin'] >= in_nodeznmeso['FEZ']) & (in_mf32['origin'] <= in_nodeznmeso['LEZ'])].copy()   # Identify all origins in external zones
wtrintra = wtrintra[['origin']]                    # Keep only origin column
wtrintra['destination'] = wtrintra['origin']       # Creates new column, destination, with same values as origin for intrazonal OD pairs

#- Find intrazonal inland waterways that are not connected to a second zone
wtrintra2 = in_waterLinks.iloc[:, 1:2]
wtrintra2.columns=['origin']
wtrintra2['destination'] = wtrintra2['origin']       # Creates new column, destination, with same values as origin for intrazonal OD pairs
wtrintra2=wtrintra2.loc[wtrintra2['origin'] <= in_nodeznmeso['LEZ']]

#- Combine all intrazonal OD pairs
wtrintra=pd.concat([wtrintra, wtrintra2])
wtrintra=wtrintra.drop_duplicates()

#- Attach intrazonal distance to estimated travel distance
wtrintra = pd.merge(wtrintra, intdr, how = 'left', on = ['origin', 'destination'])
wtrintra['Waterway']=wtrintra['Tdist00']*2   # double truck distance to account for rivers meandering and limited access through ports

#- Add intrazonal OD pairs with inland OD pairs
inland = pd.concat([inland, wtrintra])
inland = inland[['origin', 'destination', 'Waterway']]
inland=inland.drop_duplicates()

#- Export
inland.to_csv(outInland, index=False)