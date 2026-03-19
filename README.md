# Among Us Mod Updater

A simple shell script to update your among us mods without manually moving files. Supports Linux, macOS, and Windows (via WSL).

---

# Contents
- [**Contents**](#contents)
- [**Installation**](#installation)
    - [Linux](#linux)
    - [Mac](#mac)
    - [Windows](#windows)
- [**Usage**](#usage)

---

# Installation

## Linux

1. Clone the repository:
```bash
git clone https://github.com/dgrondona/among-us-mod-updater
cd among-us-mod-updater
```

2. Install dependencies (if not already installed):
```bash
sudo apt update
sudo apt install curl jq unzip rsync
```

3. Verify Game Directory:
By default, the script assumes your game is at `~/.steam/steam/steamapps/common/Among Us`. If your game is elsewhere, you can export these variables before running the script:

```bash
export GAME_DIR="/path/to/Among Us"
export DOWNLOAD_DIR="/path/to/where/game/folder/is/located"
```

4. Make the script executable:
```bash
chmod +x update.sh
```

## Mac

1. Clone the repository:
```bash
git clone https://github.com/dgrondona/among-us-mod-updater
cd among-us-mod-updater
```

2. Install dependencies using Homebrew:
```bash
brew install curl jq unzip rsync
```

3. Verify game directory:

By default, the script assumes your game is at `~/Library/Application Support/Steam/steamapps/common/Among Us`. If your game is elsewhere, you can export these variables before running the script:
```bash
export GAME_DIR="/path/to/Among Us"
export DOWNLOAD_DIR="/path/to/where/game/folder/is/located"
```

4. Make the script executable:
```bash
chmod +x update.sh
```

## Windows

> NOTE!
> To run this script on Windows, WSL is required.

1. Install WSL:

Open PowerShell as an administrator and run:
```shell
wsl --install
```
- Restart your computer when done.
- Install Ubuntu (or your preferred Linux distro).
```shell
wsl --install ubuntu
```
- Set the username and password when prompted.

2. Update Ubuntu packages:
```bash
sudo apt update && sudo apt upgrade -y
```

3. Install dependencies:
```bash
sudo apt install curl jq unzip rsync git
```

4. Clone the script:
```bash
cd ~
git clone https://github.com/dgrondona/among-us-mod-updater
cd among-us-mod-updater
```

5. Make the script executable
``` bash
sudo chmod +x update.sh
```

---

# Usage

1. Make sure your game is up to date by launching it.

2. Run the script:
```bash
sudo ./update.sh
```

The script comes with various options that you can use:
```
-f, --force                 Force update even if mod is up to date
-n, --no-backup              Skip backing up existing mod
-b, --force-backup           Force backup of existing mod
-p, --platform [steam|epic]  Choose platform explicitly
-v, --verbose                Show detailed logs
-h, --help                   Show this help message
```