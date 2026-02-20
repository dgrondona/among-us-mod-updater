#!/usr/bin/env sh
set -eu

IFS=' 	
'

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

    if [ "${1:-}" = "-n" ]; then
        shift
        printf "%b" "${INFO}$*"
    else
        printf "%b\n" "${INFO}$*";
    fi

}

logWarn() {

    if [ "${1:-}" = "-n" ]; then
        shift
        printf "%b" "${WARN}$*"
    else
        printf "%b\n" "${WARN}$*";
    fi

}

logError() {

    if [ "${1:-}" = "-n" ]; then
        shift
        printf "%b" "${ERROR}$*"
    else
        printf "%b\n" "${ERROR}$*";
    fi

}

logDone() {

    if [ "${1:-}" = "-n" ]; then
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
    if [ -n "${FILENAME:-}" ] && [ -f "$DOWNLOAD_DIR/$FILENAME" ]; then

        rm -f "$DOWNLOAD_DIR/$FILENAME" 2>/dev/null || true

    fi

}

trap 'cleanup' 0


# Grab the latest release from GitHub
getLatestReleaseUrl() {

    curl -s "https://api.github.com/repos/$OWNER/$REPO/releases/latest" |
        jq -r --arg MATCH "$MATCH" \
        '.assets[] | select(.name | contains($MATCH)) | .browser_download_url'

}


# Progress bar
progressBar() {
    pb_CURRENT=$1
    pb_TOTAL=$2
    pb_BAR_LENGTH=30

    if [ "$pb_TOTAL" -gt 0 ]; then
        pb_PERCENT=$(( pb_CURRENT * 100 / pb_TOTAL ))
    else
        pb_PERCENT=0
    fi

    pb_FILLED=$(( pb_PERCENT * pb_BAR_LENGTH / 100 ))
    pb_EMPTY=$(( pb_BAR_LENGTH - pb_FILLED ))

    pb_BAR="$(printf "%*s" "$pb_FILLED" "" | tr ' ' '#')"
    pb_BAR="${pb_BAR}$(printf "%*s" "$pb_EMPTY" "")"

    # If download is complete, print green and newline
    if [ "$pb_CURRENT" -ge "$pb_TOTAL" ] && [ "$pb_TOTAL" -ne 0 ]; then
        printf "${GREEN}\r[%-${pb_BAR_LENGTH}s] 100%%${NC}\n" "$(printf '#%.0s' $(seq 1 $pb_BAR_LENGTH))"
    else
        printf "\r[%-${pb_BAR_LENGTH}s] %3d%%" "$pb_BAR" "$pb_PERCENT"
    fi
}


# Try both stat -c and stat -f for mac and linux
get_size() {
    stat -c %s "$1" 2>/dev/null || stat -f %z "$1" 2>/dev/null || echo 0
}


# Get the total size of the download
get_total_size() {
    url="$1"
    # Use curl with -sI -L to follow redirects, grep Content-Length anywhere, pick the last one
    total=$(curl -sI -L "$url" 2>/dev/null | \
            grep -i 'Content-Length:' | \
            tail -n 1 | \
            awk '{print $2}' | tr -d '\r')
    # fallback to 0 if empty
    total=${total:-0}
    echo "$total"
}


# Download file
download() {
    logInfo "Downloading $FILENAME..."

    d_URL="$1"
    d_OUTPUT="$2"

    # Create file empty first (so loop has something to stat)
    : > "$d_OUTPUT"

    # Get total size from headers
    d_TOTAL=$(get_total_size "$d_URL")

    # Start download in background
    curl -sL "$d_URL" -o "$d_OUTPUT" &
    d_PID=$!

    # Wait for file to exist before polling
    while [ ! -f "$d_OUTPUT" ]; do
        sleep 0.05
    done

    # Poll download progress
    while kill -0 "$d_PID" 2>/dev/null; do
        d_DOWNLOADED=$(get_size "$d_OUTPUT")
        progressBar "$d_DOWNLOADED" "$d_TOTAL"
        sleep 0.2
    done

    wait "$d_PID"
    d_STATUS=$?

    # Print full bar at the end
    progressBar "$d_TOTAL" "$d_TOTAL"

    if [ "$d_STATUS" -ne 0 ]; then
        logError "Download failed for $d_OUTPUT"
        exit 1
    fi

    logInfo "Download complete!"
}


backup() {

    b_VERSION="$1"

    logWarn -n "A previous mod version ($b_VERSION) exists. Save a backup? [Y/n]: "
    read SAVE_BACKUP || SAVE_BACKUP=""
    SAVE_BACKUP=$(printf "%s" "$SAVE_BACKUP" | tr '[:upper:]' '[:lower:]')

    if [ "$SAVE_BACKUP" != "n" -a "$SAVE_BACKUP" != "no" ]; then

        doBackup "$b_VERSION"

    else

        logInfo "Deleting existing mod..."
        rm -rf "$MOD_DIR"

    fi

}

