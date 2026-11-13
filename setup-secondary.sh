#!/usr/bin/env bash
# ==============================================================================
# Antigravity Standalone Second Instance Setup Script
# https://github.com/Zauwad/my-antigravity-installer
#
# Sets up a completely separate, standalone second installation for
# Antigravity Desktop 2.0 and Antigravity IDE to allow two Google Pro accounts
# to run simultaneously with zero shared storage, zero account collisions,
# and separate native dock icons.
#
# Usage:
#   ./setup-secondary.sh [install|status|uninstall]
# ==============================================================================

set -euo pipefail

RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
CYAN='\033[1;36m'
NC='\033[0m'

info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$1"
}

success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
}

warn() {
    printf "${YELLOW}[WARN]${NC} %s\n" "$1"
}

error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
}

REAL_HOME="${HOME}"
OPT_DIR="$REAL_HOME/.local/opt"
BIN_DIR="$REAL_HOME/.local/bin"
DESKTOP_DIR="$REAL_HOME/.local/share/applications"
ICONS_DIR="$REAL_HOME/.local/share/icons/hicolor/512x512/apps"

PRIMARY_DESK="$OPT_DIR/antigravity"
PRIMARY_IDE="$OPT_DIR/antigravity-ide"

SEC_DESK="$OPT_DIR/antigravity2"
SEC_IDE="$OPT_DIR/antigravity-ide2"

generate_badged_icons() {
    info "Generating distinct icons with instance '2' badge..."
    python3 - << 'PYEOF'
import os
from PIL import Image, ImageDraw, ImageFont

def badge_icon(src_path, dst_path):
    if not os.path.exists(src_path):
        return
    img = Image.open(src_path).convert("RGBA")
    w, h = img.size
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    
    radius = int(w * 0.20)
    cx = int(w * 0.78)
    cy = int(h * 0.78)
    
    draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=(255, 255, 255, 255))
    inner_r = int(radius * 0.88)
    draw.ellipse([cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r], fill=(30, 115, 240, 255))
    
    font_size = int(radius * 1.3)
    font = None
    for fp in [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
    ]:
        if os.path.exists(fp):
            font = ImageFont.truetype(fp, font_size)
            break
    if font is None:
        font = ImageFont.load_default()
    
    bbox = draw.textbbox((0, 0), "2", font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = cx - tw / 2 - bbox[0]
    ty = cy - th / 2 - bbox[1]
    draw.text((tx, ty), "2", fill=(255, 255, 255, 255), font=font)
    
    final_img = Image.alpha_composite(img, overlay)
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    final_img.save(dst_path, "PNG")

badge_icon("/home/ridwanul/.local/share/icons/hicolor/512x512/apps/antigravity.png",
           "/home/ridwanul/.local/share/icons/hicolor/512x512/apps/antigravity2.png")
badge_icon("/home/ridwanul/.local/share/icons/hicolor/512x512/apps/antigravity-ide.png",
           "/home/ridwanul/.local/share/icons/hicolor/512x512/apps/antigravity-ide2.png")
PYEOF
}

patch_desktop_app_asar() {
    local asar_path="$SEC_DESK/resources/app.asar"
    if [ ! -f "$asar_path" ]; then
        error "app.asar not found at $asar_path"
        return 1
    fi

    info "Patching Antigravity 2 package identity and token isolation in app.asar..."
    local tmp_dir
    tmp_dir="$(mktemp -d /tmp/antigravity2-asar-XXXXXX)"

    npx --yes asar extract "$asar_path" "$tmp_dir"

    python3 - << PYEOF
import json

# 1. Update package.json identity
with open("$tmp_dir/package.json", "r") as f:
    pkg = json.load(f)
pkg["name"] = "antigravity2"
pkg["productName"] = "Antigravity2"
with open("$tmp_dir/package.json", "w") as f:
    json.dump(pkg, f, indent=2)

# 2. Isolate language_server to use independent file token storage (bypass Keyring)
with open("$tmp_dir/dist/languageServer.js", "r") as f:
    ls_code = f.read()
target = "const env = { ...process.env, ...loginShellEnv };"
replacement = "const env = { ...process.env, ...loginShellEnv };\\n        env['SSH_CONNECTION'] = '127.0.0.1 1 127.0.0.1 2';\\n        env['HOME'] = '$REAL_HOME/.antigravity2-profile';"
if target in ls_code and "SSH_CONNECTION" not in ls_code:
    ls_code = ls_code.replace(target, replacement, 1)
    with open("$tmp_dir/dist/languageServer.js", "w") as f:
        f.write(ls_code)
PYEOF

    npx --yes asar pack "$tmp_dir" "$asar_path"
    rm -rf "$tmp_dir"
}

