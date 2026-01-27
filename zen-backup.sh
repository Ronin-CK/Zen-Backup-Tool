#!/bin/bash
# ==============================================================================
# ZEN BROWSER BACKUP TOOL
# ==============================================================================

BACKUP_ROOT="$HOME/Backups/ZenBrowser"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
TEMP_DIR="$BACKUP_ROOT/temp_staging"

# Text Colors
RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

pause_and_exit() {
    echo -e "\nPress Enter to exit..."
    read
    exit $1
}

# Header
clear
echo -e "${BLUE}========================================${RESET}"
echo -e "${BOLD}   ZEN BROWSER BACKUP TOOL   ${RESET}"
echo -e "${BLUE}========================================${RESET}"

# 1. DETECT PROFILES
# ------------------
# Scans common Linux locations for Zen profiles
POSSIBLE_SEARCH_PATHS=(
    "$HOME/.zen"
    "$HOME/.var/app/io.github.zen_browser.zen/.zen"
    "$HOME/.local/share/zen"
    "$HOME/.mozilla/zen"
    "$HOME/snap/zen/common/.zen"
)
PROFILE_PATHS=$(find "${POSSIBLE_SEARCH_PATHS[@]}" -maxdepth 4 -name "places.sqlite" 2>/dev/null | sed 's|/places.sqlite||')
IFS=$'\n' read -rd '' -a PROFILES <<< "$PROFILE_PATHS"

