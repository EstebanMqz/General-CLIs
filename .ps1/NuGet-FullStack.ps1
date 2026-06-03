<#
.SYNOPSIS
    Unified setup for NuGet CLI and PowerShell Package Management stack.
.DESCRIPTION
    Automates the installation of nuget.exe, updates the System PATH, 
    and ensures the PowerShell NuGet provider and management modules are current.
    Includes UAC elevation, TLS 1.2 enforcement, and conflict resolution.
.NOTES
    Author  : EstebanMqz
    License : Apache-2.0
#>

[CmdletBinding()]
param(
    [switch]$Force
)

# Verify Administrative context; required for C:\ writes and System PATH modifications.
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Administrative rights required for NuGet stack setup. Requesting UAC..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Configuration ---
$InstallDir = "C:\NuGet"
$NugetExe = Join-Path $InstallDir "nuget.exe"
$DownloadUrl = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"

$originalWarningPreference = $WarningPreference
$originalProgressPreference = $ProgressPreference

try {
    # Enforce TLS 1.2 for secure connectivity to NuGet and PSGallery endpoints.
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    # 1. Setup NuGet CLI (nuget.exe)
    Write-Host "--- Initializing NuGet CLI (nuget.exe) ---" -ForegroundColor Cyan
    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }

    if (-not (Test-Path $NugetExe) -or $Force) {
        Write-Host "Downloading latest nuget.exe..." -ForegroundColor Yellow
        if (-not $PSBoundParameters.ContainsKey('Verbose')) { $ProgressPreference = 'SilentlyContinue' }
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $NugetExe
        $ProgressPreference = $originalProgressPreference
    }

    # Update Machine PATH (persistence) and Process PATH (immediate use)
    $path = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if (($path -split ';' | ForEach-Object { $_.TrimEnd('\') }) -notcontains $InstallDir.TrimEnd('\')) {
        Write-Host "Adding $InstallDir to System PATH..." -ForegroundColor Cyan
        [Environment]::SetEnvironmentVariable("Path", ($path.TrimEnd(';') + ";$InstallDir"), "Machine")
        $env:Path += ";$InstallDir"
    }

    # 2. Setup PowerShell NuGet Provider & Modules
    Write-Host "`n--- Initializing PowerShell Package Management Stack ---" -ForegroundColor Cyan
    
    # Temporarily hide C:\NuGet from PATH during provider installation to prevent the "Missing -source" CLI conflict.
    $originalPath = $env:Path
    $env:Path = ($env:Path -split ';' | Where-Object { $_.TrimEnd('\') -ne $InstallDir }) -join ';'
    
    if (-not $PSBoundParameters.ContainsKey('Verbose')) { $WarningPreference = 'SilentlyContinue' }

    # Refresh PSGallery to resolve stale metadata tags.
    Write-Host "Refreshing PSGallery repository configuration..." -ForegroundColor Yellow
    $gallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    if ($gallery) { Unregister-PSRepository -Name PSGallery }
    Register-PSRepository -Default | Out-Null
    Set-PSRepository -Name PSGallery -SourceLocation "https://www.powershellgallery.com/api/v2" -InstallationPolicy Trusted

    # Install/Update the NuGet Package Provider.
    Write-Host "Ensuring NuGet provider is available and up-to-date..." -ForegroundColor Yellow
    Install-PackageProvider -Name NuGet -Scope AllUsers -Force -ForceBootstrap -ErrorAction Stop | Out-Null

    # Update core management modules.
    $modulesToUpdate = "PackageManagement", "PowerShellGet"
    foreach ($mod in $modulesToUpdate) {
        Write-Host "Checking for $mod updates..." -ForegroundColor Gray
        if ($Force) { Install-Module -Name $mod -Repository PSGallery -Force -AllowClobber -Scope AllUsers -ErrorAction SilentlyContinue }
        else { Update-Module -Name $mod -ErrorAction SilentlyContinue }
    }
}
catch {
    Write-Host "`n❌ An error occurred: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    # Restore original environment state.
    $WarningPreference = $originalWarningPreference
    $ProgressPreference = $originalProgressPreference
    if ($originalPath) { $env:Path = $originalPath }

    # Final Health Check Summary
    Write-Host "`n--- Post-Installation Summary ---" -ForegroundColor Cyan
    if (Test-Path $NugetExe) {
        $cliVersion = & $NugetExe help | Select-Object -First 1
        Write-Host "NuGet CLI:       $cliVersion" -ForegroundColor Green
    }
    
    $latestNuGet = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
    $psGet = Get-Module -Name PowerShellGet -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    $pkgMgmt = Get-Module -Name PackageManagement -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1

    Write-Host "NuGet Provider:  $($latestNuGet.Version)" -ForegroundColor Green
    Write-Host "PowerShellGet:   $($psGet.Version)" -ForegroundColor Green
    Write-Host "PackageMgmt:     $($pkgMgmt.Version)" -ForegroundColor Green
    $psGet = Get-Module -Name PowerShellGet -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    $pkgMgmt = Get-Module -Name PackageManagement -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
}


Write-Host "`nPress any key to exit..." -ForegroundColor Gray
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
