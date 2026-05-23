<#
.SYNOPSIS
    Installs the NuGet CLI (nuget.exe) on Windows.
.DESCRIPTION
    Automates the download of the latest NuGet executable, places it in a 
    standard directory (C:\NuGet), and ensures it is available in the System PATH.
.NOTES
    Author  : EstebanMqz
    License : Apache-2.0
    Source  : https://github.com/EstebanMqz/CLIs-Automatic-Installations-Azure-Neovim-Docker-
#>

param(
    [switch]$Force
)

# Self-elevate to Administrator if not already elevated
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Administrator privileges required to install NuGet. Elevating..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Configuration ---
$InstallDir = "C:\NuGet"
$NugetExe = Join-Path $InstallDir "nuget.exe"
$DownloadUrl = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"

Write-Host "Starting NuGet CLI Installation..." -ForegroundColor Cyan

try {
    # 1. Enforce TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # 2. Create directory if missing
    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }

    # 3. Download NuGet.exe
    if (-not (Test-Path $NugetExe) -or $Force) {
        Write-Host "Downloading latest nuget.exe..." -ForegroundColor Yellow
        $oldProgress = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $NugetExe
        $ProgressPreference = $oldProgress
    }

    # 4. Add to System PATH if not already present
    $path = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if (($path -split ';' | ForEach-Object { $_.TrimEnd('\') }) -notcontains $InstallDir.TrimEnd('\')) {
        Write-Host "Adding NuGet to system PATH..." -ForegroundColor Cyan
        $newPath = $path.TrimEnd(';') + ";$InstallDir"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
        Write-Host "SUCCESS: NuGet added to system PATH." -ForegroundColor Green
    }
    else {
        Write-Host "NuGet path already exists in system PATH." -ForegroundColor Gray
    }

    Write-Host "`n✅ NuGet installation completed successfully." -ForegroundColor Green
    Write-Host "You may need to restart your terminal to use the 'nuget' command." -ForegroundColor Cyan
}
catch {
    Write-Host "`n❌ Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
