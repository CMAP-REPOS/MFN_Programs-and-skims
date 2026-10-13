
## to add context ##
# ---------------------------------------------------------------
# Import Directories
# ---------------------------------------------------------------
import sys, os, shutil, math, yaml, io, random
from datetime import datetime
import pandas as pd, numpy as np

# ---------------------------------------------------------------
# SET PATHS
# ---------------------------------------------------------------
##-- System inputs
year= sys.argv[1]     ##-- Skim year
scenario = sys.argv[2]

##-- File directories
databaseDir = os.getcwd()      ##-- Database     
inDir = os.path.join(databaseDir + '/input_data/post_processing')    ##-- Database/input_data/post_processing
outDir = os.path.join(databaseDir + '/output_data/post_processing' + "_" + scenario)      ##-- Database/output_data/post_processing
outTempDir = os.path.join(outDir + '/tempOut/')

##-- Inputs 
pth_rlyard = os.path.join(outTempDir + "/rlyard_" + year + ".csv") 
pth_emskim = os.path.join(outTempDir + "/emskim_" + year + ".csv") 
pth_railGCD = os.path.join(outTempDir + "/railGCD_" + year + ".csv") 
pth_waterI = os.path.join(outTempDir + "/skims_adjWater_" + year + ".csv") 
pth_intdr = os.path.join(outTempDir + "/outWaterintdr_" + year + ".csv") 
pth_inland = os.path.join(outTempDir + "/waterInland_" + year + ".csv") 
pth_gcd= os.path.join(outDir + "/data_mesozone_gcd_" + year + ".csv")              ##-- GCD file created during STEP1
pth_mf31=os.path.join(outTempDir + "/mf31_formatted_" + year+".csv")
pth_nodeznmeso= os.path.join(databaseDir + "/input_data/constants/node_zone_meso.yaml")           ##-- Zone and node ranges by mode and region (CMAP, logistics, non-CMAP)
pth_sptime= os.path.join(databaseDir + "/input_data/constants/speeds_and_time.yaml")      ##-- Speeds (MPH), handling time (hours), and dwell time at interchanges (hours) as constants
pth_charges= os.path.join(databaseDir + "/input_data/constants/charges.yaml")             ##-- Handling charges, linehaul charges, and surcharges constants

##-- Outputs
pth_outTimeCosts= os.path.join(outTempDir + "/data_modepath_skim1_"+year + ".csv")         ##-- New output file of modepath skim costs and times 
pth_outModeDist= os.path.join(outTempDir + "/data_modepath_miles1_"+year + ".csv")     
pth_outPorts= os.path.join(outDir + "/data_modepath_ports_"+year + ".csv")     
pth_outAirports= os.path.join(outDir + "/data_modepath_airports_"+year + ".csv")     
pth_outMesoSkim= os.path.join(outDir + "/data_mesozone_skims_"+year + ".csv")    
pth_outModeCosts = os.path.join(outDir + "/data_all_modepath_costs_" + year + ".csv")

##-- Constants
rlLogos = [147, 148, 149, 150]
rlDwlCodes = {
    1: 'MemphisCong',
    2: 'NewOrleansCong',
    3: 'StLouisCong',
    4: 'KansasCityCong'
}

# ---------------------------------------------------------------
# IMPORT DATA
# ---------------------------------------------------------------
in_rlyard= pd.read_csv(pth_rlyard)     ##-- 
in_emskim= pd.read_csv(pth_emskim)     ##-- 
in_railGCD= pd.read_csv(pth_railGCD)           ##--
in_waterI=pd.read_csv(pth_waterI, low_memory=False)
in_intdr=pd.read_csv(pth_intdr)
in_inland=pd.read_csv(pth_inland)
in_gcd= pd.read_csv(pth_gcd)     ##-- Top 30 US ports for international shipping (based on 2013 tonnage, including total foreign tonnage [imports+exports])
in_mf31=pd.read_csv(pth_mf31)
with open(pth_nodeznmeso, 'r') as file:         ##-- Zone and node ranges by mode and region (CMAP, logistics, non-CMAP)
    in_nodeznmeso = yaml.safe_load(file)
with open(pth_sptime, 'r') as file:             ##-- Speeds (MPH), handling time (hours), and dwell time at interchanges (hours) as constants
    in_sptime = yaml.safe_load(file)
with open(pth_charges, 'r') as file:            ##-- Handling charges, linehaul charges, and surcharges constants
    in_charges = yaml.safe_load(file)

inDF = in_waterI.copy()
view = inDF.loc[((inDF['origin']==310) & (inDF['destination']==151)) | ((inDF['destination']==310) & (inDF['origin']==151))].copy()
view[['origin', 'destination', 'GCD']]

# ---------------------------------------------------------------
# DEFINE FUNCTIONS
# ---------------------------------------------------------------
def timelapse_records(startTime, totRows, rowRem):
    # Format start time
    startSeconds = (startTime.hour*60*60) + (startTime.minute*60)+ startTime.second

    # Format current time
    currentTime = datetime.now()
    currentSeconds = (currentTime.hour*60*60) + (currentTime.minute*60)+ currentTime.second

    # Calculate time passed
    timeElapsed = round((currentSeconds - startSeconds)/60, 2)

    # Format output message
    mes0 = "     - Rows processed: " + str(totRows)
    mes1 = "     - Remaining rows: " + str(rowRem)
    mes2 = "     - Time elapsed: " + str(timeElapsed) +" minutes"
    if is_divisible_by_50k(rowRem):
        print(mes0)
        print(mes1)
        print(mes2)

def is_divisible_by_50k(num):
    return num % 50000 == 0

# ---------------------------------------------------------------
# COMBINE ALL SKIM DATA
# ---------------------------------------------------------------
updatedi = pd.merge(in_waterI, in_intdr, how='outer', on=['origin', 'destination'], suffixes=('', '_new'))

# Update missing values in data for columns with the same name in the two dfs
dupNames = [col for col in updatedi.columns if '_new' in col]
dupNames = [s.replace('_new', '') for s in dupNames]
for nm in dupNames:
    longnm = nm + "_new"
    updatedi[nm] = updatedi[nm].combine_first(updatedi[longnm]) # Update missing values
    updatedi = updatedi.drop(columns=[longnm])# Drop the temporary column

# Keep only the last row of each origin-destination group (will have the largest Tdist00)
updatedi = updatedi.sort_values(by=['origin', 'destination', 'Tdist00'])
lasti = updatedi.groupby(['origin', 'destination'], as_index=False).last() #.reset_index()  # Keep only the last row in each origin-destination group

# Merge with additional data
allData = pd.merge(lasti, in_emskim, how='left', on=['origin', 'destination'])
allData = pd.merge(allData, in_inland, how='left', on=['origin', 'destination'])
allData = pd.merge(allData, in_rlyard, how='left', on=['origin', 'destination'])

# Format fields
allData['Tdist00']=np.where( (allData['Tdist00'].isnull()) & (allData['EmDist'] > 0), allData['EmDist'], allData['Tdist00'])
allData['Tdsml00']=np.where( (allData['Tdsml00'].isnull()) & 
                            ((allData['origin'] <= in_nodeznmeso['LEZ']) & (allData['destination'] <= in_nodeznmeso['LEZ'])), allData['EmDist'], allData['Tdsml00'])

allData['zero'] = 0
allData['CmapPsRL']=allData[['CmapPsRL', 'zero']].max(axis=1) 
allData['CmapPsTR']=allData[['CmapPsTR', 'zero']].max(axis=1) 
allData['Rtrnf']=allData[['Rtrnf', 'zero']].max(axis=1) 
allData['Rdwl']=allData[['Rdwl', 'zero']].max(axis=1) 

# Merge with rail and water GCD
allData = pd.merge(allData, in_railGCD, how='left', on = 'destination')

# ---------------------------------------------------------------
# ASSIGN RAIL DWELL HOURS
# ---------------------------------------------------------------
# Assign rail dwell hours
# only keep intermediate rail yard for actual pass-through routes or those beginning/ending in CMAP 08-11-2017
allData['Rintyrd']=np.where((allData['CmapPsRL'] == 0) & ((allData['origin'] > in_nodeznmeso['LIZ']) & (allData['destination'] > in_nodeznmeso['LIZ'])), 0, allData['Rintyrd']) 
allData['CngHours']=in_sptime['OtherCong']

#- Adjust rail dwell hours for logistics nodes
cond_1 = (
    (allData['CmapPsRL'] == 1) |
    ((allData['origin'] <= in_nodeznmeso['LIZ'])|(allData['destination'] <= in_nodeznmeso['LIZ']))
)

for rlID in rlLogos:
    refCode = 'dwl' + str(rlID)
    allData.loc[cond_1 & (allData['Rintyrd'] == rlID), 'CngHours'] = in_sptime[refCode]

#- Adjust remaining rail dwell hours based on Rdwl code
chDwl = 1
while chDwl < 5:
    allData.loc[~(cond_1) & (allData['Rdwl'] == chDwl), 'CngHours'] = in_sptime[rlDwlCodes[chDwl]]
    chDwl=chDwl+1

