@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "RC4_DIR=%~dp0"
if exist "%RC4_DIR%ProjectCrystal.exe" goto located
if exist "%~dp0..\builds\g08\rc4-fixed-0bb2188-v2\candidate\ProjectCrystal.exe" (
    for %%I in ("%~dp0..\builds\g08\rc4-fixed-0bb2188-v2\candidate") do set "RC4_DIR=%%~fI\"
    goto located
)
echo Project Crystal executable was not found beside this launcher.
if not defined RC4_NO_PAUSE if not defined RC3_NO_PAUSE pause
exit /b 2
:located
if exist "%RC4_DIR%ProjectCrystal.pck" goto prepare
echo Project Crystal data pack is missing. Keep the EXE and PCK together.
if not defined RC4_NO_PAUSE if not defined RC3_NO_PAUSE pause
exit /b 3
:prepare
set "RC4_TEST=%RC4_DIR%user_test"
for %%D in (profile local temp) do (
    if not exist "%RC4_TEST%\%%D" mkdir "%RC4_TEST%\%%D"
    if not exist "%RC4_TEST%\%%D" goto folder_error
)
set "APPDATA=%RC4_TEST%\profile"
set "LOCALAPPDATA=%RC4_TEST%\local"
set "TEMP=%RC4_TEST%\temp"
set "TMP=%RC4_TEST%\temp"
:choose_log
set "RC4_LOG=%RC4_TEST%\play-%RANDOM%-%RANDOM%.log"
if exist "%RC4_LOG%" goto choose_log
echo Starting Project Crystal RC4...
start "" /b /wait /d "%RC4_DIR%" "%RC4_DIR%ProjectCrystal.exe" --log-file "%RC4_LOG%" %* > "%RC4_LOG%.stdout.txt" 2>&1
set "RC4_LAST_EXIT=%ERRORLEVEL%"
if "%RC4_LAST_EXIT%"=="0" exit /b 0
echo Project Crystal exited with code %RC4_LAST_EXIT%.
echo Game log: "%RC4_LOG%"
echo Launcher output: "%RC4_LOG%.stdout.txt"
if not defined RC4_NO_PAUSE if not defined RC3_NO_PAUSE pause
exit /b %RC4_LAST_EXIT%
:folder_error
echo The test save folder could not be created: "%RC4_TEST%"
if not defined RC4_NO_PAUSE if not defined RC3_NO_PAUSE pause
exit /b 4
