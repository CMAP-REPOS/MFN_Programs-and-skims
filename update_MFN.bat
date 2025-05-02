@echo off
rem Karly Cazzato, CMAP
rem update gdb name to include c25q2 rather than FY25
rem add cleanup of files prior to Running

REM ###################################################################################################################################################
rem HEADER INFO

@echo SELECT RUN MODE
@echo Mode 1: Run all (runs setup, MFN update, skims, and skim QC)
@echo Mode 2: Skip setup (only runs MFN update, skims, and skim QC)
@echo Mode 3: Run skims (only runs skims and skim QC)
@echo Mode 4: Run only final QC
set /p flagModule="[RUN analyze_mode_access? (enter 1, 2, 3, or 4)] "
@echo.
@echo ENTER CONFORMITY NUMBER FOR MFN UPDATE
set /p conf="[Conformity number (enter c##q##)] "

REM ###################################################################################################################################################
rem FIND PYTHON, R & SAS Installations
CD %~dp0
set infile=path.txt
if exist %infile% (del %infile% /Q)
rem dir "C:\Users\kcazzato\AppData\Local\Programs\R\R-4.4.1\bin\x64\R.exe" /s /b >> %infile% 2>nul
dir "C:\Users\kcazzato\AppData\Local\Programs\R\R-4.4.1\bin\Rscript.exe" /s /b >> %infile% 2>nul
set /p path2=<%infile%
set paren="
set rpath=%paren%%path2%%paren%
echo rpath = %rpath%

rem Activate Python env
call %~dp0Meso_Freight_Skim_Setup_c##q##_YYYY\Scripts\manage\env\activate_env.cmd CMAP-TRIP2
CD %~dp0
pause
if exist model_run_timestamp.txt (del model_run_timestamp.txt /Q)
@Echo Press enter to begin run
pause
@ECHO ============================================================= >> model_run_timestamp.txt
@ECHO BEGIN CMAP FREIGHT NETWORK UPDATE AND SKIMS >> model_run_timestamp.txt
@ECHO Model Run Start Time: %date% %time% >> model_run_timestamp.txt
@ECHO ============================================================= >> model_run_timestamp.txt

REM ###################################################################################################################################################
rem SET VARIABLES AND PATHS
set mhnDir="V:/Secure/Master_Highway/archive/gdb/conformity/mhn_%conf%.gdb"
set outGDB="..\Output\MFN_temp.gdb"
set currentDir=V:\Secure\Master_Freight\Current
set inputDir=%currentDir%\Input
set emmebankDir=%currentDir%\EmmeBank
set gdbDir=%currentDir%\MFN_currentFY25.gdb
set /a scenMax = 212

if "%flagModule%"=="1" (goto run1)
if "%flagModule%"=="2" (goto run2)
if "%flagModule%"=="3" (goto run3)
if "%flagModule%"=="4" (goto run4)

:run1
@Echo Copying Base Data from V Drive...%date% %time%  >> model_run_timestamp.txt

REM ###################################################################################################################################################
rem DEVELOP REMAINING FOLDER STRUCTURE
if not exist %outGDB% (mkdir %outGDB%)
if not exist "..\Skim_New\Model_Setups" (mkdir "..\Skim_New\Model_Setups")
if not exist "..\Input" (mkdir "..\Input")
if not exist "..\Input\MHN_temp.gdb" (mkdir "..\Input\MHN_temp.gdb")
if not exist "..\Output\Batchin" (mkdir "..\Output\Batchin")

rem COPY INPUT FILE FOLDER
xcopy %inputDir% "..\Input" /s

rem COPY GDB TO TEMPORARY FOLDER
copy %gdbDir% "..\Output\MFN_temp.gdb"
copy %mhnDir% "..\Input\MHN_temp.gdb"

