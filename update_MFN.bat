@echo off
rem Karly Cazzato, CMAP
rem add cleanup of files prior to Running

REM ###################################################################################################################################################
rem FIND R Installation
set infile=pathR.txt
if exist %infile% (del %infile% /Q)
dir "C:\Program Files\R\*Rscript.exe" /s /b >> %infile% 2>nul
set /p path2=<%infile%
set paren="
set rpath=%paren%%path2%%paren%
echo rpath = %rpath%
CD %~dp0

rem FIND SAS Installation
set infile=pathSAS.txt
if exist %infile% (del %infile% /Q)
dir "C:\Program Files\SASHome\SASFoundation\*sas.exe" /s /b >> %infile% 2>nul
set /p path2=<%infile%
set saspath=%paren%%path2%%paren%
echo saspath = %saspath%
CD %~dp0

rem FIND PYTHON Installation
rem call %~dp0Meso_Freight_Skim_Setup_c##q##_YYYY\Scripts\manage\env\activate_env.cmd MFN_env
set infile=pathPY.txt
if exist %infile% (del %infile% /Q)
dir "C:\Program Files\ArcGIS\Pro\bin\Python\envs\arcgispro-py3\python.exe" /s /b >> %infile% 2>nul
set /p path2=<%infile%
set pypath=%paren%%path2%%paren%
echo pypath = %pypath%
CD %~dp0

REM ###################################################################################################################################################
rem HEADER INFO

@echo SELECT RUN MODE
@echo Mode 1: Run all (runs setup, MFN update, skims, and skim QC)
@echo Mode 2: Skip setup (only runs MFN update, skims, and skim QC)
@echo Mode 3: Run skims (only runs skims and skim QC)
@echo Mode 4: Run only final QC
set /p flagModule="[RUN analyze_mode_access? (enter 1, 2, 3, or 4)] "
@echo.
@echo ENTER CONFORMITY NUMBER FOR NEW MFN UPDATE
set /p newconf="[Conformity number (enter c##q##)] "
@echo ENTER CONFORMITY NUMBER FOR TO COMPARE UPDATE TO 
@echo Usually the previous conformity number
@echo EX: if you're updating to c25q2, enter c24q4
set /p oldconf="[Conformity number (enter c##q##)] "

rem SET PATHS
set mhnDir="V:/Secure/Master_Highway/archive/gdb/conformity/mhn_%newconf%.gdb"
set mfnDir=V:/Secure/Master_Freight/Archive/%oldconf%
set tbmInputDir=V:/Secure/Master_Freight/TBM_Inputs/%newconf%
set procDir=V:/Secure/Master_Freight/Processing_Data

rem SET VARIABLES
set /a scenMax = 212
set /a baseYr = 2022
set /a firstYr = 2025
set /a lastYr = 2050

REM ###################################################################################################################################################
rem BEGIN RUN
@Echo Press enter to begin run
pause

if "%flagModule%"=="1" (goto run1)
if "%flagModule%"=="2" (goto run2)
if "%flagModule%"=="3" (goto run3)
if "%flagModule%"=="4" (goto run4)

:run1
CD %~dp0
if exist model_run_timestamp.txt (del model_run_timestamp.txt /Q)
@ECHO ============================================================= >> %~dp0/model_run_timestamp.txt
@ECHO BEGIN CMAP FREIGHT NETWORK UPDATE AND SKIMS >> %~dp0/model_run_timestamp.txt
@ECHO Model Run Start Time: %date% %time% >> %~dp0/model_run_timestamp.txt
@ECHO ============================================================= >> model_run_timestamp.txt
@Echo %date% %time% Copying Base Data from V Drive...  >> %~dp0/model_run_timestamp.txt

REM ###################################################################################################################################################
rem DEVELOP REMAINING FOLDER STRUCTURE
if not exist "..\Input" (mkdir "..\Input")
if not exist "..\Input\Skim_Output_%oldconf%" (mkdir "..\Input\Skim_Output_%oldconf%")
if not exist "..\Input\BatchinFiles_%oldconf%" (mkdir "..\Input\BatchinFiles_%oldconf%")
if not exist "..\Input\MFN_%oldconf%.gdb" (mkdir "..\Input\MFN_%oldconf%.gdb")
<<<<<<< Updated upstream
if not exist "..\Input\MHN_%oldconf%.gdb" (mkdir "..\Input\MHN_%oldconf%.gdb")
=======
if not exist "..\Input\MHN_%newconf%.gdb" (mkdir "..\Input\MHN_%newconf%.gdb")
>>>>>>> Stashed changes
if not exist "..\Output\MFN_updated_%newconf%.gdb" (mkdir "..\Output\MFN_updated_%newconf%.gdb")
if not exist "..\Skim_New\Model_Setups" (mkdir "..\Skim_New\Model_Setups")
if not exist "..\Output\BatchinFiles" (mkdir "..\Output\BatchinFiles")
@echo created folder structure

