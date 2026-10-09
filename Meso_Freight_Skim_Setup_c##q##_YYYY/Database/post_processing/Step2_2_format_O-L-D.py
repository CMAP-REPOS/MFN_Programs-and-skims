
### TO ADD CONTEXT####
# ---------------------------------------------------------------
# Import Directories
# ---------------------------------------------------------------
import sys, os, shutil, math, yaml, io, random
import pandas as pd, numpy as np

# ---------------------------------------------------------------
# Set Paths and Constants
# ---------------------------------------------------------------
##-- System inputs
year=sys.argv[1]      ##-- Skim year
scenario = sys.argv[2]

##-- File directories
databaseDir = os.getcwd()       ##-- Database     
inDir = os.path.join(databaseDir + '/input_data/post_processing')    ##-- Database/input_data/post_processing
inDir2 = os.path.join(databaseDir + '/output_data/' + scenario)             ##-- Database/output_data/skim
outDir = os.path.join(databaseDir + '/output_data/post_processing' + "_" + scenario)        ##-- Database/output_data/post_processing
outTempDir = os.path.join(outDir + '/tempOut/')

##-- Inputs 
pth_nodeznmeso= os.path.join(databaseDir + "/input_data/constants/node_zone_meso.yaml")   ##-- Zone and node ranges by mode and region (CMAP, logistics, non-CMAP)
pth_CCdist= os.path.join(inDir2 + "/CCdist.txt")               ##-- Highway centroid connector length
pth_gcd= os.path.join(outDir + "/data_mesozone_gcd_" + year + ".csv")              ##-- GCD file created during STEP1
pth_skims=os.path.join(outTempDir + "/allSkims_" + year+".csv")

##-- Outputs
outOLD= os.path.join(outTempDir + "/all_O-L-D_" + year + ".csv")        ##-- New output file of modepath skim costs and times 
outEmSkim= os.path.join(outTempDir + "/emskim_" + year + ".csv")

##-- Variables
ExtDrayFor=100     ##-- Assume fixed drayage at each foreign destination country 

# ---------------------------------------------------------------
# Import Data
# ---------------------------------------------------------------
in_CCdist = pd.read_csv(pth_CCdist, sep = '\s+', engine='python')                                  ##-- Highway centroid connector length
in_gcd= pd.read_csv(pth_gcd)     ##-- Top 30 US ports for international shipping (based on 2013 tonnage, including total foreign tonnage [imports+exports])
allSkim=pd.read_csv(pth_skims)
with open(pth_nodeznmeso, 'r') as file:         ##-- Zone and node ranges by mode and region (CMAP, logistics, non-CMAP)
    in_nodeznmeso = yaml.safe_load(file)

# ---------------------------------------------------------------
# Create Templates
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

# ---------------------------------------------------------------
# FORMAT ALL ORIGIN-LOGISTICS NODE (IF APPLICABLE)-DESTINATION COMBINATION OPTIONS
# ---------------------------------------------------------------
##-- Create OD list with every potential Origin-Logistics Node (if applicable)-Destination combination
##-- GROUP1: Trips outside CMAP region (OD Other US Zones)
outside=allSkim.loc[(allSkim['origin'] >= in_nodeznmeso['FEZ']) & (allSkim['destination'] >= in_nodeznmeso['FEZ'])].copy() 
outside['Source']='II_IE_Direct'

##-- GROUP2: II/IE Trips with no stop at internal logistics node
directII_IE=allSkim.loc[(allSkim['origin'] <= in_nodeznmeso['LIZ']) & ((allSkim['destination'] <= in_nodeznmeso['LIZ']) | (allSkim['destination'] >= in_nodeznmeso['FEZ']))].copy() 
directII_IE['Source']='II_IE_Direct'

