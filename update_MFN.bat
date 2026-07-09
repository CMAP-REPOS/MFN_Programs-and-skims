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

rem FIND PYTHON Installation
rem call %~dp0Meso_Freight_Skim_Setup_c##q##_YYYY\Scripts\manage\env\activate_env.cmd MFN_env
set infile=pathPY.txt
if exist %infile% (del %infile% /Q)
dir "C:\Users\kcazzato\AppData\Local\ESRI\conda\envs\arcgispro-py3-MFN\python.exe" /s /b >> %infile% 2>nul
set /p path2=<%infile%
set pypath=%paren%%path2%%paren%
echo pypath = %pypath%
CD %~dp0

REM ###################################################################################################################################################
rem HEADER INFO
@echo ENTER NAME OF TEST OR CONFORMITY TO RUN
set /p newconf="[Conformity number (enter c##q##)] "
@echo ENTER CONFORMITY NUMBER FOR TO COMPARE UPDATE TO 
@echo Usually the previous conformity number
@echo EX: if you're updating to c25q2, enter c24q4
set /p oldconf="[Conformity number (enter c##q##)] "
@ECHO SELECT MODE TO RUN
@ECHO 	1. Setup only
@echo 	2. Skims only
@echo 	3. Setup and Skims
set /p gotoRun="[Run mode (enter number only)] "

rem SET PATHS
set tbmInputDir=V:/Secure/Master_Freight/TBM_Inputs/%newconf%
set procDir=V:/Secure/Master_Freight/Processing_Data

rem SET VARIABLES
set /a scenMax = 212
set /a baseYr = 2019
set /a firstYr = 2026
set /a lastYr = 2050

REM ###################################################################################################################################################
rem BEGIN RUN
@Echo Press enter to begin run
pause
goto %gotoRun%

:3
@echo BEGINNING SKIM SETUP AND SKIMS

:1
@echo BEGINNING SKIM SETUP 

CD %~dp0
if exist model_run_timestamp.txt (del model_run_timestamp.txt /Q)
@ECHO ============================================================= >> %~dp0/model_run_timestamp.txt
@ECHO BEGIN CMAP FREIGHT NETWORK UPDATE AND SKIMS >> %~dp0/model_run_timestamp.txt
@ECHO Model Run Start Time: %date% %time% >> %~dp0/model_run_timestamp.txt
@ECHO ============================================================= >> model_run_timestamp.txt
@Echo %date% %time% Copying Base Data from V Drive...  >> %~dp0/model_run_timestamp.txt

REM ###################################################################################################################################################
rem DEVELOP REMAINING FOLDER STRUCTURE
if not exist "Model_Setups" (mkdir "Model_Setups")

REM add processing data to base model setup
@echo --- Copying static input data from %procDir%\Skim_input_data\Static
xcopy "%procDir%\Skim_input_data\Static" "Meso_Freight_Skim_Setup_c##q##_YYYY/Database/input_data" /S /Q /Y >nul 2>&1

REM add non-year or scenario specific batchin Data
@echo --- Copying batchin input data from %procDir%\Skim_input_data\%newconf%
xcopy "%procDir%\Skim_input_data\%newconf%" "Meso_Freight_Skim_Setup_c##q##_YYYY/Database/input_data" /Q /Y >nul 2>&1

REM add emmebank to base model setup
@echo --- Copying emmebank from %procDir%\EmmeBank\emmebank
copy "%procDir%\EmmeBank\emmebank" "Meso_Freight_Skim_Setup_c##q##_YYYY/Database" 

rem COPY AND RENAME SKIMS SETUPS, INCLUDING EMMEBANK FROM V DRIVE
set /A counter=%baseYr%
:while
if %counter% GTR %lastYr% (goto loopend)
rem create folders if they do not exist
set nameMod=Meso_Freight_Skim_Setup_%newconf%_%counter%
if not exist "Model_Setups\%nameMod%" (mkdir = "Model_Setups\%nameMod%")

rem copy model set up for year
@echo --- Copying model setup for %counter%
xcopy "Meso_Freight_Skim_Setup_c##q##_YYYY\" "Model_Setups\%nameMod%" /E /Q /Y 

rem copy batchin data for the year
@echo --- Copying input data from %procDir%\Skim_input_data\%newconf%\scen_%counter%
xcopy "%procDir%\Skim_input_data\%newconf%\scen_%counter%\" "Model_Setups\%nameMod%\Database\input_data" /S /Q /Y

rem find name of FOLDER
if %counter% EQU 2019 (set scen=100)
if %counter% EQU 2026 (set scen=200)
if %counter% EQU 2030 (set scen=300)
if %counter% EQU 2035 (set scen=500)
if %counter% EQU 2040 (set scen=600)
if %counter% EQU 2050 (set scen=800)

if not exist "Model_Setups\%nameMod%\Database\input_data\post_processing" (mkdir "Model_Setups\%nameMod%\Database\input_data\post_processing")
@echo --- Copying data from %tbmInputDir%\Freight_Skim_Inputs_%newconf%_%scen%
xcopy "%tbmInputDir%\Freight_Skim_Inputs_%newconf%_%scen%" "Model_Setups\%nameMod%\Database\input_data\post_processing" /S /Q /Y
rename "Model_Setups\%nameMod%\Database\input_data\post_processing\subzn_emp%counter%.csv" subzn_emp.csv

rem increment counter
if %counter% GTR %firstYr% (set /A counter=counter+5)
if %counter% EQU 2045 (set /A counter=counter+5)
if %counter% EQU %firstYr% (set /A counter=counter+4)
if %counter% EQU %baseYr% (set /A counter=%firstYr%)

goto while
:loopend
@echo created skim folders and copied Data

CD %~dp0
@ECHO All prep work complete
if %gotoRun% EQU 1 (goto END)

