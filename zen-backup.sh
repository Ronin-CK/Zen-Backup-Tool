#!/bin/bash

# backup location
zenBackupDir="$HOME/Backups/ZenBrowser"
staging="$zenBackupDir/temp_staging"
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")

# colors
GREEN="\e[32m"
BLUE="\e[34m"
YELLOW="\e[33m"
RED="\e[31m"
BOLD="\e[1m"
RESET="\e[0m"

# check if zen is installed
search_paths=(
    "$HOME/.zen"
    "$HOME/.var/app/io.github.zen_browser.zen/.zen"
    "$HOME/.var/app/app.zen_browser.zen/zen"
    "$HOME/.config/zen"
    "$HOME/.local/share/zen"
    "$HOME/snap/zen-browser/common/.zen"
)

# find profiles that actually have history (places.sqlite)
profiles_list=$(find "${search_paths[@]}" -maxdepth 4 -name "places.sqlite" 2>/dev/null | sed 's|/places.sqlite||')

# PROFILE SELECTION LOGIC
select_profile() {
    local prompt_msg=$1
    # Handle case where no profiles are found
    if [ -z "$profiles_list" ]; then
        echo -e "${YELLOW}No profiles found automatically.${RESET}" >&2
        read -e -p "Enter full path to Zen profile manually: " manual_path >&2
        manual_path="${manual_path/#\~/$HOME}"
        if [ -d "$manual_path" ] && [ -f "$manual_path/places.sqlite" ]; then
            echo "$manual_path"
            return
        else
            echo -e "${RED}Error: Path invalid or missing places.sqlite.${RESET}" >&2
            exit 1
        fi
    fi

    IFS=$'\n' read -rd '' -a profArray <<< "$profiles_list"
    
    echo -e "${BLUE}${prompt_msg}${RESET}" >&2
    i=1
    for p in "${profArray[@]}"; do
        echo "  [$i] $(basename "$p")" >&2
        ((i++))
    done
    echo "  [m] Enter Manual Path" >&2
    
    read -p "Selection [1]: " choice >&2
    choice=${choice:-1}
    
    if [[ "$choice" == "m" ]]; then
        read -e -p "Enter full path to profile: " manual_path >&2
        manual_path="${manual_path/#\~/$HOME}"
        if [ -d "$manual_path" ] && [ -f "$manual_path/places.sqlite" ]; then
            selected_path="$manual_path"
        else
            echo -e "${RED}Error: Path invalid or missing places.sqlite.${RESET}" >&2
            exit 1
        fi
    else
        selected_path="${profArray[$((choice-1))]}"
    fi
    
    if [ -z "$selected_path" ] || [ ! -d "$selected_path" ]; then
        echo -e "${RED}Invalid selection.${RESET}" >&2
        exit 1
    fi
    echo "$selected_path"
}

