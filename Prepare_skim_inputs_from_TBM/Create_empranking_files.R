## Create_freight_model_CMAP_employment_files.R
##   Craig Heither, 02-07-2025
##
##  This script reads the socioeconomic data from the trip-based model and creates the freight model input files:
##      - cmap_data_zone_employment 
##      - data_mesozone_emprankings.csv
    ## is it county percentile or mesozone percentile?? -- Mesozone rnk within county

##----------------------------------------------------------------------------------------------------------------------------------------

# =======================================================================
	## --> Update this information <-- ##
conformity = 'c25q4'                                      ##-- Conformity
factor2060 = 0.99                                   ##-- 2060 employment factor (in lieu of a formal process)
scenario_list = list(
  '100'= '2019',
  '200'= '2026',
  '300'= '2030',
  '500'= '2035',
  '600'= '2040',
  '800'= '2050'
)
  
# Input paths
tbmFolder = paste0("M:/catslib/modelprod/",	conformity)												##-- folder containing Conformity runs
szmeso = "V:/Secure/Master_Freight/Processing_Data/NetworkUpdate/MFN_crosswalks.xlsx"   ##-- subzone-zone-mesozone correspondence

# Create list of conformity folders
conformityDir = paste0('M:/catslib/modelprod/', conformity)
conformityFolders <- list.dirs(
  conformityDir,
  recursive = FALSE,
  full.names = FALSE
)

conformityFolders <- conformityFolders[grepl(paste0("^", conformity, "_[0-9]+_[0-9]{8}$"), conformityFolders)]

# Create list of all scenario years
# adding 2060 if not present 
scenLabel = c()
for(folder in conformityFolders){
  scenario = strsplit(folder, "_")[[1]][2]
  
  year = as.character(scenario_list[scenario])
  print(year)
  
  scenLabel <- c(scenLabel, year)
}

if(!('2060' %in% scenLabel)){
  scenLabel <- c(scenLabel, '2060')
}

# Create list of all input tgFiles
subfolderPath = 'cmap_trip-based_model/Database/tg/UrbanSim_inputs'

tg_folders <- file.path(tbmFolder, conformityFolders, subfolderPath)
tg_paths = c()  
for(file_dir in tg_folders){
  if (!dir.exists(file_dir)) {
    print(file_dir)
    print('Folder does not exist!')
  }
  else{
    file_paths <- list.files(
      file_dir,
      pattern = "^(subzonetm_|xsubzonetm_)",
      full.names = TRUE
    )
    
    tg_paths = c(tg_paths, file_paths)
  }
}

tgFiles = c()
for(tg_file in tg_paths){
  file = basename(tg_file)
  file = strsplit(file, '.csv', 1)
  tgFiles = c(tgFiles, file)
}

tgFiles <- unlist(tgFiles)     ##-- UrbanSim subzone files 

#Outputs 
outputFolder = paste0(getwd(), '/Output_', conformity)	##-- where the output files will be stored
if (!dir.exists(outputFolder)) {
  dir.create(outputFolder, recursive = TRUE)
}

qcFile = "QC_employment.csv"
# cmap_data_zone_employment
# data_mesozone_emprankings

# =======================================================================

max7maz <- 16426			##-- maximum subzone number in CMAP seven counties

##----------------------------------------------------------------------------------------------------------------------------------------
loadPackage <- function (package) {
                if(!package %in% .packages(all = TRUE)) {
                                install.packages(package, repos = "http://cran.r-project.org")
                }
                eval(parse(text=paste("library(", package, ")", sep="")))
}
loadPackage("data.table")
loadPackage("dplyr")
loadPackage("readxl")
##----------------------------------------------------------------------------------------------------------------------------------------