patch_ide_manifests() {
    info "Patching Antigravity IDE 2 product and package definitions..."
    local prod_path="$SEC_IDE/resources/app/product.json"
    local pkg_path="$SEC_IDE/resources/app/package.json"
    local app_dir="$SEC_IDE/resources/app"

    python3 - << PYEOF
import json, os

if os.path.exists("$prod_path"):
    with open("$prod_path", "r") as f:
        prod = json.load(f)
    prod["nameShort"] = "Antigravity IDE 2"
    prod["nameLong"] = "Antigravity IDE 2"
    prod["applicationName"] = "antigravity-ide2"
    prod["aliasName"] = "agy-ide2"
    prod["dataFolderName"] = ".antigravity-ide2"
    prod["win32MutexName"] = "antigravity-ide2"
    prod["win32AppUserModelId"] = "Google.AntigravityIDE2"
    prod["serverApplicationName"] = "antigravity-ide-server2"
    prod["serverDataFolderName"] = ".antigravity-ide-server2"
    prod["linuxIconName"] = "antigravity-ide2"
    prod["desktopName"] = "antigravity-ide2.desktop"
    with open("$prod_path", "w") as f:
        json.dump(prod, f, indent=4)

if os.path.exists("$pkg_path"):
    with open("$pkg_path", "r") as f:
        pkg = json.load(f)
    pkg["name"] = "antigravity-ide2"
    pkg["desktopName"] = "antigravity-ide2.desktop"
    with open("$pkg_path", "w") as f:
        json.dump(pkg, f, indent=4)

# Patch inlined desktopName in built JS bundles so Wayland/GNOME maps window exclusively to antigravity-ide2.desktop
for js_file in ["out/bootstrap-fork.js", "out/main.js", "out/cli.js"]:
    p = os.path.join("$app_dir", js_file)
    if os.path.exists(p):
        with open(p, "r") as f:
            c = f.read()
        if '"desktopName":"antigravity-ide.desktop"' in c:
            c = c.replace('"desktopName":"antigravity-ide.desktop"', '"desktopName":"antigravity-ide2.desktop"')
            with open(p, "w") as f:
                f.write(c)
PYEOF
}

