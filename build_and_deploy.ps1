$ErrorActionPreference = "Stop"

$projectRoot = $PSScriptRoot
$serverDir = Join-Path $projectRoot "game-server"
$publicDir = Join-Path $serverDir "public"
$versionFile = Join-Path $serverDir "version.json"
$pubspecFile = Join-Path $projectRoot "pubspec.yaml"
$apkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-release.apk"
$destApkPath = Join-Path $publicDir "app-release.apk"

Write-Host "Starting Automated OTA Build Process..." -ForegroundColor Cyan

# 1. Read current version from pubspec.yaml safely
if (-Not (Test-Path $pubspecFile)) {
    Write-Error "pubspec.yaml not found!"
    exit 1
}

$lines = Get-Content $pubspecFile
$newLines = @()
$newBuildNumber = 0

foreach ($line in $lines) {
    if ($line -match '^version:\s*(\d+\.\d+\.\d+)\+(\d+)') {
        $baseVersion = $matches[1]
        $currentBuildNumber = [int]$matches[2]
        $newBuildNumber = $currentBuildNumber + 1
        
        Write-Host "Incrementing Flutter build number: $currentBuildNumber -> $newBuildNumber" -ForegroundColor Yellow
        $newLines += "version: $baseVersion+$newBuildNumber"
    }
    else {
        $newLines += $line
    }
}

if ($newBuildNumber -eq 0) {
    Write-Error "Could not find 'version: x.y.z+n' string in pubspec.yaml"
    exit 1
}

Set-Content -Path $pubspecFile -Value $newLines -Encoding UTF8

# 2. Build APK
Write-Host "Compiling Flutter APK..." -ForegroundColor Cyan
Invoke-Expression "flutter build apk"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter build failed"
    exit $LASTEXITCODE
}

# 3. Copy APK to Server
Write-Host "Moving APK to Node.js server..." -ForegroundColor Cyan
if (-Not (Test-Path $publicDir)) {
    New-Item -ItemType Directory -Force -Path $publicDir | Out-Null
}

if (Test-Path $destApkPath) {
    Remove-Item $destApkPath -Force
}

Copy-Item -Path $apkPath -Destination $destApkPath -Force

# 4. Save new version.json on server
$newVersionData = @{
    version = $newBuildNumber
}
$newVersionData | ConvertTo-Json | Set-Content $versionFile

Write-Host "OTA Update v$newBuildNumber deployed successfully!" -ForegroundColor Green
Write-Host "The Node.js server will now serve this update to all clients." -ForegroundColor Green
