# GVD Project (Godot 4.6.1)

A 2D Godot game project with a main menu and multiple scenes (`new_game`, `continue`, `hi_score`, and `tutorial`).

This guide covers **full setup and installation** for both **Windows** and **macOS**, plus running, exporting, and troubleshooting.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Requirements](#requirements)
3. [Install Godot 4.6.1](#install-godot-461)
	- [Windows Installation](#windows-installation)
	- [macOS Installation](#macos-installation)
4. [Get the Project](#get-the-project)
5. [Open and Run the Project](#open-and-run-the-project)
6. [Build/Export Game](#buildexport-game)
7. [Project Structure](#project-structure)
8. [Troubleshooting](#troubleshooting)
9. [Recommended Tools](#recommended-tools)

---

## Project Overview

- Engine: **Godot 4.6.1**
- Main entry scene: `ui/main_menu_v2/MainMenuV2.tscn`
- Project config file: `project.godot`
- Scripts are in `scripts/`
- Scenes are in `scenes/`
- Image assets are in `assets/images/`

---

## Requirements

Before you start, make sure you have:

- **Godot Engine 4.6.1**
- A machine running:
  - **Windows 10/11** (64-bit), or
  - **macOS 12+** (Intel or Apple Silicon)
- At least **2 GB free disk space** (engine + project + export artifacts)
- Optional but recommended:
  - **Git** (to clone/pull project updates)
  - **VS Code** or another code editor for `.gd` files

---

## Install Godot 4.6.1

Download Godot from the official site:

- https://godotengine.org/download

Choose the **Godot 4.6.1** build matching your OS.

> Note: If you use the .NET/C# version, install the .NET SDK required by that Godot build. This project currently uses GDScript (`.gd`).

### Windows Installation

#### Option A: Standard executable (portable)

1. Download the Windows 64-bit Godot 4.6.1 executable.
2. Extract ZIP if needed.
3. Place `Godot_v4.6.1-stable_win64.exe` in a permanent folder, for example:
	- `C:\Tools\Godot\`
4. (Optional) Rename it to `godot.exe` for convenience.

#### Option B: Steam

1. Install Godot from Steam.
2. Confirm the installed version is **4.6.1**.

#### Optional: Add Godot to PATH (Windows)

1. Press `Win + S`, search **Environment Variables**, open **Edit the system environment variables**.
2. Click **Environment Variables**.
3. Under **User variables**, edit `Path`.
4. Add the folder containing the Godot executable.
5. Open a new PowerShell and verify:

```powershell
godot --version
```

You should see `4.6.1`.

### macOS Installation

#### Option A: Official DMG/ZIP

1. Download Godot 4.6.1 for macOS from the official website.
2. Open the downloaded file.
3. Drag **Godot.app** into **Applications**.
4. Launch Godot from Applications.

If macOS blocks first launch:

1. Open **System Settings** → **Privacy & Security**.
2. Under Security, allow the app and retry.

#### Optional: CLI alias on macOS

Add a shell alias in `~/.zshrc`:

```bash
alias godot='/Applications/Godot.app/Contents/MacOS/Godot'
```

Then reload shell:

```bash
source ~/.zshrc
godot --version
```

You should see `4.6.1`.

---

## Get the Project

### Option A: Clone with Git

```bash
git clone <your-repository-url> gvd-project
cd gvd-project
```

### Option B: Download ZIP

1. Download the repository ZIP from your source host.
2. Extract it to a folder (for example `Documents/gvd-project`).

---

## Open and Run the Project

### Open project in Godot

1. Launch Godot 4.6.1.
2. In Project Manager, click **Import** (or **Scan**).
3. Select this folder’s `project.godot` file.
4. Click **Import & Edit**.

### Run from the editor

1. Open the project.
2. Press **F5** (Run Project), or click the **Play** button.
3. The game should start at the main menu scene.

### Run from command line (optional)

From project root:

```bash
godot --path .
```

To run immediately:

```bash
godot --path . --main-pack project.godot
```

---

## Build/Export Game

To create distributable builds:

1. Open project in Godot.
2. Go to **Project → Export**.
3. Click **Add...** and choose a target platform (Windows, macOS, etc.).
4. Configure export settings:
	- Executable name
	- Icons
	- Display options
5. Click **Export Project**.

### Export templates

If prompted, install export templates:

1. In Godot, open **Editor → Manage Export Templates**.
2. Install templates matching **4.6.1**.
3. Retry export.

---

## Project Structure

```text
gvd-project/
├─ project.godot
├─ ui/main_menu_v2/MainMenuV2.tscn
├─ core/
│  ├─ shop_floor/
│  └─ autoloads/
├─ ui/
│  ├─ daily_summary/
│  ├─ game_over/
│  ├─ hi_score/
│  └─ settings/
└─ assets/
	└─ images/
```

---

## Troubleshooting

### Project does not open

- Make sure you selected the correct `project.godot` file.
- Confirm you are using **Godot 4.6.1**.

### Parse/script errors on startup

- Re-open scripts and check for syntax errors in the Output panel.
- Ensure line endings/encoding were not changed by external tools.

### Missing textures or broken imports

- Do not delete `.import` files/folders.
- In Godot, use **Project → Tools → Reimport**.

### Export fails

- Verify export templates are installed for **4.6.1**.
- Check export preset configuration in **Project → Export**.

### macOS app blocked by security

- Open **System Settings → Privacy & Security** and allow app execution.

---

## Recommended Tools

- **Godot 4.6.1** (required)
- **Git** (recommended)
- **Visual Studio Code** with Godot/GDScript extensions (optional)

---

If you want, you can extend this README with controls, gameplay rules, and screenshots once those details are finalized.
