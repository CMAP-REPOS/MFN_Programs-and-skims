############################################################################################
# STEP3_VERIFY_COSTS_TIMES.py                                                              # 
# kcazzato 09/05/2025 updates                                                              #
# ----- Translated SAS processsing                                                         #
# Craig Heither, rev. 05-06-2016                                                           #
# 03-09-2017: revised to include port summaries for Atlanta, Las Vegas and Cincinnati. 	   #
# 08-30-2017: revised to allow intrazonal inland waterways movements for non-CMAP zones.   #         
#                                                                                          #
# This program                                                                             #
#  - verifies all appropriate modes are available between zone pairs.                      #
#  - creates files to verify that the "best" domestic port logic is reasonable             #                                                                             # 
#                                                                                          #
#-- Input files needed (located in ..\input_data\post_processing\):                #
#	  -            #

#                                                                                          #
#
#-- Output (../output_data/post_processing/)	                                #
#	  - port_detail_review_YYYY.csv      #
#	  - port_summary_review__YYYY.csv      #

#                                                                                          #
############################################################################################

# ---------------------------------------------------------------
# Import Directories
# ---------------------------------------------------------------
import sys, os, shutil, math, yaml, io, random
import time
import pandas as pd, numpy as np

# ---------------------------------------------------------------
# Define paths
# ---------------------------------------------------------------
##-- System inputs
year = sys.argv[1]       ##-- Model run year, used to label output files
scenario = sys.argv[2]

##-- File directories
databaseDir = os.getcwd()            ##-- Database     
inDir = os.path.join(databaseDir + '/input_data/post_processing')          ##-- Database/input_data/post_processing
outDir = os.path.join(databaseDir + '/output_data/post_processing' + "_" + scenario)        ##-- Database/output_data/post_processing

##-- Inputs 
pth_nodeznmeso= os.path.join(inDir + "/node_zone_meso.yaml")           ##-- Zone and node ranges by mode and region (CMAP, logistics, non-CMAP)
pth_modepathcosts = os.path.join(outDir + "/data_all_modepath_costs_" + year + ".csv")

# ---------------------------------------------------------------
# Import Data
# ---------------------------------------------------------------
in_modepathcosts = pd.read_csv(pth_modepathcosts, low_memory=False)
with open(pth_nodeznmeso, 'r') as file:         ##-- Zone and node ranges by mode and region (CMAP, logistics, non-CMAP)
    in_nodeznmeso = yaml.safe_load(file)

# ---------------------------------------------------------------
# Set direct shipment flag
# ---------------------------------------------------------------
in_modepathcosts['direct'] = np.nan

# SET Direct shipment options to:
# intra-CMAP shipments
in_modepathcosts['direct'] = np.where((in_modepathcosts['origin'] <= in_nodeznmeso['LIZ']) & (in_modepathcosts['destination'] <= in_nodeznmeso['LIZ']), 1, in_modepathcosts['direct'])  
# intrazonal shipments (U.S. states)
in_modepathcosts['direct'] = np.where((in_modepathcosts['origin'] == in_modepathcosts['destination']), 1, in_modepathcosts['direct'])

# shipments between the two Hawaiian zones
in_modepathcosts['direct'] = np.where(((in_modepathcosts['origin'] == in_nodeznmeso['Hawaii1']) | (in_modepathcosts['origin'] == in_nodeznmeso['Hawaii2'])) & 
                              ((in_modepathcosts['destination'] == in_nodeznmeso['Hawaii1']) | (in_modepathcosts['destination'] == in_nodeznmeso['Hawaii2'])), 1, in_modepathcosts['direct'])  


# shipments between states (but not between Hawaii and any other state)
in_modepathcosts['direct'] = np.where(((in_modepathcosts['origin'] <= in_nodeznmeso['LEZ']) & 
                               ((in_modepathcosts['origin'] != in_nodeznmeso['Hawaii1']) & (in_modepathcosts['origin'] != in_nodeznmeso['Hawaii2']))) &
                               ((in_modepathcosts['destination'] <= in_nodeznmeso['LEZ']) & 
                               ((in_modepathcosts['destination'] != in_nodeznmeso['Hawaii1']) & (in_modepathcosts['destination'] != in_nodeznmeso['Hawaii2']))), 
                               1, in_modepathcosts['direct'])  

