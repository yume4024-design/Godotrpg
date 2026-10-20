@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "RC3_DIR=%~dp0"
if exist "%RC3_DIR%ProjectCrystal.exe" goto located
if exist "%~dp0..\builds\g08\rc3-20261020\candidate\ProjectCrystal.exe" (
    for %%I in ("%~dp0..\builds\g08\rc3-20261020\candidate") do set "RC3_DIR=%%~fI\"
    goto located
)
echo Project Crystal executable was not found beside this launcher.
if not defined RC3_NO_PAUSE pause
exit /b 2
:located
if exist "%RC3_DIR%ProjectCrystal.pck" goto prepare
echo Project Crystal data pack is missing. Keep the EXE and PCK together.
if not defined RC3_NO_PAUSE pause
exit /b 3
:prepare
set "RC3_TEST=%RC3_DIR%user_test"
for %%D in (profile local temp) do (
    if not exist "%RC3_TEST%\%%D" mkdir "%RC3_TEST%\%%D"
    if not exist "%RC3_TEST%\%%D" goto folder_error
)
set "APPDATA=%RC3_TEST%\profile"
set "LOCALAPPDATA=%RC3_TEST%\local"
set "TEMP=%RC3_TEST%\temp"
set "TMP=%RC3_TEST%\temp"
:choose_log
set "RC3_LOG=%RC3_TEST%\play-%RANDOM%-%RANDOM%.log"
if exist "%RC3_LOG%" goto choose_log
echo Starting Project Crystal RC3...
start "" /b /wait /d "%RC3_DIR%" "%RC3_DIR%ProjectCrystal.exe" --log-file "%RC3_LOG%" %* > "%RC3_LOG%.stdout.txt" 2>&1
set "RC3_LAST_EXIT=%ERRORLEVEL%"
if "%RC3_LAST_EXIT%"=="0" exit /b 0
echo Project Crystal exited with code %RC3_LAST_EXIT%.
echo Game log: "%RC3_LOG%"
echo Launcher output: "%RC3_LOG%.stdout.txt"
if not defined RC3_NO_PAUSE pause
exit /b %RC3_LAST_EXIT%
:folder_error
echo The test save folder could not be created: "%RC3_TEST%"
if not defined RC3_NO_PAUSE pause
exit /b 4