##-- GROUP3: IE Trips with one stop at internal logistics node (truck only; assume only trucks carry dray freight)
IElogI=allSkim.loc[(allSkim['origin'] <= in_nodeznmeso['LIZ']) & ((allSkim['destination'] <= in_nodeznmeso['LLN']) & (allSkim['destination'] >= in_nodeznmeso['FLN']))].copy() 
IElogI['LogNode']=IElogI['destination']
IElogI['ILNTtt']=IElogI['Ttt']
IElogI['ILNTdsml']=IElogI['Tdsml']
IElogI=IElogI[['origin', 'LogNode', 'ILNTtt', 'ILNTdsml']]

##-- GROUP4: IE Trips with one stop at an external logisitcs node
IElogE=allSkim.loc[((allSkim['origin'] <= in_nodeznmeso['LLN']) & (allSkim['origin'] >= in_nodeznmeso['FLN'])) &  (allSkim['destination'] >= in_nodeznmeso['FEZ'])].copy() 
IElogE['LogNode']=IElogE['origin']
IElogE['LNETtt']=IElogE['Ttt']
IElogE['LNETdsml']=IElogE['Tdsml']
IElogE=IElogE[['LogNode', 'destination', 'Rtt', 'Rivtt', 'Wtt', 'LNETtt', 'RAvail', 'WAvail', 'LNETdsml', 'Rdsml']]

##-- Join Internal-Drayage-Time data to External-Linehaul-time data
#- This code enumerates the potential options: all combinations of CMAP origins-logistics nodes-all non-CMAP US/Canada/Mexico destinations
IELN1=pd.merge(IElogI, IElogE, how='outer', on=['LogNode'])

##-- Combine Direct and Indirect routes and select the 'best' carrier
# IELN1 = all trips that stop at logistics node-- all potential options of CMAP origins-logistics nodes with all non-CMAP destinations 
# outside = all OD trips outside CMAP region
# directII_IE = all trips that do not stop at logicstics node
# collectivley, allGroups1 should be all OD trips with special info if there's a logistics pass through
allODL = pd.concat([IELN1, outside, directII_IE])                  ##-- Combine 
allODL['ChosCarr']=1
allODL['Carr']='R'
allODL['ChRtt']=allODL['Rtt']
allODL['ChRivtt']=allODL['Rivtt']
allODL['CmapPsRL']=allODL['Rpoe']

##-- Subset columns
allODL=allODL[['origin', 'LogNode', 'destination', 'ILNTtt', 'LNETtt', 'ILNTdsml', 'LNETdsml', 'Wtt', 'Ttt', 'Tdsml', 'RAvail', 'WAvail', 'ChosCarr',
                       'Carr', 'ChRtt', 'ChRivtt', 'Rdsml', 'CmapPsRL', 'CmapPsTR', 'Rtrnf', 'Rdwl', 'Source']].copy()

##-- Format connector length (miles) at the Destination End
destCCmi=in_CCdist[['inode', 'jnode', 'len']]
destCCmi.columns=['destination', 'node', 'destCCmi']
destCCmi=destCCmi.loc[destCCmi['node']>=in_nodeznmeso['MinHwyNode']].copy()
destCCmi=destCCmi.drop('node', axis=1)

##-- Merge connector lengths with trip skims
allODL=pd.merge(allODL, destCCmi, how='left', on='destination')

# ---------------------------------------------------------------
# SPLIT DATA INTO 1. DOES NOT USE CMAP LOGISTICS NODE AND 2. DOES USE CMAP LOGISTICS NODE
# ---------------------------------------------------------------
##-- No logistics stop in CMAP region (truck and rail only)
#- Assumes water and air travel always involve truck drayage within CMAP region
noLogo=allODL.loc[allODL['Source']=='II_IE_Direct'].copy()
noLogo = noLogo.rename(columns={'Ttt': 'Tdist00', 'ChRtt': 'Rdist00', 'RAvail': 'RAvail00', 'Tdsml': 'Tdsml00', 'Rdsml': 'Rdsml00'})
noLogo=noLogo[['Source', 'Tdist00', 'Rdist00', 'RAvail00', 'Tdsml00', 'Rdsml00', 'origin', 'destination', 'Carr', 'CmapPsRL', 'CmapPsTR', 'Rtrnf', 'Rdwl']]