# shipments between the U.S. (except Hawaii) and Canada/Mexico 
in_modepathcosts['direct'] = np.where(((in_modepathcosts['origin'] <= in_nodeznmeso['LEZ']) & 
                               ((in_modepathcosts['origin'] != in_nodeznmeso['Hawaii1']) & (in_modepathcosts['origin'] != in_nodeznmeso['Hawaii2']))) &
                               ((in_modepathcosts['destination'] == in_nodeznmeso['Mexico']) | (in_modepathcosts['destination'] == in_nodeznmeso['Canada'])), 
                               1, in_modepathcosts['direct'])  

in_modepathcosts['direct'] = np.where(((in_modepathcosts['origin'] == in_nodeznmeso['Mexico']) | (in_modepathcosts['origin'] == in_nodeznmeso['Canada'])) &
                              ((in_modepathcosts['destination'] <= in_nodeznmeso['LEZ']) & 
                               ((in_modepathcosts['destination'] != in_nodeznmeso['Hawaii1']) & (in_modepathcosts['destination'] != in_nodeznmeso['Hawaii2']))), 
                              1, in_modepathcosts['direct'])  

# ---------------------------------------------------------------
# Verify Every Pair has at least One Viable Option
# ---------------------------------------------------------------
# takes the original in_modepathcosts dataframe and checks that each origin-destination pair has at least one modepath with non-zero time and cost
v_options = in_modepathcosts.copy()
timecols =  [c for c in v_options.columns if c.startswith('time')] 
costcols = [c for c in v_options.columns if c.startswith('cost')]

v_options['na_count_time'] = v_options[timecols].isna().sum(axis=1)
v_options['na_count_cost'] = v_options[costcols].isna().sum(axis=1)

v_options = v_options.loc[(v_options['na_count_time'] == len(timecols)) | (v_options['na_count_cost'] == len(costcols))].copy()

if len(v_options) > 0:
    print("Movement has NO Time Transport Options")
    print(v_options[['origin', 'destination']])
    sys.exit()

# -----------------------------------------------------------------------------------------------
# Define Functions for different QC checks
# -----------------------------------------------------------------------------------------------
# Inputs: input dataframe, condition for filter, modepath list, string of origin-destination type

# Check for missing data (NA) when data should be present
def qc_MissingData(input_df, condition, modepaths, strOD):
    qc1 = input_df.loc[condition].copy()
    if year!='2022':
        modepaths.append(49)
    for _, row in qc1.iterrows(): 
        for path in modepaths:
            if pd.isnull(row[f'time{path}']):
                print(f"Missing Time Data for {strOD}: ")
                print(row[['origin', 'destination', f'time{path}']])
                sys.exit()
            if pd.isnull(row[f'cost{path}']):
                print(f"Missing Cost Data for {strOD}: ")
                print(row[['origin', 'destination', f'cost{path}']])
                sys.exit()

# Check for data when no data should be there for all modepaths
def qc_badData(input_df, condition, modepaths, strOD):
    qc1 = input_df.loc[condition].copy()
    for _, row in qc1.iterrows(): 
        for path in modepaths:
            if row[f'time{path}'] > 0:
                print(f"Bad Time Data for {strOD}: ")
                print(row[['origin', 'destination', f'time{path}']])
                sys.exit()
            if row[f'cost{path}'] > 0:
                print(f"Bad Cost Data for {strOD}: ")
                print(row[['origin', 'destination', f'cost{path}']])
                sys.exit()

# Check that some modepaths have non-zero max time and cost
def qc_nonZeroMax(input_df, condition, modepaths, strOD):
    qc1 = input_df.loc[condition].copy()
    for path in modepaths:
        maxTime = qc1[f'time{path}'].max()
        maxCost = qc1[f'cost{path}'].max()
        if maxTime == 0:
            print(f"ERROR: No Rail Service Time found for {strOD}: ")
            sys.exit()
        if maxCost == 0:
            print(f"ERROR: No Rail Service Cost found for {strOD}: ")
            sys.exit()    