# ---------------------------------------------------------------
# CALCULATE TIMES, COSTS, AND ADDITIONAL DATA BY MODEPATH: Air
# ---------------------------------------------------------------
oRows_air = [] 
# Calculate cost of shipping by air per ton
print("---> PROCESSING AIR MODEPATHS")
counter=1
startTime = datetime.now()
for _, row in allData.iterrows(): 
    # Create arrays for air time and costs
    cA = {idx: np.nan for idx in range(in_nodeznmeso['FAT'], in_nodeznmeso['LAT'] + 1)}
    tA = {idx: np.nan for idx in range(in_nodeznmeso['FAT'], in_nodeznmeso['LAT'] + 1)}   
    mlA = {idx: np.nan for idx in range(in_nodeznmeso['FAT'], in_nodeznmeso['LAT'] + 1)}  # Air mode complete mileage
    lhA = {idx: np.nan for idx in range(in_nodeznmeso['FAT'], in_nodeznmeso['LAT'] + 1)}  # Air mode linehaul mileage
    drA = {idx: np.nan for idx in range(in_nodeznmeso['FAT'], in_nodeznmeso['LAT'] + 1)}  # Air mode drayage mileage
    
    if row['origin'] <= in_nodeznmeso['LEZ']:
        # Format for CMAP origins
        if row['origin'] <= in_nodeznmeso['LIZ']: 
            idx = in_nodeznmeso['FAT']
            while idx <= in_nodeznmeso['LAT']:      # Loop through to create options
                rowIntDray = 'IntDray' + str(idx)
                rowLineHaul = 'LineHaul' + str(idx)

                cA[idx] = in_charges['LTL53rate']*(row[rowIntDray]+row['ExtDray']) + row[rowLineHaul]*in_charges['AirRate'] + 2*in_charges['AirHandFee']
                tA[idx] = (row[rowIntDray]+row['ExtDray'])/in_sptime['DrayTruckMPH'] + row[rowLineHaul]/in_sptime['AirMPH'] + 2*in_sptime['AirTime']      # Heither: original calculation erroneously multiplied by AirHandFee not AirTime
                mlA[idx] = (row[rowIntDray]+row['ExtDray']) + row[rowLineHaul]
                lhA[idx] = row[rowLineHaul]

                if row['destination'] <= in_nodeznmeso['LEZ']:
                    drA[idx] = row[rowIntDray]+row['ExtDray'] 
                else:
                    drA[idx] = row[rowIntDray]
                
                idx=idx+1
                
        # Format for non-CMAP origins
        else:
            idx = in_nodeznmeso['FAT']    # Only one airport option
            rowIntDray = 'IntDray' + str(idx)
            rowLineHaul = 'LineHaul' + str(idx)

            # Format intrazonal (assume drayage by truck)
            if row['origin'] == row['destination']:
                cA[idx] = in_charges['LTL53rate']*(row[rowIntDray]) + row[rowLineHaul]*in_charges['AirRate'] + 2*in_charges['AirHandFee']
                tA[idx] = (row[rowIntDray])/in_sptime['DrayTruckMPH'] + row[rowLineHaul]/in_sptime['AirMPH'] + 2*in_sptime['AirTime']     
                mlA[idx] = row[rowIntDray] + row[rowLineHaul]
                lhA[idx] = row[rowLineHaul]
                drA[idx] = row[rowIntDray]
            
            # Format non-CMAP US origin - Foreign destinations (assume drayage by plane)
            elif row['destination'] > in_nodeznmeso['LEZ']:
                cA[idx] = in_charges['LTL53rate']*row['ExtDray'] + (row[rowLineHaul]+row[rowIntDray])*in_charges['AirRate'] + 2*in_charges['AirHandFee']
                tA[idx] = row['ExtDray']/in_sptime['DrayTruckMPH'] + (row[rowLineHaul]+row[rowIntDray])/in_sptime['AirMPH'] + 2*in_sptime['AirTime'] 
                mlA[idx] = (row[rowIntDray]+row['ExtDray']) + row[rowLineHaul]
                lhA[idx] = 0
                drA[idx] = row[rowIntDray]

            # Format non-CMAP US origin-US destination (assume drayage by truck)
            else:
                cA[idx] = in_charges['LTL53rate']*(row[rowIntDray]+row['ExtDray']) + row[rowLineHaul]*in_charges['AirHandFee'] + 2*in_charges['AirHandFee']
                tA[idx] = (row[rowIntDray]+row['ExtDray'])/in_sptime['DrayTruckMPH'] + row[rowLineHaul]/in_sptime['AirMPH']+ 2*in_sptime['AirTime']  
                mlA[idx] = (row[rowIntDray]+row['ExtDray']) + row[rowLineHaul]
                lhA[idx] = row[rowLineHaul]
                drA[idx] = row[rowIntDray]+row['ExtDray']
    
    # Format output rows
    output_row = {
        'origin': row['origin'],
        'destination': row['destination'],
    }

    # Add array values to the row (flattened)
    for idx in range(in_nodeznmeso['FAT'], in_nodeznmeso['LAT'] + 1):
        output_row[f'cA{idx}'] = cA[idx]
        output_row[f'tA{idx}'] = tA[idx]
        output_row[f'mlA{idx}'] = mlA[idx]
        output_row[f'lhA{idx}'] = lhA[idx]
        output_row[f'drA{idx}'] = drA[idx]

    # Append to result list
    oRows_air.append(output_row)

    remainingRows = len(allData)-counter
    timelapse_records(startTime, counter, remainingRows)  
    counter = counter+1 

outAir = pd.DataFrame(oRows_air)


# -----------------------------------------------------------------------------
# CALCULATE TIMES, COSTS, AND ADDITIONAL DATA BY MODEPATH: CMAP/Inland Water
# -----------------------------------------------------------------------------
oRows_inlandW = [] 
# Calculate cost of shipping by water per ton
print("---> PROCESSING CMAP/INLAND WATER MODEPATHS")
counter=1
startTime = datetime.now()
for _, row in allData.iterrows(): 
    # Create arrays for water time and costs
    cW = {idx: np.nan for idx in range(in_nodeznmeso['FWT'], in_nodeznmeso['LWT'] + 1)}
    tW = {idx: np.nan for idx in range(in_nodeznmeso['FWT'], in_nodeznmeso['LWT'] + 1)}
    mlW = {idx: np.nan for idx in range(in_nodeznmeso['FWT'], in_nodeznmeso['LWT'] + 1)}  # Inland water mode complete mileage
    lhW = {idx: np.nan for idx in range(in_nodeznmeso['FWT'], in_nodeznmeso['LWT'] + 1)}  # Inland water linehaul mileage
    drW = {idx: np.nan for idx in range(in_nodeznmeso['FWT'], in_nodeznmeso['LWT'] + 1)}  # Inland water drayage mileage
    
    # Format for CMAP origins
    if row['origin'] <= in_nodeznmeso['LIZ']:
        if row['RailWtr'] > 0:
            row['ExtDray'] = row['RailWtr']
        idx = in_nodeznmeso['FWT']
        while idx <= in_nodeznmeso['LWT']:      # Loop through to create options
            rowIntDray = 'IntDray' + str(idx)
            rowLineHaul = 'LineHaul' + str(idx)

            cW[idx] = in_charges['FTL53rate']*(row[rowIntDray]+row['ExtDray']) + row[rowLineHaul]*in_charges['WaterRate2'] + 2*in_charges['BulkHandFee']
            tW[idx] = (row[rowIntDray]+row['ExtDray'])/in_sptime['DrayTruckMPH'] + row[rowLineHaul]/in_sptime['WaterMPH'] + 2*in_sptime['BulkTime'] + row[rowLineHaul]*in_sptime['bargeDelay']
            mlW[idx] = (row[rowIntDray]+row['ExtDray']) + row[rowLineHaul]
            lhW[idx] = row[rowLineHaul]
            if row['destination'] <= in_nodeznmeso['LEZ']:
                drW[idx] = row[rowIntDray]+row['ExtDray'] 
            else:
                drW[idx] = row[rowIntDray]
                        
            idx=idx+1
          
    # Format for non-CMAP origins
    else:
        if row['RailWtr'] > 0:
            row['ExtDray'] = row['RailWtr']
        idx = in_nodeznmeso['FWT']
        if np.isnan(row['InDray']):
            row['IWDray'] = in_sptime['ExtDrayDom']
        else:
            row['IWDray'] = row['InDray']

        cW[idx] = in_charges['FTL53rate']*(row['IWDray']+row['ExtDray']) + row['Waterway']*in_charges['WaterRate2'] + 2*in_charges['BulkHandFee']	
        tW[idx] = (row['IWDray']+row['ExtDray'])/in_sptime['DrayTruckMPH'] + row['Waterway']/in_sptime['WaterMPH'] + 2*in_sptime['BulkTime'] + row['Waterway']*in_sptime['bargeDelay']		
        mlW[idx] = (row['IWDray']+row['ExtDray']) + row['Waterway']
        lhW[idx] = row['Waterway']
            
        if row['destination'] <= in_nodeznmeso['LEZ']: 
            drW[idx] = row['IWDray']+row['ExtDray']
        else: 
            drW[idx] = row['IWDray']

    
    # Format output rows
    output_row = {
        'origin': row['origin'],
        'destination': row['destination'],
    }

    # Add array values to the row (flattened)
    for idx in range(in_nodeznmeso['FWT'], in_nodeznmeso['LWT'] + 1):
        output_row[f'cW{idx}'] = cW[idx]
        output_row[f'tW{idx}'] = tW[idx]
        output_row[f'mlW{idx}'] = mlW[idx]
        output_row[f'lhW{idx}'] = lhW[idx]
        output_row[f'drW{idx}'] = drW[idx]

    # Append to result list
    oRows_inlandW.append(output_row)

    remainingRows = len(allData)-counter
    timelapse_records(startTime, counter, remainingRows)  
    counter = counter+1 