empCats = c("num_jobs_sector_11","num_jobs_sector_21","num_jobs_sector_22","num_jobs_sector_23","num_jobs_sector_31","num_jobs_sector_42",
            "num_jobs_sector_44","num_jobs_sector_48","num_jobs_sector_51","num_jobs_sector_52","num_jobs_sector_53","num_jobs_sector_54",
            "num_jobs_sector_55","num_jobs_sector_56","num_jobs_sector_61","num_jobs_sector_62","num_jobs_sector_71","num_jobs_sector_72",
            "num_jobs_sector_81","num_jobs_sector_92")        

qc <- data.table(COUNTY=numeric(),total_jobs=numeric())     ##-- empty data.table

yr_counter = 1
for (i in 1:length(conformityFolders)) {
  print(i)
    cat("    -----", scenLabel[i], "-----    ", fill=T)
    file1 = file.path(tbmFolder,conformityFolders[i],"cmap_trip-based_model","Database","tg","UrbanSim_inputs",paste0(tgFiles[yr_counter],".csv"))
    cmap <- fread(file1)
    cmap = cmap[subzone_id <= max7maz]		##-- limit to CMAP 7-county subzones
    cat(" ->", format(nrow(cmap), big.mark=",", scientific=F), "records in", file1, "with", ncol(cmap), "columns", fill=T)
    #
    file2 = file.path(tbmFolder,conformityFolders[i],"cmap_trip-based_model","Database","tg","UrbanSim_inputs",paste0(tgFiles[yr_counter+1],".csv"))
    extn <- fread(file2)
    cat(" ->", format(nrow(extn), big.mark=",", scientific=F), "records in", file2, "with", ncol(extn), "columns", fill=T)
    cmap <- rbindlist(list(cmap,extn), use.names=T, fill=T)
    #
    ## -- Read file and create full subzone template -- ##
    file3 = file.path(tbmFolder,conformityFolders[i],"cmap_trip-based_model","Database","tg","fortran","GEOG_IN.TXT")
    geog <- fread(file3)
    setnames(geog, c("V1","V2"), c("subzone_id","COUNTY"))
    geog <- geog[, list(subzone_id,COUNTY)]
    setkey(geog,subzone_id); setkey(cmap,subzone_id)
    cmap <- cmap[geog]
    #
    ## -- Sum employment by subzone -- ##
    cmap1 <- cmap[, .(total_jobs=sum(total_jobs,na.rm=T), num_jobs_sector_11=sum(num_jobs_sector_11,na.rm=T), num_jobs_sector_21=sum(num_jobs_sector_21,na.rm=T),
                    num_jobs_sector_22=sum(num_jobs_sector_22,na.rm=T), num_jobs_sector_23=sum(num_jobs_sector_23,na.rm=T),
                    num_jobs_sector_31=sum(num_jobs_sector_31,na.rm=T), num_jobs_sector_42=sum(num_jobs_sector_42,na.rm=T),
                    num_jobs_sector_44=sum(num_jobs_sector_44,na.rm=T), num_jobs_sector_48=sum(num_jobs_sector_48,na.rm=T),
                    num_jobs_sector_51=sum(num_jobs_sector_51,na.rm=T), num_jobs_sector_52=sum(num_jobs_sector_52,na.rm=T),
                    num_jobs_sector_53=sum(num_jobs_sector_53,na.rm=T), num_jobs_sector_54=sum(num_jobs_sector_54,na.rm=T),
                    num_jobs_sector_55=sum(num_jobs_sector_55,na.rm=T), num_jobs_sector_56=sum(num_jobs_sector_56,na.rm=T),
                    num_jobs_sector_61=sum(num_jobs_sector_61,na.rm=T), num_jobs_sector_62=sum(num_jobs_sector_62,na.rm=T),
                    num_jobs_sector_71=sum(num_jobs_sector_71,na.rm=T), num_jobs_sector_72=sum(num_jobs_sector_72,na.rm=T),
                    num_jobs_sector_81=sum(num_jobs_sector_81,na.rm=T), num_jobs_sector_92=sum(num_jobs_sector_92,na.rm=T)), by=.(subzone_id)][order(subzone_id)]
    #--------------------------------------------------------------------------------------------------------------------------------
    ### --- Adjust 2060 employment --- ###
    if (scenLabel[i]=="2060") {
        cmap2 <- cmap1[, lapply(.SD, "*", factor2060), .SDcols=empCats]
        cmap2 <- cmap2[,(empCats) := round(.SD,0), .SDcols=empCats]
        cmap2 <- cmap2[, total_jobs := rowSums(.SD), .SDcols=empCats]
        cmap2[, subzone_id:=.I]
        cmap1 <- copy(cmap2)
    }

    cat(" ->", format(length(unique(cmap1$subzone_id)), big.mark=",", scientific=F), "unique subzones in", format(nrow(cmap1), big.mark=",",
        scientific=F), "records", fill=T)
    #--------------------------------------------------------------------------------------------------------------------------------
    ## -- Read file and attach MESOZONE and Zone -- ##
    corresp <- read_excel(szmeso, sheet = 'sz_mz')
    corresp <- corresp %>% rename(Zone = zone17, subzone_id = subzone17)
    cmap1 <- cmap1 %>% left_join(corresp, by = 'subzone_id')
#    setnames(corresp, c("zone17","subzone17"), c("Zone","subzone_id"))
#    setkey(corresp,subzone_id); setkey(cmap1,subzone_id)
 #   cmap1 <- cmap1[corresp]
    #
    ## -- Sum total employment by zone -- ##
    znEmp <- cmap1[, .(totalemp=sum(total_jobs)), by=.(Zone,mesozone)][order(Zone,mesozone)]
    file1name = paste0("cmap_data_zone_employment_",scenLabel[i],".csv")
    fwrite(znEmp, file=file.path(outputFolder,file1name))
    cat(" ->", format(nrow(znEmp), big.mark=",", scientific=F), "records written to", file1name, "with", ncol(znEmp), "columns", fill=T)
    cat("  -> QC zones: - minimum value=", min(znEmp$Zone), " maximum value=", max(znEmp$Zone), fill=T)
    cat("  -> QC mesozones: - minimum value=", min(znEmp$mesozone), " maximum value=", max(znEmp$mesozone), fill=T)
    cat("  -> QC employment: - minimum value=", format(min(znEmp$totalemp), big.mark=",", scientific=F), " mean value=", 
	    format(mean(znEmp$totalemp), big.mark=",", scientific=F), " median value=", format(median(znEmp$totalemp), big.mark=",", scientific=F), 
	    " maximum value=", format(max(znEmp$totalemp), big.mark=",", scientific=F), fill=T)
    cat("  ->", scenLabel[i], "total CMAP modeling area employment:", format(sum(znEmp$totalemp), big.mark=",", scientific=F), fill=T)
    #
    ## -- QC County level employment -- ##
    setkey(geog,subzone_id); setkey(cmap1,subzone_id)
    cmap1 <- cmap1[geog]
    cnty <- cmap1[, .(total_jobs=sum(total_jobs)), by=.(COUNTY)][order(COUNTY)]
    cnty[, year:=scenLabel[i]]
    qc <- rbindlist(list(qc,cnty), use.names=T, fill=T)
    #
    ## -- Create employment ranking file -- ##
    cmap1[, c("subzone_id","total_jobs","Zone"):=NULL]
    empSum <- cmap1[, .(num_jobs_sector_11=sum(num_jobs_sector_11), num_jobs_sector_21=sum(num_jobs_sector_21),
                    num_jobs_sector_22=sum(num_jobs_sector_22), num_jobs_sector_23=sum(num_jobs_sector_23),
                    num_jobs_sector_31=sum(num_jobs_sector_31), num_jobs_sector_42=sum(num_jobs_sector_42),
                    num_jobs_sector_44=sum(num_jobs_sector_44), num_jobs_sector_48=sum(num_jobs_sector_48),
                    num_jobs_sector_51=sum(num_jobs_sector_51), num_jobs_sector_52=sum(num_jobs_sector_52),
                    num_jobs_sector_53=sum(num_jobs_sector_53), num_jobs_sector_54=sum(num_jobs_sector_54),
                    num_jobs_sector_55=sum(num_jobs_sector_55), num_jobs_sector_56=sum(num_jobs_sector_56),
                    num_jobs_sector_61=sum(num_jobs_sector_61), num_jobs_sector_62=sum(num_jobs_sector_62),
                    num_jobs_sector_71=sum(num_jobs_sector_71), num_jobs_sector_72=sum(num_jobs_sector_72),
                    num_jobs_sector_81=sum(num_jobs_sector_81), num_jobs_sector_92=sum(num_jobs_sector_92)), 
                    by=.(mesozone,COUNTY)][order(mesozone,COUNTY)]
    

    # group_by(COUNTY) %>% mutate(percent_rank11 = rank(num_jobs_sector_11)/length(num_jobs_sector_11)))  ##-- calculate percent rank
    # rank:=as.integer(round(10 * percent_rank11 + 0.49))]     ##-- format to a rank ranging from 1 to 10
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ## -- QC -- ##
    #empSum <- as.data.table(empSum %>% group_by(COUNTY) %>% mutate(percent_rank11 = rank(num_jobs_sector_11)/length(num_jobs_sector_11)))
    #empSum[, rank11:=as.integer(round(10 * percent_rank11 + 0.49))] 
    #empSum <- as.data.table(empSum %>% group_by(COUNTY) %>% mutate(test11 = as.integer(round(rank(num_jobs_sector_11)/length(num_jobs_sector_11) * 10 + 0.49))))
    #check <- empSum[rank11 != test11]
    #cat(nrow(check), "rows do not have matching values", fill=T)
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    empSum <- as.data.table(empSum %>% group_by(COUNTY) %>%
                mutate(rank11 = as.integer(round(rank(num_jobs_sector_11)/length(num_jobs_sector_11) * 10 + 0.49))))
    empSum <- as.data.table(empSum %>% group_by(COUNTY) %>%
                mutate(rank21 = as.integer(round(rank(num_jobs_sector_21)/length(num_jobs_sector_21) * 10 + 0.49))))
    empSum <- as.data.table(empSum %>% group_by(COUNTY) %>%
                mutate(rank22 = as.integer(round(rank(num_jobs_sector_22)/length(num_jobs_sector_22) * 10 + 0.49))))
    empSum <- as.data.table(empSum %>% group_by(COUNTY) %>%
                mutate(rank23 = as.integer(round(rank(num_jobs_sector_23)/length(num_jobs_sector_23) * 10 + 0.49))))
    empSum <- as.data.table(empSum %>% group_by(COUNTY) %>%
                mutate(rank31 = as.integer(round(rank(num_jobs_sector_31)/length(num_jobs_sector_31) * 10 + 0.49))))
    empSum <- as.data.table(empSum %>% group_by(COUNTY) %>%
                mutate(rank42 = as.integer(round(rank(num_jobs_sector_42)/length(num_jobs_sector_42) * 10 + 0.49))))
    empSum <- as.data.table(empSum %>% group_by(COUNTY) %>%
                mutate(rank44 = as.integer(round(rank(num_jobs_sector_44)/length(num_jobs_sector_44) * 10 + 0.49))))
    empSum <- as.data.table(empSum %>% group_by(COUNTY) %>%
                mutate(rank48 = as.integer(round(rank(num_jobs_sector_48)/length(num_jobs_sector_48) * 10 + 0.49))))
    empSum <- as.data.table(empSum %>% group_by(COUNTY) %>%
                mutate(rank51 = as.integer(round(rank(num_jobs_sector_51)/length(num_jobs_sector_51) * 10 + 0.49))))
    empSum <- as.data.table(empSum %>% group_by(COUNTY) %>%
                mutate(rank52 = as.integer(round(rank(num_jobs_sector_52)/length(num_jobs_sector_52) * 10 + 0.49))))
    empSum <- as.data.table(empSum %>% group_by(COUNTY) %>%
                mutate(rank53 = as.integer(round(rank(num_jobs_sector_53)/length(num_jobs_sector_53) * 10 + 0.49))))
    empSum <- as.data.table(empSum %>% group_by(COUNTY) %>%
                mutate(rank54 = as.integer(round(rank(num_jobs_sector_54)/length(num_jobs_sector_54) * 10 + 0.49))))
    empSum <- as.data.table(empSum %>% group_by(COUNTY) %>%
                mutate(rank55 = as.integer(round(rank(num_jobs_sector_55)/length(num_jobs_sector_55) * 10 + 0.49))))
    empSum <- as.data.table(empSum %>% group_by(COUNTY) %>%
                mutate(rank56 = as.integer(round(rank(num_jobs_sector_56)/length(num_jobs_sector_56) * 10 + 0.49))))
    empSum <- as.data.table(empSum %>% group_by(COUNTY) %>%
                mutate(rank61 = as.integer(round(rank(num_jobs_sector_61)/length(num_jobs_sector_61) * 10 + 0.49))))
    empSum <- as.data.table(empSum %>% group_by(COUNTY) %>%
                mutate(rank62 = as.integer(round(rank(num_jobs_sector_62)/length(num_jobs_sector_62) * 10 + 0.49))))
    empSum <- as.data.table(empSum %>% group_by(COUNTY) %>%
                mutate(rank71 = as.integer(round(rank(num_jobs_sector_71)/length(num_jobs_sector_71) * 10 + 0.49))))
    empSum <- as.data.table(empSum %>% group_by(COUNTY) %>%
                mutate(rank72 = as.integer(round(rank(num_jobs_sector_72)/length(num_jobs_sector_72) * 10 + 0.49))))
    empSum <- as.data.table(empSum %>% group_by(COUNTY) %>%
                mutate(rank81 = as.integer(round(rank(num_jobs_sector_81)/length(num_jobs_sector_81) * 10 + 0.49))))
    empSum <- as.data.table(empSum %>% group_by(COUNTY) %>%
                mutate(rank92 = as.integer(round(rank(num_jobs_sector_92)/length(num_jobs_sector_92) * 10 + 0.49))))
    empSum[, (empCats):=NULL]
    empSum[, rank99:=1]         ##-- no NAICS 99 employment in UrbanSim but provide a rank as original file did
    setnames(empSum, c("mesozone","rank31","rank44","rank48"), c("MESOZONE","rank3133","rank4445","rank4849"))
    setcolorder(empSum, c("COUNTY"))
    #
    file2name = paste0("data_mesozone_emprankings_",scenLabel[i],".csv")
    fwrite(empSum, file=file.path(outputFolder,file2name))
    cat("   -> QC rank11:", nrow(empSum[is.na(rank11)]), "records have no values; minimum value=", min(empSum$rank11), "median value=",
                median(empSum$rank11), "maximum value=", max(empSum$rank11), fill=T)
    cat("   -> QC rank21:", nrow(empSum[is.na(rank21)]), "records have no values; minimum value=", min(empSum$rank21), "median value=",
                median(empSum$rank21), "maximum value=", max(empSum$rank21), fill=T)
    cat("   -> QC rank22:", nrow(empSum[is.na(rank22)]), "records have no values; minimum value=", min(empSum$rank22), "median value=",
                median(empSum$rank22), "maximum value=", max(empSum$rank22), fill=T)
    cat("   -> QC rank23:", nrow(empSum[is.na(rank23)]), "records have no values; minimum value=", min(empSum$rank23), "median value=",
                median(empSum$rank23), "maximum value=", max(empSum$rank23), fill=T)
    cat("   -> QC rank3133:", nrow(empSum[is.na(rank3133)]), "records have no values; minimum value=", min(empSum$rank3133), "median value=",
                median(empSum$rank3133), "maximum value=", max(empSum$rank3133), fill=T)
    cat("   -> QC rank42:", nrow(empSum[is.na(rank42)]), "records have no values; minimum value=", min(empSum$rank42), "median value=",
                median(empSum$rank42), "maximum value=", max(empSum$rank42), fill=T)
    cat("   -> QC rank4445:", nrow(empSum[is.na(rank4445)]), "records have no values; minimum value=", min(empSum$rank4445), "median value=",
                median(empSum$rank4445), "maximum value=", max(empSum$rank4445), fill=T)
    cat("   -> QC rank4849:", nrow(empSum[is.na(rank4849)]), "records have no values; minimum value=", min(empSum$rank4849), "median value=",
                median(empSum$rank4849), "maximum value=", max(empSum$rank4849), fill=T)
    cat("   -> QC rank51:", nrow(empSum[is.na(rank51)]), "records have no values; minimum value=", min(empSum$rank51), "median value=",
                median(empSum$rank51), "maximum value=", max(empSum$rank51), fill=T)
    cat("   -> QC rank52:", nrow(empSum[is.na(rank52)]), "records have no values; minimum value=", min(empSum$rank52), "median value=",
                median(empSum$rank52), "maximum value=", max(empSum$rank52), fill=T)
    cat("   -> QC rank53:", nrow(empSum[is.na(rank53)]), "records have no values; minimum value=", min(empSum$rank53), "median value=",
                median(empSum$rank53), "maximum value=", max(empSum$rank53), fill=T)
    cat("   -> QC rank54:", nrow(empSum[is.na(rank54)]), "records have no values; minimum value=", min(empSum$rank54), "median value=",
                median(empSum$rank54), "maximum value=", max(empSum$rank54), fill=T)
    cat("   -> QC rank55:", nrow(empSum[is.na(rank55)]), "records have no values; minimum value=", min(empSum$rank55), "median value=",
                median(empSum$rank55), "maximum value=", max(empSum$rank55), fill=T)
    cat("   -> QC rank56:", nrow(empSum[is.na(rank56)]), "records have no values; minimum value=", min(empSum$rank56), "median value=",
                median(empSum$rank56), "maximum value=", max(empSum$rank56), fill=T)
    cat("   -> QC rank61:", nrow(empSum[is.na(rank61)]), "records have no values; minimum value=", min(empSum$rank61), "median value=",
                median(empSum$rank61), "maximum value=", max(empSum$rank61), fill=T)
    cat("   -> QC rank62:", nrow(empSum[is.na(rank62)]), "records have no values; minimum value=", min(empSum$rank62), "median value=",
                median(empSum$rank62), "maximum value=", max(empSum$rank62), fill=T)
    cat("   -> QC rank71:", nrow(empSum[is.na(rank71)]), "records have no values; minimum value=", min(empSum$rank71), "median value=",
                median(empSum$rank71), "maximum value=", max(empSum$rank71), fill=T)
    cat("   -> QC rank72:", nrow(empSum[is.na(rank72)]), "records have no values; minimum value=", min(empSum$rank72), "median value=",
                median(empSum$rank72), "maximum value=", max(empSum$rank72), fill=T)
    cat("   -> QC rank81:", nrow(empSum[is.na(rank81)]), "records have no values; minimum value=", min(empSum$rank81), "median value=",
                median(empSum$rank81), "maximum value=", max(empSum$rank81), fill=T)
    cat("   -> QC rank92:", nrow(empSum[is.na(rank92)]), "records have no values; minimum value=", min(empSum$rank92), "median value=",
                median(empSum$rank92), "maximum value=", max(empSum$rank92), fill=T)    
    yr_counter =yr_counter+2
}

## -- Write QC file -- ##
fwrite(qc, file=file.path(outputFolder,qcFile))
cat("Done!", fill=T)