if [ ${#PROFILES[@]} -eq 0 ]; then
    echo -e "${RED}❌ Error: No Zen profiles found!${RESET}"
    echo -e "   Checked locations:"
    for path in "${POSSIBLE_SEARCH_PATHS[@]}"; do
        echo -e "   - $path"
    done
    pause_and_exit 1
fi

# 2. USER SELECTION
# -----------------
echo -e "${GREEN}Found ${#PROFILES[@]} profile(s):${RESET}"
i=1
for p in "${PROFILES[@]}"; do
    echo "  [$i] $(basename "$p")"
    ((i++))
done
echo "  [M] Manually enter path"

echo ""
read -p "Select profile [1-${#PROFILES[@]}] or 'M': " CHOICE

# Handle Manual Selection
if [[ "$CHOICE" == "M" || "$CHOICE" == "m" ]]; then
    echo -e "\nEnter the full path to your Zen profile folder:"
    read -e -p "Path: " MANUAL_PATH
    
    # Validate manual path
    if [ ! -d "$MANUAL_PATH" ]; then
        echo -e "${RED}❌ Error: Directory does not exist!${RESET}"
        pause_and_exit 1
    fi
    if [ ! -f "$MANUAL_PATH/places.sqlite" ]; then
        echo -e "${RED}⚠️  Warning: This doesn't look like a standard profile (missing places.sqlite).${RESET}"
        echo -e "   We will try to proceed anyway..."
    fi
    
    SELECTED_PROFILE="$MANUAL_PATH"

# Handle Numeric Selection
elif [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le ${#PROFILES[@]} ]; then
    SELECTED_PROFILE="${PROFILES[$((CHOICE-1))]}"
else
    echo -e "${RED}❌ Invalid selection.${RESET}"; pause_and_exit 1
fi
ARCHIVE_NAME="zen_backup_$(basename "$SELECTED_PROFILE")_${DATE}.tar.gz"

# 3. START BACKUP
# ---------------
mkdir -p "$TEMP_DIR"
echo -e "\n${BLUE}📂 Processing: $SELECTED_PROFILE${RESET}"

# --- Step A: Essential Data ---
echo "   • Copying Data (History, Passwords, Cookies)..."
cp "$SELECTED_PROFILE/places.sqlite" "$TEMP_DIR/" 2>/dev/null
cp "$SELECTED_PROFILE/cookies.sqlite" "$TEMP_DIR/" 2>/dev/null
cp "$SELECTED_PROFILE/favicons.sqlite" "$TEMP_DIR/" 2>/dev/null
cp "$SELECTED_PROFILE/key4.db" "$TEMP_DIR/" 2>/dev/null
cp "$SELECTED_PROFILE/logins.json" "$TEMP_DIR/" 2>/dev/null
cp "$SELECTED_PROFILE/pkcs11.txt" "$TEMP_DIR/" 2>/dev/null

# --- Step A.5: Zen 1.18+ Compatibility ---
# Zen 1.18 moved Sidebar/Workspace data to JSON files.
# We copy ALL root JSONs to be safe (includes handlers, containers, etc.)
echo "   • Copying Configs (Ensures 1.18+ Sidebar support)..."
cp "$SELECTED_PROFILE/"*.json "$TEMP_DIR/" 2>/dev/null

# --- Step B: Session ---
echo "   • Copying Session (Tabs & Windows)..."
cp "$SELECTED_PROFILE/sessionstore.jsonlz4" "$TEMP_DIR/" 2>/dev/null
if [ -d "$SELECTED_PROFILE/sessionstore-backups" ]; then cp -r "$SELECTED_PROFILE/sessionstore-backups" "$TEMP_DIR/"; fi

# --- Step C: Extensions ---
echo "   • Copying Extensions..."
if [ -d "$SELECTED_PROFILE/extensions" ]; then cp -r "$SELECTED_PROFILE/extensions" "$TEMP_DIR/"; fi
cp "$SELECTED_PROFILE/extensions.json" "$TEMP_DIR/" 2>/dev/null
cp "$SELECTED_PROFILE/extension-preferences.json" "$TEMP_DIR/" 2>/dev/null
cp "$SELECTED_PROFILE/extension-settings.json" "$TEMP_DIR/" 2>/dev/null

# --- Step D: Visuals (Intelligent Check) ---
echo "   • Checking for Visual Mods..."
if [ -d "$SELECTED_PROFILE/chrome" ]; then
    cp -r "$SELECTED_PROFILE/chrome" "$TEMP_DIR/"

    # Identify what we found for the user
    if [ -f "$SELECTED_PROFILE/chrome/userChrome.css" ]; then
        echo "     -> Found 'userChrome.css' (Styles backed up)."
    elif [ -d "$SELECTED_PROFILE/chrome/sine" ]; then
        echo "     -> Found 'Sine Mod' (Theme backed up)."
    else
        echo "     -> Found chrome folder (Backed up)."
    fi
else
    echo "     -> No visual mods found (Skipping)."
fi
cp "$SELECTED_PROFILE/xulstore.json" "$TEMP_DIR/" 2>/dev/null

# --- Step E: Settings (The "Sanitizer") ---
echo "   • 🧠 Cleaning Settings (Removing unnecessary things)..."

if [ -f "$SELECTED_PROFILE/prefs.js" ]; then
    # Copy full settings to user.js (Zen loads this on startup)
    cp "$SELECTED_PROFILE/prefs.js" "$TEMP_DIR/user.js"

    # 1. Remove absolute file paths (Fixes Crashes on restore)
    sed -i '/\/home\//d' "$TEMP_DIR/user.js"
    sed -i '/file:\/\//d' "$TEMP_DIR/user.js"

    # 2. Remove broken icon settings (Fixes Sine/Icon issues)
    sed -i '/svg.context-properties.content.enabled/d' "$TEMP_DIR/user.js"
    sed -i '/toolkit.legacyUserProfileCustomizations.stylesheets/d' "$TEMP_DIR/user.js"
fi

# Inject The Icon Fix (Guarantees mods work)
echo "" >> "$TEMP_DIR/user.js"
echo '// AUTO-INJECTED FIX: Force Visuals & Icons' >> "$TEMP_DIR/user.js"
echo 'user_pref("svg.context-properties.content.enabled", true);' >> "$TEMP_DIR/user.js"
echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >> "$TEMP_DIR/user.js"

# 4. COMPRESSION & CLEANUP
# ------------------------
echo -e "\n${BOLD}📦 Compressing archive...${RESET}"
tar -czf "$BACKUP_ROOT/$ARCHIVE_NAME" -C "$TEMP_DIR" .
rm -rf "$TEMP_DIR"

# 5. SUMMARY & INSTRUCTIONS
# -------------------------
echo -e "${BLUE}========================================${RESET}"
echo -e "${GREEN}✅ BACKUP SUCCESSFUL!${RESET}"
echo -e "   File: ${BOLD}$BACKUP_ROOT/$ARCHIVE_NAME${RESET}"
echo -e "${BLUE}========================================${RESET}"

echo -e "\n${BOLD}📝 HOW TO RESTORE:${RESET}"
echo -e "2. Extract this archive into ${BLUE}$HOME/.zen${RESET}."
echo -e "3. Open Zen -> Go to ${BOLD}about:profiles${RESET} -> Create New Profile."
echo -e "4. Select the folder you just created."

echo -e "\e[34m----------------------------------------\e[0m"

echo -e "\e[1m\e[36m   ✨  Backup secure. Go break your \e[31mBROWSER\e[36m.  ✨\e[0m"
echo -e "\e[34m----------------------------------------\e[0m"

pause_and_exit 0