outInlandW = pd.DataFrame(oRows_inlandW)

# -----------------------------------------------------------------------------
# CALCULATE TIMES, COSTS, AND ADDITIONAL DATA BY MODEPATH: Truck and Rail
# -----------------------------------------------------------------------------
TRdata = allData.copy()
drT31 = np.nan            																	# drayage mileage for minpath 31,46 

oRows_TR = [] 
# Calculate cost of shipping by water per ton
print("---> PROCESSING TRUCK AND RAIL MODEPATHS")
counter=1
startTime = datetime.now()
for _, row in TRdata.iterrows(): 
    # Create arrays for rail logistics stops: 0/1 external stops and 1 internal stop
    t0cf = {idx: np.nan for idx in range(in_nodeznmeso['FRT'], in_nodeznmeso['LRT'] + 1)}
    t0if = {idx: np.nan for idx in range(in_nodeznmeso['FRT'], in_nodeznmeso['LRT'] + 1)}
    t0iL = {idx: np.nan for idx in range(in_nodeznmeso['FRT'], in_nodeznmeso['LRT'] + 1)}
    t1fcf = {idx: np.nan for idx in range(in_nodeznmeso['FRT'], in_nodeznmeso['LRT'] + 1)}
    t1fif = {idx: np.nan for idx in range(in_nodeznmeso['FRT'], in_nodeznmeso['LRT'] + 1)}
    t1LiL = {idx: np.nan for idx in range(in_nodeznmeso['FRT'], in_nodeznmeso['LRT'] + 1)}
    mlR = {idx: np.nan for idx in range(in_nodeznmeso['FRT'], in_nodeznmeso['LRT'] + 1)}     # Rail mode complete mileage
    lhR = {idx: np.nan for idx in range(in_nodeznmeso['FRT'], in_nodeznmeso['LRT'] + 1)}     # Rail mode linehaul mileage
    drR = {idx: np.nan for idx in range(in_nodeznmeso['FRT'], in_nodeznmeso['LRT'] + 1)}     # Rail mode drayage mileage 
    c0cf = {idx: np.nan for idx in range(in_nodeznmeso['FRT'], in_nodeznmeso['LRT'] + 1)}
    c0if = {idx: np.nan for idx in range(in_nodeznmeso['FRT'], in_nodeznmeso['LRT'] + 1)}
    c0iL = {idx: np.nan for idx in range(in_nodeznmeso['FRT'], in_nodeznmeso['LRT'] + 1)}
    c1fcf = {idx: np.nan for idx in range(in_nodeznmeso['FRT'], in_nodeznmeso['LRT'] + 1)}
    c1fif = {idx: np.nan for idx in range(in_nodeznmeso['FRT'], in_nodeznmeso['LRT'] + 1)}
    c1LiL = {idx: np.nan for idx in range(in_nodeznmeso['FRT'], in_nodeznmeso['LRT'] + 1)}
    
    # Create arrays for truck logistics stops: 0/1 external stops and 1 internal stop
    t0fL = {idx: np.nan for idx in range(in_nodeznmeso['FTT'], in_nodeznmeso['LTT'] + 1)}
    t0LL = {idx: np.nan for idx in range(in_nodeznmeso['FTT'], in_nodeznmeso['LTT'] + 1)}
    t1LfL = {idx: np.nan for idx in range(in_nodeznmeso['FTT'], in_nodeznmeso['LTT'] + 1)}
    c0fL = {idx: np.nan for idx in range(in_nodeznmeso['FTT'], in_nodeznmeso['LTT'] + 1)}
    c0LL = {idx: np.nan for idx in range(in_nodeznmeso['FTT'], in_nodeznmeso['LTT'] + 1)}
    c1LfL = {idx: np.nan for idx in range(in_nodeznmeso['FTT'], in_nodeznmeso['LTT'] + 1)}
    mlT = {idx: np.nan for idx in range(in_nodeznmeso['FTT'], in_nodeznmeso['LTT'] + 1)}    # Truck mode complete mileage 
    lhT = {idx: np.nan for idx in range(in_nodeznmeso['FTT'], in_nodeznmeso['LTT'] + 1)}    # Truck mode domestic linehaul mileage
    drT = {idx: np.nan for idx in range(in_nodeznmeso['FTT'], in_nodeznmeso['LTT'] + 1)}    # Truck mode drayage mileage 

    # Apply the direct/express surcharge where appropriate
    # 05-22-2017: Add CMAP/non-CMAP congestion
    tCarload = row['Rdist00']/in_sptime['RailMPH'] + row['CngHours'] 				    # time: minpath 3 	
    cCarload = in_charges['ExpressSurcharge']*row['Rdist00']*in_charges['CarloadRate']	# cost: minpath 3 
    tIMX = row['Rdist00']/in_sptime['RailMPH'] + row['CngHours'] 					    # time: minpath 13 
    cIMX = in_charges['ExpressSurcharge']*row['Rdist00']*in_charges['IMXRate'] 			# cost: minpath 13 
    tFTL = row['Tdist00']/in_sptime['LHTruckMPH'] 							            # time: minpath 31 
    cFTL = in_charges['ExpressSurcharge']*row['Tdist00']*in_charges['FTL53rate']			# cost: minpath 31
    tLTL = row['Tdist00']/in_sptime['LHTruckMPH']							            # time: minpath 46 
    cLTL = in_charges['ExpressSurcharge']*row['Tdist00']*in_charges['LTL53rate']			# cost: minpath 46
    mlT31 = row['Tdist00']              							                        # mileage for minpath 31,46 
    lhT31 = row['Tdsml00']              							                        # domestic linehaul mileage for minpath 31,46 
    drT31 = 0              												                # drayage mileage for minpath 31,46
    d = np.nan # Initialize
    mlT31 = row['Tdist00']              																# mileage for minpath 31,46 
    lhT31 = row['Tdsml00']              																# domestic linehaul mileage for minpath 31,46

    # 1 Stop  (assume stops only happen with mode switching)
    # 1 external stop, 0 internal stops
    if row['origin'] == row['destination']:   # Intrazonal
        t1fc0 = row['IntraDray']/in_sptime['DrayTruckMPH'] + row['Rdist00']/in_sptime['RailMPH'] + 1*in_sptime['BulkTime']			# time: minpath 4 -- ***; *** Heither, 01-04-2017: added IntraDray 
        t1fi0 = row['IntraDray']/in_sptime['DrayTruckMPH'] + row['Rdist00']/in_sptime['RailMPH'] + 1*in_sptime['IMXTime']		 		# time: minpath 14 -- ***; *** Heither, 01-04-2017: changed BulkTime to IMXTime, added IntraDray 
        t1Li0 = row['IntraDray']/in_sptime['DrayTruckMPH'] + row['Rdist00']/in_sptime['RailMPH'] + 1*in_sptime['WDCTime'] 
        t1Lf0 = row['IntraDray']/in_sptime['DrayTruckMPH'] + row['Tdist00']/in_sptime['LHTruckMPH'] + 1*in_sptime['WDCTime']
        t1LL0 = row['IntraDray']/in_sptime['DrayTruckMPH'] + row['Tdist00']/in_sptime['LHTruckMPH'] + 1*in_sptime['WDCTime'] 
        c1fc0 = row['IntraDray']*in_charges['FTL53rate'] + row['Rdist00']*in_charges['CarloadRate'] + 1*in_charges['BulkHandFee'] 		# cost: minpath 4 -- ***; *** Heither, 01-04-2017: added IntraDray
        c1fi0 = row['IntraDray']*in_charges['FTL53rate'] + row['Rdist00']*in_charges['IMXRate'] + 1*in_charges['IMXHandFee'] 			# cost: minpath 14 -- ***; *** Heither, 01-04-2017: changed BulkHandFee to IMXHandFee, added IntraDray
        c1Li0 = row['IntraDray']*in_charges['LTL53rate'] + row['Rdist00']*in_charges['IMXRate'] + 1*in_charges['WDCHandFee']
        c1Lf0 = row['IntraDray']*in_charges['LTL53rate'] + row['Tdist00']*in_charges['FTL53rate'] + 1*in_charges['WDCHandFee']
        c1LL0 = row['IntraDray']*in_charges['LTL53rate'] + row['Tdist00']*in_charges['LTL53rate'] + 1*in_charges['WDCHandFee']  
        mlR4 = row['IntraDray'] + row['Rdist00']              										# mileage for minpath 4,14 	  
        lhR4 = row['Rdsml00']           			   										# domestic linehaul mileage for minpath 4,14 		  
        drR4 = row['IntraDray']
    else:   # CMAP/non-CMAP congestion
        t1fc0 = row['ExtDray']/in_sptime['DrayTruckMPH'] + row['Rdist00']/in_sptime['RailMPH'] + 1*in_sptime['BulkTime'] + row['CngHours'] 	# time: minpath 4 -- ***; 
        t1fi0 = row['ExtDray']/in_sptime['DrayTruckMPH'] + row['Rdist00']/in_sptime['RailMPH'] + 1*in_sptime['IMXTime'] + row['CngHours']		# time: minpath 14 -- ***; *** Heither, 01-03-2017: changed BulkTime to IMXTime ***;
        t1Li0 = row['ExtDray']/in_sptime['DrayTruckMPH'] + row['Rdist00']/in_sptime['RailMPH'] + 1*in_sptime['WDCTime'] 
        t1Lf0 = row['ExtDray']/in_sptime['DrayTruckMPH'] + row['Tdist00']/in_sptime['LHTruckMPH'] + 1*in_sptime['WDCTime'] 
        t1LL0 = row['ExtDray']/in_sptime['DrayTruckMPH'] + row['Tdist00']/in_sptime['LHTruckMPH'] + 1*in_sptime['WDCTime'] 
        c1fc0 = row['ExtDray']*in_charges['FTL53rate'] + row['Rdist00']*in_charges['CarloadRate'] + 1*in_charges['BulkHandFee'] 			# cost: minpath 4 -- ***; 
        c1fi0 = row['ExtDray']*in_charges['FTL53rate'] + row['Rdist00']*in_charges['IMXRate'] + 1*in_charges['IMXHandFee'] 				# cost: minpath 14 -- ***; *** Heither, 01-04-2017: changed BulkHandFee to IMXHandFee ***;
        c1Li0 = row['ExtDray']*in_charges['LTL53rate'] + row['Rdist00']*in_charges['IMXRate'] + 1*in_charges['WDCHandFee'] 
        c1Lf0 = row['ExtDray']*in_charges['LTL53rate'] + row['Tdist00']*in_charges['FTL53rate'] + 1*in_charges['WDCHandFee']
        c1LL0 = row['ExtDray']*in_charges['LTL53rate'] + row['Tdist00']*in_charges['LTL53rate'] + 1*in_charges['WDCHandFee']  
        mlR4 = row['ExtDray']+row['Rdist00']           											# mileage for minpath 4,14 -- ***;		
        lhR4 = row['Rdsml00']           			   										# domestic linehaul mileage for minpath 4,14 -- ***;
        if row['destination'] <= in_nodeznmeso['LEZ']:
            drR4 = row['ExtDray']
        else:
            drR4 = 0					# domestic drayage mileage for minpath 4,14 --- ***;	 
  
    # 0/1 external stops, 1 internal stop
    # Rail
    idx = in_nodeznmeso['FRT']
    while idx <= in_nodeznmeso['LRT']:
        rowIntDray = 'IntDray' + str(idx)
        rowLineHaul = 'LineHaul' + str(idx)
        rowLHdms = 'LHdms' + str(idx)
        
        t0cf[idx]=(row['ExtDray']+row[rowLineHaul])/in_sptime['RailMPH'] + row[rowIntDray]/in_sptime['DrayTruckMPH'] + 1*in_sptime['BulkTime'] + row['CngHours']           # time: minpath 5-8   08-11-2017
        t0if[idx]=(row['ExtDray']+row[rowLineHaul])/in_sptime['RailMPH'] + row[rowIntDray]/in_sptime['DrayTruckMPH'] + 1*in_sptime['WDCTime']  + row['CngHours']           # time: minpath 19-22   08-11-2017
        t0iL[idx]=(row['ExtDray']+row[rowLineHaul])/in_sptime['RailMPH'] + row[rowIntDray]/in_sptime['DrayTruckMPH'] + 1*in_sptime['WDCTime']  + row['CngHours']            # time: minpath 15-18   08-11-2017 
        c0cf[idx]=(row['ExtDray']+row[rowLineHaul])*in_charges['CarloadRate'] + row[rowIntDray]*in_charges['FTL53rate'] + 1*in_charges['BulkHandFee']      # cost: minpath 5-8
        c0if[idx]=(row['ExtDray']+row[rowLineHaul])*in_charges['IMXRate'] + row[rowIntDray]*in_charges['FTL53rate'] + 1*in_charges['WDCHandFee']            # cost: minpath 19-22 
        c0iL[idx]=(row['ExtDray']+row[rowLineHaul])*in_charges['IMXRate'] + row[rowIntDray]*in_charges['LTL53rate'] + 1*in_charges['WDCHandFee']            # cost: minpath 15-18
        t1fcf[idx]=(row[rowLineHaul]/in_sptime['RailMPH']) + (row['ExtDray']+row[rowIntDray])/in_sptime['DrayTruckMPH'] + 2*in_sptime['BulkTime'] + row['CngHours']        # time: minpath 9-12   08-11-2017
        t1fif[idx]=(row[rowLineHaul]/in_sptime['RailMPH']) + (row['ExtDray']+row[rowIntDray])/in_sptime['DrayTruckMPH'] + 2*in_sptime['WDCTime']  + row['CngHours']         # time: minpath 23-26   08-11-2017 
        t1LiL[idx]=(row[rowLineHaul]/in_sptime['RailMPH']) + (row['ExtDray']+row[rowIntDray])/in_sptime['DrayTruckMPH'] + 2*in_sptime['WDCTime']  + row['CngHours']        # time: minpath 27-30   08-11-2017 
        c1fcf[idx]=(row[rowLineHaul]*in_charges['CarloadRate']) + (row['ExtDray']+row[rowIntDray])*in_charges['FTL53rate'] + 2*in_charges['BulkHandFee']    # cost: minpath 9-12 
        c1fif[idx]=(row[rowLineHaul]*in_charges['IMXRate']) + (row['ExtDray']+row[rowIntDray])*in_charges['FTL53rate'] + 2*in_charges['WDCHandFee']         # cost: minpath 23-26 
        c1LiL[idx]=(row[rowLineHaul]*in_charges['IMXRate']) + (row['ExtDray']+row[rowIntDray])*in_charges['LTL53rate'] + 2*in_charges['WDCHandFee']         # cost: minpath 27-30 
        mlR[idx] = row[rowLineHaul] + row['ExtDray'] + row[rowIntDray]
        lhR[idx] = row[rowLHdms]  																		# rail domestic linehaul mileage 
        
        if row['destination'] <= in_nodeznmeso['LEZ']:
            drR[idx] = row['ExtDray'] + row[rowIntDray]
        else:
            drR[idx] = row[rowIntDray]				#- rail Domestic drayage 
        
        mlR3= row['Rdist00']              																# mileage for minpath 3,13 
        lhR3 = row['Rdsml00']              																# linehaul mileage for minpath 3,13 
        drR3 = 0		
        
        idx=idx+1

    # Truck
    idx = in_nodeznmeso['FTT']
    while idx <= in_nodeznmeso['LTT']:
        rowIntDray = 'IntDray' + str(idx)
        rowLineHaul = 'LineHaul' + str(idx)
        rowLHdms = 'LHdms' + str(idx)
        
        t0fL[idx]=row[rowLineHaul]/in_sptime['LHTruckMPH'] + (row['ExtDray']+row[rowIntDray])/in_sptime['DrayTruckMPH'] + 1*in_sptime['WDCTime']         # time: minpath 32-38
        t0LL[idx]=row[rowLineHaul]/in_sptime['LHTruckMPH'] + (row['ExtDray']+row[rowIntDray])/in_sptime['DrayTruckMPH'] + 1*in_sptime['WDCTime']
        t1LfL[idx]=row[rowLineHaul]/in_sptime['LHTruckMPH'] + (row['ExtDray']+row[rowIntDray])/in_sptime['DrayTruckMPH'] + 1*in_sptime['WDCTime']        # time: minpath 39-45 
        c0fL[idx]=(row['ExtDray']+row[rowLineHaul])*in_charges['FTL53rate'] + row[rowIntDray]*in_charges['LTL53rate']  + 1*in_charges['WDCHandFee']           # cost: minpath 32-38
        c0LL[idx]=(row['ExtDray']+row[rowLineHaul])*in_charges['LTL53rate'] + row[rowIntDray]*in_charges['LTL53rate']  + 1*in_charges['WDCHandFee']  
        c1LfL[idx]=row[rowLineHaul]*in_charges['FTL53rate'] + (row['ExtDray']+row[rowIntDray])*in_charges['LTL53rate'] + 2*in_charges['WDCHandFee']          # cost: minpath 39-45 
        mlT[idx] = row[rowLineHaul] + row['ExtDray'] + row[rowIntDray]   
        lhT[idx] = row[rowLHdms] 																		# truck domestic linehaul mileage 
        
        if row['destination'] <= in_nodeznmeso['LEZ']:
            drT[idx] = row['ExtDray'] + row[rowIntDray]
        else:
            drT[idx] = row[rowIntDray]				#- truck Domestic drayage 	 
        idx=idx+1

    # CREATE INDIRECT FTL [32] AND LTL [39] TRUCK COSTS/TIMES FOR U.S. SHIPMENTS NOT INVOLVING CMAP (OTHERWISE TRUCK IS NOT AN OPTION FOR THESE INDIRECT SHIPMENTS)
    cond_1 = (
        (((in_nodeznmeso['FEZ'] <= row['origin'] <= in_nodeznmeso['LEZ']) | 
          (row['origin'] in [in_nodeznmeso['Canada'], in_nodeznmeso['Mexico']])))
        &
        (((in_nodeznmeso['FEZ'] <= row['destination'] <= in_nodeznmeso['LEZ']) | 
         (row['destination'] in [in_nodeznmeso['Canada'], in_nodeznmeso['Mexico']]))))
    
    if cond_1:
        mes = "Origin: " + str(row['origin']) + ", Destination: " + str(row['destination'])
        if pd.isna(row['Tdist00']):
            d = row['GCD']
        else:
            d = row['Tdist00']
                
        # Intrazonal    
        if row['origin'] == row['destination']:
            c0fL[133]=(row['IntraDray']+d)*in_charges['FTL53rate'] + 1*in_charges['WDCHandFee'] 									# FTL indirect cost, Heither, 01-04-2017: added IntraDray-- ***;
            t0fL[133]=d/in_sptime['LHTruckMPH'] + row['IntraDray']/in_sptime['DrayTruckMPH'] + 1*in_sptime['WDCTime'] 						# FTL indirect time, Heither, 01-04-2017: added IntraDray -- ***;
            c1LfL[133]=d*in_charges['FTL53rate'] + row['IntraDray']*in_charges['LTL53rate'] + 2*in_charges['WDCHandFee']						# LTL indirect cost, Heither, 01-04-2017: added IntraDray -- ***;
            t1LfL[133]=d/in_sptime['LHTruckMPH'] + row['IntraDray']/in_sptime['DrayTruckMPH']+ 1*in_sptime['WDCTime']					# LTL indirect time, Heither, 01-04-2017: added IntraDray -- ***;
            mlT[133] = row['IntraDray']+d      														# mileage for minpath 32,39 -- ***;
    
            cond_a = ((row['destination'] <= in_nodeznmeso['LEZ']) | 
                      ((row['destination'] == in_nodeznmeso['Canada']) |(row['destination'] == in_nodeznmeso['Mexico'])))
            
            if cond_a:
                lhT[133] = d
                drT[133] = row['IntraDray']
            else:
                lhT[133] = 0	  # truck Domestic linehaul mileage for minpath 32,39 :: Updated 05-17-2018 
                drT[133] = 0     # truck Domestic drayage mileage for minpath 32,39 :: Updated 05-17-2018	 
        # non-Intrazonal
        else:
            c0fL[133]=(row['ExtDray']+d)*in_charges['FTL53rate'] + 1*in_charges['WDCHandFee']   				# FTL indirect cost 
            t0fL[133]=d/in_sptime['LHTruckMPH'] + row['ExtDray']/in_sptime['DrayTruckMPH'] + 1*in_sptime['WDCTime']  	# FTL indirect time
            c1LfL[133]=d*in_charges['FTL53rate'] + row['ExtDray']*in_charges['LTL53rate'] + 2*in_charges['WDCHandFee'] 		# LTL indirect cost 
            t1LfL[133]=d/in_sptime['LHTruckMPH'] + row['ExtDray']/in_sptime['DrayTruckMPH'] + 1*in_sptime['WDCTime'] 	# LTL indirect time
            mlT[133] = row['ExtDray']+d 
            
            if cond_a:
                lhT[133] = d
                drT[133] = row['ExtDray']
            else:
                lhT[133] = 0	  # truck Domestic linehaul mileage for minpath 32,39 :: Updated 05-17-2018 
                drT[133] = 0     # truck Domestic drayage mileage for minpath 32,39 :: Updated 05-17-2018	 
                    
        # CREATE DIRECT FTL AND LTL TRUCK COSTS/TIMES SHIPMENTS BETWEEN TWO HAWAIIAN ZONES (OTHERWISE TRUCK IS NOT AN OPTION FOR THESE DIRECT SHIPMENTS)
        cond_3 = (((row['origin'] == in_nodeznmeso['Hawaii1']) & (row['destination'] == in_nodeznmeso['Hawaii2'])) |
                    ((row['origin'] == in_nodeznmeso['Hawaii2']) & (row['destination'] == in_nodeznmeso['Hawaii1']))
                    )    
        if cond_3:
            tFTL = row['GCD']/in_sptime['LHTruckMPH'] 
            cFTL = in_charges['ExpressSurcharge']*row['GCD']*in_charges['FTL53rate']
            tLTL = row['GCD']/in_sptime['LHTruckMPH'] 
            cLTL = in_charges['ExpressSurcharge']*row['GCD']*in_charges['LTL53rate']
            mlT31 = row['GCD']    # mileage for minpath 31,46
            lhT31 = row['GCD']    # domestic linehaul mileage for minpath 31,46 
            drT31 = 0             # domestic drayage mileage for minpath 31,46   

    # Format output rows
    output_row = {
        'origin': row['origin'],
        'destination': row['destination'],
        't1fc0': t1fc0,
        't1fi0': t1fi0,
        't1Li0': t1Li0,
        't1Lf0': t1Lf0,
        't1LL0': t1LL0,
        'c1fc0': c1fc0,
        'c1fi0': c1fi0,
        'c1Li0': c1Li0,
        'c1Lf0': c1Lf0,
        'c1LL0': c1LL0,
        'mlR4': mlR4,
        'lhR4': lhR4,
        'drR4': drR4,
        'mlR3': mlR3,
        'lhR3': lhR3,
        'drR3': drR3,
        'mlT31': mlT31,
        'lhT31': lhT31,
        'drT31': drT31,
        'd': d,
        'tFTL': tFTL,
        'cFTL': cFTL,
        'tLTL': tLTL,
        'cLTL': cLTL,
        'mlT31': mlT31,
        'lhT31': lhT31,
        'drT31': drT31,
        'tCarload': tCarload,
        'cCarload': cCarload,
        'tIMX': tIMX,
        'cIMX': cIMX
    }

    # Add array values to the row (flattened)
    for idx in range(in_nodeznmeso['FRT'], in_nodeznmeso['LRT'] + 1):
        output_row[f't0cf{idx}'] = t0cf[idx]
        output_row[f't0if{idx}'] = t0if[idx]
        output_row[f't0iL{idx}'] = t0iL[idx]
        output_row[f't1fcf{idx}'] = t1fcf[idx]
        output_row[f't1fif{idx}'] = t1fif[idx]
        output_row[f't1LiL{idx}'] = t1LiL[idx]
        output_row[f'mlR{idx}'] = mlR[idx]
        output_row[f'lhR{idx}'] = lhR[idx]
        output_row[f'drR{idx}'] = drR[idx]
        output_row[f'c0cf{idx}'] = c0cf[idx]
        output_row[f'c0if{idx}'] = c0if[idx]
        output_row[f'c0iL{idx}'] = c0iL[idx]
        output_row[f'c1fcf{idx}'] = c1fcf[idx]
        output_row[f'c1fif{idx}'] = c1fif[idx]
        output_row[f'c1LiL{idx}'] = c1LiL[idx]
    for idx in range(in_nodeznmeso['FTT'], in_nodeznmeso['LTT'] + 1):
        output_row[f't0fL{idx}'] = t0fL[idx]
        output_row[f't0LL{idx}'] = t0LL[idx]
        output_row[f't1LfL{idx}'] = t1LfL[idx]
        output_row[f'c0fL{idx}'] = c0fL[idx]
        output_row[f'c0LL{idx}'] =c0LL[idx]
        output_row[f'c1LfL{idx}'] = c1LfL[idx]
        output_row[f'mlT{idx}'] = mlT[idx]
        output_row[f'lhT{idx}'] = lhT[idx]
        output_row[f'drT{idx}'] = drT[idx]

    # Append to result list
    oRows_TR.append(output_row)

    remainingRows = len(TRdata)-counter
    timelapse_records(startTime, counter, remainingRows)  
    counter = counter+1 

