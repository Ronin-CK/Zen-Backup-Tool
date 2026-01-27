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
echo -e "${BOLD}   ZEN BROWSER BACKUP & RESTORE   ${RESET}"
echo -e "${BLUE}========================================${RESET}"

# Shared: Detect Profiles Function
detect_profiles() {
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
}

# 1. BACKUP FUNCTION
perform_backup() {
    detect_profiles
    detect_step_logic "BACKUP"
    
    ARCHIVE_NAME="zen_backup_$(basename "$SELECTED_PROFILE")_${DATE}.tar.gz"
    
    # START BACKUP
    mkdir -p "$TEMP_DIR"
    echo -e "\n${BLUE}📂 Processing Backup for: $SELECTED_PROFILE${RESET}"
    
    # ... (Rest of Copy Logic will be below) ...


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

    if [ -f "$BACKUP_ROOT/$ARCHIVE_NAME" ]; then
        echo ""
        read -p "Do you want to restore this backup to a profile now? [y/N]: " RESTORE_NOW
        if [[ "$RESTORE_NOW" =~ ^[Yy]$ ]]; then
            perform_restore "$BACKUP_ROOT/$ARCHIVE_NAME"
        fi
    fi

    echo -e "\n${BOLD}📝 HOW TO RESTORE:${RESET}"
    echo -e "   Run this script again and select '[2] Restore'"
    echo -e "\e[34m----------------------------------------\e[0m"
}

# 2. RESTORE FUNCTION
perform_restore() {
    PRE_SELECTED_BACKUP=$1
    echo -e "\n${BLUE}=== RESTORE MODE ===${RESET}"
    
    if [ -n "$PRE_SELECTED_BACKUP" ] && [ -f "$PRE_SELECTED_BACKUP" ]; then
        SELECTED_BACKUP="$PRE_SELECTED_BACKUP"
        echo -e "👉 Using pre-selected backup: ${BLUE}$(basename "$SELECTED_BACKUP")${RESET}"
    else
        # 1. Find Backups
        BACKUPS=("$BACKUP_ROOT"/*.tar.gz)
        if [ ! -e "${BACKUPS[0]}" ]; then
            echo -e "${RED}❌ No backups found in $BACKUP_ROOT${RESET}"
            pause_and_exit 1
        fi
        
        echo -e "${GREEN}Available Backups:${RESET}"
        j=1
        for b in "${BACKUPS[@]}"; do
            echo "  [$j] $(basename "$b")"
            ((j++))
        done
        
        echo ""
        read -p "Select backup to restore [1-${#BACKUPS[@]}]: " B_CHOICE
        if ! [[ "$B_CHOICE" =~ ^[0-9]+$ ]] || [ "$B_CHOICE" -lt 1 ] || [ "$B_CHOICE" -gt ${#BACKUPS[@]} ]; then
            echo -e "${RED}❌ Invalid selection.${RESET}"; pause_and_exit 1
        fi
        SELECTED_BACKUP="${BACKUPS[$((B_CHOICE-1))]}"
    fi
    
    # 2. Select Target Profile
    echo -e "\n${YELLOW}Select TARGET Profile to overwrite:${RESET}"
    detect_profiles
    detect_step_logic "RESTORE_TARGET"
    
    # 3. Confirmation
    echo -e "\n${RED}${BOLD}⚠️  WARNING: OVERWRITE ACTION ⚠️${RESET}"
    echo -e "You are about to extract:"
    echo -e "   ${BLUE}$(basename "$SELECTED_BACKUP")${RESET}"
    echo -e "INTO:"
    echo -e "   ${RED}$SELECTED_PROFILE${RESET}"
    echo -e "Existing files (bookmarks, session, styles) will be REPLACED."
    echo -e "The folder itself is NOT deleted, only conflicting files are overwritten."
    
    echo ""
    read -p "Type 'y' to confirm: " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        echo "Cancelled."; pause_and_exit 0
    fi
    
    # 4. Do it
    echo -e "\n${CYAN}⏳ Extracting backup...${RESET}"
    tar -xzf "$SELECTED_BACKUP" -C "$SELECTED_PROFILE"
    
    echo -e "${GREEN}✅ Restore Complete!${RESET}"
    echo -e "Please restart Zen Browser."
}

# Shared Step Logic (Selection)
detect_step_logic() {
    MODE=$1
    if [ ${#PROFILES[@]} -eq 0 ]; then
        echo -e "${RED}❌ Error: No Zen profiles found!${RESET}"
        echo -e "   Checked locations:"
        for path in "${POSSIBLE_SEARCH_PATHS[@]}"; do
            echo -e "   - $path"
        done
        pause_and_exit 1
    fi

    echo -e "${GREEN}Found ${#PROFILES[@]} profile(s):${RESET}"
    i=1
    for p in "${PROFILES[@]}"; do
        echo "  [$i] $(basename "$p")"
        ((i++))
    done
    echo "  [M] Manually enter path"

    echo ""
    read -p "Select $MODE profile [1-${#PROFILES[@]}] or 'M': " CHOICE
    
    if [[ "$CHOICE" == "M" || "$CHOICE" == "m" ]]; then
        echo -e "\nEnter the full path to your Zen profile folder:"
        read -e -p "Path: " MANUAL_PATH
        if [ ! -d "$MANUAL_PATH" ]; then
            echo -e "${RED}❌ Error: Directory does not exist!${RESET}"
            pause_and_exit 1
        fi
        SELECTED_PROFILE="$MANUAL_PATH"
    elif [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le ${#PROFILES[@]} ]; then
        SELECTED_PROFILE="${PROFILES[$((CHOICE-1))]}"
    else
        echo -e "${RED}❌ Invalid selection.${RESET}"; pause_and_exit 1
    fi
}

# MAIN MENU
echo -e "Choose Operation:"
echo -e "  [1] Backup"
echo -e "  [2] Restore"
read -p "Select [1-2]: " OP
case $OP in
    1) perform_backup ;;
    2) perform_restore ;;
    *) echo "Invalid"; exit 1 ;;
esac

echo -e "\e[34m----------------------------------------\e[0m"

echo -e "\e[1m\e[36m   ✨  Backup secure. Go break your \e[31mBROWSER\e[36m.  ✨\e[0m"
echo -e "\e[34m----------------------------------------\e[0m"

pause_and_exit 0
