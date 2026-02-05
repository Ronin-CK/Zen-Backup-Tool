#!/bin/bash

# generic firefox-fork backup tool

# defaults
opMode="backup"
autoBrowser=""

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -b|--browser)
      case "$2" in
        firefox) autoBrowser="firefox";;
        zen) autoBrowser="zen";;
        librewolf) autoBrowser="librewolf";;
        floorp) autoBrowser="floorp";;
        mercury) autoBrowser="mercury";;
        waterfox) autoBrowser="waterfox";;
      esac
      shift;;
    restore) opMode="restore";;
  esac
  shift
done

# check script name for auto-detection
scriptName=$(basename "$0")
if [ -z "$autoBrowser" ]; then
  [[ "$scriptName" == *"zen"* ]] && autoBrowser="zen"
  [[ "$scriptName" == *"firefox"* ]] && [[ "$scriptName" != *"universal"* ]] && autoBrowser="firefox"
  [[ "$scriptName" == *"librewolf"* ]] && autoBrowser="librewolf"
fi

get_browser_config() {
  local selection=$1
  case $selection in
    1|firefox)
      bName="Firefox"
      searchPaths=("$HOME/.mozilla/firefox" "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox" "$HOME/snap/firefox/common/.mozilla/firefox")
      ;;
    2|zen)
      bName="Zen"
      searchPaths=("$HOME/.zen" "$HOME/.var/app/io.github.zen_browser.zen/.zen" "$HOME/.local/share/zen")
      ;;
    3|librewolf)
      bName="LibreWolf"
      searchPaths=("$HOME/.librewolf" "$HOME/.var/app/io.gitlab.librewolf-community/.librewolf")
      ;;
    4|floorp)
      bName="Floorp"
      searchPaths=("$HOME/.floorp" "$HOME/.var/app/one.ablaze.floorp/.floorp")
      ;;
    5|mercury)
      bName="Mercury"
      searchPaths=("$HOME/.mercury" "$HOME/.var/app/io.gitlab.mercury/.mercury")
      ;;
    6|waterfox)
      bName="Waterfox"
      searchPaths=("$HOME/.waterfox" "$HOME/.var/app/net.waterfox.waterfox/.waterfox")
      ;;
    *)
      echo "Unknown browser selection."
      exit 1
      ;;
  esac
}

if [ -z "$autoBrowser" ]; then
  echo "Select Browser:"

  echo "  1) Firefox"
  echo "  2) Zen Browser"
  echo "  3) LibreWolf"
  echo "  4) Floorp"
  echo "  5) Mercury"
  echo "  6) Waterfox"
  read -p "> " choice
  get_browser_config "$choice"
else
  get_browser_config "$autoBrowser"
fi

# scan for profiles
echo "Scanning for $bName profiles..."
profiles=()
for path in "${searchPaths[@]}"; do
  if [ -d "$path" ]; then
    # find any directory containing places.sqlite
    while IFS= read -r file; do
      profiles+=("$(dirname "$file")")
    done < <(find "$path" -maxdepth 4 -name "places.sqlite" 2>/dev/null)
  fi
done

if [ ${#profiles[@]} -eq 0 ]; then
  echo "No profiles found for $bName. Check installation?"
  exit 1
fi

# let user pick one
list_profiles() {
  local pList=("${!1}")
  for i in "${!pList[@]}"; do
    echo "[$((i+1))] $(basename "${pList[$i]}")"
  done
}

list_profiles profiles[@]
read -p "Select Profile [1]: " pIndex
pIndex=${pIndex:-1}
selectedProfile="${profiles[$((pIndex-1))]}"

[ -d "$selectedProfile" ] || { echo "Bad selection"; exit 1; }

# setup paths
backupRoot="$HOME/Backups/$bName"
mkdir -p "$backupRoot"
tempStaging="$backupRoot/tmp_$(date +%s)"

do_backup() {
  echo "Backing up $selectedProfile..."
  mkdir -p "$tempStaging"
  
  # core data
  cp "$selectedProfile"/{places.sqlite,cookies.sqlite,key4.db,logins.json} "$tempStaging/" 2>/dev/null
  
  # optional stuff
  cp "$selectedProfile"/sessionstore.jsonlz4 "$tempStaging/" 2>/dev/null
  [ -d "$selectedProfile/sessionstore-backups" ] && cp -r "$selectedProfile/sessionstore-backups" "$tempStaging/"
  cp "$selectedProfile"/*.json "$tempStaging/" 2>/dev/null
  [ -d "$selectedProfile/extensions" ] && cp -r "$selectedProfile/extensions" "$tempStaging/"
  [ -d "$selectedProfile/chrome" ] && cp -r "$selectedProfile/chrome" "$tempStaging/"
  
  # firefox/zen need these cleaned up or they crash on restore
  if [ -f "$selectedProfile/prefs.js" ]; then
    cp "$selectedProfile/prefs.js" "$tempStaging/user.js"
    # remove local paths
    sed -i '/\/home\//d' "$tempStaging/user.js"
    sed -i '/file:\/\//d' "$tempStaging/user.js"
    echo 'user_pref("svg.context-properties.content.enabled", true);' >> "$tempStaging/user.js"
  fi
  
  tarName="${bName}_$(basename "$selectedProfile")_$(date +%F).tar.gz"
  tar -czf "$backupRoot/$tarName" -C "$tempStaging" .
  
  rm -rf "$tempStaging"
  echo "Saved to $backupRoot/$tarName"
}

do_restore() {
  # list backups
  local backups=("$backupRoot"/*.tar.gz)
  [ -e "${backups[0]}" ] || { echo "No backups found."; exit 1; }
  
  for i in "${!backups[@]}"; do
    echo "[$((i+1))] $(basename "${backups[$i]}")"
  done
  
  read -p "Restore which? " bIndex
  restoreFile="${backups[$((bIndex-1))]}"
  
  echo "Restoring to $selectedProfile"
  echo "WARNING: Overwriting files."
  read -p "Unpack? [y/N] " confirm
  [[ "$confirm" =~ ^[Yy] ]] || exit 0
  
  tar -xzf "$restoreFile" -C "$selectedProfile"
  echo "Done."
}

else
  do_backup
fi

read -t 5 -p "Done. Closing in 5s..."
