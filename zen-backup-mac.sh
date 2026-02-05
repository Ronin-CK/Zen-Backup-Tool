#!/bin/bash

# simple backup for zen on macos
# saves to ~/Backups/ZenBrowser

# backup location
backup_root="$HOME/Backups/ZenBrowser"
mkdir -p "$backup_root"

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
temp_dir="$backup_root/tmp_staging"

# macos standard path
profiles_root="$HOME/Library/Application Support/Zen Browser/Profiles"

# fallback for legacy paths
if [ ! -d "$profiles_root" ]; then
    profiles_root="$HOME/Library/Application Support/zen/Profiles"
fi

if [ ! -d "$profiles_root" ]; then
    echo "Zen profiles not found. Check ~/Library/Application Support/"
    exit 1
fi

# get profiles
# finding only folders with places.sqlite to avoid junk
profiles=()
while IFS= read -r file; do
    profiles+=("$(dirname "$file")")
done < <(find "$profiles_root" -maxdepth 2 -name "places.sqlite" 2>/dev/null)

if [ ${#profiles[@]} -eq 0 ]; then
    echo "No valid profiles found."
    exit 1
fi

echo "Select Profile:"
for i in "${!profiles[@]}"; do
    echo "  [$((i+1))] $(basename "${profiles[$i]}")"
done

read -p "> " choice
choice=${choice:-1}
selected="${profiles[$((choice-1))]}"

[ -d "$selected" ] || { echo "Invalid selection"; exit 1; }

echo "Backing up $(basename "$selected")..."
mkdir -p "$temp_dir"

cp "$selected"/{places.sqlite,cookies.sqlite,key4.db,logins.json} "$temp_dir/" 2>/dev/null

# zen workspace configs
cp "$selected"/*.json "$temp_dir/" 2>/dev/null

# session (pinned tabs etc)
cp "$selected/sessionstore.jsonlz4" "$temp_dir/" 2>/dev/null
[ -d "$selected/sessionstore-backups" ] && cp -R "$selected/sessionstore-backups" "$temp_dir/"

# extensions & themes
[ -d "$selected/extensions" ] && cp -R "$selected/extensions" "$temp_dir/"
[ -d "$selected/chrome" ] && cp -R "$selected/chrome" "$temp_dir/"

# clean up prefs for portability
if [ -f "$selected/prefs.js" ]; then
    dest_user_js="$temp_dir/user.js"
    cp "$selected/prefs.js" "$dest_user_js"
    
    sed -i '' '/\/Users\//d' "$dest_user_js"
    sed -i '' '/file:\/\//d' "$dest_user_js"
    
    echo >> "$dest_user_js"
    echo 'user_pref("svg.context-properties.content.enabled", true);' >> "$dest_user_js"
    echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >> "$dest_user_js"
fi

# zip it
archive_name="zen_backup_$(basename "$selected")_${timestamp}.tar.gz"
tar -czf "$backup_root/$archive_name" -C "$temp_dir" .

rm -rf "$temp_dir"

echo "Done: $backup_root/$archive_name"
open -R "$backup_root/$archive_name"
