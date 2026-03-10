> [!NOTE]
> A 

# Among Us Mod Updater

This is a simple sheel script to update your Among Us mods. Then you don't have to do a million steps everytime your mods need updating. Supports Linux, macOS, and Windows (with WSL or Git Bash).

---

# Contents
- [**Contents**](#contents)
- [**Installation**](#installation)
    - [Linux](#linux)
    - [Mac](#mac)
    - [Windows](#windows)

---

# Installation

## Linux

Either clone the repository or download the latest release:

```bash
git clone https://github.com/dgrondona/among-us-mod-updater
cd among-us-mod-updater
```

Most Linux distributions should come with these dependencies, but you can install them with:

```bash
sudo apt install curl jq unzip rsync
```

By default, the game directory is set for `~/.steam/steam/steamapps/common/Among Us`. If your game is located elsewhere, you can change `DOWNLOAD_DIR` and `GAME_DIR`.

## Mac
placeholder

## Windows

To run this on Windows, you will need to install WSL. First, open the powershell or terminal as an administrator with `Right Click > Run as Administrator`. Once you have that open, you can run:

```shell
wsl --install
```

Once WSL is installed, you will need to restart your computer. Then you can open the terminal as an administrator again and run:

```shell
wsl --install ubuntu
```

You will then be prompted to set a username and password.

Once set up, run

```bash
sudo apt update && sudo apt upgrade
```

For this you may need to enable `sudo` in the Windows developer settings. There should be a link to it in the commandline.

cd /mnt/c/Users/USERNAME (look for bin on windows)

git clone

cd among-us-mod-updater

install among us

run script

add modded to steam (maybe different section)

To Be Continued in a bit

---

for download dir, make it check possible locations for game for steam and epic games, epic games is in
/mnt/c/Users/user/Program Files/Epic Games