outTR= pd.DataFrame(oRows_TR)

# Do not allow for Hawaii to Non-Hawaii Shipments
cond_hawaii1 = (
    (((outTR['origin'] == in_nodeznmeso['Hawaii1'])|(outTR['origin'] == in_nodeznmeso['Hawaii2'])) & 
    ((outTR['destination'] != in_nodeznmeso['Hawaii1'])&(outTR['destination'] != in_nodeznmeso['Hawaii2']))) |
    (((outTR['origin'] != in_nodeznmeso['Hawaii1'])&(outTR['origin'] != in_nodeznmeso['Hawaii2'])) & 
    ((outTR['destination'] == in_nodeznmeso['Hawaii1'])|(outTR['destination'] == in_nodeznmeso['Hawaii2'])))
)

outTR['c0fL133'] = np.where(cond_hawaii1, np.nan, outTR['c0fL133'] )
outTR['t0fL133'] = np.where(cond_hawaii1, np.nan, outTR['t0fL133'] )
outTR['c1LfL133'] = np.where(cond_hawaii1, np.nan, outTR['c1LfL133'] )
outTR['t1LfL133'] = np.where(cond_hawaii1, np.nan, outTR['t1LfL133'] )

# --------------------------------------------------------------------------------
# CALCULATE TIMES, COSTS, AND ADDITIONAL DATA BY MODEPATH: International Shipping
# --------------------------------------------------------------------------------
intshipdata = allData.copy()
oRows_intship = [] 
# Calculate cost of shipping by water per ton
print("---> PROCESSING INTERNATIONAL SHIPPING MODEPATHS")
counter=1
startTime = datetime.now()
for _, row in intshipdata.iterrows(): 
    cond_intship = (
        (row['origin'] in [in_nodeznmeso['Alaska'], in_nodeznmeso['Hawaii1'], in_nodeznmeso['Hawaii2']]) or
        (row['destination'] in [in_nodeznmeso['Alaska'], in_nodeznmeso['Hawaii1'], in_nodeznmeso['Hawaii2']]) or
        (row['destination'] > in_nodeznmeso['LEZ'])
    )
    
    cont_intship2 = (
        ((row['origin'] <= in_nodeznmeso['LIZ']) and
         (row['destination'] in [in_nodeznmeso['Canada'], in_nodeznmeso['Mexico']])) or 
        (row['origin'] == row['destination'])
    )

    
    cFTL40dir = np.nan
    tFTL40dir = np.nan
    cLTL40dir = np.nan
    tLTL40dir = np.nan
    cFTL53tload = np.nan
    tFTL53tload = np.nan
    cLTL53tload = np.nan
    tLTL53tload = np.nan
    mlIW = np.nan
    lhIW = np.nan  	   							# domestic linehaul mileage 
    drIW = np.nan				    		# domestic drayage mileage 	
    shpIW = np.nan

    if cond_intship:
        if cont_intship2:
            cFTL40dir = np.nan
            tFTL40dir = np.nan
            cLTL40dir = np.nan
            tLTL40dir = np.nan
            cFTL53tload = np.nan
            tFTL53tload = np.nan
            cLTL53tload = np.nan
            tLTL53tload = np.nan
        else:
            # #51 [Intl Water, no transload, 40 ft container direct from port to dest]: use Bulk handling and fees
            # Costlier rate because this path involves no transloading of containerized goods into 53' trailers	  
            cFTL40dir= in_charges['ExpressSurcharge']*(row['Tdist']+row['InDray']+row['ExDray'])*in_charges['FTL40rate'] + row['GCD']*in_charges['WaterRate'] + 2*in_charges['BulkHandFee']   # cost 
            tFTL40dir= row['GCD']/in_sptime['WaterMPH'] + row['Tdist']/in_sptime['LHTruckMPH'] + (row['InDray']+row['ExDray'])/in_sptime['DrayTruckMPH'] + 2*in_sptime['BulkTime']        # time 
            # #52 [Intl Water, no transload, 40 ft direct]: use Bulk handling and fees ==== **;
            # Costlier rate because this path involves no transloading of containerized goods into 53' trailers		  
            cLTL40dir= in_charges['ExpressSurcharge']*(row['Tdist']+row['InDray']+row['ExDray'])*in_charges['LTL40rate'] + row['GCD']*in_charges['WaterRate'] + 2*in_charges['BulkHandFee']   # cost 
            tLTL40dir= row['GCD']/in_sptime['WaterMPH'] + row['Tdist']/in_sptime['LHTruckMPH'] + (row['InDray']+row['ExDray'])/in_sptime['DrayTruckMPH']+ 2*in_sptime['BulkTime']       # time 

            # #53 [Intl Water, Transload, 53 ft FTL]: use Transload handling and fees ==== **;
            # No express surcharge because involves transloading of containerized goods into 53' trailers ==== **;	  
            cFTL53tload= (row['Tdist']+row['InDray']+row['ExDray'])*in_charges['FTL53rate'] + row['GCD']*in_charges['WaterRate'] + 2*in_charges['TloadHandFee']                  # cost
            tFTL53tload= row['GCD']/in_sptime['WaterMPH'] + row['Tdist']/in_sptime['LHTruckMPH'] + (row['InDray']+row['ExDray'])/in_sptime['DrayTruckMPH']+ 2*in_sptime['TloadTime']     # time	   
	   
            # #54 [Intl Water, Transload, 53 ft LTL]: use Transload handling and fees ==== **;	
            # No express surcharge because involves transloading of containerized goods into 53' trailers	  
            cLTL53tload= (row['Tdist']+row['InDray']+row['ExDray'])*in_charges['LTL53rate'] + row['GCD']*in_charges['WaterRate'] + 2*in_charges['TloadHandFee']                  # cost
            tLTL53tload= row['GCD']/in_sptime['WaterMPH'] + row['Tdist']/in_sptime['LHTruckMPH'] + (row['InDray']+row['ExDray'])/in_sptime['DrayTruckMPH']+ 2*in_sptime['TloadTime']     # time 
            
            mlIW = row['GCD'] + row['Tdist'] + (row['InDray']+row['ExDray']) 		# all four International Water modes have the same mileage calculation 
            lhIW = row['Tdsml']  	   							# domestic linehaul mileage 
            drIW = row['InDray']					    		# domestic drayage mileage 	
            shpIW = row['GCD']						 		# ocean linehaul mileage		   
              
    # Format output rows
    output_row = {
        'origin': row['origin'],
        'destination': row['destination'],
        'cFTL40dir': cFTL40dir,
        'tFTL40dir': tFTL40dir,
        'cLTL40dir': cLTL40dir,
        'tLTL40dir': tLTL40dir,
        'cFTL53tload': cFTL53tload,
        'tFTL53tload': tFTL53tload,
        'cLTL53tload': cLTL53tload,
        'tLTL53tload': tLTL53tload,
        'mlIW': mlIW,
        'lhIW': lhIW,
        'drIW': drIW,
        'shpIW': shpIW
    }
    
    # Append to result list
    oRows_intship.append(output_row)

    remainingRows = len(intshipdata)-counter
    timelapse_records(startTime, counter, remainingRows)  
    counter = counter+1 

