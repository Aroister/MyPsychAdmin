@echo off
title MyPsychAdmin Installer
echo ================================
echo   MyPsychAdmin Installer
echo ================================
echo.
echo Creating install directory...
if not exist "%LOCALAPPDATA%\MyPsychAdmin" mkdir "%LOCALAPPDATA%\MyPsychAdmin"
echo Downloading MyPsychAdmin...
echo This may take a few minutes...
echo.

REM Download from OneDrive (direct download link)
curl -L -o "%LOCALAPPDATA%\MyPsychAdmin\MyPsychAdmin.exe" "https://1drv.ms/u/c/0968cd554b2a5e46/IQCCphuUS9w-RZ1IJpu6MhaPAdATDAE4LYwAZD0Bp2iPV5E?download=1"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Curl failed, trying PowerShell...
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('https://1drv.ms/u/c/0968cd554b2a5e46/IQCCphuUS9w-RZ1IJpu6MhaPAdATDAE4LYwAZD0Bp2iPV5E?download=1', '%LOCALAPPDATA%\MyPsychAdmin\MyPsychAdmin.exe')"
)

REM Check file size - should be over 200MB
for %%A in ("%LOCALAPPDATA%\MyPsychAdmin\MyPsychAdmin.exe") do set size=%%~zA
if %size% LSS 100000000 (
    echo.
    echo ERROR: Download incomplete - file is too small.
    echo The download may have been blocked by your network.
    echo.
    echo Please download manually from:
    echo https://1drv.ms/u/c/0968cd554b2a5e46/IQCCphuUS9w-RZ1IJpu6MhaPAdATDAE4LYwAZD0Bp2iPV5E
    echo.
    pause
    exit /b 1
)

echo Download complete!
echo Creating desktop shortcut...
powershell -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut('%USERPROFILE%\Desktop\MyPsychAdmin.lnk'); $s.TargetPath = '%LOCALAPPDATA%\MyPsychAdmin\MyPsychAdmin.exe'; $s.WorkingDirectory = '%LOCALAPPDATA%\MyPsychAdmin'; $s.Save()"
echo.
echo ================================
echo   Installation Complete!
echo ================================
echo.
echo Launching MyPsychAdmin...
start "" "%LOCALAPPDATA%\MyPsychAdmin\MyPsychAdmin.exe"
echo.
echo Press any key to close this window...
pause >nul