##-- 1 Logistics stop in CMAP region
#- Assumes drayage to the logistics node is always by truck
tmp=allODL.loc[allODL['Source']!='II_IE_Direct'].copy()
tmp['OD']=tmp['origin'].astype(str) + '_' + tmp['destination'].astype(str)

tmp['LHmiles'] = np.nan
tmp['LHcheck'] = np.nan
tmp['LhdsMiles'] = np.nan

tmp['LHmiles']= np.where((tmp['LogNode'] >= in_nodeznmeso['FTT']) & (tmp['LogNode'] <= in_nodeznmeso['LTT']), tmp['LNETtt']-tmp['destCCmi'], tmp['LHmiles'])
tmp['LHcheck']= np.where((tmp['LogNode'] >= in_nodeznmeso['FTT']) & (tmp['LogNode'] <= in_nodeznmeso['LTT']), tmp['LHmiles']/tmp['LNETtt'], tmp['LHmiles'])
tmp['LhdsMiles']= np.where((tmp['LogNode'] >= in_nodeznmeso['FTT']) & (tmp['LogNode'] <= in_nodeznmeso['LTT']), tmp['LNETdsml']-tmp['destCCmi'], tmp['LhdsMiles'])

tmp['LHmiles']= np.where((tmp['LogNode'] >= in_nodeznmeso['FAT']) & (tmp['LogNode'] <= in_nodeznmeso['LAT']), tmp['LNETtt']-tmp['destCCmi'], tmp['LHmiles'])
tmp['LHcheck']= np.where((tmp['LogNode'] >= in_nodeznmeso['FAT']) & (tmp['LogNode'] <= in_nodeznmeso['LAT']), tmp['LHmiles']/tmp['LNETtt'], tmp['LHmiles'])
tmp['LhdsMiles']= np.where((tmp['LogNode'] >= in_nodeznmeso['FAT']) & (tmp['LogNode'] <= in_nodeznmeso['LAT']), tmp['LNETtt']-tmp['destCCmi'], tmp['LhdsMiles'])

tmp['LHmiles']= np.where((tmp['LogNode'] >= in_nodeznmeso['FWT']) & (tmp['LogNode'] <= in_nodeznmeso['LWT']), tmp['Wtt'], tmp['LHmiles'])
tmp['LHcheck']= np.where((tmp['LogNode'] >= in_nodeznmeso['FWT']) & (tmp['LogNode'] <= in_nodeznmeso['LWT']), tmp['LHmiles']/tmp['Wtt'], tmp['LHmiles'])
tmp['LhdsMiles']= np.where((tmp['LogNode'] >= in_nodeznmeso['FWT']) & (tmp['LogNode'] <= in_nodeznmeso['LWT']), tmp['Wtt'], tmp['LhdsMiles'])

tmp['LHmiles']= np.where((tmp['LogNode'] >= in_nodeznmeso['FRT']) & (tmp['LogNode'] <= in_nodeznmeso['LRT']), tmp['ChRtt'], tmp['LHmiles'])
tmp['LhdsMiles']= np.where((tmp['LogNode'] >= in_nodeznmeso['FRT']) & (tmp['LogNode'] <= in_nodeznmeso['LRT']), tmp['Rdsml'], tmp['LhdsMiles'])

#- Create Additional columns to hold logistics node passthrough information
colNameList=['IntDray', 'LineHaul', 'LHdms', 'Carr']

for collist in colNameList:
    if collist == 'Carr':
        i=in_nodeznmeso['FRT']
        while i <= in_nodeznmeso['LRT']:
            nstr=collist+str(i)
            if i == in_nodeznmeso['FRT']:
                arrayNms=[nstr]
            else:
                arrayNms.append(nstr)
            i=i+1
    else:
        i=in_nodeznmeso['FLN']
        while i <= in_nodeznmeso['LLN']:
            nstr=collist+str(i)
            if i == in_nodeznmeso['FLN']:
                arrayNms=[nstr]
            else:
                arrayNms.append(nstr)
            i=i+1
    for item in arrayNms:
        tmp[item]=np.nan