outIntship= pd.DataFrame(oRows_intship)       

# ---------------------------------------
# COMBINE ALL TIME AND COST COLUMNS
# ---------------------------------------
# Combine all output
temp1 = pd.merge(outIntship, outInlandW, how='outer', on=['origin', 'destination'])
temp1 = pd.merge(temp1, outAir, how='outer', on=['origin', 'destination'])
temp1 = pd.merge(temp1, outTR, how='outer', on=['origin', 'destination'])
outData = pd.merge(temp1, allData, how='outer', on=['origin', 'destination'])

# Remove logistics nodes as origins/destinations
cond_rev = (
    ((in_nodeznmeso['FLN'] <= outData['origin']) & (outData['origin'] <= in_nodeznmeso['LLN'])) |
    ((in_nodeznmeso['FLN'] <= outData['destination']) & (outData['destination'] <= in_nodeznmeso['LLN']))
)
outData = outData.loc[~cond_rev]

# Ensure all reverse directions exist
routData = outData.copy()
routData['reverse'] = 1
routData = routData.rename(columns={'origin': 'destination', 'destination': 'origin'})

# Combine both directions
allOutData = pd.concat([outData, routData])

# Keep only the last row per OD group
allOutData = allOutData.sort_values(['origin', 'destination', 'reverse'])
allOutData = allOutData.groupby(['origin', 'destination'], as_index=False).last()