rem COPY FILES FROM V DRIVE TO WORKSPACE
xcopy "%mfnDir%\Skim_Output" "..\Input\Skim_Output_%oldconf%" /s
xcopy "%mfnDir%\BatchinFiles" "..\Input\BatchinFiles_%oldconf%" /s
copy "%mfnDir%\MFN_%oldconf%.gdb" "..\Input\MFN_%oldconf%.gdb"
copy "%mfnDir%\MFN_%oldconf%.gdb" "..\Output\MFN_updated_%newconf%.gdb"
<<<<<<< Updated upstream
copy %mhnDir% "..\Input\MHN_%oldconf%.gdb"
=======
copy %mhnDir% "..\Input\MHN_%newconf%.gdb"
>>>>>>> Stashed changes
copy "%procDir%\NetworkUpdate" "..\Input"
@echo copied files

rem COPY AND RENAME SKIMS SETUPS, INCLUDING EMMEBANK FROM V DRIVE
set /A counter=%baseYr%
:while
if %counter% GTR %lastYr% (goto loopend)
rem create folders if they do not exist
set nameMod=Meso_Freight_Skim_Setup_%newconf%_%counter%
set sasInDIR="..\Skim_New\Model_Setups\%nameMod%\Database\SAS\inputs\%newconf%\"
if not exist "..\Skim_New\Model_Setups\%nameMod%" (mkdir = "..\Skim_New\Model_Setups\%nameMod%")
rem copy model set up for year
xcopy "Meso_Freight_Skim_Setup_c##q##_YYYY\" "..\Skim_New\Model_Setups\%nameMod%" /s /e
if not exist %sasInDIR% (mkdir=%sasInDIR%)
rem copy emmebank
copy "%procDir%\EmmeBank\emmebank" "..\Skim_New\Model_Setups\%nameMod%\Database"
rem add TBM data to the SAS FOLDER
copy "%tbmInputDir%" %sasInDIR%
if %counter% LEQ %firstYr% (set scen="scen200_yr2025")
if %counter% EQU 2030 (set scen="scen300_yr%counter%")
if %counter% EQU 2035 (set scen="scen400_yr%counter%")
if %counter% EQU 2040 (set scen="scen500_yr%counter%")
if %counter% EQU 2045 (set scen="scen500_yr2040")
if %counter% EQU 2050 (set scen="scen700_yr%counter%")
<<<<<<< Updated upstream
@echo %tbmInputDir%\%scen%
=======

>>>>>>> Stashed changes
copy "%tbmInputDir%\%scen%" %sasInDIR%
if %counter% GTR %baseYr% (set /A counter=counter+5)
if %counter% EQU %baseYr% (set /A counter=%firstYr%)
goto while
:loopend
@echo created skim folders and copied Data

REM ###################################################################################################################################################
:run2
CD %~dp0
@Echo %date% %time% Updating MFN and Generating Batchin Files...  >> %~dp0/model_run_timestamp.txt
rem RUN PREP SCRIPTS
@ECHO Running process_futureLinks.R >> %~dp0/model_run_timestamp.txt
%rpath% 1_PreProcessing\process_futureLinks.R %oldconf% %newconf% %baseYr% %firstYr% %lastYr%
@ECHO Running qc_generatedLayers.R  >> %~dp0/model_run_timestamp.txt
%rpath% 99_QC\qc_generatedLayers.R %oldconf% %newconf% %baseYr% %firstYr% %lastYr%
@ECHO Running batch_domestic_scen_working.py 
rem call python 2_ArcGIS_Processing\batch_domestic_scen_working.py %baseYr% %firstYr% %lastYr%
%pypath% 2_ArcGIS_Processing\batch_domestic_scen_working.py %newconf% %baseYr% %firstYr% %lastYr%
@ECHO Running qc_batchinFiles.R  >> %~dp0/model_run_timestamp.txt
<<<<<<< Updated upstream
%rpath% 99_QC\qc_batchinFiles.R %oldconf% %baseYr% %firstYr% %lastYr% %mhnDir%
=======
%rpath% 99_QC\qc_batchinFiles.R %oldconf% %baseYr% %firstYr% %lastYr%
>>>>>>> Stashed changes

