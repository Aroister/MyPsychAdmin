# MyPsychAdmin Web Installer
# Run with: powershell -ExecutionPolicy Bypass -File Install_MyPsychAdmin.ps1

$AppName = "MyPsychAdmin"
$DownloadUrl = "https://github.com/Aroister/MyPsychAdmin/releases/download/v2.7/MyPsychAdmin.exe"
$InstallPath = "$env:LOCALAPPDATA\$AppName"
$ExePath = "$InstallPath\$AppName.exe"

Write-Host "================================" -ForegroundColor Cyan
Write-Host "  $AppName Installer" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Create install directory
Write-Host "Creating install directory..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null

# Download
Write-Host "Downloading $AppName..." -ForegroundColor Yellow
Write-Host "This may take a few minutes..."
try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ExePath -UseBasicParsing
    Write-Host "Download complete!" -ForegroundColor Green
} catch {
    Write-Host "Download failed: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Create Desktop shortcut
Write-Host "Creating desktop shortcut..." -ForegroundColor Yellow
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\$AppName.lnk")
$Shortcut.TargetPath = $ExePath
$Shortcut.WorkingDirectory = $InstallPath
$Shortcut.Save()

# Create Start Menu shortcut
$StartMenuPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
$Shortcut = $WshShell.CreateShortcut("$StartMenuPath\$AppName.lnk")
$Shortcut.TargetPath = $ExePath
$Shortcut.WorkingDirectory = $InstallPath
$Shortcut.Save()

Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
Write-Host "Installed to: $InstallPath"
Write-Host "Desktop shortcut created."
Write-Host ""

$launch = Read-Host "Launch $AppName now? (Y/N)"
if ($launch -eq "Y" -or $launch -eq "y") {
    Start-Process $ExePath -WorkingDirectory $InstallPath
}