# -----------------------------------------------------------------------------------------------
# Define Geography Filter Conditions
# -----------------------------------------------------------------------------------------------
# Check non-CMAP U.S. intrazonal movements
nm_nonCMAP_Intra = "non-CMAP U.S. intrazonal movements"
cond_nonCMAP_Intra = (((in_modepathcosts['origin'] <= in_nodeznmeso['LEZ']) & (in_modepathcosts['origin'] >= in_nodeznmeso['FEZ'])) & 
                     (in_modepathcosts['destination'] == in_modepathcosts['origin']))
md_nonCMAP_Intra = [3, 4, 13, 14, 31, 32, 39, 46, 47] # Carload direct/indirect: 3, 4; IMX direct/indirect: 13, 14; FTL direct: 31; FTL indirect: 32; LTL direct: 46; LTL indirect: 39; Air: 47
bd_nonCMAP_Intra = [2, 5, 6, 7, 8, 9, 10, 11, 12, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 33, 34, 35, 36, 37, 38, 40, 41, 42, 43, 44, 45, 48, 49, 50, 51, 52, 53, 54]

# -----------------------------------------------------------------------------------------------
# Check Canada to CMAP
nm_Canada_CMAP = "Canada to CMAP movements"
cond_Canada_CMAP = ((in_modepathcosts['origin'] == in_nodeznmeso['Canada'])& 
                     (in_modepathcosts['destination'] <= in_nodeznmeso['LIZ']))
md_Canada_CMAP = [1, 2, 31, 46, 47, 48, 50]
bd_Canada_CMAP = [51, 52, 53, 54]
nzMax_Canada_CMAP = list(range(3,31))

# -----------------------------------------------------------------------------------------------
# Check Canada to non-CMAP U.S. 
cond_CanadaNonCMAP = ((in_modepathcosts['origin'] == in_nodeznmeso['Canada'])& 
                     ((in_modepathcosts['destination'] <= in_nodeznmeso['LEZ']) & (in_modepathcosts['destination'] >= in_nodeznmeso['FEZ'])))
# EXCLUDE HAWAII
nm_Canada_NonCMAP_NH = "Canada to non-CMAP U.S. movements - Excluding Hawaii"
cond_Canada_NonCMAP_NH = ((cond_CanadaNonCMAP)&
                     (in_modepathcosts['destination'] != in_nodeznmeso['Hawaii1']) & (in_modepathcosts['destination'] != in_nodeznmeso['Hawaii2']))
md_Canada_NonCMAP_NH = [31, 46, 47, 51, 52, 53, 54] # Minimum Options available to all zones should be: FTL direct [31], LTL direct [46], air [47], international water [51-54]
bd_Canada_NonCMAP_NH = [2, 48, 50]  # No CMAP water [2 only] or air [48-50] should be available


# EXCLUDE HAWAII and ALASKA
nm_Canada_NonCMAP_NHA = "Canada to non-CMAP U.S. movements - Excluding Hawaii and Alaska"
cond_Canada_NonCMAP_NHA = ((cond_Canada_NonCMAP_NH)& (in_modepathcosts['destination'] != in_nodeznmeso['Alaska']))
nzMax_Canada_NonCMAP_NHA = list(range(3,31))

# ALASKA ONLY
nm_Canada_Alaska = "Canada to Alaska movements"
cond_Canada_Alaska = ((cond_CanadaNonCMAP)& (in_modepathcosts['destination'] == in_nodeznmeso['Alaska']))
bd_Canada_Alaska = list(range(3,31))

# CANADA TO HAWAII ONLY
nm_Canada_Hawaii = "Canada to Hawaii movements"
cond_Canada_Hawaii = ((cond_CanadaNonCMAP)&((in_modepathcosts['destination'] == in_nodeznmeso['Hawaii1']) | (in_modepathcosts['destination'] == in_nodeznmeso['Hawaii2'])))
md_Canada_Hawaii = [47, 51, 52, 53]
bd_Canada_Hawaii = list(range(1,47)) + list(range(48,51))