REM ###################################################################################################################################################
@Echo %date% %time% Copying MFN Batchin Data...  >> %~dp0/model_run_timestamp.txt
rem COPY BATCHIN DATA TO APPROPRIATE FOLDER
set /A counter=%baseYr%
:while2
if %counter% GTR %lastYr% (goto loopend2)
%~dp0
copy "..\Output\BatchinFiles\scen_%counter%" "..\Skim_New\Model_Setups\Meso_Freight_Skim_Setup_%newconf%_%counter%\Database\input_data" 
copy "..\Output\Lognodes\unlink_lognode140_y%counter%.txt" "..\Skim_New\Model_Setups\Meso_Freight_Skim_Setup_%newconf%_%counter%\Database\input_data" 
rename "..\Skim_New\Model_Setups\Meso_Freight_Skim_Setup_%newconf%_%counter%\Database\input_data\unlink_lognode140_y%counter%.txt" unlink_lognode140.txt
copy "..\Output\Lognodes\unlink_lognode143_y%counter%.txt" "..\Skim_New\Model_Setups\Meso_Freight_Skim_Setup_%newconf%_%counter%\Database\input_data" 
rename "..\Skim_New\Model_Setups\Meso_Freight_Skim_Setup_%newconf%_%counter%\Database\input_data\unlink_lognode143_y%counter%.txt" unlink_lognode143.txt
if %counter% GTR %baseYr% (set /A counter=counter+5)
if %counter% EQU %baseYr% (set /A counter=%firstYr%)
goto while2
:loopend2
CD %~dp0
@ECHO Working Directory = %~dp0
@ECHO All prep work complete

REM ###################################################################################################################################################
:run3
CD %~dp0
@Echo %date% %time% Running Skims...  >> %~dp0/model_run_timestamp.txt
rem Activate Emme Python env
call %~dp0Meso_Freight_Skim_Setup_c##q##_YYYY\Scripts\manage\env\activate_env.cmd emme
set /A counter=%baseYr%
set /A scen=100
:while3
if %counter% GTR %lastYr% (set /A scen=scen+100) 
if %counter% GTR %lastYr% (set /A counter=%baseYr%) 
if %scen% GTR 200 (goto :loopend3) 
set nameMod=Meso_Freight_Skim_Setup_%newconf%_%counter%
CD ..\Skim_New\Model_Setups\%nameMod%\Database
@echo %date% %time% %nameMod% for scenario %scen%...  >> %~dp0/model_run_timestamp.txt
if "%counter%"=="2022" (
	set /A flag143=0
	goto proceed143)
if NOT "%counter%" == "2022" (
	set /A flag143=1
	goto proceed143)
:proceed143
if "%scen%"=="200" (
	set /A flag140=1
	goto proceed140)
if "%scen%"=="100" (
	set /A flag140=0
	goto proceed140)
:proceed140

REM -- Get name of .emp file --
set infile=empfile.txt
cd ..
if exist %infile% (del %infile% /Q)
dir "*.emp" /b >> %infile% 2>nul
set /p file1=<%infile%
echo file1 = %file1%
call :CheckEmpty %infile%
:filepass
if exist %infile% (del %infile% /Q)
cd Database

@Echo -----RUNNING 1_remove_old_scenarios >> %~dp0/model_run_timestamp.txt
call emme -ng 000 -m macros\1_remove_old_scenarios.mac %scen% %scenMax%
@Echo -----RUNNING 2_build_network >> %~dp0/model_run_timestamp.txt
call emme -ng 000 -m macros\2_build_network.mac %scen% %flag140% %flag143% 
@Echo -----RUNNING 3_run_skims >> %~dp0/model_run_timestamp.txt
call emme -ng 000 -m macros\3_run_skims.mac %scen% %flag140% 
rem @Echo -----RUNNING analyze_mode_access >> %~dp0/model_run_timestamp.txt
rem @ECHO NOTE: this may take over an hour per network >> %~dp0/model_run_timestamp.txt
rem call emme -ng 000 -m macros\analyze_mode_access.mac %scen%
@ECHO -----RUNNING verify rail service >> %~dp0/model_run_timestamp.txt
if exist macros\Verify_rail_service.lst (del Step1_Create_GCD_file.lst /Q)
%saspath% macros\Verify_rail_service.sas -sysparm "%scen%"
if %ERRORLEVEL% GTR 1 (goto saserr)
CD SAS
if exist Step1_Create_GCD_file.lst (del Step1_Create_GCD_file.lst /Q)
if exist Step2_Create_ModePath_Skim_file.lst (del Step2_Create_ModePath_Skim_file.lst /Q)
if exist Step3_Verify_Costs_Times.lst (del Step3_Verify_Costs_Times.lst /Q)
if exist Step4_Create_Zonal_Truck_Tour_files.lst (del Step4_Create_Zonal_Truck_Tour_files.lst /Q)