# ---------------------------------------
# FINAL TEMPLATE FORMATTING AND CHECK
# ---------------------------------------
# All US Mesozones
us=in_gcd.loc[(in_gcd['Production_zone'] <= in_nodeznmeso['LIZ']) | ((in_nodeznmeso['FEZ'] <= in_gcd['Production_zone'])& (in_gcd['Production_zone'] <= in_nodeznmeso['LEZ']))].copy()
us=us[['Production_zone']]
us.columns=['origin']
us=us.drop_duplicates()

us_d = us.copy()
us_d.columns=['destination']

# All US  & Foreign Mesozones
usforgn=in_gcd.loc[(in_gcd['Production_zone'] < in_nodeznmeso['FLN']) | (in_gcd['Production_zone'] > in_nodeznmeso['LLN'])].copy()
usforgn=usforgn[['Production_zone']]
usforgn.columns=['destination']
usforgn=usforgn.drop_duplicates()

forgn = usforgn.loc[usforgn['destination'] > in_nodeznmeso['LEZ']].copy()
forgn.columns=['origin']

# All US Mesozones (254)* All US & Foreign Mesozones (472) = 119888
#- Cross merge dataframes
us['A']=1
usforgn['A']=1
fin1 = us.merge(usforgn, how='left', on='A', copy=False)     
fin1=fin1.drop('A', axis=1)

