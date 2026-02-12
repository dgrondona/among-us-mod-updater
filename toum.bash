#!/bin/bash
set -euo pipefail

# Information for downloading from GitHub
OWNER="AU-Avengers"
REPO="TOU-Mira"

MOD_NAME="toum"

# Download must include this string
MATCH="steam-itch"

# The directory where the file is saved
DOWNLOAD_DIR="$HOME/.steam/steam/steamapps/common"

GAME_DIR="$DOWNLOAD_DIR/Among Us"
MOD_DIR="$DOWNLOAD_DIR/$MOD_NAME"
MOD_OLD_DIR="$DOWNLOAD_DIR/$MOD_NAME(old)"
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

: '
Log functions can have newline ommited with -n

logInfo "Text Here"
or
logInfo -n "Text Here"
'
logInfo() {

    if [[ "${1:-}" == "-n" ]]; then
        shift
        printf "%b" "${INFO}$*"
    else
        printf "%b\n" "${INFO}$*";
    fi

}

logWarn() {

    if [[ "${1:-}" == "-n" ]]; then
        shift
        printf "%b" "${WARN}$*"
    else
        printf "%b\n" "${WARN}$*";
    fi

}

logError() {

    if [[ "${1:-}" == "-n" ]]; then
        shift
        printf "%b" "${ERROR}$*"
    else
        printf "%b\n" "${ERROR}$*";
    fi

}

logDone() {

    if [[ "${1:-}" == "-n" ]]; then
        shift
        printf "%b" "${DONE}$*"
    else
        printf "%b\n" "${DONE}$*";
    fi

}


# For dependencies
requireCommand() {

    command -v "$1" >/dev/null 2>&1 || {
        logError "Required command '$1' is not installed."
        exit 1
    }

}

# Required dependencies
requireCommand curl
requireCommand jq
requireCommand unzip
requireCommand rsync


# Cleanup in case script crashes mid-download
cleanup() {

    # Remove temp extraction directory
    if [ -d "$DOWNLOAD_DIR/tmp_extract" ]; then

        rm -rf "$DOWNLOAD_DIR/tmp_extract" 2>/dev/null || true

    fi

    # Remove partial download
    if [ -f "$DOWNLOAD_DIR/$FILENAME" ]; then

        rm -f "$DOWNLOAD_DIR/$FILENAME" 2>/dev/null || true

    fi

}

trap cleanup EXIT


# Grab the latest release from GitHub
getLastestReleaseUrl() {

    curl -s "https://api.github.com/repos/$OWNER/$REPO/releases/latest" |
        jq -r --arg MATCH "$MATCH" \
        '.assets[] | select(.name | contains($MATCH)) | .browser_download_url'

}


# Progress bar
progressBar() {

    # Initialize all variables
    local CURRENT="$1"
    local TOTAL="$2"

    local BAR_LENGTH=30
    local PERCENT=0
    local FILLED=0
    local EMPTY=0
    local BAR=""

    # Avoid divide by 0
    if (( TOTAL > 0 )); then
        PERCENT=$(( CURRENT * 100 / TOTAL ))
    else
        PERCENT=0
    fi
    
    # Set variables
    FILLED=$(( PERCENT * BAR_LENGTH / 100 ))
    EMPTY=$(( BAR_LENGTH - FILLED ))
    BAR="$(printf "%*s" "$FILLED" "" | tr ' ' '#')$(printf "%*s" "$EMPTY" "")"

    # Print progress bar
    printf "\r[%-${BAR_LENGTH}s] %3d%%" "$BAR" "$PERCENT"

    # Finish
    if (( CURRENT >= TOTAL )); then
        printf "${GREEN}\r[%s] 100%%${NC}\n" "$(printf '#%.0s' $(seq 1 $BAR_LENGTH))"
    fi

}


