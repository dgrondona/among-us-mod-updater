#!/bin/bash
set -euo pipefail

# Information for downloading from GitHub
OWNER="AU-Avengers"
REPO="TOU-Mira"

# Download must include this string
MATCH="steam-itch"

# The directory where the file is saved
DOWNLOAD_DIR="$HOME/.steam/steam/steamapps/common"

GAME_DIR="$DOWNLOAD_DIR/Among Us"
MOD_DIR="$DOWNLOAD_DIR/toum"
MOD_OLD_DIR="$DOWNLOAD_DIR/toum(old)"
VERSION_FILE="$MOD_DIR/version.txt"

# Colors
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;93m"
NC="\033[0m" # No Color

# Log levels
INFO="\033[1m[INFO]: \033[0m"
WARN="${YELLOW}[WARN]: ${NC}"
ERROR="${RED}[ERROR]: ${NC}"
DONE="${GREEN}[DONE]: ${NC}"

logInfo() { echo -e "${INFO}$1"; }
logWarn() { echo -e "${WARN}$1"; }
logError() { echo -e "${ERROR}$1"; }
logDone() { echo -e "${DONE}$1"; }

# Progress bar
progressBar() {

    # URL and OUTPUT from outside function
    local URL="$1"
    local OUTPUT="$2"

    # Get total size in bytes
    local TOTAL
    TOTAL=$(curl -sI -L "$URL" | grep -i Content-Length | tail -n1 | awk '{print $2}' | tr -d '\r' | xargs || echo 0)
    TOTAL=${TOTAL:-0}

    local BAR_LENGTH=30
    local DOWNLOADED=0
    local PERCENT=0
    local FILLED=0
    local EMPTY=0
    local BAR=""

    # Start download in background
    curl -sL "$URL" -o "$OUTPUT" &
    local CURL_PID=$!

    # Show progress
    while kill -0 $CURL_PID 2>/dev/null; do

        DOWNLOADED=$(stat -c %s "$OUTPUT" 2>/dev/null || echo 0)

        if (( "TOTAL" > 0 )); then

            PERCENT=$(( DOWNLOADED * 100 / TOTAL ))

        else
            PERCENT=0
        fi

        FILLED=$(( PERCENT * BAR_LENGTH / 100 ))
        EMPTY=$(( BAR_LENGTH - FILLED ))
        BAR="$(printf "%*s" "$FILLED" "" | tr ' ' '#')$(printf "%*s" "$EMPTY" "")"

        printf "\r[%-${BAR_LENGTH}s] %3d%%" "$BAR" "$PERCENT"
        sleep 0.2

    done

    # Wait for curl to finish and capture exit code
    wait $CURL_PID
    local STATUS=$?

    # Complete the bar at 100%
    printf "${GREEN}\r[%s] 100%%\n" "$(printf '#%.0s' $(seq 1 $BAR_LENGTH))${NC}"

    if [ $STATUS -ne 0 ]; then
        logError "Download failed!"
        exit 1
    fi

}

# Check if Among Us folder exists
if [ ! -d "$GAME_DIR" ]; then

    logError "Among Us folder not found at $GAME_DIR"
    exit 1

fi

logWarn "Make sure your game has updated before running this!"

# Generate the asset URL
ASSET_URL=$(curl -s \
    "https://api.github.com/repos/$OWNER/$REPO/releases/latest" | \
    jq -r --arg MATCH "$MATCH" '.assets[] | select(.name | contains($MATCH)) | .browser_download_url'
)

# Check if the asset exists
if [ -z "$ASSET_URL" ]; then

    logError "No matching asset found at $OWNER/$REPO/releases/latest!"
    exit 1

fi

