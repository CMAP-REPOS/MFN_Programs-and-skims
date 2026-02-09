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
import sys, os, shutil, math, yaml, io, random, csv
import time
import pandas as pd, numpy as np

# ---------------------------------------------------------------
# Define paths
# ---------------------------------------------------------------
##-- System inputs
year = sys.argv[1]       ##-- Model run year, used to label output files
scenario = sys.argv[2]

##-- File directories
databaseDir = os.getcwd()          ##-- Database     
inDir = os.path.join(databaseDir + '/input_data/post_processing')          ##-- Database/input_data/post_processing
outDir = os.path.join(databaseDir + '/output_data/post_processing' + "_" + scenario)        ##-- Database/output_data/post_processing

##-- Inputs 
pth_nodeznmeso= os.path.join(databaseDir + "/input_data/constants/node_zone_meso.yaml")           ##-- Zone and node ranges by mode and region (CMAP, logistics, non-CMAP)
pth_modepathcosts = os.path.join(outDir + "/data_all_modepath_costs_" + year + ".csv")

##-- Outputs
outPortSummary= os.path.join(outDir + "/port_summary_review_" + year + ".csv")   ##-- Outpath for port summary file

# ---------------------------------------------------------------
# Import Data
# ---------------------------------------------------------------
in_modepathcosts = pd.read_csv(pth_modepathcosts, low_memory=False)
with open(pth_nodeznmeso, 'r') as file:         ##-- Zone and node ranges by mode and region (CMAP, logistics, non-CMAP)
    in_nodeznmeso = yaml.safe_load(file)


# In[43]:


portData = in_modepathcosts.loc[~pd.isnull(in_modepathcosts['GCD'])]
portData = portData[['origin','destination', 'Port_NameNB', 'Port_mesozoneNB','Port_NameB', 'Port_mesozoneB']]


# In[57]:


def port_summary(inDF, origins, destinations, label):
    print(label)
    sumData = inDF.loc[(inDF['origin'].isin(origins)) & (inDF['destination'].isin(destinations))].copy()
    sumDataB = sumData.copy()
    sumDataNB = sumData.copy()

    sumDataB['Frequency'] = sumDataB.groupby(['Port_NameNB', 'Port_mesozoneNB'])['origin'].transform('count')
    sumDataNB['Frequency'] = sumDataNB.groupby(['Port_NameB', 'Port_mesozoneB'])['origin'].transform('count')

    sumDataB = sumDataB[['Port_NameB', 'Port_mesozoneB', 'Frequency']].drop_duplicates().reset_index(drop=True)
    sumDataNB = sumDataNB[['Port_NameNB', 'Port_mesozoneNB', 'Frequency']].drop_duplicates().reset_index(drop=True)

    sumDataB['Port_OD'] = label
    sumDataNB['Port_OD'] = label

    sumDataB['Category'] = 'Bulk'
    sumDataNB['Category'] = 'Non-Bulk'

    sumDataB= sumDataB[['Port_OD', 'Category', 'Port_NameB', 'Port_mesozoneB', 'Frequency']]
    sumDataNB= sumDataNB[['Port_OD', 'Category', 'Port_NameNB', 'Port_mesozoneNB', 'Frequency']]

    sumDataB.to_csv(outPortSummary, mode="a", header=False, index=False)
    sumDataNB.to_csv(outPortSummary, mode="a", header=False, index=False)


# In[ ]:


# Ports
kansasCity = [189, 209]
chicago = [1,20,33,42,49,58,62,71,78,85,87,109,127,128,129]
denver = [164]
atlanta = [176]
lasvegas = [214]
cincinnati = [231]

# Other areas
eastAsia = [316,374,403,418,456]
europe = [275,285,291,292,304,324,328,330,339,344,345,350,353,364,370,372,382,388,412,419,430,431,434,435,446,451,452,458,463,464,469,481,483]
restAmerica = [281,283,293,297,300,302,310,312,315,319,323,333,334,336,356,359,360,363,373,399,414,424,426,427,484,487]


# In[63]:


dict_ports = {
    'Kansas City' : [189, 209],
    'Chicago': [1,20,33,42,49,58,62,71,78,85,87,109,127,128,129],
    'Denver' : [164],
    'Atlanta': [176],
    'Las Vegas' : [214],
    'Cincinnati' : [231]
}

dict_areas = {
    'Eastern Asia' : [316,374,403,418,456],
    'Europe': [275,285,291,292,304,324,328,330,339,344,345,350,353,364,370,372,382,388,412,419,430,431,434,435,446,451,452,458,463,464,469,481,483],
    'Rest of America': [281,283,293,297,300,302,310,312,315,319,323,333,334,336,356,359,360,363,373,399,414,424,426,427,484,487]
}


# In[66]:


with open(outPortSummary, "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["Port_OD_Area", "Category", "Port_Name", "Port_mesozone", 'Frequency'])

for port in dict_ports:
    for area in dict_areas:
        name = "---> Checking " + port + ' to ' + area
        port_summary(portData, dict_ports[port], dict_areas[area], name)

