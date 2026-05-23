<#
.SYNOPSIS
    Installs Neovim on Windows.
.DESCRIPTION
    Automates the installation of Neovim includes administrative privilege checks, automated cleanup of old versions,
    extraction to a standard directory (C:\Neovim), and system-wide PATH updates
    to allow 'nvim' command usage from any terminal. The script also handles progress suppression for faster downloads and ensures a clean installation.
.NOTES
    Author  : EstebanMqz
    License : Apache-2.0
    Source  : https://github.com/EstebanMqz/CLIs-Automatic-Installations-Azure-Neovim-Docker-/blob/main/.ps1/Neovim.ps1
#>

# Self-elevate to Administrator if not already elevated
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Administrator privileges required to modify System PATH. Elevating..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 1. Download Neovim
$neovimUrl = "https://github.com/neovim/neovim/releases/latest/download/nvim-win64.zip"
$downloadPath = "$env:TEMP\nvim-win64.zip"
$extractPath = "C:\Neovim"
$binPath = "$extractPath\nvim-win64\bin"
Write-Host "Downloading Neovim..." -ForegroundColor Cyan
$oldProgress = $ProgressPreference
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri $neovimUrl -OutFile $downloadPath
$ProgressPreference = $oldProgress

# 2. Remove old installation if exists
if (Test-Path -Path $extractPath) {
    if (Get-Process -Name nvim -ErrorAction SilentlyContinue) {
        Write-Host "Closing running Neovim instances..." -ForegroundColor Yellow
        Stop-Process -Name nvim -Force
    }

    Write-Host "Cleaning up old installation at $extractPath..." -ForegroundColor Yellow
    Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $extractPath | Out-Null

# 3. Extract zip
Write-Host "Extracting files..." -ForegroundColor Cyan
Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force

# 4. Add Neovim to System PATH
$path = [Environment]::GetEnvironmentVariable("Path", "Machine")
if (($path -split ';' | ForEach-Object { $_.TrimEnd('\') }) -notcontains $binPath.TrimEnd('\')) {
    $newPath = $path.TrimEnd(';') + ";$binPath"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
    Write-Host "SUCCESS: Added Neovim to system PATH." -ForegroundColor Green
    Write-Host "Please restart your terminal (or run 'refreshenv') to use 'nvim'." -ForegroundColor Yellow
}
else {
    Write-Host "Neovim path already exists in system PATH." -ForegroundColor Gray
}

# 5. Cleanup downloaded zip
Remove-Item -Path $downloadPath
Write-Host "Neovim installed successfully at $extractPath." -ForegroundColor Green
Write-Host "You can run 'nvim' from any terminal after restarting it." -ForegroundColor Cyan