# -----------------------------------------------------------------------------------------------
# Check Mexico to CMAP
nm_Mexico_CMAP = "Mexico to CMAP movements"
cond_Mexico_CMAP = ((in_modepathcosts['origin'] == in_nodeznmeso['Mexico']) & (in_modepathcosts['destination'] <= in_nodeznmeso['LIZ']))
md_Mexico_CMAP = [1, 2, 31, 46, 47, 48, 50]
bd_Mexico_CMAP = [51, 52, 53, 54]
nzMax_Mexico_CMAP = list(range(3,31))

# -----------------------------------------------------------------------------------------------
# Check Mexico to non-CMAP U.S.
cond_Mexico_NonCMAP = ((in_modepathcosts['origin'] == in_nodeznmeso['Mexico'])& 
                     ((in_modepathcosts['destination'] <= in_nodeznmeso['LEZ']) & (in_modepathcosts['destination'] >= in_nodeznmeso['FEZ'])))

# EXCLUDE HAWAII
nm_Mexico_NonCMAP_NH = "Mexico to non-CMAP U.S. movements - Excluding Hawaii"
cond_Mexico_NonCMAP_NH = ((cond_Mexico_NonCMAP)& (in_modepathcosts['destination'] != in_nodeznmeso['Hawaii1']) & (in_modepathcosts['destination'] != in_nodeznmeso['Hawaii2']))
md_Mexico_NonCMAP_NH = [31, 46, 47, 51, 52, 53, 54]   # Minimum Options available to all zones should be: FTL direct [31], LTL direct [46], air [47], international water [51-54]
bd_Mexico_NonCMAP_NH = [2, 48, 50]   # No CMAP water [2 only] or air [48-50] should be available


# EXCLUDE HAWAII and ALASKA
nm_Mexico_NonCMAP_NHA = "Mexico to non-CMAP U.S. movements - Excluding Hawaii and Alaska"
cond_Mexico_NonCMAP_NHA = ((cond_Mexico_NonCMAP_NH)& (in_modepathcosts['destination'] != in_nodeznmeso['Alaska']))
nzMax_Mexico_NonCMAP_NHA = list(range(3,31))

# ALASKA ONLY
nm_Mexico_Alaska = "Mexico to Alaska movements"
cond_Mexico_Alaska = ((cond_Mexico_NonCMAP)& (in_modepathcosts['destination'] == in_nodeznmeso['Alaska']))
bd_Mexico_Alaska = list(range(3,31))

# -----------------------------------------------------------------------------------------------
# Check Hawaii to everywhere except Hawaii
cond_Hawaii_notHawaii = (((in_modepathcosts['origin'] == in_nodeznmeso['Hawaii1']) | (in_modepathcosts['origin'] == in_nodeznmeso['Hawaii2']))& 
                     ((in_modepathcosts['destination'] != in_nodeznmeso['Hawaii1']) & (in_modepathcosts['destination'] != in_nodeznmeso['Hawaii2'])))

# HAWAII to CMAP ZONES
nm_Hawaii_CMAP = "Hawaii to CMAP movements"
cond_Hawaii_CMAP = ((cond_Hawaii_notHawaii) & (in_modepathcosts['destination'] <= in_nodeznmeso['LIZ']))
md_Hawaii_CMAP = [47, 48, 50, 51, 52, 53, 54]    # ONLY air [47-50] and international water [51-54] should be available to CMAP zones
bd_Hawaii_CMAP = list(range(1,47))

# HAWAII to NON-CMAP ZONES
nm_Hawaii_NonCMAP = "Hawaii to non-CMAP movements"
cond_Hawaii_NonCMAP = ((cond_Hawaii_notHawaii) & (in_modepathcosts['destination'] > in_nodeznmeso['LIZ']))
md_Hawaii_NonCMAP = [47, 51, 52, 53, 54]   # ONLY air [47] and international water [51-54] should be available to non-CMAP zone
bd_Hawaii_NonCMAP = list(range(1,47)) + list(range(48,51))
     
# -----------------------------------------------------------------------------------------------
# Check Alaska to everywhere except Alaska
cond_Alaska_notAlaska = ((in_modepathcosts['origin'] == in_nodeznmeso['Alaska']) & (in_modepathcosts['destination'] != in_nodeznmeso['Alaska']))

