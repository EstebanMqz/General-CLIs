<#
.SYNOPSIS
    Installs the Chocolatey package manager on Windows.
.DESCRIPTION
    Automates the installation of Chocolatey using the official installer.
    Includes administrative privilege checks, TLS 1.2 enforcement, 
    execution policy scoping, PATH refresh, and post-install verification.
    Skips the "already installed" check and re-runs the installer (useful for repairs).   
.NOTES
    Author  : EstebanMqz
    License : Apache-2.0
    Source  : https://github.com/EstebanMqz/CLIs-Automatic-Installations-Azure-Neovim-Docker-/blob/main/.ps1/choco.ps1
#>


# Self-elevate to Administrator if not already elevated
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Elevation required for Chocolatey installation. Requesting UAC..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

param(
    [switch]$Force
)

# --- Configuration & Constants ---
$ChocoInstallUrl = "https://community.chocolatey.org/install.ps1"


try {
    # 1. Pre-flight: Check if Chocolatey is already installed
    if ((Get-Command choco -ErrorAction SilentlyContinue) -and -not $Force) {
        $chocoVersion = (choco --version).Trim()
        Write-Host "Chocolatey v$chocoVersion is already installed. Exiting." -ForegroundColor Cyan
        exit 0
    }

    Write-Host "Chocolatey not found or force flag set. Proceeding with installation..." -ForegroundColor Yellow

    # 3. Enforce TLS 1.2 (required by Chocolatey's CDN)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # 4. Temporarily bypass execution policy for this process only
    Set-ExecutionPolicy Bypass -Scope Process -Force -ErrorAction Stop

    Write-Host "Downloading and executing official Chocolatey installer..." -ForegroundColor Yellow
    
    # 5. Download & Execute official installer
    Invoke-WebRequest -Uri $ChocoInstallUrl -UseBasicParsing | Invoke-Expression

    # 6. Refresh environment variables so 'choco' is available in this session
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
    [System.Environment]::GetEnvironmentVariable("Path", "User")

    # 7. Verify installation
    $installedVersion = (choco --version).Trim()
    if ($installedVersion) {
        Write-Host "`n✅ Chocolatey v$installedVersion installed successfully!" -ForegroundColor Green
        Write-Host "💡 Tip: Run 'choco install <package>' to get started."
    }
    else {
        throw "Installation completed but 'choco' command not found in PATH."
    }
    
    # Hold window open to show results
    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
}
catch {
    Write-Host "`n❌ Chocolatey installation failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Press any key to exit..." -ForegroundColor Gray   
}

