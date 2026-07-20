<#
    Zen Browser Backup (Windows)
    Sanitizes paths so you can restore to different machines/users.
#>

$ErrorActionPreference = "SilentlyContinue"
$BackupRoot = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "Backups\ZenBrowser"
$TempDir = "$BackupRoot\temp_staging"

# Standard paths for Zen on Windows
$PathsToCheck = @(
    "$env:APPDATA\Zen\Profiles",
    "$env:APPDATA\Zen Browser\Profiles"
)

Write-Host "Scanning for profiles..." -ForegroundColor Cyan

$Profiles = @()
foreach ($p in $PathsToCheck) {
    if (Test-Path $p) {
        Get-ChildItem -Path $p -Directory | Where-Object { Test-Path "$($_.FullName)\places.sqlite" } | ForEach-Object {
            $Profiles += $_
        }
    }
}

if ($Profiles.Count -eq 0) {
    Write-Host "No Zen profiles found." -ForegroundColor Red
    Write-Host "Checked: $($PathsToCheck -join ', ')"
    Pause
    Exit
}

# Simple selection
$i = 1
foreach ($p in $Profiles) {
    Write-Host "[$i] $($p.Name)"
    $i++
}

$Selection = Read-Host "Select [1]"
if ([string]::IsNullOrWhiteSpace($Selection)) { $Selection = 1 }

try {
    $Target = $Profiles[$Selection - 1]
} catch {
    Write-Host "Invalid selection." -ForegroundColor Red
    Pause
    Exit
}

Write-Host "Backing up: $($Target.Name)" -ForegroundColor Green

if (Test-Path $TempDir) { Remove-Item -Recurse -Force $TempDir }
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

# Essential files
$Files = @("places.sqlite", "cookies.sqlite", "key4.db", "logins.json", "sessionstore.jsonlz4")
foreach ($f in $Files) {
    Copy-Item "$($Target.FullName)\$f" -Destination $TempDir
}

# Configs & Extensions
Copy-Item "$($Target.FullName)\*.json" -Destination $TempDir
if (Test-Path "$($Target.FullName)\extensions") {
    Copy-Item -Recurse "$($Target.FullName)\extensions" -Destination "$TempDir\extensions"
}
if (Test-Path "$($Target.FullName)\chrome") {
    Copy-Item -Recurse "$($Target.FullName)\chrome" -Destination "$TempDir\chrome"
}

# Session (pinned tabs)
if (Test-Path "$($Target.FullName)\sessionstore-backups") {
    Copy-Item -Recurse "$($Target.FullName)\sessionstore-backups" -Destination "$TempDir\sessionstore-backups" 
}

# The Sanitizer
# This prevents the hardcoded C:\Users\Name paths from breaking things on other PCs
if (Test-Path "$($Target.FullName)\prefs.js") {
    $UserJs = "$TempDir\user.js"
    $Content = Get-Content "$($Target.FullName)\prefs.js"
    
    $Filtered = $Content | Where-Object { 
        $_ -notmatch "C:\\\\Users" -and 
        $_ -notmatch "file:///" 
    }
    
    $Filtered | Set-Content $UserJs -Encoding UTF8
    
    # Fix icon rendering
    Add-Content -Path $UserJs -Value "`nuser_pref(`"svg.context-properties.content.enabled`", true);"
    Add-Content -Path $UserJs -Value "user_pref(`"toolkit.legacyUserProfileCustomizations.stylesheets`", true);"
}

# Zip it up
$Stamp = Get-Date -Format "yyyy-MM-dd"
$ZipName = "zen_win_backup_$($Target.Name)_$Stamp.zip"
$Dest = "$BackupRoot\$ZipName"

Write-Host "Compressing..."
Compress-Archive -Path "$TempDir\*" -DestinationPath $Dest -Update

Remove-Item -Recurse -Force $TempDir

Write-Host "Done! Saved to:" -ForegroundColor Cyan
Write-Host $Dest
Write-Host ""
Pause
