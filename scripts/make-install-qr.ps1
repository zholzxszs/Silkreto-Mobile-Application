[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ApkUrl,

    [string]$ApkPath = "build/app/outputs/flutter-apk/app-release.apk",
    [string]$QrOutput = "build/install-qr.png",

    [ValidatePattern("^\d+x\d+$")]
    [string]$QrSize = "800x800",

    [switch]$BuildApk,
    [switch]$SkipApkCheck,
    [switch]$SkipUrlCheck
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Write-Info($msg) { Write-Host "[INFO] $msg" }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $projectRoot

if ($BuildApk) {
    Write-Info "Building release APK..."
    & flutter build apk --release
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build apk --release failed with exit code $LASTEXITCODE."
    }
}

if (-not $SkipApkCheck -and -not (Test-Path -LiteralPath $ApkPath)) {
    throw "APK not found at '$ApkPath'. Run with -BuildApk or set -ApkPath."
}

if ($ApkUrl -notmatch "^https?://") {
    throw "ApkUrl must start with http:// or https://"
}

# Helpful hint: GitHub Releases direct-download URL usually contains /releases/download/
if ($ApkUrl -notmatch "/releases/download/") {
    Write-Warn "ApkUrl doesn't look like a GitHub Releases direct-download link."
    Write-Warn "Expected format: https://github.com/<owner>/<repo>/releases/download/<tag>/app-release.apk"
    Write-Warn "It may still work, but QR scanners might open a webpage instead of downloading."
}

if (-not $SkipUrlCheck) {
    Write-Info "Checking APK URL (HEAD request)..."
    try {
        # Follow redirects (GitHub often redirects to an asset host)
        $resp = Invoke-WebRequest -Uri $ApkUrl -Method Head -MaximumRedirection 10 -TimeoutSec 20
        if ($resp.StatusCode -lt 200 -or $resp.StatusCode -ge 400) {
            throw "URL returned status $($resp.StatusCode)"
        }
    } catch {
        throw "APK URL check failed. Make sure it's publicly reachable and is a direct download URL. Details: $($_.Exception.Message)"
    }
}

$qrDir = Split-Path -Parent $QrOutput
if ($qrDir -and -not (Test-Path -LiteralPath $qrDir)) {
    New-Item -ItemType Directory -Path $qrDir -Force | Out-Null
}

$encodedUrl = [uri]::EscapeDataString($ApkUrl)
$qrApiUrl = "https://api.qrserver.com/v1/create-qr-code/?size=$QrSize&data=$encodedUrl"

Write-Info "Generating QR code..."
Invoke-WebRequest -Uri $qrApiUrl -OutFile $QrOutput

Write-Host ""
Write-Host "Done."
Write-Host "APK URL : $ApkUrl"
Write-Host "QR file : $QrOutput"
if (-not $SkipApkCheck) {
    Write-Host "APK file: $ApkPath"
}