install_secondary() {
    printf "${BOLD}${CYAN}================================================================${NC}\n"
    printf "${BOLD}${CYAN}     Installing Standalone Second Instance (Antigravity 2)     ${NC}\n"
    printf "${BOLD}${CYAN}================================================================${NC}\n\n"

    # 1. Antigravity Desktop 2
    if [ ! -d "$PRIMARY_DESK" ]; then
        error "Primary Antigravity not found at '$PRIMARY_DESK'. Please run install.sh first."
        exit 1
    fi

    info "Setting up standalone Antigravity Desktop 2 engine..."
    rm -rf "$SEC_DESK"
    cp -r "$PRIMARY_DESK" "$SEC_DESK"

    patch_desktop_app_asar

    if [ -f "$SEC_DESK/antigravity" ]; then
        mv "$SEC_DESK/antigravity" "$SEC_DESK/antigravity2"
    fi
    success "Configured Desktop 2 Engine at '$SEC_DESK'"

    # 2. Antigravity IDE 2
    if [ -d "$PRIMARY_IDE" ]; then
        info "Setting up standalone Antigravity IDE 2 engine..."
        rm -rf "$SEC_IDE"
        cp -r "$PRIMARY_IDE" "$SEC_IDE"

        patch_ide_manifests

        if [ -f "$SEC_IDE/antigravity-ide" ]; then
            mv "$SEC_IDE/antigravity-ide" "$SEC_IDE/antigravity-ide2"
        fi
        if [ -f "$SEC_IDE/bin/antigravity-ide" ]; then
            mv "$SEC_IDE/bin/antigravity-ide" "$SEC_IDE/bin/antigravity-ide2"
            sed -i 's|ELECTRON="$VSCODE_PATH/antigravity-ide"|ELECTRON="$VSCODE_PATH/antigravity-ide2"|' "$SEC_IDE/bin/antigravity-ide2"
        fi
        success "Configured IDE 2 Engine at '$SEC_IDE'"
    fi

    # 3. Icons
    generate_badged_icons
    if [ -f "$ICONS_DIR/antigravity2.png" ]; then
        cp "$ICONS_DIR/antigravity2.png" "$SEC_DESK/icon.png"
    fi
    if [ -f "$ICONS_DIR/antigravity-ide2.png" ]; then
        cp "$ICONS_DIR/antigravity-ide2.png" "$SEC_IDE/icon.png"
    fi

    # 4. Profile & Developer Config Symlinks
    local sec_profile="$REAL_HOME/.antigravity2-profile"
    mkdir -p "$sec_profile"
    if [ -d "$REAL_HOME/.ssh" ]; then
        ln -sfn "$REAL_HOME/.ssh" "$sec_profile/.ssh"
    fi
    if [ -f "$REAL_HOME/.gitconfig" ]; then
        ln -sfn "$REAL_HOME/.gitconfig" "$sec_profile/.gitconfig"
    fi

    # 5. Ecosystem Sharing (Skills, Plugins, MCP, Rules, IDE Extensions & Settings)
    info "Linking shared ecosystem (skills, plugins, MCP, rules, IDE extensions & settings)..."
    mkdir -p "$sec_profile/.gemini/config" "$sec_profile/.gemini/antigravity" "$sec_profile/.gemini/antigravity2"

    # Skills & Plugins
    if [ -d "$REAL_HOME/.gemini/config/skills" ]; then
        rm -rf "$sec_profile/.gemini/config/skills"
        ln -sfn "$REAL_HOME/.gemini/config/skills" "$sec_profile/.gemini/config/skills"
    fi
    if [ -d "$REAL_HOME/.gemini/config/skills set aside" ]; then
        rm -rf "$sec_profile/.gemini/config/skills set aside"
        ln -sfn "$REAL_HOME/.gemini/config/skills set aside" "$sec_profile/.gemini/config/skills set aside"
    fi
    if [ -d "$REAL_HOME/.gemini/config/plugins" ]; then
        rm -rf "$sec_profile/.gemini/config/plugins"
        ln -sfn "$REAL_HOME/.gemini/config/plugins" "$sec_profile/.gemini/config/plugins"
    fi

    # MCP config & rules
    if [ -f "$REAL_HOME/.gemini/config/mcp_config.json" ]; then
        ln -sfn "$REAL_HOME/.gemini/config/mcp_config.json" "$sec_profile/.gemini/config/mcp_config.json"
    fi
    if [ -f "$REAL_HOME/.gemini/config/AGENTS.md" ]; then
        ln -sfn "$REAL_HOME/.gemini/config/AGENTS.md" "$sec_profile/.gemini/config/AGENTS.md"
        ln -sfn "$REAL_HOME/.gemini/config/AGENTS.md" "$sec_profile/.gemini/AGENTS.md"
        ln -sfn "$REAL_HOME/.gemini/config/AGENTS.md" "$sec_profile/.gemini/GEMINI.md"
    fi

    # MCP tool schemas & plugin binaries
    if [ -d "$REAL_HOME/.gemini/antigravity/mcp" ]; then
        ln -sfn "$REAL_HOME/.gemini/antigravity/mcp" "$sec_profile/.gemini/antigravity/mcp"
        ln -sfn "$REAL_HOME/.gemini/antigravity/mcp" "$sec_profile/.gemini/antigravity2/mcp"
    fi
    if [ -d "$REAL_HOME/.gemini/antigravity/plugin_data" ]; then
        ln -sfn "$REAL_HOME/.gemini/antigravity/plugin_data" "$sec_profile/.gemini/antigravity/plugin_data"
        ln -sfn "$REAL_HOME/.gemini/antigravity/plugin_data" "$sec_profile/.gemini/antigravity2/plugin_data"
    fi

    # Mirror config.json plugins & userSettings (excluding background sidecar crons)
    python3 - << 'PYEOF'
import json, os

primary_cfg_file = "/home/ridwanul/.gemini/config/config.json"
sec_cfg_file = "/home/ridwanul/.antigravity2-profile/.gemini/config/config.json"

if os.path.exists(primary_cfg_file):
    with open(primary_cfg_file, "r") as f:
        primary_cfg = json.load(f)
    
    sec_cfg = {}
    if os.path.exists(sec_cfg_file):
        try:
            with open(sec_cfg_file, "r") as f:
                sec_cfg = json.load(f)
        except Exception:
            pass

    sec_cfg["plugins"] = primary_cfg.get("plugins", {})
    sec_cfg["sidecars"] = {}
    
    sec_hostname = sec_cfg.get("userSettings", {}).get("remoteControlHostname")
    sec_cfg["userSettings"] = primary_cfg.get("userSettings", {}).copy()
    if sec_hostname:
        sec_cfg["userSettings"]["remoteControlHostname"] = sec_hostname

    with open(sec_cfg_file, "w") as f:
        json.dump(sec_cfg, f, indent=2)
PYEOF

    # IDE Extensions & User Settings
    if [ -d "$REAL_HOME/.antigravity-ide/extensions" ]; then
        rm -rf "$sec_profile/.antigravity-ide2/extensions"
        mkdir -p "$sec_profile/.antigravity-ide2"
        ln -sfn "$REAL_HOME/.antigravity-ide/extensions" "$sec_profile/.antigravity-ide2/extensions"
    fi
    mkdir -p "$sec_profile/.config/Antigravity IDE 2/User"
    if [ -f "$REAL_HOME/.config/Antigravity IDE/User/settings.json" ]; then
        ln -sfn "$REAL_HOME/.config/Antigravity IDE/User/settings.json" "$sec_profile/.config/Antigravity IDE 2/User/settings.json"
    fi
    if [ -d "$REAL_HOME/.config/Antigravity IDE/User/snippets" ]; then
        rm -rf "$sec_profile/.config/Antigravity IDE 2/User/snippets"
        ln -sfn "$REAL_HOME/.config/Antigravity IDE/User/snippets" "$sec_profile/.config/Antigravity IDE 2/User/snippets"
    fi
    if [ -f "$REAL_HOME/.config/Antigravity IDE/User/keybindings.json" ]; then
        ln -sfn "$REAL_HOME/.config/Antigravity IDE/User/keybindings.json" "$sec_profile/.config/Antigravity IDE 2/User/keybindings.json"
    fi
    success "Ecosystem assets and IDE extensions linked"

    # 6. Launchers
    mkdir -p "$BIN_DIR"

    cat << 'EOF' > "$BIN_DIR/antigravity2"
#!/usr/bin/env bash
set -e

REAL_HOME="${REAL_HOME:-$HOME}"
export HOME="${REAL_HOME}/.antigravity2-profile"
export SSH_CONNECTION="127.0.0.1 1 127.0.0.1 2"

APP_DIR="${REAL_HOME}/.local/opt/antigravity2"
USER_DATA_DIR="${HOME}/.config/Antigravity2"

mkdir -p "$USER_DATA_DIR"

if [ ! -d "$APP_DIR" ]; then
    printf "\033[1;31m[ERROR]\033[0m Antigravity 2 not found at %s\n" "$APP_DIR" >&2
    exit 1
fi

SANDBOX_ARG=""
if [ -f "$APP_DIR/chrome-sandbox" ] && [ ! -u "$APP_DIR/chrome-sandbox" ]; then
    SANDBOX_ARG="--no-sandbox"
fi

exec "$APP_DIR/antigravity2" \
    --class=antigravity2 \
    --name=antigravity2 \
    --user-data-dir="$USER_DATA_DIR" \
    $SANDBOX_ARG "$@"
EOF
    chmod 755 "$BIN_DIR/antigravity2"

    cat << 'EOF' > "$BIN_DIR/antigravity-ide2"
#!/usr/bin/env bash
set -e

REAL_HOME="${REAL_HOME:-$HOME}"
export HOME="${REAL_HOME}/.antigravity2-profile"
export SSH_CONNECTION="127.0.0.1 1 127.0.0.1 2"

APP_BIN="${REAL_HOME}/.local/opt/antigravity-ide2/bin/antigravity-ide2"
USER_DATA_DIR="$HOME/.config/Antigravity IDE 2"
EXTENSIONS_DIR="$HOME/.antigravity-ide2/extensions"

mkdir -p "$USER_DATA_DIR" "$EXTENSIONS_DIR"

exec "$APP_BIN" \
    --class=antigravity-ide2 \
    --name=antigravity-ide2 \
    --user-data-dir "$USER_DATA_DIR" \
    --extensions-dir "$EXTENSIONS_DIR" \
    "$@"
EOF
    chmod 755 "$BIN_DIR/antigravity-ide2"

    ln -sfn "$BIN_DIR/antigravity-ide2" "$BIN_DIR/agy-ide2"
    success "Created binary launchers in '$BIN_DIR'"

    # 5. Desktop Entries
    mkdir -p "$DESKTOP_DIR"

    cat << EOF > "$DESKTOP_DIR/antigravity2.desktop"
[Desktop Entry]
Name=Antigravity 2
Comment=Antigravity 2.0 Desktop Application (Second Instance)
GenericName=AI Agent Platform
Exec=$BIN_DIR/antigravity2 %U
Icon=$ICONS_DIR/antigravity2.png
Type=Application
StartupNotify=true
StartupWMClass=antigravity2
Categories=Development;
EOF
    chmod 644 "$DESKTOP_DIR/antigravity2.desktop"

    cat << EOF > "$DESKTOP_DIR/antigravity-ide2.desktop"
[Desktop Entry]
Name=Antigravity IDE 2
Comment=AI-first Integrated Development Environment (Second Instance)
GenericName=Text Editor
Exec=$BIN_DIR/antigravity-ide2 %F
Icon=$ICONS_DIR/antigravity-ide2.png
Type=Application
StartupNotify=true
StartupWMClass=antigravity-ide2
Categories=Development;IDE;TextEditor;
MimeType=text/plain;inode/directory;
Actions=new-empty-window;

[Desktop Action new-empty-window]
Name=New Empty Window
Exec=$BIN_DIR/antigravity-ide2 --new-window %F
Icon=$ICONS_DIR/antigravity-ide2.png
EOF
    chmod 644 "$DESKTOP_DIR/antigravity-ide2.desktop"

    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
    gtk-update-icon-cache -f -t "$REAL_HOME/.local/share/icons/hicolor" 2>/dev/null || true
    success "Desktop integration registered with separate Wayland WMClasses"

    printf "\n${BOLD}${GREEN}✔ Second Instance installation completed successfully!${NC}\n"
    printf "Launch commands:\n"
    printf "  - Antigravity Desktop 2: ${CYAN}antigravity2${NC}\n"
    printf "  - Antigravity IDE 2:     ${CYAN}antigravity-ide2${NC} (or ${CYAN}agy-ide2${NC})\n"
}

