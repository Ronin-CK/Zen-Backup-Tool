#!/bin/bash
# ==============================================================================
# UNIVERSAL FIREFOX-FORK BACKUP TOOL
# ==============================================================================

# Text Colors
RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
CYAN="\e[36m"
YELLOW="\e[33m"
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
echo -e "${BOLD}   🦊 UNIVERSAL BROWSER BACKUP   ${RESET}"
echo -e "${BLUE}========================================${RESET}"

# 1. BROWSER SELECTION
# --------------------
echo -e "Which browser are you backing up?"
echo -e "  [1] Firefox"
echo -e "  [2] Zen Browser"
echo -e "  [3] LibreWolf"
echo -e "  [4] Floorp"
echo -e "  [5] Mercury"
echo -e "  [6] Waterfox"
echo -e "  [7] Custom Path"
echo ""
read -p "Select [1-7]: " BROWSER_CHOICE

BROWSER_NAME="Browser"
TARGET_PATHS=""

case $BROWSER_CHOICE in
    1)
        BROWSER_NAME="Firefox"
        TARGET_PATHS="$HOME/.mozilla/firefox $HOME/.var/app/org.mozilla.firefox/.mozilla/firefox $HOME/snap/firefox/common/.mozilla/firefox" ;;
    2)
        BROWSER_NAME="Zen"
        TARGET_PATHS="$HOME/.zen $HOME/.var/app/io.github.zen_browser.zen/.zen" ;;
    3)
        BROWSER_NAME="LibreWolf"
        TARGET_PATHS="$HOME/.librewolf $HOME/.var/app/io.gitlab.librewolf-community/.librewolf" ;;
    4)
        BROWSER_NAME="Floorp"
        TARGET_PATHS="$HOME/.floorp $HOME/.var/app/one.ablaze.floorp/.floorp" ;;
    5)
        BROWSER_NAME="Mercury"
        TARGET_PATHS="$HOME/.mercury $HOME/.var/app/io.gitlab.mercury/.mercury" ;;
    6)
        BROWSER_NAME="Waterfox"
        TARGET_PATHS="$HOME/.waterfox $HOME/.var/app/net.waterfox.waterfox/.waterfox" ;;
    7)
        read -p "Enter full path to config folder (parent of profile folder): " CUSTOM_PATH
        TARGET_PATHS="$CUSTOM_PATH"
        BROWSER_NAME="Custom" ;;
    *)
        echo -e "${RED}❌ Invalid selection.${RESET}"; pause_and_exit 1 ;;
esac

BACKUP_ROOT="$HOME/Backups/$BROWSER_NAME"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
TEMP_DIR="$BACKUP_ROOT/temp_staging"

# 2. DETECT PROFILES (Restored Depth to 4)
# ------------------
echo -e "\n${BLUE}🔍 Scanning for $BROWSER_NAME profiles...${RESET}"

# Build a list of existing directories from the target paths
EXISTING_PATHS=()
for path in $TARGET_PATHS; do
    if [ -d "$path" ]; then
        EXISTING_PATHS+=("$path")
    fi
done

