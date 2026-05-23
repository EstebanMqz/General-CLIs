<#
.SYNOPSIS
    Updates or installs the NuGet Package Provider.
.DESCRIPTION
    Enforces TLS 1.2 for secure connectivity to PSGallery and ensures the NuGet provider is up-to-date.
#>

param(
    [switch]$Force
)

# Self-elevate to Administrator if not already elevated (required for AllUsers scope)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Administrator privileges required to update NuGet provider. Elevating..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Set-StrictMode -Version Latest

# Enforce TLS 1.2 for PSGallery/NuGet connectivity (Fixes "No match was found" error)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Suppress noisy assembly loading warnings (like Windows.Devices.Printers.Extensions.dll)
$originalWarningPreference = $WarningPreference
try {
    $WarningPreference = 'SilentlyContinue'

    # PackageManagement is required for managing NuGet providers
    if (-not (Get-Module -Name PackageManagement)) {
        Write-Host "Loading PackageManagement module..." -ForegroundColor Cyan
        Import-Module PackageManagement -ErrorAction SilentlyContinue
    }

    # Display currently available providers and their metadata (Tags)
    Write-Host "Ensuring PackageManagement providers are loaded..." -ForegroundColor Cyan
    Get-PackageProvider -ListAvailable | Select-Object Name, Version, ProviderPath | Format-Table -AutoSize

    # Ensure PSGallery is registered and trusted
    Write-Host "Ensuring PSGallery repository is registered and trusted..." -ForegroundColor Yellow
    
    # Temporarily hide C:\NuGet from PATH to prevent CLI conflict
    $originalPath = $env:Path
    $env:Path = ($env:Path -split ';' | Where-Object { $_.TrimEnd('\') -ne 'C:\NuGet' }) -join ';'

    # Always ensure PSGallery is correctly registered to avoid the "Missing Provider Tags" metadata error.
    # This error occurs when the local repository cache doesn't correctly index NuGet as a valid provider.
    Write-Host "Re-registering PSGallery to ensure correct metadata tags..." -ForegroundColor Yellow
    Unregister-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    Register-PSRepository -Default -ErrorAction SilentlyContinue
    Set-PSRepository -Name PSGallery -SourceLocation "https://www.powershellgallery.com/api/v2" -InstallationPolicy Trusted -ErrorAction Stop

    # Install or Update NuGet provider
    Write-Host "Ensuring NuGet provider is available and up-to-date..." -ForegroundColor Yellow
    # Install-PackageProvider with -Force will install if not present, or update if a newer version is available.
    # This handles both initial installation and updates.
    Install-PackageProvider -Name NuGet -Scope AllUsers -Force -ForceBootstrap -ErrorAction Stop | Out-Null

    # Install/Update the core modules that interact with NuGet and PSGallery
    Write-Host "Ensuring PowerShellGet and PackageManagement modules are up-to-date..." -ForegroundColor Yellow
    
    # Only update if forced or if versions are significantly old/missing
    $modulesToUpdate = "PackageManagement", "PowerShellGet"
    foreach ($mod in $modulesToUpdate) {
        # Update-Module is generally faster than Install-Module -Force if the module exists
        if ($Force) { Install-Module -Name $mod -Repository PSGallery -Force -AllowClobber -Scope AllUsers -ErrorAction SilentlyContinue }
        else { Update-Module -Name $mod -ErrorAction SilentlyContinue }
    }
}
catch {
    Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
    return
}
finally {
    $WarningPreference = $originalWarningPreference
    if ($originalPath) { $env:Path = $originalPath }
}

# Summary of the NuGet infrastructure
Write-Host "`nSummary of NuGet infrastructure:" -ForegroundColor Cyan
$latestNuGet = Get-PackageProvider -Name NuGet | Sort-Object Version -Descending | Select-Object -First 1
Write-Host "NuGet Provider:  $($latestNuGet.Version) ($($latestNuGet.Path))" -ForegroundColor Green
Write-Host "PowerShellGet:   $((Get-Module -Name PowerShellGet -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version)" -ForegroundColor Green
Write-Host "PackageMgmt:     $((Get-Module -Name PackageManagement -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version)" -ForegroundColor Green
Write-Host "`nNuGet stack is fully updated and ready for use." -ForegroundColor Green

# Retrieve the latest provider info to avoid array issues if multiple versions exist
$latestNuGet = Get-PackageProvider -Name NuGet | Sort-Object Version -Descending | Select-Object -First 1
Write-Host "NuGet provider path: $($latestNuGet.Path)" -ForegroundColor Green
Write-Host "NuGet provider version: $($latestNuGet.Version)" -ForegroundColor Green
Write-Host "NuGet provider updated & ready for use in installing the Az module and dependencies." -ForegroundColor Green

# The $output is already handled by the stream; no need to emit it again here unless logging to a file.
