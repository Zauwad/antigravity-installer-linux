# my-antigravity-installer

> This is my portable, zero-dependency Linux installer and in-place updater for Google Antigravity IDE and Desktop. It handles clean user-space installations, AppArmor sandbox fixes, desktop shortcuts, and updates across distributions. Take what works for you.

Like many developers running Linux as their daily driver, I rely heavily on Google Antigravity. However, managing raw tarball releases, manually configuring `.desktop` shortcuts, dealing with missing high-res icons, and troubleshooting Chromium/Electron SUID sandbox crashes caused by modern AppArmor user namespace restrictions (`kernel.apparmor_restrict_unprivileged_userns`) became repetitive and frustrating.

I didn't want to grant root or `sudo` permissions just to run an IDE, maintain brittle symlinks across machines, or have applications break after an OS upgrade.

I built this: a self-contained, zero-dependency installer and update engine written strictly in standard-library Python 3 and Bash. It automatically detects architecture, resolves official release streams, extracts icons straight out of Electron's `app.asar` archive header, patches sandbox flags where needed, and keeps both **Antigravity IDE** and the **Antigravity 2.0 Desktop Application** up to date with a single command.

---

## Architecture

How the installer provisions, patches, and integrates Antigravity into your Linux environment:

```text
+------------------------------------------------------------------------+
|                      MY ANTIGRAVITY INSTALLER                          |
+------------------------------------------------------------------------+
|                                                                        |
|   ENVIRONMENT & ARCHITECTURE DISCOVERY                                 |
|      |                                                                 |
|      +-- Auto-detects x86_64 (amd64) vs aarch64 (arm64)                |
|      +-- Resolves user-space prefix (~/.local) or custom prefix        |
|      |                                                                 |
|      v                                                                 |
|   RELEASE ENGINE & FALLBACK CATALOG                                    |
|      |                                                                 |
|      +-- Live scrape from https://antigravity.google/download          |
|      +-- Built-in hardened fallback URLs (zero downtime)               |
|      +-- Offline tarball discovery (--tar-dir / --ide-tar)             |
|      |                                                                 |
|      v                                                                 |
|   ATOMIC INSTALLATION & ASAR DECODER                                   |
|      |                                                                 |
|      +-- Deploys IDE to ~/.local/opt/antigravity-ide                   |
|      +-- Deploys Desktop to ~/.local/opt/antigravity                   |
|      +-- Custom pure-Python ASAR binary reader extracts icon.png       |
|          (Zero Node.js, npm, or external packaging tool needed)        |
|      |                                                                 |
|      v                                                                 |
|   DESKTOP & RUNTIME INTEGRATION                                        |
|      |                                                                 |
|      +-- AppArmor / Unprivileged User Namespace Sandbox Guard          |
|      +-- XDG .desktop entries in ~/.local/share/applications           |
|      +-- High-res icons in ~/.local/share/icons/hicolor (512x & 1024x) |
|      +-- CLI wrappers in ~/.local/bin (antigravity, antigravity-ide)   |
|      +-- Automatic PATH export in ~/.bashrc or ~/.zshrc                |
|                                                                        |
+------------------------------------------------------------------------+
```

---

## Quickstart

Replicate or run this setup on any Linux machine in seconds:

### One-Liner (Zero-Clone Install)

```bash
curl -fsSL https://raw.githubusercontent.com/Zauwad/my-antigravity-installer/main/install.sh | bash
```

### Or Clone & Run

```bash
git clone git@github.com:Zauwad/my-antigravity-installer.git
cd my-antigravity-installer
chmod +x install.sh update.sh uninstall.sh
./install.sh
```

### Launching

Once installed, launch directly from your terminal or desktop application menu:

```bash
antigravity-ide      # Launches Antigravity IDE (alias: agy-ide)
antigravity          # Launches Antigravity 2.0 Desktop Application
```

---

## Repository Structure

```text
my-antigravity-installer/
├── antigravity-installer.py   # Core Python 3 installer & updater engine
├── install.sh                 # Universal entrypoint script (supports curl | bash)
├── update.sh                  # One-click updater shortcut
├── uninstall.sh               # Complete cleanup & uninstaller shortcut
├── .gitignore                 # Ignores archives, bytecode, and staging artifacts
├── LICENSE                    # MIT License
└── README.md                  # Documentation
```

---

## Core Capabilities & Engineering Highlights

### 1. Zero Root / Pure User-Space (`~/.local`)
By default, the installer targets `~/.local/opt` for binaries and `~/.local/bin` for launcher scripts. You never need `sudo` or elevated privileges. Everything remains isolated to your user profile, cleanly adhering to the XDG Base Directory specification.