rem COPY AND RENAME SKIMS SETUPS, INCLUDING EMMEBANK FROM V DRIVE
set /A counter=2022
:while
if %counter% GTR 2050 (goto loopend)
set nameMod=Meso_Freight_Skim_Setup_%conf%_%counter%
mkdir = "..\Skim_New\Model_Setups\%nameMod%"
xcopy "Meso_Freight_Skim_Setup_c##q##_YYYY\" "..\Skim_New\Model_Setups\%nameMod%" /s /e
copy "%emmebankDir%\emmebank" "..\Skim_New\Model_Setups\%nameMod%\Database"
if %counter% GTR 2025 (set /A counter=counter+10)
if %counter% EQU 2022 (set /A counter=2030)
goto while
:loopend

REM ###################################################################################################################################################
:run2
CD %~dp0
@Echo Updating MFN and Generating Batchin Files...%date% %time%  >> model_run_timestamp.txt
rem RUN PREP SCRIPTS
@ECHO Running process_futureLinks.R >> model_run_timestamp.txt
%rpath% 1_PreProcessing\process_futureLinks.R
@ECHO Running qc_generatedLayers.R  >> model_run_timestamp.txt
%rpath% 99_QC\qc_generatedLayers.R %gdbDir% 
@ECHO Running batch_domestic_scen_working.py 
call python 2_ArcGIS_Processing\batch_domestic_scen_working.py 
@ECHO Running qc_batchinFiles.R  >> model_run_timestamp.txt
%rpath% 99_QC\qc_batchinFiles.R 

REM ###################################################################################################################################################
@Echo Copying MFN Batchin Data...%date% %time%  >> model_run_timestamp.txt
rem COPY BATCHIN DATA TO APPROPRIATE FOLDER
set /A counter=2022
:while2
if %counter% GTR 2050 (goto loopend2)
set sasInDIR="..\Skim_New\Model_Setups\Meso_Freight_Skim_Setup_%conf%_%counter%\Database\SAS\inputs\%conf%"
copy "..\Output\Batchin\batchin_%counter%" "..\Skim_New\Model_Setups\Meso_Freight_Skim_Setup_%conf%_%counter%\Database\input_data" 
copy "..\Output\Lognodes\unlink_lognode140_y%counter%.txt" "..\Skim_New\Model_Setups\Meso_Freight_Skim_Setup_%conf%_%counter%\Database\input_data" 
rename "..\Skim_New\Model_Setups\Meso_Freight_Skim_Setup_%conf%_%counter%\Database\input_data\unlink_lognode140_y%counter%.txt" unlink_lognode140.txt
copy "..\Output\Lognodes\unlink_lognode143_y%counter%.txt" "..\Skim_New\Model_Setups\Meso_Freight_Skim_Setup_%conf%_%counter%\Database\input_data" 
rename "..\Skim_New\Model_Setups\Meso_Freight_Skim_Setup_%conf%_%counter%\Database\input_data\unlink_lognode143_y%counter%.txt" unlink_lognode143.txt
if not exist %sasInDIR% (mkdir %sasInDIR%)
copy "..\Input\TBM_Data\c24q4_%counter%" %sasInDIR%
if %counter% GTR 2025 (set /A counter=counter+10)
if %counter% EQU 2022 (set /A counter=2030)
goto while2
:loopend2
CD %~dp0
@ECHO Working Directory = %~dp0
@ECHO All prep work complete

REM ###################################################################################################################################################
:run3
@Echo Running Skims...%date% %time%  >> model_run_timestamp.txt
rem Activate Emme Python env
call %~dp0..\Scripts\manage\env\activate_env.cmd emme

set /A counter=2022
set /A scen=100
:while3
if %counter% GTR 2050 (set /A scen=scen+100) 
if %counter% GTR 2050 (set /A counter=2022) 
if %scen% GTR 200 (goto :loopend3) 
set nameMod=Meso_Freight_Skim_Setup_%conf%_%counter%
CD ..\Skim_New\Model_Setups\%nameMod%\Database
@echo %nameMod% for scenario %scen%...%date% %time%  >> model_run_timestamp.txt
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