# ALASKA to CMAP ZONES
nm_Alaska_CMAP = "Alaska to CMAP movements"
cond_Alaska_CMAP = ((cond_Alaska_notAlaska) & (in_modepathcosts['destination'] <= in_nodeznmeso['LIZ']))
md_Alaska_CMAP = [31, 46, 47, 48, 50, 51, 52, 53, 54]   # Minimum Options available to all zones should be: FTL direct [31], LTL direct [46], air [47-50], international water [51-54]
bd_Alaska_CMAP = list(range(1,31))   # No CMAP water [1-2] or rail [3-30] should be available

# ALASKA to NON-CMAP ZONES
nm_Alaska_NonCMAP = "Alaska to non-CMAP movements"
cond_Alaska_NonCMAP = ((cond_Alaska_notAlaska) & 
                       ((in_modepathcosts['destination'] > in_nodeznmeso['LIZ']) & (in_modepathcosts['destination'] <= in_nodeznmeso['LEZ'])) &
                       ((in_modepathcosts['destination'] != in_nodeznmeso['Hawaii1']) & (in_modepathcosts['destination'] != in_nodeznmeso['Hawaii2']))
                       )
md_Alaska_NonCMAP = [31, 46, 47, 51, 52, 53, 54]  # Minimum Options available to all zones should be: FTL direct [31], LTL direct [46], air [47], international water [51-54]
bd_Alaska_NonCMAP = list(range(1,31)) + list(range(48,51)) # No CMAP water [1-2], rail [3-30] or air [48-50] should be available 

# ALASKA TO FOREIGN ZONES (except Canada/Mexico and Hawaii)
nm_Alaska_Foreign = "Alaska to foreign movements (except Canada/Mexico and Hawaii)"
cond_Alaska_Foreign = ((cond_Alaska_notAlaska) & 
                       ((in_modepathcosts['destination'] > in_nodeznmeso['LEZ'])) &
                       ((in_modepathcosts['destination'] != in_nodeznmeso['Hawaii1']) & (in_modepathcosts['destination'] != in_nodeznmeso['Hawaii2'])) &
                       (in_modepathcosts['destination'] != in_nodeznmeso['Canada']) &
                       (in_modepathcosts['destination'] != in_nodeznmeso['Mexico']))
md_Alaska_Foreign = [47, 51, 52, 53, 54]  # ONLY air [47] and international water [51-54] should be available to foreign zones
bd_Alaska_Foreign = list(range(1,47)) + list(range(48,51)) 

# -----------------------------------------------------------------------------------------------
# Check U.S. to Foreign
cond_US_Foreign = ((in_modepathcosts['origin'] <= in_nodeznmeso['LEZ']) &
                   ((in_modepathcosts['origin'] != in_nodeznmeso['Alaska']) & 
                    (in_modepathcosts['origin'] != in_nodeznmeso['Hawaii1']) & (in_modepathcosts['origin'] != in_nodeznmeso['Hawaii2'])) &
                   (in_modepathcosts['destination'] > in_nodeznmeso['LEZ']) &
                   ((in_modepathcosts['destination'] != in_nodeznmeso['Canada']) & (in_modepathcosts['destination'] != in_nodeznmeso['Mexico'])))

# FOREIGN to CMAP ZONES
nm_Foreign_CMAP = "Foreign to CMAP movements"
cond_Foreign_CMAP = ((cond_US_Foreign) & (in_modepathcosts['destination'] <= in_nodeznmeso['LIZ']))
md_Foreign_CMAP = [47, 48, 50, 51, 52, 53, 54]   # ONLY air [47-50] and international water [51-54] should be available to foreign zones
bd_Foreign_CMAP = list(range(1,47))   

# FOREIGN to NON-CMAP ZONES
nm_Foreign_NonCMAP = "Foreign to non-CMAP movements"
cond_Foreign_NonCMAP = ((cond_Foreign_CMAP) & (in_modepathcosts['destination'] > in_nodeznmeso['LIZ']))
md_Foreign_NonCMAP =  [47, 51, 52, 53, 54]   # ONLY air [47] and international water [51-54] should be available to foreign zones
bd_Foreign_NonCMAP = list(range(1,47)) + list(range(48,51))  

