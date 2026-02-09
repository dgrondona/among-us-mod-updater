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

# Check if Among Us folder exists
if [ ! -d "$GAME_DIR" ]; then

    echo "Error: Among Us folder not found at $GAME_DIR"
    exit 1

fi

echo "⚠️ Make sure your game has updated before running this!"

# Generate the asset URL
ASSET_URL=$(curl -s \
    "https://api.github.com/repos/$OWNER/$REPO/releases/latest" | \
    jq -r --arg MATCH "$MATCH" '.assets[] | select(.name | contains($MATCH)) | .browser_download_url'
)

# Check if the asset exists
if [ -z "$ASSET_URL" ]; then

    echo "No matching asset found at $OWNER/$REPO/releases/latest!"
    exit 1

fi

# Get filename and latest version from the asset URL
FILENAME=$(basename "$ASSET_URL")
LATEST_VERSION=$(echo "$FILENAME" | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+')

echo "Latest mod version: $LATEST_VERSION"

# Check to see if mod needs updating
if [ -d "$MOD_DIR" ] && [ -f "$VERSION_FILE" ]; then

    INSTALLED_VERSION=$(cat "$VERSION_FILE")

    if [ "$INSTALLED_VERSION" == "$LATEST_VERSION" ]; then

        echo "Mod is already up to date ($INSTALLED_VERSION)."
        exit 0

    fi

    # Ask user if they want to save a backup
    read -p "A previous mod version ($INSTALLED_VERSION) exists. Save a backup? [Y/n]: " SAVE_BACKUP
    SAVE_BACKUP=${SAVE_BACKUP,,}  # convert to lowercase

    if [[ "$SAVE_BACKUP" != "n" && "$SAVE_BACKUP" != "no" ]]; then

        # Backup directory with incrementing number if needed
        BACKUP_BASE="$DOWNLOAD_DIR/toum($INSTALLED_VERSION)"
        BACKUP_DIR="$BACKUP_BASE"
        COUNTER=1

        while [ -d "$BACKUP_DIR" ]; do

            BACKUP_DIR="${BACKUP_BASE}_$COUNTER"
            COUNTER=$((COUNTER + 1))

        done

        echo "Backing up existing mod to $BACKUP_DIR..."
        mv "$MOD_DIR" "$BACKUP_DIR"

    else

        echo "Deleting existing mod..."
        rm -rf "$MOD_DIR"

    fi

elif [ -d "$MOD_DIR" ]; then

    # No version file, but mod exists
    INSTALLED_VERSION="unknown"
    read -p "A previous mod version exists. Save a backup? [Y/n]: " SAVE_BACKUP
    SAVE_BACKUP=${SAVE_BACKUP,,}

    if [[ "$SAVE_BACKUP" != "n" && "$SAVE_BACKUP" != "no" ]]; then

        BACKUP_DIR="$DOWNLOAD_DIR/toum($INSTALLED_VERSION)"
        echo "Backing up existing mod to $BACKUP_DIR..."
        mv "$MOD_DIR" "$BACKUP_DIR"

    else

        echo "Deleting existing mod..."
        rm -rf "$MOD_DIR"

    fi

fi

# If mod folder does not exits, make it
mkdir -p "$MOD_DIR"

# Copy Among Us folder to toum
echo "Copying game folder for mod..."

if ! cp -r "$GAME_DIR"/. "$MOD_DIR"/; then
    echo "Error: Failed to copy Among Us folder to toum."
    exit 1
fi

# Download mod
echo "Downloading $FILENAME to $DOWNLOAD_DIR..."

if ! curl -L -o "$DOWNLOAD_DIR/$FILENAME" "$ASSET_URL"; then
    echo "Error: Failed to download mod."
    exit 1
fi

echo "Done!"

# Extract mod from ZIP archive
if ! unzip "$DOWNLOAD_DIR/$FILENAME"; then

    echo "Error: Failed to unzip mod."
    exit 1

fi

EXTRACTED_DIR="$DOWNLOAD_DIR/${FILENAME%.zip}"

if [ ! -d "$EXTRACTED_DIR" ]; then

    echo "Error: Extracted directory not found!"
    exit 1

fi

# Move everything to the mod directory
if ! rsync -a --remove-source-files --remove-source-empty-dirs "$EXTRACTED_DIR"/ "$MOD_DIR"/; then

    echo "Error: Failed to move mod files into toum."
    exit 1

fi

# Delete extracted directory and ZIP
rm -rf "$EXTRACTED_DIR"
rm -f "$DOWNLOAD_DIR/$FILENAME"

# Update version file
echo "$LATEST_VERSION" > "$VERSION_FILE"

echo "Mod updated to version $LATEST_VERSION at $MOD_DIR!"