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
set /p choiceYR=%1

@echo Enter 100 to run model WITHOUT logistics node 140 connected
@echo Enter 200 to run model WITH logistics node 140 connected
set /p choice=%1

@echo Run analyze_mode_access ('y' or 'no'; note, this will take at least an hour)
set /p flagAccess="[RUN analyze_mode_access? (y/n)] "

if "%choiceYR%"=="2022" (
	set /A flag143=0
	goto proceed143)
if NOT "%choiceYR%" == "2022" (
	set /A flag143=1
	goto proceed143)
:proceed143

set choice=%2
if "%choice%"=="200" (
	set /A scenario=200
	set /A flag140=1
	goto proceed140)

if "%choice%"=="100" (
	set /A scenario=100
	set /A flag140=0
	goto proceed140)

:proceed140
pause
@echo Model run year: %choiceYR%
@echo Model run scenario: %scenario%
@echo Model Node 140 Flag: %flag140%
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
@echo ==================================================================
@ECHO.
@ECHO Start Time: %date% %time% 
@ECHO.
@ECHO.
@ECHO -- Running Scenario %scenario% --
@ECHO.
@ECHO %CD%
set /a scenMax = 212
@Echo RUNNING 1_remove_old_scenarios
call python macros\1_remove_old_scenarios.py %scenario% %scenMax%
@Echo RUNNING 2_build_network
call emme -ng 000 -m macros\2_build_network.mac %scenario% %flag140% %flag143% 
@Echo RUNNING 3_run_skims
call emme -ng 000 -m macros\3_run_skims.mac %scenario% %flag140% 

if "%flagAccess%" == "y"(call emme -ng 000 -m macros\analyze_mode_access.mac %scenario%) 

@echo Skims Complete
@echo Scenario = %scenario%, Flag140 = %flag140%, Flag143 = %flag143%

REM ======================================================================
@echo
@echo RUNNING Post-Processing Procedures
@echo

call %~dp0..\Scripts\manage\env\activate_env.cmd CMAP-TRIP2

@Echo RUNNING Step1_Create_GCD_file.ipynb
call python post_processing\Step1_Create_GCD_file.ipynb %choiceYR%
pause

@Echo RUNNING Step2_1_formatSkims
call python post_processing\Step2_1_formatSkims.ipynb %choiceYR% %flag140%
pause

@Echo RUNNING Step2_2_format_O
call python post_processing\Step2_2_format_O-L-D.ipynb %choiceYR% 
pause

@Echo RUNNING Step2_3_format_Airport_Trips
call python post_processing\Step2_3_format_Airport_Trips.ipynb %choiceYR% 
pause

@Echo RUNNING Step2_4_format_waterport_trips
call python post_processing\Step2_4_format_waterport_trips.ipynb %choiceYR% 
pause

@Echo RUNNING Step2_5_finalize_skims
call python post_processing\Step2_5_finalize_skims.ipynb %choiceYR% %flag140% %flag143% 
pause

@Echo RUNNING Step3_1_Verify_Costs_Times
call python post_processing\Step3_1_Verify_Costs_Times.ipynb %choiceYR% %flag140% %flag143% 
pause

@Echo RUNNING Step3_2_port_summary
call python post_processing\Step3_2_port_summary.ipynb %choiceYR% %flag140% %flag143% 
pause

@Echo RUNNING Step4_create_zonal_truck_tour_files
call python post_processing\Step4_create_zonal_truck_tour_files.ipynb %choiceYR%
pause


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

echo. done
pause
exit /B 0