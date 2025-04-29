@echo off
rem Karly Cazzato, CMAP
rem update gdb name to include c25q2 rather than FY25
rem add cleanup of files prior to Running

REM ###################################################################################################################################################
rem HEADER INFO

@echo Run analyze_mode_access ('y' or 'no'; note, this will take at least an hour)
set /p flagAccess="[RUN analyze_mode_access? (y/n)] "
@echo.
REM ###################################################################################################################################################
rem SET VARIABLES AND PATHS
set conf=c25q2
set mhnDir=V:/Secure/Master_Highway/mhn_%conf%.gdb
set outGDB="..\Output\MFN_temp.gdb"
set currentDir=V:\Secure\Master_Freight\Current
set inputDir=%currentDir%\Input
set emmebankDir=%currentDir%\EmmeBank
set gdbDir=%currentDir%\MFN_currentFY25.gdb
set /a scenMax = 212

REM ###################################################################################################################################################
rem DEVELOP REMAINING FOLDER STRUCTURE
if not exist %outGDB% (mkdir %outGDB%)
if not exist "..\Skim_New\Model_Setups" (mkdir "..\Skim_New\Model_Setups")
if not exist "..\Input" (mkdir "..\Input")
if not exist "..\Output\Batchin" (mkdir "..\Output\Batchin")

rem COPY INPUT FILE FOLDER
xcopy %inputDir% "..\Input" /s

rem COPY GDB TO TEMPORARY FOLDER
copy %gdbDir% "..\Output\MFN_temp.gdb"

:copyFolders
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

:skipSetup
REM ###################################################################################################################################################
rem FIND PYTHON, R SAS, & EMME INSTALLATIONS
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

REM ###################################################################################################################################################
@ECHO ######################################################################################################################################################
@ECHO Setup Complete; Press enter if directory below is correct
@echo currentDir = %currentDir%
@echo inputDir = %inputDir%
@echo emmebankDir = %emmebankDir%
@echo gdbDir = %gdbDir%
@ECHO Working Directory = %~dp0
@ECHO ######################################################################################################################################################
pause

REM ###################################################################################################################################################
rem RUN PREP SCRIPTS
@ECHO Running process_futureLinks.R
%rpath% 1_PreProcessing\process_futureLinks.R %mhnDir% 
@ECHO Running qc_generatedLayers.R 
%rpath% 99_QC\qc_generatedLayers.R %gdbDir% %mhnDir% 
@ECHO Running batch_domestic_scen_working.py 
call python 2_ArcGIS_Processing\batch_domestic_scen_working.py 
@ECHO Running qc_batchinFiles.R 
%rpath% 99_QC\qc_batchinFiles.R %mhnDir%

REM ###################################################################################################################################################
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
pause
REM ###################################################################################################################################################
rem RUN SKIMS
rem for year in years
	rem for scenario in scenarios
		rem access batch file in each skim setup and execute based on stored variables

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
@echo %nameMod% for scenario %scen%
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

@Echo RUNNING 1_remove_old_scenarios
call emme -ng 000 -m macros\1_remove_old_scenarios.mac %scen% %scenMax%
@Echo RUNNING 2_build_network
call emme -ng 000 -m macros\2_build_network.mac %scen% %flag140% %flag143% 
@Echo RUNNING 3_run_skims
call emme -ng 000 -m macros\3_run_skims.mac %scen% %flag140% 

if "%flagAccess%" == "y"(call emme -ng 000 -m macros\analyze_mode_access.mac %scen%) 

CD SAS
if exist Step1_Create_GCD_file.lst (del Step1_Create_GCD_file.lst /Q)
if exist Step2_Create_ModePath_Skim_file.lst (del Step2_Create_ModePath_Skim_file.lst /Q)
if exist Step3_Verify_Costs_Times.lst (del Step3_Verify_Costs_Times.lst /Q)
if exist Step4_Create_Zonal_Truck_Tour_files.lst (del Step4_Create_Zonal_Truck_Tour_files.lst /Q)

@echo %CD%
@ECHO running step 1
"C:/Program Files/SASHome/SASFoundation/9.4/sas.exe" Step1_Create_GCD_file.sas -sysparm "%scen% %counter%"
if %ERRORLEVEL% GTR 1 (goto saserr)
@ECHO running step 2
"C:/Program Files/SASHome/SASFoundation/9.4/sas.exe" Step2_Create_ModePath_Skim_file.sas -sysparm "%scen% %flag140% %flag143% %counter%"
if %ERRORLEVEL% GTR 1 (goto saserr)
@ECHO running step 3
"C:/Program Files/SASHome/SASFoundation/9.4/sas.exe" Step3_Verify_Costs_Times.sas -sysparm "%scen% %flag143%"
if %ERRORLEVEL% GTR 1 (goto saserr)
@ECHO running step 4
if exist Step3_Verify_Costs_Times.lst (goto mode_err)
"C:/Program Files/SASHome/SASFoundation/9.4/sas.exe" Step4_Create_Zonal_Truck_Tour_files.sas -sysparm "%scen% %counter% %conf%"
if %ERRORLEVEL% GTR 1 (goto saserr)
@ECHO running step 5
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
pause
REM ###################################################################################################################################################
rem RUN FINAL QC SCRIPTS
@ECHO Running qc_finalSkimOutput.R
%rpath% 99_QC\qc_finalSkimOutput.R %conf%
@ECHO Running qc_compareSkimOutput.R
%rpath% 99_QC\qc_compareSkimOutput.R %conf%
pause
REM ###################################################################################################################################################
:CheckEmpty
if %~z1 == 0 (goto badfile)
goto filepass

:badfile
@ECHO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@ECHO    COULD NOT FIND .EMP FILE.
@ECHO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@ECHO.
pause
goto end

:mode_err
@ECHO.
@ECHO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@ECHO   SAS IDENTIFIED MODEPATH ERRORS!!! 
@ECHO   REVIEW .LST FILE AND CORRECT ISSUE.
@ECHO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@ECHO.
pause
goto end

:saserr
@ECHO.
@ECHO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@ECHO   SAS DID NOT TERMINATE PROPERLY!!! 
@ECHO   REVIEW .LOG FILE TO IDENTIFY AND CORRECT ISSUE.
@ECHO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@ECHO.
pause
goto end