
### TO ADD CONTEXT####
# ---------------------------------------------------------------
# Import Directories
# ---------------------------------------------------------------
import sys, os, shutil, math, yaml, io, random
import pandas as pd, numpy as np

# ---------------------------------------------------------------
# Define Paths and Variables
# ---------------------------------------------------------------
##-- System inputs
year= sys.argv[1]      ##-- Skim year
scenario = sys.argv[2]

##-- File directories
databaseDir = os.getcwd()       ##-- Database     
inDir = os.path.join(databaseDir + '/input_data/')    ##-- Database/input_data/post_processing
inDir2 = os.path.join(databaseDir + '/output_data/'+ scenario)             ##-- Database/output_data/skim
outDir = os.path.join(databaseDir + '/output_data/post_processing' + "_" + scenario)        ##-- Database/output_data/post_processing
outTempDir = os.path.join(outDir + '/tempOut/')

# Create temp output folder
os.mkdir(outTempDir)

##-- Inputs
inMatNames = os.path.join(inDir, "matrix.in")
pth_nodeznmeso= os.path.join(inDir + "/constants/node_zone_meso.yaml")   ##-- Zone and node ranges by mode and region (CMAP, logistics, non-CMAP)

##-- Outputs
outskims= os.path.join(outTempDir + "/allSkims_" + year + ".csv")        ##-- New output file of modepath skim costs and times 
outMF31=os.path.join(outTempDir + "/mf31_formatted_" + year + ".csv")
outMF32=os.path.join(outTempDir + "/mf32_formatted_" + year + ".csv")
outRlyard=os.path.join(outTempDir + "/rlyard_" + year + ".csv")

##-- Constants
minMat = 31

# ---------------------------------------------------------------
# Import Data
# ---------------------------------------------------------------
with open(pth_nodeznmeso, 'r') as file:         ##-- Zone and node ranges by mode and region (CMAP, logistics, non-CMAP)
    in_nodeznmeso = yaml.safe_load(file)
in_MatNames = pd.read_csv(inMatNames, sep = '(\d+)', skiprows = 11, header=None, engine='python')

##-- Create matrix origins and destinations 
maxZone = in_nodeznmeso['maxNatMeso']		
mtxdest = np.arange(1,maxZone+1)								## -- array of consecutive numbers representing matrix destinations
dest = np.tile(mtxdest,maxZone)									## -- array of repeating destination zone pattern
orig = np.repeat(mtxdest,maxZone)								## -- repeated in ascending order for origins
origdf = pd.DataFrame(orig, columns = ['origin'])
origdf.insert(loc=0, column='A',value=np.arange(len(origdf)))
destdf = pd.DataFrame(dest, columns = ['destination'])
destdf.insert(loc=0, column='A',value=np.arange(len(destdf)))
tmplt = origdf.merge(destdf, how='left', on='A', copy=False)

# ---------------------------------------------------------------
# Format input files
# ---------------------------------------------------------------
##-- Format list of rail passthrough POE nodes
temp=in_nodeznmeso['rpass'].replace(',', ',\n')       ##-- Replace 'a' in line with ''
rpass=pd.read_csv(io.StringIO(temp), sep=",", header = None)
rpass.columns=['poeCode', 'newRPOE']
rpass['newRPOE']=0
rpass=rpass.astype({'poeCode':float, 'newRPOE': int})    ##-- Format data types

##-- Format list of truck passthrough POE nodes
temp=in_nodeznmeso['tpass'].replace(',', ',\n')       ##-- Replace 'a' in line with ''
tpass=pd.read_csv(io.StringIO(temp), sep=",", header = None)
tpass.columns=['poeCode', 'newTPOE']
tpass['newTPOE']=0
tpass=tpass.astype({'poeCode':float, 'newTPOE': int})    ##-- Format data types

##-- Format matrix numbers and data names
in_MatNames.columns=['mfnm', 'mf', 'abbrev', 'skip', 'desc']
matNames = in_MatNames.loc[in_MatNames['mf'] >= minMat].copy() 
matNames=matNames[['mf', 'abbrev', 'desc']]
matNames=matNames[matNames['desc'].str.contains('Crude Oil') == False]
matNames=matNames[matNames['desc'].str.contains('Petroleum') == False]
matNames=matNames[matNames['desc'].str.contains('Coal') == False]
matNames['abbrev'] = matNames['abbrev'].str.strip()