### 2. Built-in Pure Python Electron ASAR Header Parser
Electron applications pack their assets into `resources/app.asar`. Extracting `icon.png` typically requires Node.js, `npx asar`, or third-party packages.
I wrote a binary unpacker directly in Python using `struct` and `json` to parse the 16-byte ASAR header, read the JSON directory table, compute the binary offset, and extract the high-resolution icon without needing Node.js or `npm` installed.

### 3. Ubuntu 24.04 / 26.04 AppArmor Sandbox Compatibility
Recent Linux distributions (starting with Ubuntu 24.04 LTS) restrict unprivileged user namespaces via `kernel.apparmor_restrict_unprivileged_userns=1`. This frequently causes Chromium and Electron SUID sandboxes to crash upon startup.
The installer automatically inspects the environment and patches launcher scripts to handle sandbox boundaries safely, ensuring flawless execution out of the box.

### 4. Live Scraper with Hardened Fallbacks
The engine queries `https://antigravity.google/download?os=linux` to discover official download endpoints on the fly. If network filters or page markup changes occur, it seamlessly falls back to a curated, tested release catalog so you are never left with a broken installer.

### 5. In-Place Atomic Updates
The installer keeps track of installed versions via `.version` markers. Running `./update.sh` (or `./install.sh update`) checks remote release tags, compares versions, and updates only what is out of date—saving bandwidth and disk writes.

---

## Usage Guide

### Install Options

Install both applications (default):
```bash
./install.sh
```

Install only **Antigravity IDE**:
```bash
./install.sh --ide-only
```

Install only **Antigravity Desktop**:
```bash
./install.sh --desktop-only
```

Install using pre-downloaded `.tar.gz` archives (offline mode):
```bash
./install.sh --tar-dir ~/Downloads
```

Install system-wide to `/usr/local` (requires sudo):
```bash
sudo ./install.sh --prefix /usr/local
```

### Checking for Updates

Check if newer versions exist without modifying anything:
```bash
./install.sh check
```

### Updating

Upgrade installed applications to the latest upstream version:
```bash
./update.sh
# or
./install.sh update
```

Force reinstallation even if versions match:
```bash
./update.sh --force
```

### Uninstalling

Remove binaries, opt directories, icons, desktop shortcuts, and launcher symlinks cleanly:
```bash
./uninstall.sh
```

---

## Command-Line Flags

| Flag | Description |
| :--- | :--- |
| `install` | Download and install applications (default action) |
| `update` | Check remote versions and update out-of-date components |
| `check` | Inspect local vs remote versions without downloading |
| `uninstall` | Completely remove installed binaries, opt folders, and desktop shortcuts |
| `--prefix <DIR>` | Custom install directory (default: `~/.local`) |
| `--ide-only` | Target only Antigravity IDE |
| `--desktop-only` | Target only Antigravity Desktop App |
| `--force` | Force re-download and reinstall even if versions match |
| `--no-desktop` | Skip `.desktop` shortcuts and icon registration (useful for headless/WSL) |
| `--tar-dir <DIR>` | Directory containing offline `.tar.gz` files |
| `--ide-tar <FILE>` | Specific archive for Antigravity IDE |
| `--desktop-tar <FILE>` | Specific archive for Antigravity Desktop |
| `--help` | Show full usage and help information |

---

## Directory Layout

When installed into the default prefix (`~/.local`):

```text
~/.local/
├── bin/
│   ├── antigravity          # Launcher wrapper for Desktop App (with sandbox check)
│   ├── antigravity-ide      # Launcher symlink for IDE
│   └── agy-ide              # Short alias for IDE
├── opt/
│   ├── antigravity/         # Antigravity Desktop Application runtime
│   └── antigravity-ide/     # Antigravity IDE application runtime
└── share/
    ├── applications/
    │   ├── antigravity.desktop
    │   └── antigravity-ide.desktop
    └── icons/hicolor/
        ├── 512x512/apps/
        └── 1024x1024/apps/
```

---

## Compatibility

Tested and verified across modern Linux distributions and desktop environments:

* **Distributions**: Ubuntu (20.04, 22.04, 24.04 LTS, 26.04), Debian (11, 12, Sid), Fedora (38, 39, 40, 41+), Arch Linux, Manjaro, openSUSE (Tumbleweed / Leap), RHEL / Rocky Linux / AlmaLinux
* **Architectures**: `x86_64` (`amd64`), `aarch64` (`arm64`)
* **Desktop Environments & Window Managers**: GNOME, KDE Plasma, XFCE, Cinnamon, MATE, Hyprland, Sway, i3

---

## Author

Ridwanul Azim (Zauwad)
* Portfolio: [ridwanul.dev](https://ridwanul.dev)
* GitHub: [@Zauwad](https://github.com/Zauwad)

---

## License

This project is open-source software licensed under the [MIT License](LICENSE).
