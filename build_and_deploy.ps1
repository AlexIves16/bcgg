$ErrorActionPreference = "Stop"

# === CONFIGURATION ===
$githubOwner = "ormix"       # CHANGE: your GitHub username
$githubRepo = "bcgame"      # CHANGE: your GitHub repo name

$projectRoot = $PSScriptRoot
$pubspecFile = Join-Path $projectRoot "pubspec.yaml"
$apkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-release.apk"

# Ensure gh is on PATH (installed via winget)
$env:PATH += ";$env:ProgramFiles\GitHub CLI"

Write-Host "=== Digital Ether — GitHub Releases OTA Build ===" -ForegroundColor Cyan

# --- Step 1: Read and increment build number from pubspec.yaml ---
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
Write-Host "Building Flutter APK..." -ForegroundColor Cyan
flutter build apk --release
if ($LASTEXITCODE -ne 0) { Write-Error "Flutter build failed"; exit 1 }

# --- Step 3: Stage and commit the version bump ---
Write-Host "Committing version bump..." -ForegroundColor Cyan
git add pubspec.yaml
git commit -m "chore: bump version to $baseVersion+$newBuildNum"
git push origin main

# --- Step 4: Create GitHub Release and upload APK ---
$tag = "v$newBuildNum"
$title = "Digital Ether v$newBuildNum"
$notes = "OTA release $tag — built $(Get-Date -Format 'yyyy-MM-dd HH:mm')"

Write-Host "Publishing GitHub Release $tag..." -ForegroundColor Cyan
gh release create $tag $apkPath `
    --repo "$githubOwner/$githubRepo" `
    --title $title `
    --notes $notes

if ($LASTEXITCODE -ne 0) { Write-Error "GitHub release failed"; exit 1 }

Write-Host ""
Write-Host "=== SUCCESS: Release $tag published to GitHub! ===" -ForegroundColor Green
Write-Host "APK URL: https://github.com/$githubOwner/$githubRepo/releases/tag/$tag" -ForegroundColor Green
