@echo off
rem Karly Cazzato, CMAP
rem update gdb name to include c25q2 rather than FY25
rem add cleanup of files prior to Running

REM #################################################
rem HEADER INFO

REM #################################################
rem SET VARIABLES
set conf=c25q2
set mhnDir=V:/Secure/Master_Highway/mhn_%conf%.gdb
set outGDB="..\Output\MFN_temp.gdb"

rem SET PATHS
set currentDir=V:\Secure\Master_Freight\Current
set inputDir=%currentDir%\Input
set emmebankDir=%currentDir%\EmmeBank
set gdbDir=%currentDir%\MFN_currentFY25.gdb

@echo currentDir = %currentDir%
@echo inputDir = %inputDir%
@echo emmebankDir = %emmebankDir%
@echo gdbDir = %gdbDir%

REM #################################################
rem FIND PYTHON, R & EMME INSTALLATIONS
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

goto SKIP

REM #################################################
CD %~dp0
rem DEVELOP REMAINING FOLDER STRUCTURE
if not exist %outGDB% (mkdir %outGDB%)
if not exist "..\Skim_New\Model_Setups" (mkdir "..\Skim_New\Model_Setups")
if not exist "..\Input" (mkdir "..\Input")
if not exist "..\Output\Batchin" (mkdir "..\Output\Batchin")

rem COPY INPUT FILE FOLDER
copy %inputDir% "..\Input"

rem COPY GDB TO TEMPORARY FOLDER
copy %gdbDir% "..\Output\MFN_temp.gdb"

rem COPY AND RENAME SKIMS SETUPS, INCLUDING EMMEBANK FROM V DRIVE
set /A counter=2022
:while
if %counter% GTR 2050 (goto loopend)
set nameMod=Meso_Freight_Skim_Setup_%conf%_%counter%
mkdir = "..\Skim_New\Model_Setups\%nameMod%"
xcopy "Meso_Freight_Skim_Setup_c##q##_YYYY\" "..\Skim_New\Model_Setups\%nameMod%" /s
copy "%emmebankDir%\emmebank" "..\Skim_New\Model_Setups\%nameMod%\Database"
if %counter% GTR 2025 (set /A counter=counter+10)
if %counter% EQU 2022 (set /A counter=2030)
goto while
:loopend

:SKIP
CD %~dp0
@ECHO ######################################################################################################################################################
@ECHO Setup Complete; Press enter if directory below is correct
@ECHO %~dp0
@ECHO ######################################################################################################################################################
pause

REM #################################################
rem RUN PREP SCRIPTS
rem process links R script
@ECHO Running process_futureLinks.R
rem %rpath% 1_PreProcessing\process_futureLinks.R %mhnDir% 

rem qc R script
@ECHO Running qc_generatedLayers.R 
rem %rpath% 99_QC\qc_generatedLayers.R %gdbDir% %mhnDir% 

rem toolbox work
@ECHO Running batch_domestic_scen_working.py 
rem call python 2_ArcGIS_Processing\batch_domestic_scen_working.py 

rem qc R script
@ECHO Running qc_batchinFiles.R 
%rpath% 99_QC\qc_batchinFiles.R %mhnDir%
pause
REM #################################################
rem RUN SKIMS
rem for year in years
	rem for scenario in scenarios
		rem access batch file in each skim setup and execute based on stored variables

REM #################################################
rem RUN FINAL QC SCRIPTS
@ECHO Running qc_finalSkimOutput.R
%rpath% 99_QC\qc_finalSkimOutput.R
@ECHO Running qc_compareSkimOutput.R
%rpath% 99_QC\qc_compareSkimOutput.R

REM #################################################