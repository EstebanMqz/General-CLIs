# Get the latest stable version of kubectl
Write-Output "Fetching latest kubectl version..."
$kubectlVersion = (Invoke-RestMethod -Uri "https://dl.k8s.io/release/stable.txt").Trim()
$kubectlUrl = "https://dl.k8s.io/release/$kubectlVersion/bin/windows/amd64/kubectl.exe"
$installPath = "$env:USERPROFILE\kubectl"
$kubectlExePath = "$installPath\kubectl.exe"

# Create install directory if it doesn't exist
if (-Not (Test-Path -Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath | Out-Null
}

# Download kubectl.exe
Write-Output "Downloading kubectl $kubectlVersion..."
Invoke-WebRequest -Uri $kubectlUrl -OutFile $kubectlExePath

# Verify checksum
Write-Output "Verifying checksum..."
$expectedChecksum = (Invoke-RestMethod -Uri "$kubectlUrl.sha256").Trim()
$actualHash = (Get-FileHash -Path $kubectlExePath -Algorithm SHA256).Hash
if ($actualHash -ne $expectedChecksum) {
    Write-Error "Hash mismatch! Download may be corrupted."
    return
}

# Add install directory to user PATH if not already present
$currentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
if ($currentPath -split ";" -notcontains $installPath) {
    $newPath = "$currentPath;$installPath"
    [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::User)
    # Update current session PATH immediately
    $env:Path += ";$installPath"
    Write-Output "Added $installPath to PATH."
} else {
    Write-Output "$installPath is already in PATH."
}

Write-Output "Installation complete. You can now run 'kubectl version --client' to verify."
kubectl version --client
