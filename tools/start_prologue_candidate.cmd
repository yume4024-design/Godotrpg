@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "CRYSTAL_DIR=%~dp0"
if not exist "%CRYSTAL_DIR%ProjectCrystal.exe" exit /b 2
if not exist "%CRYSTAL_DIR%ProjectCrystal.pck" exit /b 2
set "CRYSTAL_TEST=%CRYSTAL_DIR%user_test"
for %%D in (profile local temp) do if not exist "%CRYSTAL_TEST%\%%D" mkdir "%CRYSTAL_TEST%\%%D"
set "APPDATA=%CRYSTAL_TEST%\profile"
set "LOCALAPPDATA=%CRYSTAL_TEST%\local"
set "TEMP=%CRYSTAL_TEST%\temp"
set "TMP=%CRYSTAL_TEST%\temp"
set "CRYSTAL_LOG=%CRYSTAL_TEST%\play-%RANDOM%-%RANDOM%.log"
start "" /b /wait /d "%CRYSTAL_DIR%" "%CRYSTAL_DIR%ProjectCrystal.exe" --log-file "%CRYSTAL_LOG%" %*
exit /b %ERRORLEVEL%
