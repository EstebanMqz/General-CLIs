<#
.SYNOPSIS
    Installs the Azure PowerShell module on Windows.
.DESCRIPTION
    Automates the installation of the Azure submodules. 
    Includes administrative privilege checks, TLS 1.2 enforcement for secure downloads, NuGet provider installation, trusted repository configuration, and a summary of installed submodules through PSGallery scoped installation. It doesn't add the module to the system PATH; they are imported via PowerShell natively with all their cmdlets for autocompletion and loading. It also removes the Az module and all its submodules if the -Force flag is used, ensuring a clean installation by purging all related folders and package entries across scopes and installs the latest version of the Az submodules in the standard Global path (Program Files) to avoid duplication issues.
.NOTES
    Author  : EstebanMqz
    License : Apache-2.0
    Source  : https://github.com/EstebanMqz/CLIs-Automatic-Installations-Azure-Neovim-Docker-/blob/main/.ps1/Azure.ps1
#>

param(
    [switch]$Force
)

# Self-elevate to Administrator if not already.
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Administrator privileges required for Azure module setup. Requesting UAC..." -ForegroundColor Yellow
    # Dynamically detect if using powershell.exe or pwsh.exe for proper elevation
    $psExe = (Get-Process -Id $PID).Path
    Start-Process $psExe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Write-Host "Checking for Azure (Az) module..." -ForegroundColor Cyan

#TLS 1.2 for Nuget and PowerShell Gallery set for the installation of Az submodules & dependencies.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Suppress noisy assembly loading warnings (like Windows.Devices.Printers.Extensions.dll)
$originalWarningPreference = $WarningPreference
$WarningPreference = 'SilentlyContinue'

if ((-not (Get-Module -Name Az -ListAvailable -ErrorAction SilentlyContinue)) -or $Force) {
    $WarningPreference = $originalWarningPreference
    if ($Force) {
        Write-Host "Force flag detected. Performing deep clean of Azure modules..." -ForegroundColor Yellow

        # 1. Uninstall via Package Management (targets the database entries)
        # We loop to catch every single version found in the list you provided
        if (Get-Package -Name "Az" -ErrorAction SilentlyContinue) {
            Uninstall-Package -Name "Az" -Force -ErrorAction SilentlyContinue
        }
        $packages = Get-Package -Name "Az.*" -ErrorAction SilentlyContinue
        if ($packages) {
            Write-Host "  Uninstalling $($packages.Count) package entries..." -ForegroundColor Gray
            $packages | Uninstall-Package -Force -ErrorAction SilentlyContinue
        }

        # 2. Manually purge folders from all known module paths
        # This is the most effective way to handle the "Esteban" user folder vs "Program Files" conflict
        $env:PSModulePath -split ';' | ForEach-Object {
            $path = $_.Trim().TrimEnd('\')
            if (Test-Path $path) {
                $folders = Get-ChildItem -Path $path -Filter "Az.*" -Directory -ErrorAction SilentlyContinue
                foreach ($folder in $folders) {
                    Write-Host "  Deleting folder: $($folder.FullName)" -ForegroundColor Gray
                    Remove-Item -Path $folder.FullName -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    # Ensure PackageManagement module is loaded
    if (-not (Get-Module -Name PackageManagement)) {
        Write-Host "Loading PackageManagement module..." -ForegroundColor Gray
        Import-Module PackageManagement -ErrorAction SilentlyContinue
    }

    # Reset PSGallery to resolve metadata parsing/tag issues before installation
    Write-Host "Resetting PSGallery repository configuration..." -ForegroundColor Yellow
    Unregister-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    Register-PSRepository -Default -ErrorAction SilentlyContinue
    # Explicitly setting the SourceLocation fixes the "Missing Provider Tags" metadata bug
    Set-PSRepository -Name PSGallery -SourceLocation "https://www.powershellgallery.com/api/v2" -InstallationPolicy Trusted -ErrorAction SilentlyContinue

    Write-Host "Ensuring NuGet provider is available..." -ForegroundColor Yellow
    Install-PackageProvider -Name NuGet -Scope AllUsers -Force -ForceBootstrap -ErrorAction SilentlyContinue | Out-Null
    
    Write-Host "Installing Az module..." -ForegroundColor Yellow
    Write-Host "Installing Az module to the standard Global path (Program Files)..." -ForegroundColor Yellow
    Install-Module -Name Az -Repository PSGallery -AllowClobber -Scope AllUsers -Force -Confirm:$false -ErrorAction Stop
}
else {
    $WarningPreference = $originalWarningPreference
}

# Summary Az submodules (Name, version, path).
Write-Host "`nSummary of installed Az submodules:" -ForegroundColor Cyan
$WarningPreference = 'SilentlyContinue'
Get-Module -Name Az.* -ListAvailable | Select-Object Name, Version, ModuleBase | Sort-Object Name, Version | Format-Table -AutoSize
$WarningPreference = $originalWarningPreference
Write-Host "Azure setup complete." -ForegroundColor Green

#Run ./Azure.ps1 -Force