#################################################################################
# STEP4_CREATE_ZONAL_TRUCK_TOUR_FILES.SAS                                       # 
# kcazzato 09/05/2025 updates                                                   #
# ----- Translated SAS processsing                                              #
# Craig Heither, rev. 05-06-2016                                                #
#                                                                               #
#	This program creates the CMAP zonal files used in the truck touring model.  #
#                                                                               # 
#                                                                             	#
#-- Input files needed (located in ..\input_data\post_processing\):             #
#	  - hwydist_pk - AM Peak skimmed miles (from zn09_skim_data.mac)            #
#	  - hwytime_pk - AM Peak skimmed minutes (from zn09_skim_data.mac)          #	  
#	  - hwytime_op - Midday skimmed minutes (from zn09_skim_data.mac)           #
#	  - zcentroid_sqmi.txt - zonal area                                         #
#	  - zcentroid_xcoord.txt - zonal X coordinate	                            #  
#	  - zcentroid_ycoord.txt - zonal Y coordinate                               #	  	  
#	  - subzn_emp.csv - Conformity subzone total employment	                    #
#	  - sz_zn09_meso.csv - subzone-zone-mesozone correspondence file	        #
#                                                                             	#
#-- Output (zone17, located in ../output_data/post_processing/)                 #
#	  - cmap_data_zone_skims_YYYY.csv - zonal peak and offpeak skims            #
#	  - cmap_data_zone_centroids_YYYY.csv - zone centroid coordinates	        #
#	  - cmap_data_zone_employment_YYYY.csv - zonal employment                   #
#################################################################################

# ---------------------------------------------------------------
# Import Directories
# ---------------------------------------------------------------
import sys, os
import pandas as pd, numpy as np

# ---------------------------------------------------------------
# Define paths
# ---------------------------------------------------------------
year=sys.argv[0]				          ##-- Flag Year 
programDir = os.getcwd()                  ##-- Database/post_processing

##-- File directories
databaseDir = os.path.abspath(os.path.join(programDir, "../"))             ##-- Database     
inDir = os.path.join(databaseDir + '/input_data/post_processing')          ##-- Database/input_data/post_processing
outDir = os.path.join(databaseDir + '/output_data/post_processing')        ##-- Database/output_data/post_processing

##-- Inputs 
pth_hwydist= os.path.join(inDir + "/hwydist_pk" )           ##-- AM Peak skimmed miles 
pth_hwytmpk= os.path.join(inDir + "/hwytime_pk" )           ##-- AM Peak skimmed minutes
pth_hwytmop= os.path.join(inDir + "/hwytime_op")            ##-- Midday skimmed minutes 
pth_znsqmi= os.path.join(inDir + "/zcentroid_sqmi.txt")     ##-- zonal area
pth_znx= os.path.join(inDir + "/zcentroid_xcoord.txt")      ##-- zone x-coordinate
pth_zny= os.path.join(inDir + "/zcentroid_ycoord.txt")      ##-- zone y-coordinate 
pth_emp= os.path.join(inDir + "/subzn_emp.csv")             ##-- subzone total employment 
pth_corresp= os.path.join(inDir + "/sz_zn09_meso.csv")      ##-- subzone-zone-mesozone correspondence file 

##-- Outputs 
outSkims= os.path.join(outDir + "/cmap_data_zone_skims_" + year + ".csv")            ##-- New output file of Zonal skims
outCentroids= os.path.join(outDir + "/cmap_data_zone_centroids_" + year + ".csv")    ##-- New output file of CMAP zone centroid coordinates
outEmp= os.path.join(outDir + "/cmap_data_zone_employment_" + year + ".csv")         ##-- New output file of CMAP zonal employment 

# ---------------------------------------------------------------
# Import Data
# ---------------------------------------------------------------
in_hwydist = pd.read_csv(pth_hwydist, sep = ' ', skiprows = 5, header=None)           ##-- AM Peak skimmed miles 
in_hwytmpk = pd.read_csv(pth_hwytmpk, sep = ' ', skiprows = 5, header=None)           ##-- AM Peak skimmed minutes
in_hwymop = pd.read_csv(pth_hwytmop, sep = ' ', skiprows = 5, header=None)            ##-- Midday skimmed minutes 

in_znsqmi = pd.read_csv(pth_znsqmi, sep = ' all', skiprows = 5, header=None, engine='python')   ##-- zonal area
in_znx = pd.read_csv(pth_znx, sep = ' all:', skiprows = 3, header=None, engine='python')        ##-- zone x-coordinate
in_zny = pd.read_csv(pth_zny,  sep = ':', skiprows = 3, header=None, engine='python')           ##-- zone y-coordinate 

in_emp = pd.read_csv(pth_emp)           ##-- subzone total employment 
in_corresp = pd.read_csv(pth_corresp)   ##-- subzone-zone-mesozone correspondence file 

