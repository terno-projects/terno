[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$NoStart
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if ($env:OS -ne "Windows_NT") { throw "This installer supports Windows only." }
if ($Uninstall -and $NoStart) { throw "Use either -Uninstall or -NoStart." }

$Repository = "terno-projects/terno"
$Program = "terno"
$DefaultInstallDirectory = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "Programs\Terno\bin"
$InstallDirectory = if ($env:TERNO_INSTALL_DIR) { $env:TERNO_INSTALL_DIR } else { $DefaultInstallDirectory }
$InstallDirectory = [IO.Path]::GetFullPath($InstallDirectory)
$InstallPath = Join-Path $InstallDirectory "$Program.exe"
if ((Test-Path -LiteralPath $InstallPath) -and ((Get-Item -LiteralPath $InstallPath).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Refusing to replace or remove a symbolic link." }
$ServerPort = if ($env:TERNO_PORT) { $env:TERNO_PORT } else { "7200" }
if ($ServerPort -notmatch '^\d{1,5}$' -or [int]$ServerPort -lt 1 -or [int]$ServerPort -gt 65535) { throw "TERNO_PORT must be an integer from 1 to 65535." }
$ServerUrl = "http://127.0.0.1:$ServerPort"
$AutoStartRegistryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$AutoStartEntryName = "Terno Server"

function Enable-TernoAutoStart {
    $escapedInstallPath = $InstallPath.Replace("'", "''")
    $startupScript = "`$env:PORT = '$ServerPort'; & '$escapedInstallPath'"
    $encodedStartupScript = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($startupScript))
    $startupCommand = "powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand $encodedStartupScript"

    New-Item -Path $AutoStartRegistryPath -Force | Out-Null
    New-ItemProperty `
        -Path $AutoStartRegistryPath `
        -Name $AutoStartEntryName `
        -Value $startupCommand `
        -PropertyType String `
        -Force | Out-Null
    Write-Host "Terno Server will start automatically when you sign in."
}

function Disable-TernoAutoStart {
    Remove-ItemProperty `
        -Path $AutoStartRegistryPath `
        -Name $AutoStartEntryName `
        -ErrorAction SilentlyContinue
}

function Start-ManagedTerno {
    if ($NoStart) {
        Write-Host "Not started. Run: & '$InstallPath'"
        return
    }

    $previousPort = $env:PORT
    try {
        $env:PORT = $ServerPort
        $serverProcess = Start-Process -FilePath $InstallPath -WindowStyle Hidden -PassThru
    }
    finally { $env:PORT = $previousPort }
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        Start-Sleep -Seconds 1
        if ($serverProcess.HasExited) { throw "Terno exited; check port $ServerPort." }
        try {
            $health = Invoke-RestMethod -Uri "$ServerUrl/api/health" -TimeoutSec 2 -UseBasicParsing
            if ($health.service -eq "terno" -and $health.status -eq "ok" -and $health.version -eq $TargetVersion) {
                Write-Host "Terno is running at $ServerUrl. Login startup enabled."
                return
            }
        }
        catch { }
    }
    throw "Startup not confirmed. The installed binary and startup configuration were kept."
}

function Stop-ManagedTerno {
    $normalizedInstallPath = [IO.Path]::GetFullPath($InstallPath)
    $managedProcesses = @(Get-Process -Name $Program -ErrorAction SilentlyContinue | Where-Object {
        try {
            [StringComparer]::OrdinalIgnoreCase.Equals(
                [IO.Path]::GetFullPath($_.Path),
                $normalizedInstallPath
            )
        }
        catch {
            $false
        }
    })

    foreach ($process in $managedProcesses) {
        Write-Host "Stopping Terno Server (PID $($process.Id))..."
        Stop-Process -Id $process.Id
        Wait-Process -Id $process.Id -Timeout 15 -ErrorAction SilentlyContinue
        if (Get-Process -Id $process.Id -ErrorAction SilentlyContinue) {
            throw "Terno Server did not stop within 15 seconds"
        }
    }
}

function Update-UserPath([bool]$Remove) {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $entries = @($userPath -split ";" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $matchingEntries = @($entries | Where-Object {
        [StringComparer]::OrdinalIgnoreCase.Equals($_.TrimEnd("\"), $InstallDirectory.TrimEnd("\"))
    })

    if ($Remove) {
        if ($matchingEntries.Count -gt 0) {
            $newPath = ($entries | Where-Object {
                -not [StringComparer]::OrdinalIgnoreCase.Equals($_.TrimEnd("\"), $InstallDirectory.TrimEnd("\"))
            }) -join ";"
            [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        }
        return
    }

    if ($matchingEntries.Count -eq 0) {
        $newPath = if ([string]::IsNullOrWhiteSpace($userPath)) {
            $InstallDirectory
        }
        else {
            "$InstallDirectory;$userPath"
        }
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Host "Added $InstallDirectory to your user PATH. Open a new terminal to use 'terno'."
    }
}

if ($Uninstall) {
    Disable-TernoAutoStart

    if (-not (Test-Path -LiteralPath $InstallPath -PathType Leaf)) {
        Write-Host "Terno is not installed at $InstallPath."
        return
    }

    $identity = (& $InstallPath version 2>$null | Out-String).Trim()
    if ($identity -notmatch '^terno\s+') {
        throw "$InstallPath does not identify itself as Terno"
    }

    Stop-ManagedTerno
    Remove-Item -LiteralPath $InstallPath -Force
    Update-UserPath $true
    if ((Test-Path -LiteralPath $InstallDirectory -PathType Container) -and
        @(Get-ChildItem -LiteralPath $InstallDirectory -Force).Count -eq 0) {
        Remove-Item -LiteralPath $InstallDirectory -Force
    }
    Write-Host "Terno executable removed from $InstallPath."
    Write-Host "User data was kept."
    return
}

$machineArchitecture = if ($env:PROCESSOR_ARCHITEW6432) {
    $env:PROCESSOR_ARCHITEW6432
}
else {
    $env:PROCESSOR_ARCHITECTURE
}
$TargetArchitecture = switch ($machineArchitecture.ToUpperInvariant()) {
    "AMD64" { "amd64" }
    "ARM64" { "arm64" }
    default { throw "Unsupported Windows architecture: $machineArchitecture" }
}

$headers = @{
    Accept = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}
$release = Invoke-RestMethod `
    -Uri "https://api.github.com/repos/$Repository/releases/latest" `
    -Headers $headers `
    -UserAgent "Terno-Installer" `
    -UseBasicParsing
$ReleaseTag = [string]$release.tag_name
if ($ReleaseTag -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+$') {
    throw "Could not determine the latest release"
}
$TargetVersion = $ReleaseTag.Substring(1)
$AssetName = "terno-$ReleaseTag-windows-$TargetArchitecture.exe"
$matchingAssets = @($release.assets | Where-Object { $_.name -eq $AssetName })
if ($matchingAssets.Count -ne 1) {
    throw "Release $ReleaseTag does not contain $AssetName"
}
$asset = $matchingAssets[0]
$digest = [string]$asset.digest
if ($digest -notmatch '^sha256:([0-9a-fA-F]{64})$') {
    throw "GitHub release metadata has no valid SHA-256 digest for $AssetName"
}
$ExpectedChecksum = $Matches[1].ToLowerInvariant()

$CurrentVersion = ""
if (Test-Path -LiteralPath $InstallPath -PathType Leaf) {
    $currentIdentity = (& $InstallPath version 2>$null | Out-String).Trim()
    if ($currentIdentity -match '^terno\s+(.+)$') {
        $CurrentVersion = $Matches[1]
    }
    else { throw "$InstallPath does not identify itself as Terno; refusing to replace it." }
}
if ($CurrentVersion -eq $TargetVersion) {
    Write-Host "Terno $TargetVersion is already installed at $InstallPath."
    Stop-ManagedTerno
    Update-UserPath $false
    if ($NoStart) { Disable-TernoAutoStart } else { Enable-TernoAutoStart }
    Start-ManagedTerno
    return
}

if ($CurrentVersion) {
    Write-Host "Upgrading Terno $CurrentVersion to $TargetVersion..."
}
else {
    Write-Host "Installing Terno $TargetVersion..."
}

$TemporaryDirectory = Join-Path ([IO.Path]::GetTempPath()) ("terno-install-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $TemporaryDirectory | Out-Null
try {
    $SourceBinary = Join-Path $TemporaryDirectory $AssetName
    Invoke-WebRequest `
        -Uri ([string]$asset.browser_download_url) `
        -OutFile $SourceBinary `
        -Headers @{ Accept = "application/octet-stream" } `
        -UserAgent "Terno-Installer" `
        -UseBasicParsing

    $ActualChecksum = (Get-FileHash -LiteralPath $SourceBinary -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($ActualChecksum -ne $ExpectedChecksum) {
        throw "Checksum verification failed for $AssetName"
    }
    Write-Host "Checksum verified against GitHub release metadata."

    if (-not (Test-Path -LiteralPath $SourceBinary -PathType Leaf)) {
        throw "Downloaded asset is missing $Program.exe"
    }
    $DownloadedIdentity = (& $SourceBinary version 2>$null | Out-String).Trim()
    if ($DownloadedIdentity -ne "terno $TargetVersion") {
        throw "Downloaded binary failed version verification"
    }

    Stop-ManagedTerno
    Disable-TernoAutoStart
    New-Item -ItemType Directory -Path $InstallDirectory -Force | Out-Null
    Copy-Item -LiteralPath $SourceBinary -Destination $InstallPath -Force

    $InstalledIdentity = (& $InstallPath version 2>$null | Out-String).Trim()
    if ($InstalledIdentity -ne "terno $TargetVersion") {
        throw "Installed binary failed version verification"
    }
}
finally {
    if (Test-Path -LiteralPath $TemporaryDirectory) {
        Remove-Item -LiteralPath $TemporaryDirectory -Recurse -Force
    }
}

Update-UserPath $false
if ($NoStart) { Disable-TernoAutoStart } else { Enable-TernoAutoStart }
Write-Host "Terno $TargetVersion installed at $InstallPath."
Start-ManagedTerno