# BACKUP
do_backup() {
    echo -e "${BLUE}${BOLD}--- Zen Browser Backup ---${RESET}"
    
    selected=$(select_profile "Select Profile to Backup:")

    mkdir -p "$staging"
    echo -e "${YELLOW}Backing up: $(basename "$selected")${RESET}"

    # Essential Database Files
    files=(
        "places.sqlite" "cookies.sqlite" "favicons.sqlite" 
        "key4.db" "logins.json" "cert9.db" 
        "permissions.sqlite" "content-prefs.sqlite" "formhistory.sqlite"
    )
    
    for f in "${files[@]}"; do
        [ -f "$selected/$f" ] && cp "$selected/$f" "$staging/"
    done

    # Configs, Sessions & Extension State
    # This covers: zen-themes.json, zen-sessions.jsonlz4, extensions.json, containers.json, etc.
    cp "$selected"/*.{json,jsonlz4,mozlz4,lz4} "$staging/" 2>/dev/null

    # Session store backups
    [ -d "$selected/sessionstore-backups" ] && cp -r "$selected/sessionstore-backups" "$staging/"
    
    # Extensions & Chrome (Themes)
    [ -d "$selected/extensions" ] && cp -r "$selected/extensions" "$staging/"
    [ -d "$selected/storage" ] && cp -r "$selected/storage" "$staging/"
    [ -d "$selected/chrome" ] && cp -r "$selected/chrome" "$staging/"

    # PREFERENCES - Copy as-is to prevent settings reset
    if [ -f "$selected/prefs.js" ]; then
        cp "$selected/prefs.js" "$staging/prefs.js"
        
        {
            echo '// Zen Backup Tool - UI Fixes'
            echo 'user_pref("svg.context-properties.content.enabled", true);'
            echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'
            echo 'user_pref("browser.tabs.allow_css_customization", true);'
        } > "$staging/user.js"
    fi

    # Archive
    archiveName="zen_backup_$(basename "$selected")_${timestamp}.tar.gz"
    tar -czf "$zenBackupDir/$archiveName" -C "$staging" .
    
    rm -rf "$staging"
    echo -e "${GREEN}${BOLD}Success! Backup saved to:${RESET}"
    echo -e "${GREEN}$zenBackupDir/$archiveName${RESET}"
}

# RESTORE
do_restore() {
    echo -e "${BLUE}${BOLD}--- Zen Browser Restore ---${RESET}"
    mkdir -p "$zenBackupDir"

    backups=()
    for item in "$zenBackupDir"/*.tar.gz; do
        [ -e "$item" ] && backups+=("$item")
    done
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${YELLOW}No backups found in $zenBackupDir${RESET}"
        exit 0
    fi

    echo -e "${BLUE}Select Backup:${RESET}"
    j=1
    for b in "${backups[@]}"; do
        echo "  [$j] $(basename "$b")"
        ((j++))
    done
    read -p "Which one? " b_choice
    selected_backup="${backups[$((b_choice-1))]}"

    # Target selection
    target_profile=$(select_profile "Select Target Profile (OVERWRITTEN):")

    echo -e "${YELLOW}Restoring $(basename "$selected_backup") -> $(basename "$target_profile")${RESET}"
    read -p "Are you sure? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy] ]] || exit 0

    # Safety: Close Zen
    if pgrep -x "zen" > /dev/null || pgrep -x "zen-bin" > /dev/null; then
        echo -e "${YELLOW}Closing Zen Browser...${RESET}"
        pkill -x "zen" || pkill -x "zen-bin"
        sleep 2
    fi

    # CLEAN SLATE: Remove old data that causes conflicts
    echo -e "${YELLOW}Cleaning target profile...${RESET}"
    rm -f "$target_profile/sessionstore.jsonlz4"
    rm -f "$target_profile/sessionCheckpoints.json"
    rm -f "$target_profile/xulstore.json"
    rm -f "$target_profile/lock" "$target_profile/.parentlock"
    rm -rf "$target_profile/sessionstore-backups"
    
    # Crucial: Wipe extensions and storage to prevent conflicts
    rm -rf "$target_profile/extensions"
    rm -rf "$target_profile/storage"

    if [[ "$selected_backup" == *.tar.gz ]]; then
        tar -xzvf "$selected_backup" -C "$target_profile"
    else
        cp -rv "$selected_backup"/* "$target_profile/"
    fi

    # Optional Session Recovery
    echo -e "${BLUE}Session Restore Options:${RESET}"
    read -p "Restore open tabs from the backup? [y/N] " restore_tabs
    if [[ "$restore_tabs" =~ ^[Yy] ]]; then
        if [ -f "$target_profile/sessionstore-backups/recovery.jsonlz4" ]; then
            cp "$target_profile/sessionstore-backups/recovery.jsonlz4" "$target_profile/sessionstore.jsonlz4"
            echo -e "${GREEN}  -> Session restored.${RESET}"
        fi
    else
        rm -f "$target_profile/sessionstore.jsonlz4"
        rm -rf "$target_profile/sessionstore-backups"
        echo -e "${YELLOW}  -> Starting with a clean session.${RESET}"
    fi

    echo -e "${GREEN}${BOLD}Restore complete!${RESET}"
}




# RESTORE TO NEW PROFILE
do_restore_new() {
    echo -e "${BLUE}${BOLD}--- Zen Restore to New Profile ---${RESET}"
    mkdir -p "$zenBackupDir"

    backups=()
    for item in "$zenBackupDir"/*.tar.gz; do
        [ -e "$item" ] && backups+=("$item")
    done
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${YELLOW}No backups found.${RESET}"
        exit 0
    fi

    echo -e "${BLUE}Select Backup:${RESET}"
    j=1
    for b in "${backups[@]}"; do
        echo "  [$j] $(basename "$b")"
        ((j++))
    done
    read -p "Which one? " b_choice
    selected_backup="${backups[$((b_choice-1))]}"

    # Find base directory (prefer ~/.zen)
    base_dir="$HOME/.zen"
    [ -d "$base_dir" ] || base_dir=$(dirname "${profArray[0]}")
    [ -d "$base_dir" ] || base_dir="$HOME/.zen" # Fallback

    read -p "Enter name for new profile (e.g. zen-recovered): " new_name
    new_name=${new_name:-"zen-restored-$(date +%s)"}
    target_path="$base_dir/$new_name"

    echo -e "${YELLOW}Creating new profile at: $target_path...${RESET}"
    mkdir -p "$target_path"

    echo -e "${YELLOW}Extracting...${RESET}"
    tar -xzvf "$selected_backup" -C "$target_path"

    # Session Recovery
    if [ ! -f "$target_path/sessionstore.jsonlz4" ]; then
        if [ -f "$target_path/sessionstore-backups/recovery.jsonlz4" ]; then
            cp "$target_path/sessionstore-backups/recovery.jsonlz4" "$target_path/sessionstore.jsonlz4"
        fi
    fi

    echo -e "${GREEN}${BOLD}Success! New profile created.${RESET}"
    echo -e "${BLUE}To launch Zen with this profile, run:${RESET}"
    echo -e "${YELLOW}zen --profile \"$target_path\"${RESET}"
}

# FIX PROFILE (MAINTENANCE)
do_fix() {
    echo -e "${BLUE}${BOLD}--- Zen Profile Maintenance ---${RESET}"
    
    selected=$(select_profile "Select Profile to Fix:")
    
    echo -e "${YELLOW}Fixing Profile: $(basename "$selected")${RESET}"
    echo -e "${YELLOW}This will clear your open tabs and window layouts to fix duplicate windows/crashes.${RESET}"
    read -p "Continue? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy] ]] || exit 0

    # Safety: Close Zen
    if pgrep -x "zen" > /dev/null || pgrep -x "zen-bin" > /dev/null; then
        echo -e "${YELLOW}Closing Zen Browser...${RESET}"
        pkill -x "zen" || pkill -x "zen-bin"
        sleep 2
    fi

    echo -e "${YELLOW}Cleaning layout and session data...${RESET}"
    # xulstore.json: stores window sizes/positions (causes phantom windows)
    # sessionstore.jsonlz4: stores open tabs (causes duplicate windows on launch)
    # .parentlock: prevents browser from opening if it crashed
    rm -f "$selected/xulstore.json"
    rm -f "$selected/sessionstore.jsonlz4"
    rm -f "$selected/sessionCheckpoints.json"
    rm -f "$selected/lock" "$selected/.parentlock"
    rm -rf "$selected/sessionstore-backups"

    echo -e "${GREEN}${BOLD}Done! Profile cleaned. Launch Zen to check.${RESET}"
}

# MAIN
case "$1" in
    restore) do_restore ;;
    backup)  do_backup ;;
    new)     do_restore_new ;;
    fix)     do_fix ;;
    *)
        echo -e "${BLUE}${BOLD}Zen Backup Tool${RESET}"
        echo "1) Backup"
        echo "2) Restore (Overwrite Profile)"
        echo "3) Restore to New Profile"
        echo "4) Fix Profile (Duplicate Windows/Crashes)"
        read -p "Choice [1]: " action
        action=${action:-1}
        case $action in
            2) do_restore ;;
            3) do_restore_new ;;
            4) do_fix ;;
            *) do_backup ;;
        esac
        ;;
esac


read -t 5 -p "Auto-closing in 5s..."
echo ""




