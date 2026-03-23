# Among Us Mod Updater

A simple shell script to update your among us mods without manually moving files. Supports **Linux**, **macOS**, and **Windows (via WSL)**.

> It is assumed that you already have **Among Us** installed.

---

# Contents
- [**Installation**](#installation)
    - [Linux](#linux)
    - [Mac](#mac)
    - [Windows](#windows)
- [**Usage**](#usage)
    - [Linux / Mac](#linux--mac)
    - [Windows](#windows-1)
    - [Updater Options](#options)

---

# Installation

## Linux

**1. Clone the repository**:

```bash
git clone https://github.com/dgrondona/among-us-mod-updater
cd among-us-mod-updater
```

**2. Install dependencies** (if not already installed):

```bash
sudo apt update
sudo apt install curl jq unzip rsync
```

**3. Verify Game Directory**:

By default, the script assumes your game is at `~/.steam/steam/steamapps/common/Among Us`. If your game is elsewhere, you can export these variables before running the script:

```bash
export GAME_DIR="/path/to/Among Us"
export DOWNLOAD_DIR="/path/to/where/game/folder/is/located"
```

**4. Make the script executable**:

```bash
chmod +x update.sh
```

> **NOTE**:
> Be sure Proton Experimental is enabled and include any launch options you need. I use `PROTON_LOG=1 PROTON_USE_WINED3D=1 DRI_PRIME=1 %command%`, but this may be different depending on your distrobution and your computer's hardware.

## Mac

**1. Clone the repository**:

```bash
git clone https://github.com/dgrondona/among-us-mod-updater
cd among-us-mod-updater
```

**2. Install dependencies using Homebrew**:

```bash
brew install curl jq unzip rsync
```

**3. Verify game directory**:

By default, the script assumes your game is at `~/Library/Application Support/Steam/steamapps/common/Among Us`. If your game is elsewhere, you can export these variables before running the script:

```bash
export GAME_DIR="/path/to/Among Us"
export DOWNLOAD_DIR="/path/to/where/game/folder/is/located"
```

**4. Make the script executable**:

```bash
chmod +x update.sh
```

## Windows

> **NOTE**:
> To run this script on Windows, WSL is required.

**1. Install WSL**:

Open PowerShell as an administrator and run:

```shell
wsl --install
```

- Restart your computer when done.
- Open PowerShell as an administrator again.
- Install Ubuntu (or your preferred Linux distro).

```shell
wsl --install ubuntu
```

- Set the username and password when prompted.

**2. Update Ubuntu packages**:

```bash
sudo apt update && sudo apt upgrade -y
```

You may need to enable the use of `sudo` in Windows settings.

**3. Install dependencies**:

```bash
sudo apt install curl jq unzip rsync git
```

**4. Clone the script**:

```bash
cd ~
git clone https://github.com/dgrondona/among-us-mod-updater
cd among-us-mod-updater
```

**5. Make the script executable**:

``` bash
sudo chmod +x update.sh
```

---

# Usage

## Linux / Mac

**1. Update game**:

Make sure that your game is updated by launching it.

**2. Run the updater**:

Navigate to wherever you installed the updater and run:

```bash
sudo ./update.sh
```

## Windows

**1. Update game**:

Make sure that your game is updated by launching it.

**2. Open WSL**:

Open PowerShell as an administrator and run:

```shell
wsl
```

You will most likely need to enter your username and password that you set when you first installed WSL.

**3. Run the updater**:

```bash
cd ~/among-us-mod-updater
sudo ./update.sh
```

## Options

The script comes with various options that you can use:
```
-f, --force                 Force update even if mod is up to date
-n, --no-backup              Skip backing up existing mod
-b, --force-backup           Force backup of existing mod
-p, --platform [steam|epic]  Choose platform explicitly
-v, --verbose                Show detailed logs
-h, --help                   Show this help message
```

---

# Launching Modded Game From Steam

**1. Open Steam**:

Open Steam and navigate to your games library.

**2. Add new non-steam game**:

In the bottom left corner, click add new game, then Add a Non-Steam Game.

![add a game](https://github.com/dgrondona/image-storage/blob/847863191842df3cdc3e25c7ddb3a0dbe9af32b4/among-us-mod-updater/steam_1.png)


**3. Select modded executable**:

In the pop up dialogue, click on `Browse` and navigate to the folder in your `(...)/steam/steamapps/common` folder labeled `toum`. Then select `Among Us.exe`.

**4. Edit game profile**:

I'd recommend editing the name of your modded profile. If you select it in your library, click on the gear icon on the right and select properties. You can then edit the shortcut name, image, etc.

> **NOTE**:
> For **Linux**, be sure Proton Experimental is enabled and include any launch options you need. I use `PROTON_LOG=1 PROTON_USE_WINED3D=1 DRI_PRIME=1 %command%`, but this may be different depending on your distrobution and your computer's hardware.