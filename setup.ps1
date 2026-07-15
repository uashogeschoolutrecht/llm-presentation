$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PyenvHome = Join-Path $HOME ".pyenv"
$PyenvRoot = Join-Path $HOME ".pyenv\pyenv-win"
$PyenvBin = Join-Path $PyenvRoot "bin"
$PyenvShims = Join-Path $PyenvRoot "shims"
$UvBin = Join-Path $HOME ".local\bin"

# Make existing user-level installations available in this PowerShell session.
$env:PYENV = $PyenvRoot
$env:PYENV_HOME = $PyenvRoot
$env:PYENV_ROOT = $PyenvRoot
$env:Path = "$PyenvBin;$PyenvShims;$UvBin;$env:Path"

function Invoke-DownloadWithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Uri,

        [Parameter(Mandatory = $true)]
        [string] $OutFile,

        [int] $Attempts = 3
    )

    $LastError = $null

    for ($Attempt = 1; $Attempt -le $Attempts; $Attempt++) {
        try {
            Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile $OutFile
            return
        }
        catch {
            $LastError = $_
            if ($Attempt -lt $Attempts) {
                Write-Warning "Download failed from $Uri (attempt $Attempt of $Attempts). Retrying..."
                Start-Sleep -Seconds ([Math]::Min(5 * $Attempt, 15))
            }
        }
    }

    throw $LastError
}

function Install-PyenvWinFromArchive {
    $Archive = Join-Path $env:TEMP "pyenv-win-master.zip"
    $ExtractRoot = Join-Path $env:TEMP ("pyenv-win-" + [guid]::NewGuid().ToString("N"))

    try {
        Invoke-DownloadWithRetry `
            -Uri "https://github.com/pyenv-win/pyenv-win/archive/refs/heads/master.zip" `
            -OutFile $Archive

        Expand-Archive -LiteralPath $Archive -DestinationPath $ExtractRoot -Force

        $ExtractedDirectory = Get-ChildItem $ExtractRoot -Directory | Select-Object -First 1
        if (-not $ExtractedDirectory) {
            throw "Downloaded pyenv-win archive could not be extracted."
        }

        $ArchivedPyenvRoot = Join-Path $ExtractedDirectory.FullName "pyenv-win"
        if (-not (Test-Path $ArchivedPyenvRoot)) {
            throw "Downloaded pyenv-win archive did not contain the expected pyenv-win directory."
        }

        New-Item -ItemType Directory -Path $PyenvHome -Force | Out-Null
        if (Test-Path $PyenvRoot) {
            throw "A partial pyenv-win installation already exists at $PyenvRoot. Remove it and rerun setup."
        }

        Copy-Item -LiteralPath $ArchivedPyenvRoot -Destination $PyenvRoot -Recurse
    }
    finally {
        Remove-Item $Archive -Force -ErrorAction SilentlyContinue
        Remove-Item $ExtractRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Install-PyenvWin {
    $OriginalSecurityProtocol = [Net.ServicePointManager]::SecurityProtocol

    try {
        [Net.ServicePointManager]::SecurityProtocol = $OriginalSecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

        $Installer = Join-Path $env:TEMP "install-pyenv-win.ps1"
        try {
            Invoke-DownloadWithRetry `
                -Uri "https://raw.githubusercontent.com/pyenv-win/pyenv-win/master/pyenv-win/install-pyenv-win.ps1" `
                -OutFile $Installer
            & $Installer
            return
        }
        catch {
            Write-Warning "pyenv-win installer download failed. Falling back to the GitHub archive."
        }
        finally {
            Remove-Item $Installer -Force -ErrorAction SilentlyContinue
        }

        if (-not (Get-Command pyenv -ErrorAction SilentlyContinue)) {
            Install-PyenvWinFromArchive
        }
    }
    finally {
        [Net.ServicePointManager]::SecurityProtocol = $OriginalSecurityProtocol
    }
}

if (-not (Get-Command pyenv -ErrorAction SilentlyContinue)) {
    Write-Host "Installing pyenv-win..."
    Install-PyenvWin
}

$Pyenv = Get-Command pyenv -ErrorAction SilentlyContinue
if (-not $Pyenv) {
    throw "pyenv-win was installed but could not be found. Open a new PowerShell window and run this script again."
}

Set-Location $ProjectRoot

$PythonVersionFile = Join-Path $ProjectRoot ".python-version"
if (-not (Test-Path $PythonVersionFile)) {
    throw "No .python-version file found in $ProjectRoot."
}

$RequestedVersion = (Get-Content $PythonVersionFile -Raw).Trim()
if (-not $RequestedVersion) {
    throw ".python-version is empty."
}

function Find-LatestVersion {
    param(
        [string[]] $Versions,
        [string] $Requested
    )

    $Parts = $Requested.Split(".")
    if ($Parts.Count -ge 3) {
        $Pattern = "^$([regex]::Escape($Requested))$"
    }
    else {
        $Pattern = "^$([regex]::Escape($Requested))(?:\.\d+)+$"
    }

    return $Versions |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -match $Pattern } |
        Sort-Object { [version]$_ } -Descending |
        Select-Object -First 1
}

$VersionsDirectory = Join-Path $PyenvRoot "versions"
$InstalledVersions = @()
if (Test-Path $VersionsDirectory) {
    $InstalledVersions = @(Get-ChildItem $VersionsDirectory -Directory | Select-Object -ExpandProperty Name)
}

$ResolvedVersion = Find-LatestVersion -Versions $InstalledVersions -Requested $RequestedVersion

if (-not $ResolvedVersion) {
    Write-Host "Finding the latest stable Python $RequestedVersion release..."
    $AvailableVersions = @(& $Pyenv.Source install -l)
    if ($LASTEXITCODE -ne 0) {
        throw "pyenv could not list available Python versions."
    }

    $ResolvedVersion = Find-LatestVersion -Versions $AvailableVersions -Requested $RequestedVersion
    if (-not $ResolvedVersion) {
        throw "pyenv-win does not offer a stable Python version matching $RequestedVersion."
    }

    Write-Host "Installing Python $ResolvedVersion..."
    & $Pyenv.Source install $ResolvedVersion
    if ($LASTEXITCODE -ne 0) {
        throw "Python $ResolvedVersion could not be installed."
    }
}

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Host "Installing uv..."
    Invoke-RestMethod "https://astral.sh/uv/install.ps1" | Invoke-Expression
    $env:Path = "$UvBin;$env:Path"
}

$Uv = Get-Command uv -ErrorAction SilentlyContinue
if (-not $Uv) {
    throw "uv was installed but could not be found. Open a new PowerShell window and run this script again."
}

$PythonExecutable = Join-Path $VersionsDirectory "$ResolvedVersion\python.exe"
if (-not (Test-Path $PythonExecutable)) {
    throw "Python executable not found at $PythonExecutable."
}

Write-Host "Syncing project dependencies with Python $ResolvedVersion..."
& $Uv.Source sync --python $PythonExecutable
if ($LASTEXITCODE -ne 0) {
    throw "uv sync failed."
}
