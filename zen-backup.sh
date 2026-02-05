#!/bin/bash

# backup location
zenBackupDir="$HOME/Backups/ZenBrowser"
staging="$zenBackupDir/temp_staging"
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")

# colors
GREEN="\e[32m"
BLUE="\e[34m"
RESET="\e[0m"

# check if zen is installed
search_paths=(
    "$HOME/.zen"
    "$HOME/.var/app/io.github.zen_browser.zen/.zen"
    "$HOME/.local/share/zen"
)

# find profiles that actually have history (places.sqlite)
profiles=$(find "${search_paths[@]}" -maxdepth 4 -name "places.sqlite" 2>/dev/null | sed 's|/places.sqlite||')

if [ -z "$profiles" ]; then
    echo "No Zen profiles found. Is it installed?"
    exit 1
fi

# ----------------------------
# BACKUP
# ----------------------------
do_backup() {
    # simple menu if multiple exist
    echo -e "${BLUE}Found profiles:${RESET}"
    IFS=$'\n' read -rd '' -a profArray <<< "$profiles"
    
    i=1
    for p in "${profArray[@]}"; do
        echo "[$i] $(basename "$p")"
        ((i++))
    done

    # default to 1
    read -p "Select [1]: " choice
    choice=${choice:-1}
    
    selected="${profArray[$((choice-1))]}"
    [ -d "$selected" ] || { echo "Invalid selection"; exit 1; }

    # make sure we have a place to put it
    mkdir -p "$staging"

    echo "Backing up: $selected"

    # copy the important database files
    # we ignore errors here mainly because key4.db might be locked if browser is open
    cp "$selected"/{places.sqlite,cookies.sqlite,favicons.sqlite,key4.db,logins.json} "$staging/" 2>/dev/null

    # zen 1.18+ started putting workspace configs in json files
    # grabbing all of them to be safe
    cp "$selected"/*.json "$staging/" 2>/dev/null

    # sessionstore is lz4 compressed, just grab it
    cp "$selected/sessionstore.jsonlz4" "$staging/" 2>/dev/null
    [ -d "$selected/sessionstore-backups" ] && cp -r "$selected/sessionstore-backups" "$staging/"
    
    # grab extensions if they exist
    [ -d "$selected/extensions" ] && cp -r "$selected/extensions" "$staging/"

    # CSS mods (chrome folder)
    # this is where the custom themes live
    if [ -d "$selected/chrome" ]; then
        cp -r "$selected/chrome" "$staging/"
        echo "  -> Backed up chrome folder (themes/mods)"
    fi

    # SANITIZATION
    if [ -f "$selected/prefs.js" ]; then
        cp "$selected/prefs.js" "$staging/user.js"
        
        # remove absolute paths to fix restore crashes
        sed -i '/\/home\//d' "$staging/user.js"
        sed -i '/file:\/\//d' "$staging/user.js"
        
        # force enable SVG context properties or icons break on restore
        echo 'user_pref("svg.context-properties.content.enabled", true);' >> "$staging/user.js"
        echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >> "$staging/user.js"
    fi

    # tar it up
    archiveName="zen_backup_$(basename "$selected")_${timestamp}.tar.gz"
    
    tar -czf "$zenBackupDir/$archiveName" -C "$staging" .
    
    # cleanup
    rm -rf "$staging"
    
    echo -e "${GREEN}Done. Saved to: $zenBackupDir/$archiveName${RESET}"
}

# ----------------------------
# RESTORE
# ----------------------------
do_restore() {
    # check if we even have backups
    backups=("$zenBackupDir"/*.tar.gz)
    
    if [ ! -e "${backups[0]}" ]; then
        echo "No backups found in $zenBackupDir"
        exit 1
    fi

    echo -e "${BLUE}Select Backup:${RESET}"
    j=1
    for b in "${backups[@]}"; do
        echo "[$j] $(basename "$b")"
        ((j++))
    done

    read -p "Which one? " b_choice
    selected_backup="${backups[$((b_choice-1))]}"

    echo -e "${BLUE}Select Target Profile (this will be OVERWRITTEN):${RESET}"
    # reuse the profile logic
    IFS=$'\n' read -rd '' -a profArray <<< "$profiles"
    k=1
    for p in "${profArray[@]}"; do
        echo "[$k] $(basename "$p")"
        ((k++))
    done
    read -p "Target: " p_choice
    target_profile="${profArray[$((p_choice-1))]}"

    echo -e "${GREEN}Restoring $(basename "$selected_backup") -> $target_profile${RESET}"
    read -p "Are you sure? This will overwrite files. [y/N] " confirm
    [[ "$confirm" =~ ^[Yy] ]] || exit 0

    tar -xzf "$selected_backup" -C "$target_profile"
    echo "Restored. Restart Zen."
}

# super simple arg parsing
case "$1" in
    restore)
        do_restore
        ;;
    *)
        echo "1) Backup"
        echo "2) Restore"
        read -p "> " action
        case $action in
            2) do_restore ;;
            *) do_backup ;;
        esac
        ;;
esac

read -t 5 -p "Auto-closing in 5s... (Press enter to close now)"
