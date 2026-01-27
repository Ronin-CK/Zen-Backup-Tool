<#
.SYNOPSIS
    ZEN BROWSER ULTIMATE BACKUP (Windows Edition)
    "Hopp Destro" Edition - Auto-Fixes Icons & Sanitizes Paths
#>

# 1. SETUP & COLORS
$ErrorActionPreference = "SilentlyContinue"
$BackupRoot = "$HOME\Documents\Backups\ZenBrowser"
$Date = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$TempDir = "$BackupRoot\temp_staging"

function Print-Color ($Text, $Color) { Write-Host $Text -ForegroundColor $Color }
function Print-Section {
    Clear-Host
    Print-Color "========================================" "Cyan"
    Print-Color "   ZEN BROWSER ULTIMATE BACKUP (WIN)    " "White"
    Print-Color "========================================" "Cyan"
}

Print-Section

# 2. DETECT PROFILES
# ------------------
# We check standard locations
$PossiblePaths = @(
    "$env:APPDATA\Zen\Profiles",
    "$env:APPDATA\Zen Browser\Profiles"
)

$Profiles = @()
foreach ($path in $PossiblePaths) {
    if (Test-Path $path) {
        $found = Get-ChildItem -Path $path -Directory | Where-Object { Test-Path "$($_.FullName)\places.sqlite" }
        if ($found) { $Profiles += $found }
    }
}

if ($Profiles.Count -eq 0) {
    Print-Color "❌ Error: No Zen profiles found!" "Red"
    # We don't exit here anymore, we offer manual entry in the next step
}

# 3. USER SELECTION (Always Ask)
# ------------------------------
Print-Color "Found $($Profiles.Count) profile(s):" "Green"
$i = 1
foreach ($p in $Profiles) {
    Write-Host "  [$i] $($p.Name)"
    $i++
}
Write-Host "  [M] Manually enter path"

Write-Host ""
$InputVal = Read-Host "Select profile [1-$($Profiles.Count)] or 'M'"

# Handle Manual Entry
if ($InputVal -eq "M" -or $InputVal -eq "m") {
    $ManualPath = Read-Host "Enter full path to profile folder"
    if (-not (Test-Path $ManualPath)) { Print-Color "❌ Directory not found!" "Red"; Pause; Exit }
    
    # Fake a profile object
    $SelectedProfile = [PSCustomObject]@{
        Name = (Split-Path $ManualPath -Leaf)
        FullName = $ManualPath
    }
}
# Handle Numeric Selection
elseif ($InputVal -match "^\d+$" -and $InputVal -ge 1 -and $InputVal -le $Profiles.Count) {
    $SelectedProfile = $Profiles[$InputVal - 1]
}
else {
    Print-Color "❌ Invalid selection." "Red"; Pause; Exit
}
$ArchiveName = "zen_win_backup_$($SelectedProfile.Name)_$Date.zip"

# 4. START BACKUP
# ---------------
if (Test-Path $TempDir) { Remove-Item -Recurse -Force $TempDir }
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
Print-Color "`n📂 Processing: $($SelectedProfile.Name)" "Cyan"

# --- Step A: Essential Data ---
Write-Host "   • Copying Data (History, Passwords, Cookies)..."
$FilesToCopy = @("places.sqlite", "cookies.sqlite", "favicons.sqlite", "key4.db", "logins.json", "pkcs11.txt", "sessionstore.jsonlz4", "extensions.json", "extension-settings.json")

# --- Step A.5: Zen 1.18+ Compatibility (JSONs) ---
# Copy all .json files from root to ensure sidebar/workspace config is saved
Get-ChildItem -Path $SelectedProfile.FullName -Filter "*.json" | ForEach-Object {
    Copy-Item $_.FullName -Destination $TempDir
}

foreach ($file in $FilesToCopy) {
    Copy-Item "$($SelectedProfile.FullName)\$file" -Destination $TempDir
}

# --- Step B: Session ---
Write-Host "   • Copying Session..."
if (Test-Path "$($SelectedProfile.FullName)\sessionstore-backups") {
    Copy-Item -Recurse "$($SelectedProfile.FullName)\sessionstore-backups" -Destination "$TempDir\sessionstore-backups"
}

# --- Step C: Extensions ---
Write-Host "   • Copying Extensions..."
if (Test-Path "$($SelectedProfile.FullName)\extensions") {
    Copy-Item -Recurse "$($SelectedProfile.FullName)\extensions" -Destination "$TempDir\extensions"
}

# --- Step D: Visuals (Intelligent Check) ---
Write-Host "   • Checking for Visual Mods..."
if (Test-Path "$($SelectedProfile.FullName)\chrome") {
    Copy-Item -Recurse "$($SelectedProfile.FullName)\chrome" -Destination "$TempDir\chrome"
    
    if (Test-Path "$($SelectedProfile.FullName)\chrome\userChrome.css") {
        Write-Host "     -> Found 'userChrome.css' (Styles backed up)."
    } elseif (Test-Path "$($SelectedProfile.FullName)\chrome\sine") {
        Write-Host "     -> Found 'Sine Mod' (Theme backed up)."
    } else {
        Write-Host "     -> Found chrome folder (Backed up)."
    }
} else {
    Write-Host "     -> No visual mods found (Skipping)."
}
Copy-Item "$($SelectedProfile.FullName)\xulstore.json" -Destination $TempDir

# --- Step E: Settings (The Safe Sanitizer) ---
Write-Host "   • 🧠 Cleaning Settings (Removing unnecessary things)..."

if (Test-Path "$($SelectedProfile.FullName)\prefs.js") {
    $PrefsPath = "$TempDir\user.js"
    
    # Read Content
    $Content = Get-Content "$($SelectedProfile.FullName)\prefs.js"

    # Filter out lines (Delete C:\ paths and broken icon settings)
    $CleanContent = $Content | Where-Object { 
        $_ -notmatch "C:\\\\Users" -and 
        $_ -notmatch "file:///" -and 
        $_ -notmatch "svg.context-properties.content.enabled" -and
        $_ -notmatch "toolkit.legacyUserProfileCustomizations.stylesheets"
    }

    # 1. Save cleaned content
    $CleanContent | Set-Content $PrefsPath -Encoding UTF8

    # 2. Append the FIX using a Safe Text Block (No Quote Errors)
    $FixBlock = @"

// AUTO-INJECTED FIX: Force Visuals & Icons
user_pref("svg.context-properties.content.enabled", true);
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
"@

    Add-Content -Path $PrefsPath -Value $FixBlock
}

# 5. COMPRESS (ZIP)
# -----------------
Print-Color "`n📦 Compressing to ZIP..." "White"
$ZipPath = "$BackupRoot\$ArchiveName"
Compress-Archive -Path "$TempDir\*" -DestinationPath $ZipPath -Update

# Cleanup
Remove-Item -Recurse -Force $TempDir

# 6. SUMMARY
# ----------
Print-Color "========================================" "Cyan"
Print-Color "✅ BACKUP SUCCESSFUL!" "Green"
Print-Color "   File: $ZipPath" "White"
Print-Color "========================================" "Cyan"

Write-Host "`n📝 HOW TO RESTORE:" -ForegroundColor Yellow
Write-Host "1. Extract ZIP contents to a NEW folder inside:"
Print-Color "   %APPDATA%\Zen\Profiles\" "Cyan"
Write-Host "2. Open Zen -> about:profiles -> Create New Profile."
Write-Host "3. Select that folder."

Print-Color "   ✨  Backup secure. Go break your BROWSER.  ✨" "Cyan"
Write-Host ""
Pause
