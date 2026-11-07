#!/usr/bin/env bash
# Antigravity Uninstaller shortcut
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/install.sh" uninstall "$@"