REM EXECUTE SKIMS ###################################################################################################################################################
:2
@echo BEGINNING SKIMS

set /A yrcounter=%baseYr%
set /A scen=100

:while2
if %yrcounter% EQU %baseYr% (goto sameScen)

:newScen
rem increment yrcounter
if %yrcounter% GTR %firstYr% (set /A yrcounter=yrcounter+5)
if %yrcounter% EQU 2045 (set /A yrcounter=yrcounter+5)
if %yrcounter% EQU %firstYr% (set /A yrcounter=yrcounter+4)
if %yrcounter% EQU %baseYr% (set /A yrcounter=%firstYr%)
if %yrcounter% GTR %lastYr% (goto loopend2)
set /A scen=100

:sameScen
rem setup
set nameMod=Meso_Freight_Skim_Setup_%newconf%_%yrcounter%
CD %~dp0/Model_Setups/%nameMod%/Database

IF %yrcounter% GTR 2034 (
    SET /A flag143=1
) ELSE (
    SET /A flag143=0
)
GOTO proceed143
:proceed143

REM -- Get name of .emp file --
set infile=empfile.txt
cd ..
if exist %infile% (del %infile% /Q)
dir "*.emp" /b >> %infile% 2>nul
set /p file1=<%infile%
call :CheckEmpty %infile%
:filepass
if exist %infile% (del %infile% /Q)
cd Database

@Echo %date% %time% Running Skims for %nameMod% scenario %scen%, flag143 = %flag143%...  >> %~dp0/model_run_timestamp.txt
@Echo %date% %time% Running Skims for %nameMod% scenario %scen%, flag143 = %flag143%...

rem Activate Emme Python env
call %~dp0\Model_Setups\%nameMod%\Scripts\manage\env\activate_env.cmd emme

@Echo -----RUNNING 1_remove_old_scenarios >> %~dp0/model_run_timestamp.txt
call python macros\1_remove_old_scenarios.py %scen%
if %ERRORLEVEL% GTR 0 (goto issue)
@Echo -----RUNNING 2_build_network >> %~dp0/model_run_timestamp.txt
call python macros\2_build_network.py %scen% %yrcounter%
if %ERRORLEVEL% GTR 0 (goto issue)
@Echo -----RUNNING 3_run_skims >> %~dp0/model_run_timestamp.txt
call emme -ng 000 -m macros\3_run_skims.mac %scen% 
if %ERRORLEVEL% GTR 0 (goto issue)
@echo RUNNING Post-Processing Procedures
@echo
call %~dp0\Model_Setups\%nameMod%\Scripts\manage\env\activate_env.cmd CMAP-TRIP2

@Echo RUNNING Step1_Create_GCD_file.py
call python post_processing\Step1_Create_GCD_file.py %yrcounter% %scen%
if %ERRORLEVEL% GTR 0 (goto issue)
@Echo RUNNING Step2_1_formatSkims
call python post_processing\Step2_1_formatSkims.py %yrcounter% %scen%
if %ERRORLEVEL% GTR 0 (goto issue)
@Echo RUNNING Step2_2_format_O-L-D
call python post_processing\Step2_2_format_O-L-D.py %yrcounter% %scen%
if %ERRORLEVEL% GTR 0 (goto issue)
@Echo RUNNING Step2_3_format_Airport_Trips
call python post_processing\Step2_3_format_Airport_Trips.py %yrcounter% %scen%
if %ERRORLEVEL% GTR 0 (goto issue)
@Echo RUNNING Step2_4_format_waterport_trips
call python post_processing\Step2_4_format_waterport_trips.py %yrcounter% %scen%
if %ERRORLEVEL% GTR 0 (goto issue)
@Echo RUNNING Step2_5_finalize_skims
call python post_processing\Step2_5_finalize_skims.py %yrcounter% %scen%
if %ERRORLEVEL% GTR 0 (goto issue)
@Echo RUNNING Step3_1_Verify_Costs_Times
call python post_processing\Step3_1_Verify_Costs_Times.py %yrcounter% %scen% %flag143%
if %ERRORLEVEL% GTR 0 (goto issue)
@Echo RUNNING Step3_2_port_summary
call python post_processing\Step3_2_port_summary.py %yrcounter% %scen%
if %ERRORLEVEL% GTR 0 (goto issue)
@Echo RUNNING Step4_create_zonal_truck_tour_files
call python post_processing\Step4_create_zonal_truck_tour_files.py %yrcounter% %scen%

@ECHO -----RUNNING step 5 
%rpath% post_processing\Step5_determine_pipeline_costs.R %scen% %yrcounter%
if %ERRORLEVEL% GTR 0 (goto issue)
@echo DELETING TEMPORARY FILES
rmdir /S /Q "output_data\post_processing_%scen%\tempOut\"
pause
rem increment scenario counter
if %scen% EQU 200 (goto newScen)
if %scen% EQU 100 (set /A scen=200) 
goto sameScen
:loopend2
@ECHO ====================================================== >> %~dp0/model_run_timestamp.txt
@ECHO END CMAP FREIGHT NETWORK UPDATE AND SKIMS >> %~dp0/model_run_timestamp.txt
@ECHO Model Run End Time: %date% %time% >> %~dp0/model_run_timestamp.txt
@ECHO ====================================================== >> %~dp0/model_run_timestamp.txt
@ECHO.
@ECHO END OF BATCH FILE
@ECHO ==================================================================
@ECHO ==================================================================
pause
CD %~dp0
@ECHO Working Directory = %~dp0
@ECHO All skims complete
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
:issue
@ECHO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@ECHO          THE LAST PROCEDURE DID NOT TERMINATE PROPERLY!
@ECHO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@ECHO.
goto end

:END
@echo END
pause
exit