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
set choiceYR=%1

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
@echo.
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

@echo Run analyze_mode_access ('y' or 'no'; note, this will take at least an hour)
set /p flagAccess="[RUN analyze_mode_access? (y/n)] "
@echo.
@echo conf %conf%
set conf2=%conf%
@echo conf2 %conf2%
pause
rem goto skip1
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
call emme -ng 000 -m macros\1_remove_old_scenarios.mac %scenario% %scenMax%
@Echo RUNNING 2_build_network
call emme -ng 000 -m macros\2_build_network.mac %scenario% %flag140% %flag143% 
@Echo RUNNING 3_run_skims
call emme -ng 000 -m macros\3_run_skims.mac %scenario% %flag140% 

if "%flagAccess%" == "y"(call emme -ng 000 -m macros\analyze_mode_access.mac %scenario%) 
rem :skip1
rem verify rail service
@echo Scenario = %scenario%, Flag140 = %flag140%, Flag143 = %flag143%

REM ======================================================================
@echo
@echo RUNNING sas batch processing
@echo

REM ======================================================================
set /A counter=1
REM ======================================================================
cd SAS
:while
if %counter% GTR 5 (goto loopend)

if %counter% EQU 1 (set script=Step1_Create_GCD_file)
if %counter% EQU 2 (set script=Step2_Create_ModePath_Skim_file)
if %counter% EQU 3 (set script=Step3_Verify_Costs_Times)
if %counter% EQU 4 (set script=Step4_Create_Zonal_Truck_Tour_files)
if %counter% EQU 5 (set script=Step5_determine_pipeline_costs.R)

if exist %script%.lst (del %script%.lst /Q)
if exist Step3_Verify_Costs_Times.lst (del Step3_Verify_Costs_Times.lst /Q)
@ECHO.
@ECHO   - Running Script %counter%.
if %counter% EQU 1 ("C:/Program Files/SASHome/SASFoundation/9.4/sas.exe" %script% -sysparm "%scenario% %choiceYR%")
if %counter% EQU 2 ("C:/Program Files/SASHome/SASFoundation/9.4/sas.exe" %script% -sysparm "%scenario% %flag140% %flag143% %choiceYR%")
if %counter% EQU 3 ("C:/Program Files/SASHome/SASFoundation/9.4/sas.exe" %script% -sysparm "%scenario% %flag143%")
if %counter% EQU 4 ("C:/Program Files/SASHome/SASFoundation/9.4/sas.exe" %script% -sysparm "%scenario% %choiceYR% %conf2%")
if %counter% EQU 5 (%rpath% %script% %scenario% %choiceYr%)
@ECHO.
@echo ran step %counter%

if %ERRORLEVEL% GTR 1 (goto saserr)
if exist Step3_Verify_Costs_Times.lst (goto mode_err)
@ECHO   - Script %counter% (%script%) completed successfully.

set /A counter=counter+1
goto while
REM ======================================================================
goto end


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