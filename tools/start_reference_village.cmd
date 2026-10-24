@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "CRYSTAL_DIR=%~dp0"
if not exist "%CRYSTAL_DIR%ProjectCrystal.exe" goto missing
if not exist "%CRYSTAL_DIR%ProjectCrystal.pck" goto missing
set "CRYSTAL_TEST=%CRYSTAL_DIR%user_test"
for %%D in (profile local temp) do (
    if not exist "%CRYSTAL_TEST%\%%D" mkdir "%CRYSTAL_TEST%\%%D"
    if not exist "%CRYSTAL_TEST%\%%D" goto folder_error
)
set "APPDATA=%CRYSTAL_TEST%\profile"
set "LOCALAPPDATA=%CRYSTAL_TEST%\local"
set "TEMP=%CRYSTAL_TEST%\temp"
set "TMP=%CRYSTAL_TEST%\temp"
:choose_log
set "CRYSTAL_LOG=%CRYSTAL_TEST%\play-%RANDOM%-%RANDOM%.log"
if exist "%CRYSTAL_LOG%" goto choose_log
echo Starting Project Crystal - Greystone Updated Reference Village...
start "" /b /wait /d "%CRYSTAL_DIR%" "%CRYSTAL_DIR%ProjectCrystal.exe" --log-file "%CRYSTAL_LOG%" %* > "%CRYSTAL_LOG%.stdout.txt" 2>&1
set "CRYSTAL_EXIT=%ERRORLEVEL%"
if "%CRYSTAL_EXIT%"=="0" exit /b 0
echo Game exited with code %CRYSTAL_EXIT%. Log: "%CRYSTAL_LOG%"
if not defined CRYSTAL_NO_PAUSE pause
exit /b %CRYSTAL_EXIT%
:missing
echo Keep this launcher, ProjectCrystal.exe and ProjectCrystal.pck together.
if not defined CRYSTAL_NO_PAUSE pause
exit /b 2
:folder_error
echo Cannot create the isolated test-save folder: "%CRYSTAL_TEST%"
if not defined CRYSTAL_NO_PAUSE pause
exit /b 4