# -----------------------------------------------------------------------------------------------
# Check non-CMAP U.S. to non-CMAP U.S. (excluding Alaska/Hawaii)
nm_nonCMAP_nonCMAP = "non-CMAP U.S. to non-CMAP U.S. (excluding Alaska/Hawaii) movements"
cond_nonCMAP_nonCMAP  = (((in_modepathcosts['origin'] > in_nodeznmeso['LIZ']) & (in_modepathcosts['origin'] <= in_nodeznmeso['LEZ'])) &
                         ((in_modepathcosts['origin'] != in_nodeznmeso['Alaska']) & 
                          (in_modepathcosts['origin'] != in_nodeznmeso['Hawaii1']) & (in_modepathcosts['origin'] != in_nodeznmeso['Hawaii2'])) &
                         ((in_modepathcosts['destination'] > in_nodeznmeso['LIZ']) & (in_modepathcosts['destination'] <= in_nodeznmeso['LEZ'])) &
                         ((in_modepathcosts['destination'] != in_nodeznmeso['Alaska']) & 
                          (in_modepathcosts['destination'] != in_nodeznmeso['Hawaii1']) & (in_modepathcosts['destination'] != in_nodeznmeso['Hawaii2'])))
md_nonCMAP_nonCMAP  = [31, 32, 39, 46, 47]   # AT A MINIMUM: FTL direct/indirect [31,32], LTL direct/indirect [46,39] and non-CMAP air [47] must be available
bd_nonCMAP_nonCMAP = [2] + list(range(5,13)) + list(range(15, 31)) + list(range(33,39)) + list(range(40,46)) + list(range(48,55))
nzMax_nonCMAP_nonCMAP  = [1, 3, 4, 13, 14]

# -----------------------------------------------------------------------------------------------
# Verify Mode Options for DIRECT Shipments
nm_verifyDirect = "MINIMUM ALLOWABLE DIRECT MODES"
cond_verifyDirect  = (in_modepathcosts['direct'] == 1)
md_verifyDirect = [31, 46]

# -----------------------------------------------------------------------------------------------
# Verify shipments between CMAP & Rest of U.S. (except Hawaii)/Canada/Mexico
nm_verifyIntra = 'MINIMUM ALLOWABLE INDIRECT modes: between CMAP & Rest of U.S. (except Hawaii)/Canada/Mexico'
cond_verifyIntra = (((in_modepathcosts['origin'] <= in_nodeznmeso['LIZ']) &
                    (((in_modepathcosts['destination'] > in_nodeznmeso['LIZ']) & (in_modepathcosts['destination'] <= in_nodeznmeso['LEZ'])) | 
                     ((in_modepathcosts['destination'] == in_nodeznmeso['Alaska']) | (in_modepathcosts['destination'] == in_nodeznmeso['Canada'])))) &
                    ((in_modepathcosts['destination'] != in_nodeznmeso['Hawaii1']) & (in_modepathcosts['destination'] != in_nodeznmeso['Hawaii2'])))
md_verifyIntra = [32, 39, 47]

# -----------------------------------------------------------------------------------------------
# Verify shipments between Rest of U.S. (except Hawaii)/Canada/Mexico & CMAP
nm_verifyIntra2 = 'MINIMUM ALLOWABLE INDIRECT modes: between Rest of U.S. (except Hawaii)/Canada/Mexico & CMAP'
cond_verifyIntra2 = (((in_modepathcosts['destination'] <= in_nodeznmeso['LIZ']) &
                    (((in_modepathcosts['origin'] > in_nodeznmeso['LIZ']) & (in_modepathcosts['origin'] <= in_nodeznmeso['LEZ'])) | 
                     ((in_modepathcosts['origin'] == in_nodeznmeso['Alaska']) | (in_modepathcosts['origin'] == in_nodeznmeso['Canada'])))) &
                    ((in_modepathcosts['origin'] != in_nodeznmeso['Hawaii1']) & (in_modepathcosts['origin'] != in_nodeznmeso['Hawaii2'])))
md_verifyIntra2 = [32, 39, 47]

