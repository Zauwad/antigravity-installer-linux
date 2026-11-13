# Changelog

## [Unreleased]

### [Added] — 2026-11-14

**Time:** 2026-11-14 01:00 (UTC+06:00)
**Author:** Antigravity agent
**Issue:** Add multi-account second instance automation to updater and repository

**Summary:**
- Updated `update.sh` to automatically detect and synchronize secondary instances (Desktop and IDE) and their shared ecosystem assets whenever primary Antigravity is updated.
- Integrated `setup-secondary.sh` into the repository with full automated support for isolated token storage, dock window grouping, and ecosystem symlinking.
- Documented multi-account secondary instance setup commands and architecture in `README.md`.
- Staged, committed, and pushed changes to GitHub origin main.

**Files:**
- `update.sh`
- `setup-secondary.sh`
- `README.md`
- `.agents/workflow/CHANGELOG.md`

**Impact:** build env / config

### [Added] — 2026-11-14

**Time:** 2026-11-14 00:56 (UTC+06:00)
**Author:** Antigravity agent
**Issue:** Mirror ecosystem assets (skills, plugins, MCP servers, rules, IDE extensions & settings) for secondary Antigravity instances

**Summary:**
- Linked ecosystem assets from primary profile to `~/.antigravity2-profile` via live symlinks for automatic synchronization.
- Symlinked `skills/`, `plugins/`, `mcp_config.json`, `AGENTS.md`, and `GEMINI.md`.
- Symlinked MCP tool schemas (`mcp/`) and plugin binaries (`plugin_data/`) in both `antigravity` and `antigravity2` directories.
- Mirrored all 12 installed plugins and user performance settings (Turbo preset, eager auto-execution, permission grants) into `~/.antigravity2-profile/.gemini/config/config.json`, while isolating scheduled background cron sidecars to Instance 1.
- Symlinked IDE extensions (`~/.antigravity-ide/extensions` -> `~/.antigravity2-profile/.antigravity-ide2/extensions`) and user settings (`settings.json`, `snippets/`, `keybindings.json`).
- Updated `setup-secondary.sh` to permanently maintain these ecosystem symlinks and config mirroring on future setups.

**Files:**
- `~/.antigravity2-profile/.gemini/config/config.json`
- `~/.antigravity2-profile/.gemini/config/skills`
- `~/.antigravity2-profile/.gemini/config/plugins`
- `~/.antigravity2-profile/.gemini/config/mcp_config.json`
- `~/.antigravity2-profile/.gemini/config/AGENTS.md`
- `~/.antigravity2-profile/.gemini/AGENTS.md`
- `~/.antigravity2-profile/.gemini/GEMINI.md`
- `~/.antigravity2-profile/.gemini/antigravity/mcp`
- `~/.antigravity2-profile/.gemini/antigravity2/mcp`
- `~/.antigravity2-profile/.gemini/antigravity/plugin_data`
- `~/.antigravity2-profile/.gemini/antigravity2/plugin_data`
- `~/.antigravity2-profile/.antigravity-ide2/extensions`
- `~/.antigravity2-profile/.config/Antigravity IDE 2/User/settings.json`
- `~/.antigravity2-profile/.config/Antigravity IDE 2/User/snippets`
- `setup-secondary.sh`

**Impact:** UI / config

### [Fixed] — 2026-11-14

**Time:** 2026-11-14 00:48 (UTC+06:00)
**Author:** Antigravity agent
**Issue:** Isolate GNOME dock window grouping and active indicator dot for Antigravity IDE 2

**Summary:**
- Discovered that Electron initializes `a.setDesktopName(d.desktopName)` directly from `resources/app/package.json` before main bundle execution on Linux.
- Identified that `~/.local/opt/antigravity-ide2/resources/app/package.json` still contained `"desktopName": "antigravity-ide.desktop"`, causing Wayland/GNOME Shell to map running IDE 2 windows to `antigravity-ide.desktop` and place the running indicator dot on the primary IDE dock icon.
- Updated `desktopName` to `"antigravity-ide2.desktop"` in `package.json`, and set `linuxIconName` and `desktopName` in `product.json`.
- Patched inlined occurrences of `"desktopName":"antigravity-ide.desktop"` in `out/bootstrap-fork.js`, `out/main.js`, and `out/cli.js`.
- Updated `setup-secondary.sh` installer script to maintain these patches on future installations or updates.
- Refreshed desktop database and icon caches.