# Progress bar
download() {

    logInfo "Downloading $FILENAME..."

    local URL="$1"
    local OUTPUT="$2"

    : > "$OUTPUT"

    local TOTAL
    TOTAL=$(curl -sI -L "$URL" | grep -i Content-Length | tail -n1 | awk '{print $2}' | tr -d '\r' | xargs || echo 0)
    TOTAL=${TOTAL:-0}

    curl -sL "$URL" -o "$OUTPUT" &
    local PID=$!

    while kill -0 $PID 2>/dev/null; do
        local DOWNLOADED
        DOWNLOADED=$(stat -c %s "$OUTPUT" 2>/dev/null || echo 0)
        progressBar "$DOWNLOADED" "$TOTAL"

        sleep 0.2
    done

    wait $PID
    local STATUS=$?

    progressBar "$TOTAL" "$TOTAL"

    if [ $STATUS -ne 0 ]; then
        logError "Download failed for $OUTPUT"
        exit 1
    fi

    logInfo "Download complete!"

}

backup() {

    local VERSION="$1"

    logWarn -n "A previous mod version ($VERSION) exists. Save a backup? [Y/n]: "
    read SAVE_BACKUP
    SAVE_BACKUP=${SAVE_BACKUP,,}

    if [[ "$SAVE_BACKUP" != "n" && "$SAVE_BACKUP" != "no" ]]; then

        local BASE="$DOWNLOAD_DIR/$MOD_NAME($VERSION)"
        local TARGET="$BASE"
        local COUNT=1

        while [ -e "$TARGET" ]; do
            TARGET="${BASE}_$COUNT"
            ((COUNT++))
        done

        logInfo "Backing up existing mod to $TARGET..."
        mv "$MOD_DIR" "$TARGET"

    else

        logInfo "Deleting existing mod..."
        rm -rf "$MOD_DIR"

    fi

}


copyGameFiles() {

    logInfo "Copying game files to ${MOD_DIR}..."

    cp -r "$GAME_DIR"/. "$MOD_DIR"/ || {

        logError "Failed to copy Among Us folder."
        exit 1

    }

}


installModFiles() {

    # Make temporary directory to extract ZIP into
    local TMP="$DOWNLOAD_DIR/tmp_extract"
    mkdir -p "$TMP"

    # Unzip mod
    if ! unzip -oq "$DOWNLOAD_DIR/$FILENAME" -d "$TMP"; then
        logError "Failed to unzip mod."
        exit 1
    fi

    # Move all game files from temp directory to the mod directory
    for ITEM in "$TMP"/*; do
        rsync -a --remove-source-files "$ITEM"/ "$MOD_DIR"/
    done

    # Remove temp directory and ZIP file
    rm -rf "$TMP"
    rm -f "$DOWNLOAD_DIR/$FILENAME"

    # Write mod version to txt inside mod directory
    echo "$LATEST_VERSION" > "$VERSION_FILE"

    # Ensure all files have proper permissions
    chmod -R u+rwX "$MOD_DIR"

}


updateCheck() {

    # Check to see if mod needs updating and backup
    if [ -d "$MOD_DIR" ] && [ -f "$VERSION_FILE" ]; then

        INSTALLED_VERSION=$(cat "$VERSION_FILE")

        if [ "$INSTALLED_VERSION" == "$LATEST_VERSION" ]; then

            logInfo "Mod is already up to date ($INSTALLED_VERSION)."
            exit 0

        fi

        backup "$INSTALLED_VERSION"

    elif [ -d "$MOD_DIR" ]; then

        backup "unknown"

    fi

}


# Check if Among Us folder exists
if [ ! -d "$GAME_DIR" ]; then

    logError "Among Us folder not found at $GAME_DIR"
    exit 1

fi

logWarn "Make sure your game has updated before running this!"

# Generate the asset URL
ASSET_URL=$(getLastestReleaseUrl)

# Check if the asset exists
if [ -z "$ASSET_URL" ]; then

    logError "No matching asset found at $OWNER/$REPO/releases/latest!"
    exit 1

fi

# Get filename and latest version from the asset URL
FILENAME=$(basename "$ASSET_URL")
LATEST_VERSION=$(echo "$FILENAME" | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+')

logInfo "Latest mod version: $LATEST_VERSION"

# Check if mod is up to date
updateCheck

# If mod folder does not exits, make it
mkdir -p "$MOD_DIR"

# Copy Among Us folder to mod folder
copyGameFiles

# Download asset
download "$ASSET_URL" "$DOWNLOAD_DIR/$FILENAME"

# Install the mod files
installModFiles

logDone "Mod updated to version $LATEST_VERSION at $MOD_DIR!"