uninstall_secondary() {
    info "Uninstalling Standalone Second Instance..."
    rm -rf "$SEC_DESK" "$SEC_IDE"
    rm -f "$BIN_DIR/antigravity2" "$BIN_DIR/antigravity-ide2" "$BIN_DIR/agy-ide2"
    rm -f "$DESKTOP_DIR/antigravity2.desktop" "$DESKTOP_DIR/antigravity-ide2.desktop"
    rm -f "$ICONS_DIR/antigravity2.png" "$ICONS_DIR/antigravity-ide2.png"
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
    success "Standalone Second Instance uninstalled (user data in ~/.config and ~/.gemini preserved)."
}

status_secondary() {
    printf "${BOLD}Antigravity Instance Status:${NC}\n"
    printf "  Primary Desktop:   %s\n" "$([ -d "$PRIMARY_DESK" ] && echo -e "${GREEN}Installed${NC}" || echo -e "${RED}Not Found${NC}")"
    printf "  Primary IDE:       %s\n" "$([ -d "$PRIMARY_IDE" ] && echo -e "${GREEN}Installed${NC}" || echo -e "${RED}Not Found${NC}")"
    printf "  Secondary Desktop: %s\n" "$([ -d "$SEC_DESK" ] && echo -e "${GREEN}Installed (Standalone)${NC}" || echo -e "${YELLOW}Not Installed${NC}")"
    printf "  Secondary IDE:     %s\n" "$([ -d "$SEC_IDE" ] && echo -e "${GREEN}Installed (Standalone)${NC}" || echo -e "${YELLOW}Not Installed${NC}")"
}

ACTION="${1:-install}"
case "$ACTION" in
    install)
        install_secondary
        ;;
    uninstall)
        uninstall_secondary
        ;;
    status)
        status_secondary
        ;;
    *)
        error "Unknown action: $ACTION. Supported: install, uninstall, status"
        exit 1
        ;;
esac