**Files:**
- `~/.local/opt/antigravity-ide2/resources/app/package.json`
- `~/.local/opt/antigravity-ide2/resources/app/product.json`
- `~/.local/opt/antigravity-ide2/resources/app/out/bootstrap-fork.js`
- `~/.local/opt/antigravity-ide2/resources/app/out/main.js`
- `~/.local/opt/antigravity-ide2/resources/app/out/cli.js`
- `setup-secondary.sh`

**Impact:** UI / config

### [Fixed] — 2026-11-14

**Time:** 2026-11-14 00:31 (UTC+6)
**Author:** Antigravity agent
**Issue:** Fix browser auth opening for Antigravity 2 by replacing DBUS disabling with native SSH session detection

**Summary:**
- Identified that setting `DBUS_SESSION_BUS_ADDRESS="disabled"` broke Electron's `shell.openExternal()` / Freedesktop Portal (`org.freedesktop.portal.OpenURI`), preventing the external browser from opening when clicking "Continue with Google".
- Discovered that Go's `composite_token_storage` natively inspects `SSH_CONNECTION` and logs `Using file-based token storage because SSH session detected`, cleanly bypassing GNOME Keyring without touching DBus.
- Removed `DBUS_SESSION_BUS_ADDRESS="disabled"` from launchers and `languageServer.js`, restoring full DBus functionality for `shell.openExternal()`.
- Set `SSH_CONNECTION="127.0.0.1 1 127.0.0.1 2"` in `languageServer.js` and launchers, guaranteeing file token storage at `~/.antigravity2-profile/.gemini/jetski-standalone-oauth-token` while allowing the OAuth authorization URL to open in the user's browser immediately.

**Files:**
- `setup-secondary.sh`

**Impact:** route / UI / build env / config

### [Fixed] — 2026-11-14

**Time:** 2026-11-14 00:24 (UTC+6)
**Author:** Antigravity agent
**Issue:** Enforce strict Wayland window class, single-instance socket, and user-data-dir isolation for Antigravity 2 & IDE 2

**Summary:**
- Discovered that without explicit `--class=antigravity2` and `--user-data-dir`, Chromium on Wayland defaulted window identification to `antigravity` and shared the single-instance socket under GNOME Shell, grouping secondary windows under the primary dock icon and triggering single-instance delegation to Instance 1.
- Updated `/home/ridwanul/.local/bin/antigravity2` to pass `--class=antigravity2`, `--name=antigravity2`, and explicit `--user-data-dir="${HOME}/.config/Antigravity2"`.
- Updated `/home/ridwanul/.local/bin/antigravity-ide2` to pass `--class=antigravity-ide2`, `--name=antigravity-ide2`, and explicit `--user-data-dir` and `--extensions-dir`.
- Updated `/home/ridwanul/WorkStuff/antigravity-installer/setup-secondary.sh` to permanently generate isolated launchers with explicit Chromium class and profile directory flags.
- Patched `antigravity-ide2` internal CLI discovery to prioritize `antigravity-ide2`.

**Files:**
- `setup-secondary.sh`

**Impact:** route / UI / build env / config

### [Fixed] — 2026-11-14

**Time:** 2026-11-14 00:08 (UTC+6)
**Author:** Antigravity agent
**Issue:** Complete token storage and session isolation for Antigravity 2 (Disable DBus fallback to prevent GNOME Keyring sharing)

**Summary:**
- Identified through strace that setting `DBUS_SESSION_BUS_ADDRESS=""` (empty string) caused libdbus/go-keyring to fall back to `/run/user/1000/bus`, connecting directly to GNOME Keyring and retrieving Account 1's tokens.
- Explicitly set `DBUS_SESSION_BUS_ADDRESS="disabled"` in both the Electron launcher and `languageServer.js`, forcing Go's `compositeTokenStorage` to fail keyring access and fall back to file storage.
- Routed secondary profile and file tokens into dedicated `~/.antigravity2-profile` (`~/.antigravity2-profile/.gemini/jetski-standalone-oauth-token`), preventing any token collision with Account 1.
- Terminated lingering background secondary processes from previous runs that were holding the old single-instance socket.
- Cleaned up obsolete configuration directories and updated `setup-secondary.sh`.

