#!/usr/bin/env sh
set -eu

IFS=' 	
'

# Information for downloading from GitHub
OWNER="AU-Avengers"
REPO="TOU-Mira"

MOD_NAME="toum"

MATCH="steam-itch"

# Detect the OS being used
detectOS() {
    OS="$(uname -s)"

    case "$OS" in
        Linux*)   OS_TYPE="linux" ;;
        Darwin*)  OS_TYPE="mac" ;;
        *)
            logError "Unsupported OS: $OS"
            exit 1
            ;;
    esac
}

# Detect if using wsl
detectEnvironment() {

    ENVIRONMENT="native"

    if [ "$OS_TYPE" = "linux" ]; then
        if grep -qiE "(microsoft|wsl)" /proc/sys/kernel/osrelease 2>/dev/null; then
            ENVIRONMENT="wsl"
        fi
    fi

}

# Detect if using Epic or Steam
autoDetectPlatform() {

    # If user already specified platform, respect it
    if [ -n "${PLATFORM:-}" ]; then
        return
    fi

    # Detect Epic (WSL only for now)
    if [ "$ENVIRONMENT" = "wsl" ] && [ -d "/mnt/c/Games/AmongUs" ]; then
        PLATFORM="epic"
        MATCH="epic"
        return
    fi

    # Default fallback
    PLATFORM="steam"
}

# Set up file paths
configurePaths() {

    case "$PLATFORM" in

        steam)

            case "$OS_TYPE" in

                linux)
                    BASE="$HOME/.steam/steam/steamapps/common"
                    ;;

                mac)
                    BASE="$HOME/Library/Application Support/Steam/steamapps/common"
                    ;;

                *)
                    logError "Steam not supported on this OS"
                    exit 1
                    ;;
            esac

            # WSL Steam (optional future support)
            if [ "$ENVIRONMENT" = "wsl" ]; then
                BASE="/mnt/c/Program Files (x86)/Steam/steamapps/common"
            fi

            GAME_DIR="$BASE/Among Us"
            DOWNLOAD_DIR="$BASE"
            MOD_DIR="$BASE/$MOD_NAME"
            INSTALL_MODE="moddir"
            ;;

        epic)

            if [ "$ENVIRONMENT" != "wsl" ]; then
                logError "Epic currently only supported via WSL"
                exit 1
            fi

            BASE="/mnt/c/Games"

            GAME_DIR="$BASE/AmongUs"
            DOWNLOAD_DIR="$BASE"
            MOD_DIR="$GAME_DIR"
            INSTALL_MODE="inplace"
            ;;

        *)
            logError "Unknown platform: $PLATFORM"
            exit 1
            ;;
    esac

    VERSION_FILE="$MOD_DIR/version.txt"
}

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


assertSafePath() {
    TARGET="$1"

    if [ -z "$TARGET" ]; then
        logError "Empty path detected!"
        exit 1
    fi

    case "$TARGET" in
        "$HOME"/*|/mnt/c/*) ;;  # allow
        *)
            logError "Path outside expected directories: $TARGET"
            exit 1
            ;;
    esac
}


checkDependencies() {
    REQUIRED_CMDS="curl jq unzip rsync"

    for cmd in $REQUIRED_CMDS; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            case "$OS_TYPE" in
                linux|mac)
                    logError "Required command '$cmd' not found. Install it via your package manager."
                    ;;
                windows)
                    logError "Required command '$cmd' not found. Make sure Git Bash or WSL has it installed."
                    ;;
            esac
            exit 1
        fi
    done
}

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


confirmInPlaceInstall() {

    if [ "$INSTALL_MODE" = "inplace" ]; then
        logWarn "You are installing directly into the game directory!"
        logWarn "This can break your game if something goes wrong."

        printf "Continue? [y/N]: "
        read -r CONFIRM || CONFIRM="n"

        CONFIRM=$(printf "%s" "$CONFIRM" | tr '[:upper:]' '[:lower:]')

        if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "yes" ]; then
            logInfo "Aborting."
            exit 0
        fi
    fi

}


safeRemoveModDir() {

    assertSafePath "$MOD_DIR"

    if [ "$INSTALL_MODE" = "moddir" ]; then
        rm -rf "$MOD_DIR"
    else
        logWarn "Refusing to delete game directory in in-place mode..."
    fi

}


# Clean up for Epic's in-place install
epicClean() {

    assertSafePath "$GAME_DIR"

    logInfo "Cleaning old mod files (Epic in-place)..."

    rm -rf "$GAME_DIR/BepInEx"
    rm -rf "$GAME_DIR/doorstop_libs"
    rm -f "$GAME_DIR/winhttp.dll"
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
        printf "${GREEN}\r[%s] 100%%${NC}\n" "$(printf "%${pb_BAR_LENGTH}s" "" | tr ' ' '#')"
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
    read -r SAVE_BACKUP || SAVE_BACKUP=""
    SAVE_BACKUP=$(printf "%s" "$SAVE_BACKUP" | tr '[:upper:]' '[:lower:]')

    if [ "$SAVE_BACKUP" != "n" ] && [ "$SAVE_BACKUP" != "no" ]; then

        doBackup "$b_VERSION"

    else

        logInfo "Deleting existing mod..."
        safeRemoveModDir

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
    rsync -a "$MOD_DIR"/ "$db_TARGET"/

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
        rsync -a "$ITEM" "$MOD_DIR"/
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
        safeRemoveModDir

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
    -f, --force                   Force update even if mod is up to date
    -n, --no-backup               Skip backing up existing mod
    -b, --force-backup            Force backup of existing mod
    -p, --platform [steam|epic]   Choose platform (default: steam)
    -h, --help                    Show this help message
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
        -p|--platform)
            if [ $# -lt 2 ]; then
                logError "--platform requires an argument"
                exit 1
            fi

            PLATFORM="$2"
            shift 2
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

    detectOS
    detectEnvironment
    autoDetectPlatform
    configurePaths

    checkDependencies

    logInfo "OS: $OS_TYPE"
    logInfo "Environment: $ENVIRONMENT"
    logInfo "Platform: $PLATFORM"
    logInfo "Game dir: $GAME_DIR"
    logInfo "Mod dir: $MOD_DIR"

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

    confirmInPlaceInstall

    # If mod folder does not exits, make it
    if [ "$INSTALL_MODE" = "moddir" ]; then
        mkdir -p "$MOD_DIR"
        copyGameFiles
    else
        logInfo "Using in place install (Epic)"
        epicClean
    fi

    # Download asset
    download "$ASSET_URL" "$DOWNLOAD_DIR/$FILENAME"

    # Install the mod files
    installModFiles

    logDone "Mod updated to version $LATEST_VERSION at $MOD_DIR!"

}

main "$@"