# Get filename and latest version from the asset URL
FILENAME=$(basename "$ASSET_URL")
LATEST_VERSION=$(echo "$FILENAME" | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+')

logInfo "Latest mod version: $LATEST_VERSION"

# Check to see if mod needs updating
if [ -d "$MOD_DIR" ] && [ -f "$VERSION_FILE" ]; then

    INSTALLED_VERSION=$(cat "$VERSION_FILE")

    if [ "$INSTALLED_VERSION" == "$LATEST_VERSION" ]; then

        logInfo "Mod is already up to date ($INSTALLED_VERSION)."
        exit 0

    fi

    # Ask user if they want to save a backup
    echo -en "${WARN}"
    read -p "A previous mod version ($INSTALLED_VERSION) exists. Save a backup? [Y/n]: " SAVE_BACKUP
    SAVE_BACKUP=${SAVE_BACKUP,,}  # convert to lowercase

    if [[ "$SAVE_BACKUP" != "n" && "$SAVE_BACKUP" != "no" ]]; then

        # Backup directory with incrementing number if needed
        BACKUP_BASE="$DOWNLOAD_DIR/toum($INSTALLED_VERSION)"
        BACKUP_DIR="$BACKUP_BASE"
        COUNTER=1

        while [ -e "$BACKUP_DIR" ]; do

            BACKUP_DIR="${BACKUP_BASE}_$COUNTER"
            COUNTER=$((COUNTER + 1))

        done

        logInfo "Backing up existing mod to $BACKUP_DIR..."
        mv "$MOD_DIR" "$BACKUP_DIR"

    else

        logInfo "Deleting existing mod..."
        rm -rf "$MOD_DIR"

    fi

elif [ -d "$MOD_DIR" ]; then

    # No version file, but mod exists
    INSTALLED_VERSION="unknown"
    echo -en "${WARN}"
    read -p "A previous mod version exists. Save a backup? [Y/n]: " SAVE_BACKUP
    SAVE_BACKUP=${SAVE_BACKUP,,}

    if [[ "$SAVE_BACKUP" != "n" && "$SAVE_BACKUP" != "no" ]]; then

         # Backup directory with incrementing number if needed
        BACKUP_BASE="$DOWNLOAD_DIR/toum($INSTALLED_VERSION)"
        BACKUP_DIR="$BACKUP_BASE"
        COUNTER=1

        while [ -e "$BACKUP_DIR" ]; do

            BACKUP_DIR="${BACKUP_BASE}_$COUNTER"
            COUNTER=$((COUNTER + 1))

        done

        logInfo "Backing up existing mod to $BACKUP_DIR..."
        mv "$MOD_DIR" "$BACKUP_DIR"

    else

        logInfo "Deleting existing mod..."
        rm -rf "$MOD_DIR"

    fi

fi

# If mod folder does not exits, make it
mkdir -p "$MOD_DIR"

# Copy Among Us folder to toum
logInfo "Copying game folder for mod..."

if ! cp -r "$GAME_DIR"/. "$MOD_DIR"/; then
    logError "Failed to copy Among Us folder to toum."
    exit 1
fi

# Initialize DOWNLOAD_DIR/FILENAME
: > "$DOWNLOAD_DIR/$FILENAME"

# Download asset
logInfo "Downloading $FILENAME...\n"
progressBar "$ASSET_URL" "$DOWNLOAD_DIR/$FILENAME"
logInfo "Download complete!"

EXTRACTED_DIR="$DOWNLOAD_DIR/tmp_extract"

mkdir -p "$EXTRACTED_DIR"

# Extract mod from ZIP archive
if ! unzip -oq "$DOWNLOAD_DIR/$FILENAME" -d "$EXTRACTED_DIR"; then

    logError "Failed to unzip mod."
    exit 1

fi

if [ ! -d "$EXTRACTED_DIR" ]; then

    logError "Extracted directory not found!"
    exit 1

fi

# Move everything to the mod directory
for ITEM in "$EXTRACTED_DIR"/*; do

    rsync -a --remove-source-files "$ITEM"/ "$MOD_DIR"/
    
done

# Delete extracted directory and ZIP
rm -rf "$EXTRACTED_DIR"
rm -f "$DOWNLOAD_DIR/$FILENAME"

# Update version file
echo -e "$LATEST_VERSION" > "$VERSION_FILE"

# Make sure all files are readable and writeable
chmod -R u+rwX "$MOD_DIR"

logDone "Mod updated to version $LATEST_VERSION at $MOD_DIR!"