doBackup() {

    db_VERSION="$1"

    db_BASE="$DOWNLOAD_DIR/$MOD_NAME($db_VERSION)"
    db_TARGET="$db_BASE"
    db_COUNT=1

    while [ -e "$db_TARGET" ]; do
        db_TARGET="${db_BASE}_$db_COUNT"
        db_COUNT=$((db_COUNT + 1))
    done

    logInfo "Backing up existing mod to $db_TARGET..."
    rsync -a --remove-source-files "$MOD_DIR"/ "$db_TARGET"/

}


copyGameFiles() {

    logInfo "Copying game files to $MOD_DIR..."

    rsync -a "$GAME_DIR"/ "$MOD_DIR"/ || {

        logError "Failed to copy Among Us folder."
        exit 1

    }

}


installModFiles() {

    # Make temporary directory to extract ZIP into
    TMP="$DOWNLOAD_DIR/tmp_extract"
    mkdir -p "$TMP"

    # Unzip mod
    logInfo "Extracting $FILENAME..."
    if ! unzip -oq "$DOWNLOAD_DIR/$FILENAME" -d "$TMP"; then
        logError "Failed to unzip mod."
        exit 1
    fi

    # Move all game files from temp directory to the mod directory
    for ITEM in "$TMP"/*; do
        [ -e "$ITEM" ] || continue
        rsync -a --remove-source-files "$ITEM"/ "$MOD_DIR"/
    done


    # Remove temp directory and ZIP file
    rm -rf "$TMP"
    rm -f "$DOWNLOAD_DIR/$FILENAME"

    logInfo "$FILENAME extracted to $MOD_DIR"

    # Write mod version to txt inside mod directory
    echo "$LATEST_VERSION" > "$VERSION_FILE"

    # Ensure all files have proper permissions
    chmod -R u+rwX "$MOD_DIR"

}


updateCheck() {

    if [ ! -d "$MOD_DIR" ]; then

        return

    fi

    if [ -f "$VERSION_FILE" ]; then

        INSTALLED_VERSION=$(cat "$VERSION_FILE")

    else

        INSTALLED_VERSION="unknown"

    fi

    if [ "$FORCE_UPDATE" -eq 1 ]; then

        logInfo "Force update enabled, skipping version check."

    fi

    if [ "$FORCE_UPDATE" -eq 0 ] && [ "$INSTALLED_VERSION" = "$LATEST_VERSION" ]; then

        logInfo "Mod is already up to date ($INSTALLED_VERSION)."
        exit 0

    fi

    if [ "$FORCE_BACKUP" -eq 1 ]; then

        logInfo "Force backup enabled"
        doBackup "${INSTALLED_VERSION}"

    elif [ "$SKIP_BACKUP" -eq 1 ]; then

        logInfo "Skip backup enabled, skipping backup."
        logInfo "Deleting existing mod..."
        rm -rf "$MOD_DIR"

    else

        backup "${INSTALLED_VERSION}"

    fi

}


FORCE_UPDATE=0
SKIP_BACKUP=0
FORCE_BACKUP=0

usage() {

    cat <<EOF
Usage: $0 [OPTIONS]

Options:
    -f, --force          Force update even if mod is up to date
    -n, --no-backup      Skip backing up existing mod
    -b, --force-backup   Force backup of existing mod
    -h, --help           Show this help message
EOF
    exit 0

}

while [ $# -gt 0 ]; do
    case $1 in
        -f|--force)
            FORCE_UPDATE=1
            shift
            ;;
        -n|--no-backup)
            SKIP_BACKUP=1
            shift
            ;;
        -b|--force-backup)
            FORCE_BACKUP=1
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            logError "Unknown argument: $1"
            usage
            ;;
    esac
done


main() {

    # Check if Among Us folder exists
    if [ ! -d "$GAME_DIR" ]; then

        logError "Among Us folder not found at $GAME_DIR"
        exit 1

    fi

    logWarn "Make sure your game has updated before running this!"

    # Generate the asset URL
    ASSET_URL=$(getLatestReleaseUrl)

    # Check if the asset exists
    if [ -z "$ASSET_URL" ]; then

        logError "No matching asset found at $OWNER/$REPO/releases/latest!"
        exit 1

    fi

    # Get filename and latest version from the asset URL
    FILENAME=$(basename "$ASSET_URL")
    LATEST_VERSION=$(printf "%s\n" "$FILENAME" | sed -n 's/.*\(v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p')

    # Check if latest version exists
    if [ -z "$LATEST_VERSION" ]; then
        logError "Could not determine latest mod version from filename!"
        exit 1
    fi

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

}

main "$@"