# -----------------------------------------------------------------------------------------------
# Verify U.S.-Foreign (except Canada/Mexico) shipments
nm_verifyIntra3 = 'MINIMUM ALLOWABLE INDIRECT modes: U.S.-Foreign (except Canada/Mexico) shipments'
cond_verifyIntra3 = ((((in_modepathcosts['origin'] <= in_nodeznmeso['LEZ']) & (in_modepathcosts['destination'] > in_nodeznmeso['LEZ'])) & 
                     ((in_modepathcosts['destination'] != in_nodeznmeso['Mexico']) & (in_modepathcosts['destination'] != in_nodeznmeso['Canada']))) |
                     (((in_modepathcosts['origin'] > in_nodeznmeso['LEZ']) & (in_modepathcosts['destination'] <= in_nodeznmeso['LEZ'])) & 
                     ((in_modepathcosts['origin'] != in_nodeznmeso['Mexico']) & (in_modepathcosts['origin'] != in_nodeznmeso['Canada'])))
                     )
md_verifyIntra3 = [47, 51, 52, 53, 54]

# -----------------------------------------------------------------------------------------------
# Add logistics node 149 modepath as option where necessary
addLogo = [md_Canada_CMAP, bd_Canada_NonCMAP_NH, md_Mexico_CMAP, bd_Mexico_NonCMAP_NH, md_Hawaii_CMAP,
           md_Alaska_CMAP, md_Foreign_CMAP]
if year!='2022':
    for lst in addLogo:
        lst.append(49)


# In[148]:


# ---------------------------------------------------------------
# Define Dictionaries to loop through 
# ---------------------------------------------------------------
dict_missingData = {
    'nonCMAP_Intra': [nm_nonCMAP_Intra, cond_nonCMAP_Intra, md_nonCMAP_Intra],
    'Canada_CMAP': [nm_Canada_CMAP, cond_Canada_CMAP, md_Canada_CMAP],
    'Canada_NonCMAP_NH':[nm_Canada_NonCMAP_NH, cond_Canada_NonCMAP_NH, md_Canada_NonCMAP_NH],
    'Canada_Hawaii':[nm_Canada_Hawaii, cond_Canada_Hawaii, md_Canada_Hawaii],
    'Mexico_CMAP':[nm_Mexico_CMAP, cond_Mexico_CMAP, md_Mexico_CMAP],
    'Mexico_NonCMAP_NH':[nm_Mexico_NonCMAP_NH, cond_Mexico_NonCMAP_NH, md_Mexico_NonCMAP_NH],
    'Hawaii_CMAP':[nm_Hawaii_CMAP, cond_Hawaii_CMAP, md_Hawaii_CMAP],
    'Hawaii_NonCMAP':[nm_Hawaii_NonCMAP, cond_Hawaii_NonCMAP, md_Hawaii_NonCMAP],
    'Alaska_CMAP':[nm_Alaska_CMAP, cond_Alaska_CMAP, md_Alaska_CMAP],
    'Alaska_NonCMAP':[nm_Alaska_NonCMAP, cond_Alaska_NonCMAP, md_Alaska_NonCMAP],
    'Alaska_Foreign':[nm_Alaska_Foreign, cond_Alaska_Foreign, md_Alaska_Foreign],
    'Foreign_CMAP':[nm_Foreign_CMAP, cond_Foreign_CMAP, md_Foreign_CMAP],
    'Foreign_NonCMAP':[nm_Foreign_NonCMAP, cond_Foreign_NonCMAP, md_Foreign_NonCMAP],
    'nonCMAP_nonCMAP':[nm_nonCMAP_nonCMAP, cond_nonCMAP_nonCMAP, md_nonCMAP_nonCMAP],
    'verifyDirect':[nm_verifyDirect, cond_verifyDirect, md_verifyDirect],
    'verifyIntra':[nm_verifyIntra, cond_verifyIntra, md_verifyIntra],
    'verifyIntra2':[nm_verifyIntra2, cond_verifyIntra2, md_verifyIntra2],
    'verifyIntra3':[nm_verifyIntra3, cond_verifyIntra3, md_verifyIntra3]
    
}

