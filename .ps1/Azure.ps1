<#
.SYNOPSIS
    Installs the Azure PowerShell module on Windows.
    
.DESCRIPTION
    Automates the installation of the Azure submodules. 
    Includes administrative privilege checks, TLS 1.2 enforcement for secure downloads, NuGet provider installation, trusted repository configuration, and a summary of installed submodules through PSGallery scoped installation. the submodules are imported via PowerShell PATH natively with all their cmdlets for autocompletion and loading. It also removes the Az module and all its submodules. 
    Use ".\Azure.ps1 -Force" flag ensuring a clean installation by purging all related folders and package entries across scopes and installs the latest version of the Az submodules in the standard Global path (%USERPROFILE%\User\Documents\WindowsPowerShell\Modules) to avoid duplication issues and ensure latest versions are used.

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

$originalWarningPreference = $WarningPreference
try {
    # Suppress noisy assembly loading warnings
    $WarningPreference = 'SilentlyContinue'

    # Temporarily exclude the module directory from Windows Defender real-time scanning.
    # This significantly speeds up the extraction of the ~5,000 files in the Az module suite.
    Add-MpPreference -ExclusionPath "$env:ProgramFiles\WindowsPowerShell\Modules" -ErrorAction SilentlyContinue

    if ((-not (Get-Module -Name Az -ListAvailable -ErrorAction SilentlyContinue)) -or $Force) {
        if ($Force) {
            Write-Host "Force flag detected. Performing deep clean of Azure modules..." -ForegroundColor Yellow

            # 1. Uninstall via Package Management
            if (Get-Package -Name "Az" -ErrorAction SilentlyContinue) {
                Uninstall-Package -Name "Az" -Force -ErrorAction SilentlyContinue
            }
            $packages = Get-Package -Name "Az.*" -ErrorAction SilentlyContinue
            if ($packages) {
                Write-Host "  Uninstalling $($packages.Count) package entries..." -ForegroundColor Gray
                $packages | Uninstall-Package -Force -ErrorAction SilentlyContinue
            }

            # 2. Manually purge folders from all known module paths
            $env:PSModulePath -split ';' | ForEach-Object {
                $path = $_.Trim().TrimEnd('\')
                if (Test-Path $path) {
                    # Using a direct filter and avoiding the pipeline for speed
                    [System.IO.Directory]::GetDirectories($path, "Az.*") | ForEach-Object {
                        Write-Host "  Deleting folder: $_" -ForegroundColor Gray
                        # Speed up deletion by using cmd /c rd if available, or just keeping the existing Remove-Item
                        Remove-Item -Path $_ -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }

        # Ensure PackageManagement module is loaded
        if (-not (Get-Module -Name PackageManagement)) {
            Write-Host "Loading PackageManagement module..." -ForegroundColor Gray
            Import-Module PackageManagement -ErrorAction SilentlyContinue
        }

        # Reset PSGallery to resolve metadata parsing issues
        Write-Host "Resetting PSGallery repository configuration..." -ForegroundColor Yellow
        Unregister-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
        Register-PSRepository -Default -ErrorAction SilentlyContinue
        Set-PSRepository -Name PSGallery -SourceLocation "https://www.powershellgallery.com/api/v2" -InstallationPolicy Trusted -ErrorAction SilentlyContinue

        Write-Host "Ensuring NuGet provider is available..." -ForegroundColor Yellow
        Install-PackageProvider -Name NuGet -Scope AllUsers -Force -ForceBootstrap -ErrorAction SilentlyContinue | Out-Null
        
        Write-Host "Installing Az module (this can take significant time due to ~100 sub-modules)..." -ForegroundColor Yellow
        Install-Module -Name Az -Repository PSGallery -AllowClobber -Scope AllUsers -Force -Confirm:$false -ErrorAction Stop
    }
}
catch {
    Write-Host "Failed to install Azure module: $($_.Exception.Message)" -ForegroundColor Red
    return
}
finally {
    # Ensure the Windows Defender exclusion is removed once the heavy IO tasks are finished.
    Remove-MpPreference -ExclusionPath "$env:ProgramFiles\WindowsPowerShell\Modules" -ErrorAction SilentlyContinue

    # Restore preference and show summary
    $WarningPreference = $originalWarningPreference
    Write-Host "`nSummary of installed Az submodules:" -ForegroundColor Cyan
    Get-Module -Name Az.* -ListAvailable | Select-Object Name, Version, ModuleBase | Sort-Object Name, Version | Format-Table -AutoSize
    Write-Host "Azure setup complete." -ForegroundColor Green
    Write-Host "`nPress any key to close this window..." -ForegroundColor Gray
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
}

#Run by .\Azure.ps1 --Force to remove all Az modules and submodules and perform a clean installation of the latest versions and dependendencies. This is useful to resolve issues with corrupted installations, version conflicts.