# AllForeign Mesozones (218) * All US Mesozones (254) = 55372
#- Cross merge dataframes
us_d['A']=1
forgn['A']=1
fin2 = us_d.merge(forgn, how='left', on='A', copy=False)   
fin2=fin2.drop('A', axis=1)

# Combine templates
fin = pd.merge(fin1, fin2, how = 'outer', on = ['origin', 'destination'])
fin = fin.drop_duplicates()

# Combine data with template to check that all data desired exists
fin = pd.merge(fin, allOutData, how = 'left', on = ['origin', 'destination'], indicator=True)
fin = fin[fin['_merge'] == 'left_only'].drop(columns=['_merge'])

if len(fin) > 0:
    print('ERROR: Zone Pair Mismatch')
    print(fin)
    sys.stop()

# ---------------------------------------
# ESTABLISH MODEPATH COSTS AND TIMES
# ---------------------------------------
cost = {idx: np.nan for idx in range(1,55)}
time = {idx: np.nan for idx in range(1,55)}
mile = {idx: np.nan for idx in range(1,55)}
LHmile = {idx: np.nan for idx in range(1,55)}
DRmile = {idx: np.nan for idx in range(1,55)}

# modepath, cost, time, mile, lhmile, drmile
allOutData['NA'] = np.nan
if int(year) < 2035: 
    cost49 = 'NA'
    time49 = 'NA'
    mile49 = 'NA'
    LHmile49 = 'NA'
    DRmile49 = 'NA'
else:
    cost49 = 'cA143'
    time49 = 'tA143'
    mile49 = 'mlA143'
    LHmile49 = 'lhA143'
    DRmile49 = 'drA143'

# Time, Cost, Miles, Longhaul Miles, DR miles
modepath_dict = {
    1: ['cW145', 'tW145', 'mlW145', 'lhW145', 'drW145'],
    2: ['cW146', 'tW146', 'mlW146', 'lhW146', 'drW146'],
    3: ['cCarload', 'tCarload', 'mlR3', 'lhR3', 'drR3'],
    4: ['c1fc0', 't1fc0', 'mlR4', 'lhR4', 'drR4'],
    5: ['c0cf147', 't0cf147', 'mlR147', 'lhR147', 'drR147'],
    6: ['c0cf148', 't0cf148', 'mlR148', 'lhR148', 'drR148'],
    7: ['c0cf149', 't0cf149', 'mlR149', 'lhR149', 'drR149'],
    8: ['c0cf150', 't0cf150', 'mlR150', 'lhR150', 'drR150'],
    9: ['c1fcf147', 't1fcf147', 'mlR147', 'lhR147', 'drR147'],
    10: ['c1fcf148', 't1fcf148', 'mlR148', 'lhR148', 'drR148'],
    11: ['c1fcf149', 't1fcf149', 'mlR149', 'lhR149', 'drR149'],
    12: ['c1fcf150', 't1fcf150', 'mlR150', 'lhR150', 'drR150'],
    13: ['cIMX', 'tIMX', 'mlR3','lhR3', 'drR3'],
    14: ['c1fi0', 't1fi0', 'mlR4', 'lhR4', 'drR4'],
    15: ['c0iL147', 't0iL147', 'mlR147', 'lhR147', 'drR147'],
    16: ['c0iL148', 't0iL148', 'mlR148', 'lhR148', 'drR148'],
    17: ['c0iL149', 't0iL149', 'mlR149', 'lhR149', 'drR149'],
    18: ['c0iL150', 't0iL150', 'mlR150', 'lhR150', 'drR150'],
    19: ['c0if147', 't0if147', 'mlR147', 'lhR147', 'drR147'],
    20: ['c0if148', 't0if148', 'mlR148', 'lhR148', 'drR148'],
    21: ['c0if149', 't0if149', 'mlR149', 'lhR149', 'drR149'],
    22: ['c0if150', 't0if150', 'mlR150', 'lhR150', 'drR150'],
    23: ['c1fif147', 't1fif147', 'mlR147', 'lhR147', 'drR147'],
    24: ['c1fif148', 't1fif148', 'mlR148', 'lhR148', 'drR148'],
    25: ['c1fif149', 't1fif149', 'mlR149', 'lhR149', 'drR149'],
    26: ['c1fif150', 't1fif150', 'mlR150', 'lhR150', 'drR150'],
    27: ['c1LiL147', 't1LiL147', 'mlR147', 'lhR147', 'drR147'],
    28: ['c1LiL148', 't1LiL148', 'mlR148', 'lhR148', 'drR148'],
    29: ['c1LiL149', 't1LiL149', 'mlR149', 'lhR149', 'drR149'],
    30: ['c1LiL150', 't1LiL150', 'mlR150', 'lhR150', 'drR150'],
    31: ['cFTL', 'tFTL', 'mlT31', 'lhT31', 'drT31'],
    32: ['c0fL133', 't0fL133', 'mlT133', 'lhT133', 'drT133'],
    33: ['c0fL134', 't0fL134', 'mlT134', 'lhT134', 'drT134'],
    34: ['c0fL135', 't0fL135', 'mlT135', 'lhT135', 'drT135'],
    35: ['c0fL136', 't0fL136', 'mlT136', 'lhT136', 'drT136'],
    36: ['c0fL137', 't0fL137', 'mlT137', 'lhT137', 'drT137'],
    37: ['c0fL138', 't0fL138', 'mlT138', 'lhT138', 'drT138'],
    38: ['c0fL139', 't0fL139', 'mlT139', 'lhT139', 'drT139'],
    39: ['c1LfL133', 't1LfL133', 'mlT133', 'lhT133', 'drT133'],
    40: ['c1LfL134', 't1LfL134', 'mlT134', 'lhT134', 'drT134'],
    41: ['c1LfL135', 't1LfL135', 'mlT135', 'lhT135', 'drT135'],
    42: ['c1LfL136', 't1LfL136', 'mlT136', 'lhT136', 'drT136'],
    43: ['c1LfL137', 't1LfL137', 'mlT137', 'lhT137', 'drT137'],
    44: ['c1LfL138', 't1LfL138', 'mlT138', 'lhT138', 'drT138'],
    45: ['c1LfL139', 't1LfL139', 'mlT139', 'lhT139', 'drT139'],
    46: ['cLTL', 'tLTL', 'mlT31', 'lhT31', 'drT31'],
    47: ['cA141', 'tA141', 'mlA141', 'lhA141', 'drA141'],
    48: ['cA142', 'tA142', 'mlA142', 'lhA142', 'drA142'],
    49: [cost49, time49, mile49, LHmile49, DRmile49],
    50: ['cA144', 'tA144', 'mlA144', 'lhA144', 'drA144'],
    51: ['cFTL40dir', 'tFTL40dir', 'mlIW', 'lhIW', 'drIW'],
    52: ['cLTL40dir', 'tLTL40dir', 'mlIW', 'lhIW', 'drIW'],
    53: ['cFTL53tload', 'tFTL53tload', 'mlIW', 'lhIW', 'drIW'],
    54: ['cLTL53tload', 'tLTL53tload', 'mlIW', 'lhIW', 'drIW']
}

out_modepaths = []
outCols = allOutData.columns.tolist()
print("---> PROCESSING COST, TIME, MILE, LHMILE, & DRMILE DATA BY ROW AND MODEPATH")
counter=1
startTime = datetime.now()
for _, row in allOutData.iterrows():    
    idx = 1
    while idx < 55:
        cost[idx] = row[modepath_dict[idx][0]]
        time[idx] = row[modepath_dict[idx][1]]
        mile[idx] = row[modepath_dict[idx][2]]
        LHmile[idx] = row[modepath_dict[idx][3]]
        DRmile[idx] = row[modepath_dict[idx][4]]
        idx=idx+1

    # Format output rows
    output_row = {
        'Shpmile': row['shpIW'],
    }
    for colnm in outCols: 
        output_row.update({colnm: row[colnm]})
    
    idx = 1
    while idx < 55:
        output_row[f'cost{idx}'] = cost[idx]
        output_row[f'time{idx}'] = time[idx]
        output_row[f'mile{idx}'] = mile[idx]
        output_row[f'LHmile{idx}'] = LHmile[idx]
        output_row[f'DRmile{idx}'] = DRmile[idx]
        idx=idx+1

    # Append to result list
    out_modepaths.append(output_row)

    remainingRows = len(allOutData)-counter
    timelapse_records(startTime, counter, remainingRows) 
    counter = counter+1

outModepaths= pd.DataFrame(out_modepaths)     
outModepaths.to_csv(pth_outModeCosts, index=False)