numMats = len(matNames)
i=0
print("---> Processing Matrices")
while i < numMats:
    matID = matNames['mf'].loc[matNames.index[i]]
    m1 = ".....Processing mf" + str(matID)
    print(m1)
    pth_mat= os.path.join(inDir2 + "/mf" + str(matNames['mf'].loc[matNames.index[i]]) + ".in" )           ##-- AM Peak skimmed miles 
    in_mat = pd.read_csv(pth_mat, sep = '\s+', skiprows = 4, header=None, engine='python')           ##-- AM Peak skimmed miles 
    mat_in = in_mat.copy()
    mat_in.columns=['origin','dest1', 'val1', 'dest2', 'val2', 'dest3', 'val3']         ##-- Rename columns

    mat_in['dest1'] = mat_in['dest1'].str.replace(':', '')                           ##-- Replace 'a' in line with ''
    mat_in['dest2'] = mat_in['dest2'].str.replace(':', '')                           ##-- Replace 'a' in line with ''
    mat_in['dest3'] = mat_in['dest3'].str.replace(':', '')                           ##-- Replace 'a' in line with ''

    ##-- Create temporary df for each set of OD-Value column pairs
    tmp1=mat_in[['origin', 'dest1','val1']]
    tmp1.columns=['origin', 'dest', 'value']
    tmp2=mat_in[['origin', 'dest2','val2']]
    tmp2.columns=['origin', 'dest', 'value']
    tmp3=mat_in[['origin', 'dest3','val3']]
    tmp3.columns=['origin', 'dest', 'value']
    p_mat = pd.concat([tmp1, tmp2, tmp3])                                ##-- Row bind temporary dfs for final df: origin, destination, value
    
    p_mat=p_mat.dropna()                                               ##-- Remove NAs
    p_mat=p_mat.astype({'origin':int, 'dest': int, 'value': float})    ##-- Format data types
    p_mat.columns=['origin', 'destination', str(matNames['abbrev'].loc[matNames.index[i]])]                   ##-- Rename columns
    p_mat=p_mat.sort_values(['origin', 'destination'])

    ##-- Rename df for manipulation outside loop
    if matNames['mf'].loc[matNames.index[i]]==31:
        mf31 = p_mat.copy()
    if matNames['mf'].loc[matNames.index[i]]==32:
        mf32 = p_mat.copy()
    if matNames['mf'].loc[matNames.index[i]]==33:
        mf33 = p_mat.copy()
    if matNames['mf'].loc[matNames.index[i]]==34:
        mf34 = p_mat.copy()
    if matNames['mf'].loc[matNames.index[i]]==40:
        mf40 = p_mat.copy()
    if matNames['mf'].loc[matNames.index[i]]==41:
        mf41 = p_mat.copy()
    if matNames['mf'].loc[matNames.index[i]]==61:
        mf61 = p_mat.copy()
    if matNames['mf'].loc[matNames.index[i]]==62:
        mf62 = p_mat.copy()
    if matNames['mf'].loc[matNames.index[i]]==63:
        mf63 = p_mat.copy()
    if matNames['mf'].loc[matNames.index[i]]==64:
        mf64 = p_mat.copy()
    if matNames['mf'].loc[matNames.index[i]]==65:
        mf65 = p_mat.copy()
    if matNames['mf'].loc[matNames.index[i]]==66:
        mf66 = p_mat.copy()
    if matNames['mf'].loc[matNames.index[i]]==80:
        mf80 = p_mat.copy()
    
    i=i+1

##-- Format skim POE values to indicate pass through (0) or 1 POE (1)
#- Merge Rail matrices mf61, mf62, and mf64
tmp = pd.merge(mf61, mf62, how='outer', on=['origin','destination'])  ##-- Merge mf61 and m62 
rail = pd.merge(tmp, mf64, how='outer', on=['origin','destination'])  ##-- Merge mf64 with already merged mf61 and 62

#- Check all Rivtt has a value
rail['Rivtt'] = np.where(rail['Rivtt'].isnull(), ((rail['Rtt']*2)*0.8), rail['Rivtt'])   # If Rivtt is NA, set = to 80% of doubled in-vehicle time