#- Format arrays to hold IntDray, LineHaul, LHdms, and RlCarr data
#- arrays put 1 value per row, then at the end collaps down to one row
#- initialize empty output rows list
output_rows = []  

print("---> Initializing IntDray, LineHaul, LHdms, and RlCarr values by OD")
#- Loop through each OD pair
for od, group in tmp.groupby('OD', sort=False):
    # Initialize arrays/dictionaries for this OD
    IntDray = {i: np.nan for i in range(in_nodeznmeso['FLN'], in_nodeznmeso['LLN'] + 1)}
    LineHaul = {i: np.nan for i in range(in_nodeznmeso['FLN'], in_nodeznmeso['LLN'] + 1)}
    LHdms = {i: np.nan for i in range(in_nodeznmeso['FLN'], in_nodeznmeso['LLN'] + 1)}
    RlCarr = {i: "" for i in range(in_nodeznmeso['FRT'], in_nodeznmeso['LRT'] + 1)}

    # Process each row in the group
    for _, row in group.iterrows():
        idx = int(row['LogNode'])
        if in_nodeznmeso['FLN'] <= idx <= in_nodeznmeso['LLN']:
            IntDray[idx] = row['ILNTtt']
            LineHaul[idx] = row['LHmiles']
            LHdms[idx] = row['LhdsMiles']
            RlCarr[idx] = row['Carr']

    # External Dray logic
    destination = group['destination'].iloc[-1]
    o_val = group['origin'].iloc[-1]
    od_val = group['OD'].iloc[-1]
    dest_ccmi = group['destCCmi'].iloc[-1]

    # Build the output row
    output_row = {
        'origin': o_val,
        'destination': destination,
        'OD': od_val,
        'destCCmi': dest_ccmi
    }

    # Add array values to the row (flattened)
    for i in range(in_nodeznmeso['FLN'], in_nodeznmeso['LLN'] + 1):
        output_row[f'IntDray{i}'] = IntDray[i]
        output_row[f'LineHaul{i}'] = LineHaul[i]
        output_row[f'LHdms{i}'] = LHdms[i]

    for i in range(in_nodeznmeso['FRT'], in_nodeznmeso['LRT'] + 1):
        output_row[f'Carr{i}'] = RlCarr[i]

    # Append to result list
    output_rows.append(output_row)

#- Create final DataFrame and sort
yesLogo = pd.DataFrame(output_rows)
yesLogo['ExtDray']=np.where(yesLogo['destination'] <= in_nodeznmeso['LEZ'], yesLogo['destCCmi'], ExtDrayFor)
yesLogo=yesLogo.drop('destCCmi', axis=1)

##- Combine ODs without CMAP logistics node stop (noLogo) with ODs with a CMAP logistics node stop (yesLogo)
allLogo = pd.merge(noLogo, yesLogo, how='outer', on=['origin', 'destination'])
allLogo = allLogo.sort_values(['origin', 'destination'])
allLogo=allLogo.drop('Source', axis=1)

# ---------------------------------------------------------------
# Get Emme Skimmed Truck Distance for All Zones
# ---------------------------------------------------------------
emskim = allLogo.copy()
emskim['EmDist']=emskim['Tdist00']
remskim = emskim.copy()
remskim.rename(columns={'origin':'destination', 'destination':'origin'}, inplace=True)
emskim = pd.concat([emskim, remskim])
emskim=emskim[['origin', 'destination', 'EmDist']]
emskim=emskim.drop_duplicates()
emskim = emskim.sort_values(['origin', 'destination'])

# ---------------------------------------------------------------
# EXPORT
# ---------------------------------------------------------------
allLogo.to_csv(outOLD, index=False)
emskim.to_csv(outEmSkim, index=False)