**Files:**
- `setup-secondary.sh`

**Impact:** build env / backend / config

### [Fixed] — 2026-11-13

**Time:** 2026-11-13 23:53 (UTC+6)
**Author:** Antigravity agent
**Issue:** Standalone separate installation for Antigravity and Antigravity IDE (Multi-account isolation & dock separation)

**Summary:**
- Replaced wrapper/profile symlink strategy with completely separate standalone engines at `~/.local/opt/antigravity2` and `~/.local/opt/antigravity-ide2`.
- Repackaged Electron `app.asar` for Desktop 2 with `"name": "antigravity2"` and `"productName": "Antigravity2"`, enabling native Wayland `app_id` separation on GNOME Shell and dedicated `~/.config/Antigravity2` user data.
- Patched `languageServer.js` to isolate `DBUS_SESSION_BUS_ADDRESS`, routing secondary OAuth tokens into file-based storage (`~/.gemini/antigravity2`) without touching Account 1 in GNOME Keyring.
- Patched Antigravity IDE 2 manifests (`product.json` & `package.json`) to declare `antigravity-ide2` identity, with isolated configurations in `~/.config/Antigravity IDE 2` and `~/.antigravity-ide2`.
- Generated crisp blue '2'-badged icons for both applications and registered distinct `.desktop` entries with matching `StartupWMClass`.
- Updated `update.sh` and `README.md` to support seamless synchronization of both instances.

**Files:**
- `setup-secondary.sh`
- `update.sh`
- `README.md`

**Impact:** UI / build env / config

### [Fixed] — 2026-11-13

**Time:** 2026-11-13 23:24 (UTC+6)
**Author:** Antigravity agent
**Issue:** Resolve auth client initialization error and isolate keyring token storage

**Summary:**
- Preserved `--override_ide_name antigravity` and `--override_user_agent_name antigravity` in the secondary `language_server` wrapper to maintain `antigravity-hub` mode and re-enable interactive OAuth login.
- Unset `DBUS_SESSION_BUS_ADDRESS` exclusively within the `language_server` process, activating Go's built-in `shouldBypassKeyring` detector to store secondary tokens cleanly in file-based storage (`~/.antigravity-profiles/secondary/.gemini`) rather than colliding with Account 1 in GNOME Keyring.
- Re-deployed secondary instance provisioner via `setup-secondary.sh install`.

**Files:**
- `setup-secondary.sh`

### [Fixed] — 2026-11-13

**Time:** 2026-11-13 22:42 (UTC+6)
**Author:** Antigravity agent
**Issue:** Fix GNOME dock grouping and OAuth credential clobbering across dual instances

**Summary:**
- Resolved GNOME Wayland dock window grouping by using hardlinked engines with separate binary names (`antigravity-sec` and `antigravity-ide-sec`) matching `StartupWMClass`.
- Intercepted `language_server` via an execution wrapper to remap `--override_ide_name`, `--override_user_agent_name`, and `--app_data_dir` to `antigravity-sec`.
- Exported `ANTIGRAVITY_CREDENTIAL_SCOPE="antigravity-sec"` to cleanly namespace GNOME Keyring entries and prevent OAuth token collisions.
- Provisioned clean secondary profile environment and refreshed launcher scripts.

**Files:**
- `setup-secondary.sh`

### [Added] — 2026-11-13

**Time:** 2026-11-13 21:55 (UTC+6)
**Author:** Antigravity agent
**Issue:** Support secondary Antigravity & Antigravity IDE instances for multi-account usage

**Summary:**
- Added `setup-secondary.sh` to provision an isolated secondary profile environment (`~/.antigravity-profiles/secondary`).
- Configured dedicated CLI launchers (`antigravity-sec`, `antigravity-ide-sec`, and alias `agy-ide-sec`) and `.desktop` menu entries.
- Programmatically generated high-resolution badged application icons with visual accents for clean identification in docks and window switchers.
- Reuses core engine binaries, VS Code extensions, and agent skills while keeping login tokens, session caches, and SQLite databases completely decoupled.
- Updated `update.sh` to automatically synchronize the secondary instance's assets whenever primary binaries are upgraded.
- Updated `README.md` with multi-account documentation.

**Files:**
- `setup-secondary.sh`
- `update.sh`
- `README.md`

**Impact:** config / build env
