@echo off
rem Submit_MFN_Skims.bat
rem Karly Cazzato, CMAP

@echo BATCH FILE TO SUBMIT SKIMS and Post-Processing for Master Freight Network
@echo ==================================================================
@echo.
@echo %~dp0
rem =========================================================================================
rem =========================================================================================
REM USER INPUT
@echo Enter year to run skims: 
set /p year=

@echo Enter 100 to run model WITHOUT logistics node 140 connected
@echo Enter 200 to run model WITH logistics node 140 connected
set /p scenario=

@echo Run analyze_mode_access ('y' or 'no'; note, this will take at least an hour)
set /p flagAccess="[RUN analyze_mode_access? (y/n)] "

if "%year%"=="2022" (
	set flag143="---> NOTE: Node 143 not active"
	goto proceed143)
if NOT "%year%" == "2022" (
	set flag143="---> NOTE: Node 143 active"
	goto proceed143)
:proceed143


if "%scenario%"=="200" (
	set flag140="---> NOTE: Node 140 active"
	goto proceed140)

if "%scenario%"=="100" (
	set flag140="---> NOTE: Node 140 not active"
	goto proceed140)
:proceed140

set /a scenMax = 212


@echo Model run year: %year%
@echo Model run scenario: %scenario%
@echo %flag143%
@echo Model Node 140 Flag: %flag140%
@echo %flag140%
@echo. Press enter to run ------------------------------------------------------------------------------
pause

rem =========================================================================================
rem Activate Emme Python env
call %~dp0..\Scripts\manage\env\activate_env.cmd emme

REM -- Get name of .emp file --
cd %~dp0
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

@echo CLEANING UP OUTPUT FOLDERS
cd output_data
rmdir /S /Q "%scenario%"
rmdir /S /Q "output_data\post_processing_%scenario%\tempOut\"
rmdir /S /Q "post_processing_%scenario%"
@echo CLEANUP COMPLETE
cd ..

@echo ==================================================================
@ECHO.
@ECHO Start Time: %date% %time% 
@ECHO.
@ECHO.
@ECHO -- Running Scenario %scenario% --
@ECHO.
@ECHO %CD%
@Echo RUNNING 1_remove_old_scenarios
call python macros\1_remove_old_scenarios.py %scenario% %scenMax%
@Echo RUNNING 2_build_network
call emme -ng 000 -m macros\2_build_network.mac %scenario% %year% 
@Echo RUNNING 3_run_skims
call emme -ng 000 -m macros\3_run_skims.mac %scenario%

if "%flagAccess%" == "y"(call emme -ng 000 -m macros\analyze_mode_access.mac %scenario%) 

@echo Skims Complete
@echo --- Model run year: %year%
@echo --- Model run scenario: %scenario%
@echo %flag143%
@echo %flag140%

REM ======================================================================
@echo
@echo RUNNING Post-Processing Procedures
@echo
call %~dp0..\Scripts\manage\env\activate_env.cmd MFN_ENVNAME
@echo CURRENT DIRECTORY:
@echo %cd%

@Echo RUNNING Step1_Create_GCD_file.py
call python post_processing\Step1_Create_GCD_file.py %year% %scenario%

@Echo RUNNING Step2_1_formatSkims
call python post_processing\Step2_1_formatSkims.py %year% %scenario%

@Echo RUNNING Step2_2_format_O-L-D
call python post_processing\Step2_2_format_O-L-D.py %year% %scenario%

@Echo RUNNING Step2_3_format_Airport_Trips
call python post_processing\Step2_3_format_Airport_Trips.py %year% %scenario%

@Echo RUNNING Step2_4_format_waterport_trips
call python post_processing\Step2_4_format_waterport_trips.py %year% %scenario%

@Echo RUNNING Step2_5_finalize_skims
call python post_processing\Step2_5_finalize_skims.py %year% %scenario%

@Echo RUNNING Step3_1_Verify_Costs_Times
call python post_processing\Step3_1_Verify_Costs_Times.py %year% %scenario%

@Echo RUNNING Step3_2_port_summary
call python post_processing\Step3_2_port_summary.py %year% %scenario%

@Echo RUNNING Step4_create_zonal_truck_tour_files
call python post_processing\Step4_create_zonal_truck_tour_files.py %year% %scenario%

@echo DELETING TEMPORARY FILES
rmdir /S /Q "output_data\post_processing_%scenario%\tempOut\"

goto end

REM ======================================================================
REM ======================================================================
:CheckEmpty2
if %~z1 == 0 (goto badR)
goto Rpass

:badR
@ECHO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@ECHO    COULD NOT FIND R INSTALLATION.
@ECHO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@ECHO.
pause
goto end

:issue
@ECHO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@ECHO          THE LAST PROCEDURE DID NOT TERMINATE PROPERLY!
@ECHO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@ECHO.
goto end

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

:loopend
@ECHO.
@ECHO -- Scenario %val% Completed Successfully --
@ECHO.
@ECHO.
@ECHO End Time: %date% %time% 
@ECHO.
goto end

:saserr
@ECHO.
@ECHO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@ECHO   %script% DID NOT TERMINATE PROPERLY!!! 
@ECHO   REVIEW .LOG FILE TO IDENTIFY AND CORRECT ISSUE.
@ECHO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@ECHO.
pause
goto end

:mode_err
@ECHO.
@ECHO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@ECHO   %script%.sas IDENTIFIED MODEPATH ERRORS!!! 
@ECHO   REVIEW .LST FILE AND CORRECT ISSUE.
@ECHO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@ECHO.
pause
goto end

:last
@ECHO ====================================================== >> model_run_timestamp.txt
@ECHO END CMAP REGIONAL MODEL RUN - SCENARIO %val% >> model_run_timestamp.txt
@ECHO Model Run End Time: %date% %time% >> model_run_timestamp.txt
@ECHO ====================================================== >> model_run_timestamp.txt
@ECHO.
@ECHO END OF BATCH FILE - MODEL RUN COMPLETED
@ECHO ==================================================================
@ECHO ==================================================================

:end

echo. All done, see output_data/post_processing for final outputs
pause
exit