# Add placeholders for pipeline values
outTimeCosts = outModepaths.copy()
outTimeCosts['time55'] = np.nan
outTimeCosts['time56'] = np.nan
outTimeCosts['time57'] = np.nan
outTimeCosts['cost55'] = np.nan
outTimeCosts['cost56'] = np.nan
outTimeCosts['cost57'] = np.nan

# Select time and cost data
cols_cost = [c for c in outTimeCosts.columns if 'cost' in c.lower()]
cols_time = [c for c in outTimeCosts.columns if 'time' in c.lower()]
cols_select = ['origin', 'destination']
cols_select = [*cols_select, *cols_time, *cols_cost]
outTimeCosts = outTimeCosts[cols_select].copy()

# Export
outTimeCosts.to_csv(pth_outTimeCosts, index=False)

# ---------------------------------------------------------------------------
# CREATE A FILE OF MODAL DISTANCES CONSISTENT WITH TIME/COST CALCULATIONS
# ---------------------------------------------------------------------------
# Initialize columns
icolumns = ['i', 'Origin', 'Destination', 'MinPath', 'TotalNtwkMiles', 'DmsLhMiles', 'DmsDrayMiles', 'IntlShipMiles', 'CmapPsRL', 'CmapPsTR', 'RlDwlCode', 'RlTrnfr']

modeDist = outModepaths.copy()
for col in icolumns:
    if col not in modeDist.columns:
        modeDist[col]=np.nan
    
oRows_modeDist = []
counter = 1
print("---> PROCESSING MODAL DISTANCE DATA")
startTime = datetime.now()
for _, row in modeDist.iterrows(): 
    for i in range(1, 55):  # 1-54 inclusive
        time_i = row[f"time{i}"]
        if time_i > 0:
            mile_i = row[f"mile{i}"]
            LHmile_i = row[f"LHmile{i}"]
            DRmile_i = row[f"DRmile{i}"]

            TotalNtwkMiles = round(mile_i, 1)
            DmsLhMiles = round(LHmile_i, 1)
            DmsDrayMiles = max(0, round(DRmile_i, 1))

            if i <= 54:
                IntlShipMiles = max(0, round(TotalNtwkMiles - (DmsLhMiles + DmsDrayMiles), 1))
            else:
                IntlShipMiles = max(0, round(IntlShipMiles, 1))

            # Assign Carrier logic
            if i in (3, 4, 13, 14):
                Carrier = row["Carr"]
            elif i in (5, 9, 15, 19, 23, 27):
                Carrier = row["Carr147"]
            elif i in (6, 10, 16, 20, 24, 28):
                Carrier = row["Carr148"]
            elif i in (7, 11, 17, 21, 25, 29):
                Carrier = row["Carr149"]
            elif i in (8, 12, 18, 22, 26, 30):
                Carrier = row["Carr150"]
            else:
                Carrier = ""

            record = {
                "i": i,
                "origin": row["origin"],
                "destination": row["destination"],
                "MinPath": i,
                "TotalNtwkMiles": TotalNtwkMiles,
                "DmsLhMiles": DmsLhMiles,
                "DmsDrayMiles": DmsDrayMiles,
                "IntlShipMiles": IntlShipMiles,
                "CmapPsRL": row["CmapPsRL"],
                "CmapPsTR": row["CmapPsTR"],
                "RlDwlCode": row["Rdwl"],
                "RlTrnfr": np.nan,
                "Carrier": Carrier
            }
            oRows_modeDist.append(record)        
        
    remainingRows = len(modeDist)-counter
    timelapse_records(startTime, counter, remainingRows)
    counter = counter+1
    
outModeDist = pd.DataFrame.from_records(oRows_modeDist)

# Filter out duplicate origin-destination-minpath rows
outModeDist = outModeDist.groupby(['origin', 'destination', 'MinPath']).nth(0).reset_index()

outModeDist2 = outModeDist.copy()
outModeDist2['CmapPsTR'] = np.where((row['i'] < 36) | (row['i'] > 46), 0, outModeDist2['CmapPsTR'])
outModeDist2['CmapPsRL'] = np.where((row['i'] < 3) | (row['i'] > 30), 0, outModeDist2['CmapPsRL'])
outModeDist2['RlDwlCode'] = np.where((row['i'] < 3) | (row['i'] > 30), 0, outModeDist2['RlDwlCode'])
outModeDist2['RlTrnfr'] = np.where((row['i'] < 3) | (row['i'] > 30), 0, outModeDist2['RlTrnfr'])

# adjust CMAP intrazonal truck modes
condDMS = ((outModeDist2['origin'] == outModeDist2['destination']) & 
           ((outModeDist2['origin'] <= in_nodeznmeso['LIZ']) & 
           (outModeDist2['MinPath'].isin([31, 46]))))
outModeDist2['DmsLhMiles'] = np.where(condDMS, outModeDist2['TotalNtwkMiles'], outModeDist2['RlTrnfr'])

# address errors due to rounding
outModeDist2['checkSum'] = outModeDist2['DmsLhMiles'] + outModeDist2['DmsDrayMiles'] + outModeDist2['IntlShipMiles']
outModeDist2['TotalNtwkMiles'] = np.where(outModeDist2['checkSum'] > outModeDist2['TotalNtwkMiles'], outModeDist2['checkSum'], outModeDist2['TotalNtwkMiles'])

outModeDist2['RlDwlCode'] = np.where(outModeDist2['CmapPsRL'] > 0, 0, outModeDist2['RlDwlCode'])
outModeDist2['RlTrnfr'] = np.where(outModeDist2['CmapPsRL'] > 0, 0, outModeDist2['RlDwlCode'])
outModeDist2['RlTrnfr'] = np.where(~(outModeDist2['CmapPsRL'] > 0) & (outModeDist2['RlDwlCode'] > 0), 0, outModeDist2['RlTrnfr'])
    
outModeDist2=outModeDist2[['origin', 'destination', 'MinPath', 'TotalNtwkMiles', 'DmsLhMiles', 'DmsDrayMiles', 'IntlShipMiles', 'CmapPsTR', 'CmapPsRL', 'RlDwlCode', 'RlTrnfr']]

# Export
outModeDist2.to_csv(pth_outModeDist, index=False)

# -----------------------------------------------------------------------------
# CREATE MESOZONE-TO-MESOZONE TRUCK SKIMS FOR STOP SEQUENCING IN TRUCK TOURS
# -----------------------------------------------------------------------------
in_mf31 = in_mf31.rename(columns={'Ttt':'dist'})

mmCond = (
    ((in_mf31['origin'] >= in_nodeznmeso['FIZ']) & (in_mf31['origin'] <= in_nodeznmeso['LIZ'])) &
    ((in_mf31['destination'] >= in_nodeznmeso['FIZ']) & (in_mf31['destination'] <= in_nodeznmeso['LIZ'])) &
    (in_mf31['dist'] > 0)

)

mmTT = in_mf31.loc[mmCond].copy()
mmTT = mmTT[['origin', 'destination', 'dist']]

intrazn = in_gcd.loc[(in_gcd['Production_zone'] == in_gcd['Consumption_zone']) & (in_gcd['Production_zone'] <= in_nodeznmeso['LIZ'])].copy()
intrazn = intrazn.rename(columns={'Consumption_zone': 'destination', 'Production_zone': 'origin', 'GCD':'dist'})
intrazn = intrazn[['origin', 'destination', 'dist']]

mesoSkim = pd.concat([mmTT, intrazn])
mesoSkim['Time'] = round(mesoSkim['dist']/in_sptime['DrayTruckMPH'], 3)
mesoSkim = mesoSkim.groupby(['origin', 'destination']).nth(0).reset_index()
mesoSkim=mesoSkim[['origin', 'destination', 'Time']]

mesoSkim.to_csv(pth_outMesoSkim, index=False)

# -----------------------------------------------------------------------------
# CREATE PORTS FILES FOR MESO MODEL
# -----------------------------------------------------------------------------
port = outModepaths.loc[outModepaths['Port_mesozoneNB'].notnull()].copy()
port=port[['origin', 'destination', 'Port_mesozoneNB', 'Port_NameNB', 'Port_mesozoneB', 'Port_NameB']]

port = port.groupby(['origin', 'destination']).nth(0).reset_index()
port.rename(columns={'destination':'Consumption_zone', 'origin':'Production_zone'}, inplace=True)

port.to_csv(pth_outPorts, index=False)

# -----------------------------------------------------------------------------
# CREATE AIRPORTS FILES FOR MESO MODEL
# -----------------------------------------------------------------------------
airport = outModepaths.loc[outModepaths['FrAir_mesozone'].notnull()].copy()
airport=airport[['origin', 'destination', 'Port_mesozoneNB', 'Port_NameNB', 'Port_mesozoneB', 'Port_NameB']]

airport = airport.groupby(['origin', 'destination']).nth(0).reset_index()
airport.rename(columns={'destination':'Consumption_zone', 'origin':'Production_zone'}, inplace=True)

airport.to_csv(pth_outAirports, index=False)