# ----------------------------------------------------------------------------
#  Create a template of all zonal interchanges to write to matrix files -- ##
# ----------------------------------------------------------------------------
## -- Create matrix origins and destinations -- ##
maxZone = 3649		
mtxdest = np.arange(1,maxZone+1)								## -- array of consecutive numbers representing matrix destinations
dest = np.tile(mtxdest,maxZone)									## -- array of repeating destination zone pattern
orig = np.repeat(mtxdest,maxZone)								## -- repeated in ascending order for origins
origdf = pd.DataFrame(orig, columns = ['origin'])
origdf.insert(loc=0, column='A',value=np.arange(len(origdf)))
destdf = pd.DataFrame(dest, columns = ['destination'])
destdf.insert(loc=0, column='A',value=np.arange(len(destdf)))
tmplt = origdf.merge(destdf, how='left', on='A', copy=False)

# ---------------------------------------------------------------
# Format zonal geography data
# ---------------------------------------------------------------
##-- For some reason, these all are different export formats from emme?? KC can fix later to streamline but okay for now
##-- Rename columns and assign data types to zone square miles
znsqmi = in_znsqmi
znsqmi.columns = ['zone', 'sqmi']
znsqmi = znsqmi.astype({'zone': int, 'sqmi': float})

##-- Rename columns and assign data types to zone x-coordinate
znx = in_znx
znx.columns = ['zone', 'xcoord']
znx = znx.astype({'zone': int, 'xcoord': float})

##-- Rename columns and assign data types to zone y-coordinate
zny = in_zny
zny.columns = ['blech', 'ycoord']
zny[['skip', 'zone']] = zny['blech'].str.split('all', expand = True)
zny=zny[['zone','ycoord']]
zny = zny.astype({'zone': int, 'ycoord': float})

# ---------------------------------------------------------------
# Format and export zone centroid coordinates
# ---------------------------------------------------------------
zncoords = pd.merge(znx, zny, how='left', on='zone')            ##-- Combine xy coordinates
zncoords['x_coord']=(zncoords['xcoord']/5280).round(3)          ##-- Convert from State Plane feet to Miles
zncoords['y_coord']=(zncoords['ycoord']/5280).round(3)          ##-- Convert from State Plane feet to Miles
zncoords['stop_zone']=zncoords['zone']                          ##-- Create new column of zones named 'stop_zone'
zncoords=zncoords[['stop_zone', 'x_coord', 'y_coord']]          ##-- Select columns
zncoords=zncoords.sort_values('stop_zone')                      ##-- Sort by zone
zncoords.to_csv(outCentroids, index=False)                      ##-- Export as csv, outSkims

# ---------------------------------------------------------------
# Format and export zone employment data 
# ---------------------------------------------------------------
empMeso = pd.merge(in_emp, in_corresp, how='left', on=['zone09', 'subzone09'])      ##-- Combine employment data and correspondance file to attach zone-mesozone
empAgg = empMeso.groupby(['zone09', 'mesozone']).agg({'i18':'sum'}).reset_index()   ##-- Summarize select link volumes, hbw volumes, and hbs volumes
empAgg.columns = ['Zone', 'mesozone', 'totalemp']                                   ##-- Select Columns
empAgg=empAgg.sort_values('Zone')                                                   ##-- Sort by zone
empAgg.to_csv(outEmp, index=False)                                                ##-- Export as csv, outSkims

# ----------------------------------------------------------------------------
#  Format skim data
# ----------------------------------------------------------------------------
matLst = [in_hwydist, in_hwytmpk, in_hwymop]               ##-- List of input data files
type_dict = {'origin': int, 'dest': int, 'value':float}    ##-- Dictionary of data types

