param (
    [Parameter(Mandatory = $false)]
    [ValidateSet("Production", "Nightly")]
    [String]$Environment = "Production"
)

$ErrorActionPreference = "Stop"

# === CONFIGURATION ===
$githubOwner = "AlexIves16"
$githubRepo = "bcgg"

# Environment-specific settings (Firebase RTDB — no external server needed)
if ($Environment -eq "Nightly") {
    $serverUrl = "firebase-rtdb-nightly"
    $releaseSuffix = "-nightly"
}
else {
    $serverUrl = "firebase-rtdb-production"
    $releaseSuffix = ""
}

$projectRoot = $PSScriptRoot
$pubspecFile = Join-Path $projectRoot "pubspec.yaml"
$apkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-release.apk"

# Ensure gh is on PATH (installed via winget)
$env:PATH += ";$env:ProgramFiles\GitHub CLI"

Write-Host "=== Digital Ether - GitHub Releases OTA Build ===" -ForegroundColor Cyan

# --- Step 1: Increment build number ---
if (-Not (Test-Path $pubspecFile)) { Write-Error "pubspec.yaml not found!"; exit 1 }

$lines = Get-Content $pubspecFile
$newLines = @()
$newBuildNum = 0

foreach ($line in $lines) {
    if ($line -match '^version:\s*(\d+\.\d+\.\d+)\+(\d+)') {
        $baseVersion = $matches[1]
        $newBuildNum = ([int]$matches[2]) + 1
        Write-Host "Bumping build number -> $newBuildNum" -ForegroundColor Yellow
        $newLines += "version: $baseVersion+$newBuildNum"
    }
    else {
        $newLines += $line
    }
}

if ($newBuildNum -eq 0) { Write-Error "Could not parse version from pubspec.yaml"; exit 1 }
Set-Content -Path $pubspecFile -Value $newLines -Encoding UTF8

# --- Step 2: Build release APK ---
Write-Host "Building Flutter APK for $Environment ($serverUrl)..." -ForegroundColor Cyan
flutter build apk --release --dart-define=SERVER_URL=$serverUrl
if ($LASTEXITCODE -ne 0) { Write-Error "Flutter build failed"; exit 1 }

# --- Step 3: Commit and push version bump ---
Write-Host "Committing version bump..." -ForegroundColor Cyan
git add pubspec.yaml
git commit -m "chore: bump version to $baseVersion+$newBuildNum ($Environment)"
$branch = if ($Environment -eq "Nightly") { "develop" } else { "master" }
git pull --rebase origin $branch
git push origin $branch

# --- Step 4: Copy APK to Game Server for OTA ---
$publicApkPath = Join-Path $projectRoot "game-server\public\app-release.apk"
Write-Host "Copying APK to $publicApkPath for OTA..." -ForegroundColor Cyan
if (-Not (Test-Path (Join-Path $projectRoot "game-server\public"))) { New-Item -ItemType Directory -Path (Join-Path $projectRoot "game-server\public") }
Copy-Item -Path "$apkPath" -Destination "$publicApkPath" -Force

# --- Step 5: Publish GitHub Release ---
$tag = "0.$newBuildNum$releaseSuffix"
$releaseTitle = "Digital Ether $tag"
$releaseNotes = "$Environment release $tag built $(Get-Date -Format 'yyyy-MM-dd HH:mm')"

Write-Host "Publishing GitHub Release $tag..." -ForegroundColor Cyan
$isLatest = if ($Environment -eq "Production") { "true" } else { "false" }
gh release create "$tag" "$apkPath" --repo "$githubOwner/$githubRepo" --title "$releaseTitle" --notes "$releaseNotes" --latest=$isLatest

if ($LASTEXITCODE -ne 0) { Write-Error "GitHub release failed"; exit 1 }

Write-Host ""
Write-Host "=== SUCCESS: Release $tag published! ===" -ForegroundColor Green
Write-Host "URL: https://github.com/$githubOwner/$githubRepo/releases/tag/$tag" -ForegroundColor Green