@Echo RUNNING 1_remove_old_scenarios >> model_run_timestamp.txt
call emme -ng 000 -m macros\1_remove_old_scenarios.mac %scen% %scenMax%
@Echo RUNNING 2_build_network >> model_run_timestamp.txt
call emme -ng 000 -m macros\2_build_network.mac %scen% %flag140% %flag143% 
@Echo RUNNING 3_run_skims >> model_run_timestamp.txt
call emme -ng 000 -m macros\3_run_skims.mac %scen% %flag140% 
@Echo RUNNING analyze_mode_access >> model_run_timestamp.txt
@ECHO NOTE: this may take over an hour per network >> model_run_timestamp.txt
rem call emme -ng 000 -m macros\analyze_mode_access.mac %scen%
@ECHO running verify rail service >> model_run_timestamp.txt
if exist macros\Verify_rail_service.lst (del Step1_Create_GCD_file.lst /Q)
rem "C:/Program Files/SASHome/SASFoundation/9.4/sas.exe" macros\Verify_rail_service.sas -sysparm "%scen%"
if %ERRORLEVEL% GTR 1 (goto saserr)
CD SAS
if exist Step1_Create_GCD_file.lst (del Step1_Create_GCD_file.lst /Q)
if exist Step2_Create_ModePath_Skim_file.lst (del Step2_Create_ModePath_Skim_file.lst /Q)
if exist Step3_Verify_Costs_Times.lst (del Step3_Verify_Costs_Times.lst /Q)
if exist Step4_Create_Zonal_Truck_Tour_files.lst (del Step4_Create_Zonal_Truck_Tour_files.lst /Q)

@echo %CD%
@ECHO running step 1 >> model_run_timestamp.txt
"C:/Program Files/SASHome/SASFoundation/9.4/sas.exe" Step1_Create_GCD_file.sas -sysparm "%scen% %counter%"
if %ERRORLEVEL% GTR 1 (goto saserr)
@ECHO running step 2 >> model_run_timestamp.txt
"C:/Program Files/SASHome/SASFoundation/9.4/sas.exe" Step2_Create_ModePath_Skim_file.sas -sysparm "%scen% %flag140% %flag143% %counter%"
if %ERRORLEVEL% GTR 1 (goto saserr)
@ECHO running step 3 >> model_run_timestamp.txt
"C:/Program Files/SASHome/SASFoundation/9.4/sas.exe" Step3_Verify_Costs_Times.sas -sysparm "%scen% %flag143%"
if %ERRORLEVEL% GTR 1 (goto saserr)
@ECHO running step 4 >> model_run_timestamp.txt
if exist Step3_Verify_Costs_Times.lst (goto mode_err)
"C:/Program Files/SASHome/SASFoundation/9.4/sas.exe" Step4_Create_Zonal_Truck_Tour_files.sas -sysparm "%scen% %counter% %conf%"
if %ERRORLEVEL% GTR 1 (goto saserr)
@ECHO running step 5 >> model_run_timestamp.txt
%rpath% Step5_determine_pipeline_costs.R %scen% %counter%
CD %~dp0
if %counter% GTR 2025 (set /A counter=counter+10)
if %counter% EQU 2022 (set /A counter=2030)
goto while3
:loopend3

CD %~dp0
@ECHO Working Directory = %~dp0
@ECHO All skims complete
@ECHO %CD%

REM ###################################################################################################################################################
:run4
@Echo Final QC and Clean Up...%date% %time%  >> model_run_timestamp.txt
rem RUN FINAL QC SCRIPTS
@ECHO Running qc_finalSkimOutput.R >> model_run_timestamp.txt
%rpath% 99_QC\qc_finalSkimOutput.R %conf%
@ECHO Running qc_compareSkimOutput.R >> model_run_timestamp.txt
%rpath% 99_QC\qc_compareSkimOutput.R %conf%

goto end
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
@ECHO ====================================================== >> model_run_timestamp.txt
@ECHO END CMAP FREIGHT NETWORK UPDATE AND SKIMS >> model_run_timestamp.txt
@ECHO Model Run End Time: %date% %time% >> model_run_timestamp.txt
@ECHO ====================================================== >> model_run_timestamp.txt
@ECHO.
@ECHO END OF BATCH FILE
@ECHO ==================================================================
@ECHO ==================================================================
goto end

:end
pause
exit