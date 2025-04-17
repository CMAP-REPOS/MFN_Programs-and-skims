rem Runs final skim QC scripts in batch
rem Karly Cazzato, CMAP

@ECHO Finding R installation
REM Now find R executable
CD %~dp0
set infile=path.txt
if exist %infile% (del %infile% /Q)
rem dir "C:\Users\kcazzato\AppData\Local\Programs\R\R-4.4.1\bin\x64\R.exe" /s /b >> %infile% 2>nul
dir "C:\Users\kcazzato\AppData\Local\Programs\R\R-4.4.1\bin\Rscript.exe" /s /b >> %infile% 2>nul
set /p path2=<%infile%
set paren="
set rpath="C:\Users\kcazzato\AppData\Local\Programs\R\R-4.4.1\bin\Rscript.exe"
echo rpath = %rpath%

@Echo %dir%
pause
@ECHO Running qc_finalSkimOutput.R
%rpath% qc_finalSkimOutput.R
pause
@ECHO Running qc_compareSkimOutput.R
%rpath% qc_compareSkimOutput.R

@Echo End of bat file
pause
rem Errors