i=1   ##-- set counter for naming end df
##-- For each input file in the list
for mat in matLst: 
    mat_in = mat
    mat_in.columns=['skip','origin', 'dest1', 'dest2', 'dest3', 'dest4']         ##-- Rename columns
    mat_in = mat_in[['origin', 'dest1', 'dest2', 'dest3', 'dest4']]              ##-- Select columns

    ##-- Split destination zone and value (formatted: dzone:value)
    mat_in[['dest1', 'val1']] = mat_in['dest1'].str.split(':', expand = True)   
    mat_in[['dest2', 'val2']] = mat_in['dest2'].str.split(':', expand = True) 
    mat_in[['dest3', 'val3']] = mat_in['dest3'].str.split(':', expand = True)
    mat_in[['dest4', 'val4']] = mat_in['dest4'].str.split(':', expand = True)
    mat_in = mat_in[['origin', 'dest1','val1', 'dest2', 'val2', 'dest3', 'val3', 'dest4', 'val4']].reset_index()   ##-- Select columns

    ##-- Create temporary df for each set of OD-Value column pairs
    tmp1=mat_in[['origin', 'dest1','val1']]
    tmp1.columns=['origin', 'dest', 'value']
    tmp2=mat_in[['origin', 'dest2','val2']]
    tmp2.columns=['origin', 'dest', 'value']
    tmp3=mat_in[['origin', 'dest3','val3']]
    tmp3.columns=['origin', 'dest', 'value']
    tmp4=mat_in[['origin', 'dest4','val4']]
    tmp4.columns=['origin', 'dest', 'value']
    p_mat = pd.concat([tmp1, tmp2, tmp3, tmp4])   ##-- Row bind temporary dfs for final df: origin, destination, value

    ##-- Clean up, not sure if any of this is even necessary now...KC Check
    p_mat = p_mat.dropna()                         #-- Filter to remove NA
    p_mat = p_mat.loc[p_mat['value'] != '.']       #-- Filter to remove links not in sl analysis
    p_mat = p_mat.loc[p_mat['value'] != '']        #-- Filter to remove links not in sl analysis

    p_mat = p_mat.astype(type_dict)    ##-- Convert data types

    ##-- Rename df for manipulation outside loop
    if i==1:
        hwydist = p_mat
    if i==2:
        hwytmpk = p_mat
    if i==3:
        hwymop = p_mat

    i = i+1

##-- Rename columns
hwydist.columns = ['origin', 'destination', 'miles']
hwytmpk.columns = ['origin', 'destination', 'timepk']
hwymop.columns = ['origin', 'destination', 'timeop']

##-- Combine skim data ('zone' object in SAS)
zoneData = pd.merge(tmplt, hwydist, how='left', on=['origin', 'destination'], copy=False)
zoneData = pd.merge(zoneData, hwytmpk, how='left', on=['origin', 'destination'], copy=False)
zoneData = pd.merge(zoneData, hwymop, how='left', on=['origin', 'destination'], copy=False)

# ----------------------------------------------------------------------------
#  Develop Distance & Time for Intrazonal Pairs
# ----------------------------------------------------------------------------
fltZnData = zoneData.loc[zoneData['origin']==zoneData['destination']]                 ##-- Filter zoneData to keep only intrazonal od pairs
fltZnData = fltZnData.merge(znsqmi, how='left', left_on='origin', right_on='zone')    ##-- Intersect with zone square mile data
fltZnData=fltZnData[['origin', 'destination', 'sqmi']]                                ##-- Select columns
fltZnData['miles'] = ((np.sqrt(fltZnData[["sqmi"]]))/2)                               ##-- Calculate distance: assume zones are squares and calculate hypotenuse
fltZnData['timepk'] = fltZnData['miles']/3                                            ##-- Calculate peak travel time: assume speed 20 MPH
fltZnData['timeop'] = fltZnData['timepk']                                             ##-- Let off peak time == peak time
fltZnData=fltZnData[['origin', 'destination', 'miles', 'timepk', 'timeop']]           ##-- Select columns
fltZnData = fltZnData.dropna()                                                        ##-- Filter to remove NA

# ----------------------------------------------------------------------------
#  Finalize & export zonal skim distance and time
# ----------------------------------------------------------------------------
##-- Combine with non-intrazonal data
otherPairs = zoneData.loc[zoneData['origin']!=zoneData['destination']]             ##-- Filter zoneData to keep only non-intrazonal od pairs
otherPairs=otherPairs[['origin', 'destination', 'miles', 'timepk', 'timeop']]      ##-- Select columns
outSkimData = pd.concat([otherPairs, fltZnData]).reset_index()                     ##-- Combine intrazonal and non-intrazonal data

outSkimData['Peak'] = (outSkimData['timepk']/60).round(2)                          ##-- Convert peak travel time to hours
outSkimData['OffPeak'] = (outSkimData['timeop']/60).round(2)                       ##-- Convert off peak travel time to hours
outSkimData['Miles'] = outSkimData['miles'].round(2)                               ##-- Round
outSkimData['Origin'] = outSkimData['origin']                                      ##-- Create new column with capital 'O'
outSkimData['Destination'] = outSkimData['destination']                            ##-- Create new column with capital 'O'

outSkimData=outSkimData[['Origin', 'Destination', 'Peak', 'OffPeak', 'Miles']]     ##-- Select columns
outSkimData = outSkimData.dropna()                                                 ##-- Filter to remove NA

##-- Adjust 0 values
outSkimData['Peak'] = np.where(outSkimData['Peak'] == 0, 0.01, outSkimData['Peak']) 
outSkimData['OffPeak'] = np.where(outSkimData['OffPeak'] == 0, 0.01, outSkimData['OffPeak']) 

outSkimData=outSkimData.sort_values(['Origin', 'Destination'])                     ##-- Sort by origin and destination
outSkimData.to_csv(outSkims, index=False)                                          ##-- Export as csv, outSkims