#- Redefine the rail poe column meaning in combined rail df
railPOE=pd.merge(rail, rpass, how='left', left_on='Rpoe', right_on='poeCode')
railPOE['Rpoe']=np.where((railPOE['Rpoe']==railPOE['poeCode']) | (railPOE['Rpoe'].isnull()), 0, 1)
railPOE=railPOE[['origin', 'destination', 'Rtt', 'Rivtt', 'Rpoe']]

#- Redefine truck poe column meaning in mf40
truckPOE=pd.merge(mf40, tpass, how='left', left_on='Tpoe', right_on='poeCode')
truckPOE['CmapPsTR']=np.where((truckPOE['Tpoe']==truckPOE['poeCode'])| (truckPOE['Tpoe'].isnull()), 0, 1)
truckPOE=truckPOE[['origin', 'destination','CmapPsTR']]

##-- Merge all skims
inMats=[mf31, mf32, mf33, mf34, truckPOE, mf41, railPOE, mf63, mf65, mf66, mf80]
i=1
for mat in inMats:
    if i == 1:
        skims=tmplt.copy()
        i=i+1
    skims=pd.merge(skims, mat, how='outer', on=['origin', 'destination'])
skims=skims.drop('A', axis=1)


##-- Create composite of node 140 if active
if scenario == '200':
    print('SCENARIO == 200')
    ##-- Reassign origin and destination node ID
    skim140=skims.loc[(skims['origin']==in_nodeznmeso['NewRT']) | (skims['destination']==in_nodeznmeso['NewRT'])].copy() 
    skim140['originF']=np.where(skim140['origin'] == in_nodeznmeso['NewRT'], in_nodeznmeso['comboRT'], skim140['origin'])         ##-- If origin==140, change to 149, otherwise no change
    skim140['destF']=np.where(skim140['destination'] == in_nodeznmeso['NewRT'], in_nodeznmeso['comboRT'], skim140['destination'])      ##-- If destination==140, change to 149, otherwise no change
    skim140=skim140.loc[skim140['originF']!=skim140['destF']]                                                                     ##-- If origin==destination, remove from df
    skim140=skim140[['originF', 'destF', 'Ttt',	'Wtt',	'Tivtt', 'Wivtt', 'CmapPsTR',	'Tdsml', 'Rtt', 'Rivtt', 'Rpoe',	'Rdwl', 'Rtrnf', 'Rdsml', 'Rintyrd']]
    skim140.columns=['origin', 'destination', 'Ttt_newRT',	'Wtt_newRT', 'Tivtt_newRT', 'Wivtt_newRT', 'CmapPsTR_newRT',	
                     'Tdsml_newRT', 'Rtt_newRT', 'Rivtt_newRT', 'Rpoe_newRT', 'Rdwl_newRT', 'Rtrnf_newRT', 'Rdsml_newRT', 'Rintyrd_newRT']
   # skim140=skim140.fillna(0)
    
    ##-- Create df without origin or destination as node 140
    skimNo140=skims.loc[(skims['origin']!=in_nodeznmeso['NewRT']) & (skims['destination']!=in_nodeznmeso['NewRT'])] 

    ##-- Combine adjusted 140 data and non-140 data and select final data
    allSkim=pd.merge(skim140, skimNo140, how='outer', on=['origin', 'destination'])

    allSkim['f_Ttt']=np.where((allSkim['Ttt'] <= allSkim['Ttt_newRT']) | (allSkim['Ttt_newRT'].isnull()), allSkim['Ttt'], allSkim['Ttt_newRT'])
    allSkim['f_Wtt']=np.where((allSkim['Wtt'] <= allSkim['Wtt_newRT']) | (allSkim['Wtt_newRT'].isnull()), allSkim['Wtt'], allSkim['Wtt_newRT'])
    allSkim['f_Tivtt']=np.where((allSkim['Tivtt'] <= allSkim['Tivtt_newRT']) | (allSkim['Tivtt_newRT'].isnull()), allSkim['Tivtt'], allSkim['Tivtt_newRT'])
    allSkim['f_Wivtt']=np.where((allSkim['Wivtt'] <= allSkim['Wivtt_newRT']) | (allSkim['Wivtt_newRT'].isnull()), allSkim['Wivtt'], allSkim['Wivtt_newRT'])
    allSkim['f_Tdsml']=np.where((allSkim['Tdsml'] <= allSkim['Tdsml_newRT']) | (allSkim['Tdsml_newRT'].isnull()), allSkim['Tdsml'], allSkim['Tdsml_newRT'])
    allSkim['f_Rtt']=np.where((allSkim['Rtt'] <= allSkim['Rtt_newRT']) | (allSkim['Rtt_newRT'].isnull()), allSkim['Rtt'], allSkim['Rtt_newRT'])
    allSkim['f_Rivtt']=np.where((allSkim['Rivtt'] <= allSkim['Rivtt_newRT']) | (allSkim['Rivtt_newRT'].isnull()), allSkim['Rivtt'], allSkim['Rivtt_newRT'])
    allSkim['f_Rdsml']=np.where((allSkim['Rdsml'] <= allSkim['Rdsml_newRT']) | (allSkim['Rdsml_newRT'].isnull()), allSkim['Rdsml'], allSkim['Rdsml_newRT'])
    allSkim['f_Rpoe']=np.where((allSkim['Rpoe'] >= allSkim['Rpoe_newRT']) | (allSkim['Rpoe_newRT'].isnull()), allSkim['Rpoe'], allSkim['Rpoe_newRT'])
    allSkim['f_Rdwl']=np.where((allSkim['Rdwl'] >= allSkim['Rdwl_newRT']) | (allSkim['Rdwl_newRT'].isnull()), allSkim['Rdwl'], allSkim['Rdwl_newRT'])

    t=allSkim.copy()
    allSkim=allSkim[['origin', 'destination', 'f_Ttt', 'f_Wtt', 'f_Tivtt', 'f_Wivtt', 'CmapPsTR',	'f_Tdsml', 'f_Rtt', 'f_Rivtt', 'f_Rpoe',	'f_Rdwl', 'Rtrnf', 'f_Rdsml', 'Rintyrd']]
    allSkim.columns=['origin', 'destination', 'Ttt',	'Wtt', 'Tivtt', 'Wivtt', 'CmapPsTR', 'Tdsml', 'Rtt', 'Rivtt', 'Rpoe', 'Rdwl', 'Rtrnf', 'Rdsml', 'Rintyrd']
