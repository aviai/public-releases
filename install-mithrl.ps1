# Download the latest mithrl CLI binary for Windows.
#
#   .\install-mithrl.ps1                              # into the current directory
#   .\install-mithrl.ps1 -InstallDir "$HOME\bin"      # somewhere on your PATH
#
# Already have mithrl? `mithrl update` is the supported upgrade path, and it
# verifies the release signature, which this script cannot.
[CmdletBinding()]
param([string]$InstallDir = ".")

$ErrorActionPreference = "Stop"
# Invoke-WebRequest's progress UI costs more time than the download on PS 5.1.
$ProgressPreference = "SilentlyContinue"
# PS 5.1 still defaults to TLS 1.0, which GitHub refuses.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo = "mithrl-labs/public-releases"
$tagPrefix = "lattice-cli/"

if ($env:PROCESSOR_ARCHITECTURE -ne "AMD64") {
    throw "install-mithrl: no Windows build for $env:PROCESSOR_ARCHITECTURE yet -- x64 only."
}

# This repo hosts several products and GitHub's "Latest" marker is repo-wide,
# so take the newest release tagged lattice-cli/* rather than /releases/latest.
try {
    $releases = Invoke-RestMethod -UseBasicParsing "https://api.github.com/repos/$repo/releases?per_page=100"
} catch {
    throw "install-mithrl: could not reach the GitHub API. It allows 60 requests/hour per IP unauthenticated -- if you share an egress IP, wait and retry."
}
$tag = ($releases | Where-Object { $_.tag_name -like "$tagPrefix*" } | Select-Object -First 1).tag_name
if (-not $tag) { throw "install-mithrl: no $tagPrefix* release found in this repo." }

# GitHub reads a literal / in a tag as a path separator, so it has to be encoded.
$base = "https://github.com/$repo/releases/download/$($tag -replace '/', '%2F')"
$asset = "mithrl-windows-amd64.exe"
$work = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $work | Out-Null

try {
    $manifest = Invoke-RestMethod -UseBasicParsing "$base/manifest.json"
    $want = $manifest.platforms."windows-amd64".sha256
    if (-not $want) { throw "install-mithrl: manifest.json for $tag has no windows-amd64 entry." }

    Write-Host "Downloading $asset ($tag)..."
    $downloaded = Join-Path $work $asset
    Invoke-WebRequest -UseBasicParsing "$base/$asset" -OutFile $downloaded

    $got = (Get-FileHash -Algorithm SHA256 $downloaded).Hash.ToLower()
    if ($got -ne $want.ToLower()) {
        throw "install-mithrl: checksum mismatch for $asset -- got $got, manifest says $want. Not installing."
    }

    if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir | Out-Null }
    $target = Join-Path (Resolve-Path $InstallDir) "mithrl.exe"
    Move-Item -Force $downloaded $target

    Write-Host "Installed $target (checksum matches the release manifest)."
    if (($env:PATH -split ";") -contains (Split-Path $target)) {
        Write-Host "Run: mithrl --version"
    } else {
        Write-Host "Not on your PATH yet. Run: $target --version"
    }
} finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}