if [ ${#EXISTING_PATHS[@]} -eq 0 ]; then
    echo -e "${RED}❌ Error: No config directories found for $BROWSER_NAME.${RESET}"
    pause_and_exit 1
fi

# Search for places.sqlite (Indicator of a valid profile) with MAXDEPTH 4
PROFILE_PATHS=$(find "${EXISTING_PATHS[@]}" -maxdepth 4 -name "places.sqlite" 2>/dev/null | sed 's|/places.sqlite||')
IFS=$'\n' read -rd '' -a PROFILES <<< "$PROFILE_PATHS"

if [ ${#PROFILES[@]} -eq 0 ] || [ -z "$PROFILE_PATHS" ]; then
    echo -e "${RED}❌ Error: No valid profiles found inside:${RESET}"
    printf "   %s\n" "${EXISTING_PATHS[@]}"
    pause_and_exit 1
fi

# 3. SELECT PROFILE
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

if [[ "$CHOICE" == "M" || "$CHOICE" == "m" ]]; then
    echo -e "\nEnter the full path to your profile folder:"
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
ARCHIVE_NAME="${BROWSER_NAME}_backup_$(basename "$SELECTED_PROFILE")_${DATE}.tar.gz"

# 4. START BACKUP (Matches uploaded file logic)
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

# --- Step A.5: New Configs (Zen 1.18+ / Modern Firefox) ---
echo "   • Copying Configs (*.json)..."
cp "$SELECTED_PROFILE/"*.json "$TEMP_DIR/" 2>/dev/null

# --- Step B: Session ---
echo "   • Copying Session..."
cp "$SELECTED_PROFILE/sessionstore.jsonlz4" "$TEMP_DIR/" 2>/dev/null
if [ -d "$SELECTED_PROFILE/sessionstore-backups" ]; then cp -r "$SELECTED_PROFILE/sessionstore-backups" "$TEMP_DIR/"; fi

# --- Step C: Extensions ---
echo "   • Copying Extensions..."
if [ -d "$SELECTED_PROFILE/extensions" ]; then cp -r "$SELECTED_PROFILE/extensions" "$TEMP_DIR/"; fi
cp "$SELECTED_PROFILE/extensions.json" "$TEMP_DIR/" 2>/dev/null
cp "$SELECTED_PROFILE/extension-preferences.json" "$TEMP_DIR/" 2>/dev/null
cp "$SELECTED_PROFILE/extension-settings.json" "$TEMP_DIR/" 2>/dev/null

# --- Step D: Visuals ---
echo "   • Checking for Visual Mods..."
if [ -d "$SELECTED_PROFILE/chrome" ]; then
    cp -r "$SELECTED_PROFILE/chrome" "$TEMP_DIR/"
    echo "     -> Found chrome folder (Backed up)."
else
    echo "     -> No visual mods found."
fi
cp "$SELECTED_PROFILE/xulstore.json" "$TEMP_DIR/" 2>/dev/null

# --- Step E: Settings (Sanitization) ---
echo "   • 🧠 Cleaning Settings..."

if [ -f "$SELECTED_PROFILE/prefs.js" ]; then
    # Copy full settings to user.js (Firefox/Zen loads this on startup)
    cp "$SELECTED_PROFILE/prefs.js" "$TEMP_DIR/user.js"

    # 1. Remove absolute file paths (Fixes restore crashes)
    sed -i '/\/home\//d' "$TEMP_DIR/user.js"
    sed -i '/file:\/\//d' "$TEMP_DIR/user.js"

    # 2. Remove broken icon settings
    sed -i '/svg.context-properties.content.enabled/d' "$TEMP_DIR/user.js"
    sed -i '/toolkit.legacyUserProfileCustomizations.stylesheets/d' "$TEMP_DIR/user.js"
fi

# Inject Standard Fixes (Ensures themes work on restore)
echo "" >> "$TEMP_DIR/user.js"
echo '// AUTO-INJECTED FIX' >> "$TEMP_DIR/user.js"
echo 'user_pref("svg.context-properties.content.enabled", true);' >> "$TEMP_DIR/user.js"
echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >> "$TEMP_DIR/user.js"

# 5. COMPRESS
# -----------
echo -e "\n${BOLD}📦 Compressing archive...${RESET}"
tar -czf "$BACKUP_ROOT/$ARCHIVE_NAME" -C "$TEMP_DIR" .
rm -rf "$TEMP_DIR"

# 6. SUMMARY
# ----------
echo -e "${BLUE}========================================${RESET}"
echo -e "${GREEN}✅ BACKUP SUCCESSFUL!${RESET}"
echo -e "   File: ${BOLD}$BACKUP_ROOT/$ARCHIVE_NAME${RESET}"
echo -e "${BLUE}========================================${RESET}"

pause_and_exit 0