else:
    allSkim=skims.copy()

##-- Final formatting to remove OD's where all data is NA
NA_cond = (
    (allSkim['Ttt'].isnull() == True) &
    (allSkim['Wtt'].isnull() == True) &
    (allSkim['Tivtt'].isnull() == True) &
    (allSkim['Wivtt'].isnull() == True) &
    (allSkim['CmapPsTR'].isnull() == True) &
    (allSkim['Tdsml'].isnull() == True) &
    (allSkim['Rtt'].isnull() == True) &
    (allSkim['Rivtt'].isnull() == True) &
    (allSkim['Rpoe'].isnull() == True) &
    (allSkim['Rdwl'].isnull() == True) &
    (allSkim['Rtrnf'].isnull() == True) &
    (allSkim['Rdsml'].isnull() == True) &
    (allSkim['Rintyrd'].isnull() == True))

allSkim.loc[NA_cond, 'flagNA'] = 1
allSkim = allSkim.loc[allSkim['flagNA'].isnull()].copy()
allSkim=allSkim.drop('flagNA', axis=1)

##-- Assume rail/truck/water/air service links and routes are the same in both directions
allSkim['Rivtt']=np.where(allSkim['Rivtt'].isnull(), 0, allSkim['Rivtt'])
allSkim['Rdsml']=np.where(allSkim['Rdsml'].isnull(), 0, allSkim['Rdsml'])
allSkim['RAvail'] = np.where(allSkim['Rivtt'] > 0, 1, 0)    ##-- Set rail availability flag
allSkim['WAvail'] = np.where(allSkim['Wtt'] == 0, 0, 1)        ##-- Set water availability flag
allSkim=allSkim.loc[allSkim['origin'] < allSkim['destination']].copy()                       ##-- Filter to keep only instances where o<d; other direction and intrazonals will be added later
allSkim=allSkim.sort_values(['origin', 'destination'])

##-- Separate rail yard info for later
rlyard = allSkim.loc[allSkim['Rintyrd'] > in_nodeznmeso['LTT']].copy()
rlyard=rlyard[['origin', 'destination', 'Rintyrd']]

# ---------------------------------------------------------------
# EXPORT
# ---------------------------------------------------------------
allSkim.to_csv(outskims, index=False)
mf31.to_csv(outMF31, index=False)
mf32.to_csv(outMF32, index=False)
rlyard.to_csv(outRlyard, index=False)

