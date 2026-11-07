#!/usr/bin/env bash
# ==============================================================================
# Antigravity Linux Universal Installer & Updater
# https://github.com/Zauwad/my-antigravity-installer
#
# Usage:
#   ./install.sh [install|update|check|uninstall] [options]
#   curl -fsSL https://raw.githubusercontent.com/Zauwad/my-antigravity-installer/main/install.sh | bash
# ==============================================================================

set -euo pipefail

# ANSI color output helpers
RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
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

# 1. Dependency checks
if ! command -v python3 >/dev/null 2>&1; then
    error "Python 3 is required but was not found on your system."
    printf "Please install python3 using your package manager (e.g. 'sudo apt install python3' or 'sudo dnf install python3').\n"
    exit 1
fi

if ! command -v tar >/dev/null 2>&1; then
    error "'tar' utility is required for archive extraction."
    printf "Please install tar using your package manager.\n"
    exit 1
fi

# 2. Locate the installer engine
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
PY_INSTALLER="${SCRIPT_DIR}/antigravity-installer.py"

# If executing via pipe (curl | bash) or script was moved standalone
if [ ! -f "${PY_INSTALLER}" ]; then
    info "Installer engine not found locally; fetching latest release runner..."
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "${TMP_DIR}"' EXIT
    PY_INSTALLER="${TMP_DIR}/antigravity-installer.py"

    REPO_URL="${ANTIGRAVITY_INSTALLER_RAW_URL:-https://raw.githubusercontent.com/Zauwad/my-antigravity-installer/main/antigravity-installer.py}"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${REPO_URL}" -o "${PY_INSTALLER}" || true
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "${PY_INSTALLER}" "${REPO_URL}" || true
    fi

    if [ ! -s "${PY_INSTALLER}" ]; then
        warn "Could not fetch remote installer script directly. Using standard release discovery."
    fi
fi

# Execute Python installer engine
exec python3 "${PY_INSTALLER}" "$@"