dict_badData = {
    'nonCMAP_Intra': [nm_nonCMAP_Intra, cond_nonCMAP_Intra, bd_nonCMAP_Intra],
    'Canada_CMAP': [nm_Canada_CMAP, cond_Canada_CMAP, bd_Canada_CMAP],
    'Canada_NonCMAP_NH':[nm_Canada_NonCMAP_NH, cond_Canada_NonCMAP_NH, bd_Canada_NonCMAP_NH],
    'Canada_Alaska':[nm_Canada_Alaska, cond_Canada_Alaska, bd_Canada_Alaska],
    'Canada_Hawaii':[nm_Canada_Hawaii, cond_Canada_Hawaii, bd_Canada_Hawaii],
    'Mexico_CMAP':[nm_Mexico_CMAP, cond_Mexico_CMAP, bd_Mexico_CMAP],
    'Mexico_NonCMAP_NH':[nm_Mexico_NonCMAP_NH, cond_Mexico_NonCMAP_NH, bd_Mexico_NonCMAP_NH],
    'Mexico_NonCMAP_Alaska':[nm_Mexico_Alaska, cond_Mexico_Alaska, bd_Mexico_Alaska],
    'Hawaii_CMAP':[nm_Hawaii_CMAP, cond_Hawaii_CMAP, bd_Hawaii_CMAP],
    'Hawaii_NonCMAP':[nm_Hawaii_NonCMAP, cond_Hawaii_NonCMAP, bd_Hawaii_NonCMAP],
    'Alaska_CMAP':[nm_Alaska_CMAP, cond_Alaska_CMAP, bd_Alaska_CMAP],
    'Alaska_NonCMAP':[nm_Alaska_NonCMAP, cond_Alaska_NonCMAP, bd_Alaska_NonCMAP],
    'Alaska_Foreign':[nm_Alaska_Foreign, cond_Alaska_Foreign, bd_Alaska_Foreign],
    'Foreign_CMAP':[nm_Foreign_CMAP, cond_Foreign_CMAP, bd_Foreign_CMAP],
    'Foreign_NonCMAP':[nm_Foreign_NonCMAP, cond_Foreign_NonCMAP, bd_Foreign_NonCMAP],
    'nonCMAP_nonCMAP':[nm_nonCMAP_nonCMAP, cond_nonCMAP_nonCMAP, bd_nonCMAP_nonCMAP]
    
}

dict_nonZeroMax = {
    'nonCMAP_Intra': [nm_nonCMAP_Intra, cond_nonCMAP_Intra, nzMax_Canada_CMAP],
    'Canada_NonCMAP_NHA':[nm_Canada_NonCMAP_NHA, cond_Canada_NonCMAP_NHA, nzMax_Canada_NonCMAP_NHA],
    'Mexico_CMAP':[nm_Mexico_CMAP, cond_Mexico_CMAP, nzMax_Mexico_CMAP],
    'Mexico_NonCMAP_NHA':[nm_Mexico_NonCMAP_NHA, cond_Mexico_NonCMAP_NHA, nzMax_Mexico_NonCMAP_NHA],
    'nonCMAP_nonCMAP':[nm_nonCMAP_nonCMAP, cond_nonCMAP_nonCMAP, nzMax_nonCMAP_nonCMAP]
}


# In[149]:


# ---------------------------------------------------------------
# Run QC Checks
# ---------------------------------------------------------------
# Run missing data
print("---> Running missing data check")
for ODpair in dict_missingData:
    qc_MissingData(in_modepathcosts, dict_missingData[ODpair][1], dict_missingData[ODpair][2], dict_missingData[ODpair][0])

# Run bad data
print("---> Running bad data check")
for ODpair in dict_badData:
    qc_badData(in_modepathcosts, dict_badData[ODpair][1], dict_badData[ODpair][2], dict_badData[ODpair][0])

# Run non-zero max
print("---> Running non-zero max data check")
for ODpair in dict_nonZeroMax:
    qc_nonZeroMax(in_modepathcosts, dict_nonZeroMax[ODpair][1], dict_nonZeroMax[ODpair][2], dict_nonZeroMax[ODpair][0])