@echo %CD%
@ECHO -----RUNNING step 1 >> %~dp0/model_run_timestamp.txt
%saspath% Step1_Create_GCD_file.sas -sysparm "%scen% %counter%"
if %ERRORLEVEL% GTR 1 (goto saserr)
@ECHO -----RUNNING step 2 >> %~dp0/model_run_timestamp.txt
%saspath% Step2_Create_ModePath_Skim_file.sas -sysparm "%scen% %flag140% %flag143% %counter%"
if %ERRORLEVEL% GTR 1 (goto saserr)
@ECHO -----RUNNING step 3 >> %~dp0/model_run_timestamp.txt
%saspath% Step3_Verify_Costs_Times.sas -sysparm "%scen% %flag143%"
if %ERRORLEVEL% GTR 1 (goto saserr)
@ECHO -----RUNNING step 4 >> %~dp0/model_run_timestamp.txt
if exist Step3_Verify_Costs_Times.lst (goto mode_err)
%saspath% Step4_Create_Zonal_Truck_Tour_files.sas -sysparm "%scen% %counter% %newconf%"
if %ERRORLEVEL% GTR 1 (goto saserr)
@ECHO -----RUNNING step 5 >> %~dp0/model_run_timestamp.txt
%rpath% Step5_determine_pipeline_costs.R %scen% %counter%
CD %~dp0
if %counter% GTR %baseYr% (set /A counter=counter+5)
if %counter% EQU %baseYr% (set /A counter=%firstYr%)
goto while3
:loopend3

CD %~dp0
@ECHO Working Directory = %~dp0
@ECHO All skims complete
<<<<<<< Updated upstream
@ECHO %CD%
pause
=======
>>>>>>> Stashed changes
REM ###################################################################################################################################################
:run4
CD %~dp0
@Echo FINAL QC
@Echo %date% %time% Final QC and Clean Up...  >> %~dp0/model_run_timestamp.txt
rem RUN FINAL QC SCRIPTS
@ECHO Running qc_finalSkimOutput.R >> %~dp0/model_run_timestamp.txt
%rpath% 99_QC\qc_finalSkimOutput.R %newconf% %baseYr% %firstYr% %lastYr%
@ECHO Running qc_compareSkimOutput.R >> %~dp0/model_run_timestamp.txt
%rpath% 99_QC\qc_compareSkimOutput.R %oldconf%

goto last
REM ###################################################################################################################################################
:CheckEmpty
if %~z1 == 0 (goto badfile)
goto filepass

:badfile
@ECHO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@ECHO    COULD NOT FIND .EMP FILE.
@ECHO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@ECHO.
goto end

:mode_err
@ECHO.
@ECHO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@ECHO   SAS IDENTIFIED MODEPATH ERRORS!!! 
@ECHO   REVIEW .LST FILE AND CORRECT ISSUE.
@ECHO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@ECHO.
goto end

:saserr
@ECHO.
@ECHO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@ECHO   SAS DID NOT TERMINATE PROPERLY!!! 
@ECHO   REVIEW .LOG FILE TO IDENTIFY AND CORRECT ISSUE.
@ECHO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@ECHO.
goto end

:last
@ECHO ====================================================== >> %~dp0/model_run_timestamp.txt
@ECHO END CMAP FREIGHT NETWORK UPDATE AND SKIMS >> %~dp0/model_run_timestamp.txt
@ECHO Model Run End Time: %date% %time% >> %~dp0/model_run_timestamp.txt
@ECHO ====================================================== >> %~dp0/model_run_timestamp.txt
@ECHO.
@ECHO END OF BATCH FILE
@ECHO ==================================================================
@ECHO ==================================================================
goto end

:end
pause
exit