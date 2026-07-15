$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PyenvRoot = Join-Path $HOME ".pyenv\pyenv-win"
$PyenvBin = Join-Path $PyenvRoot "bin"
$PyenvShims = Join-Path $PyenvRoot "shims"
$UvBin = Join-Path $HOME ".local\bin"

# Make existing user-level installations available in this PowerShell session.
$env:PYENV = $PyenvRoot
$env:PYENV_HOME = $PyenvRoot
$env:PYENV_ROOT = $PyenvRoot
$env:Path = "$PyenvBin;$PyenvShims;$UvBin;$env:Path"

if (-not (Get-Command pyenv -ErrorAction SilentlyContinue)) {
    Write-Host "Installing pyenv-win..."
    $Installer = Join-Path $env:TEMP "install-pyenv-win.ps1"

    try {
        Invoke-WebRequest `
            -UseBasicParsing `
            -Uri "https://raw.githubusercontent.com/pyenv-win/pyenv-win/master/pyenv-win/install-pyenv-win.ps1" `
            -OutFile $Installer
        & $Installer
    }
    finally {
        Remove-Item $Installer -Force -ErrorAction SilentlyContinue
    }
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
