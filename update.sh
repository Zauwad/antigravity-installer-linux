#!/usr/bin/env bash
# Antigravity Updater shortcut
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run primary updater
"${SCRIPT_DIR}/install.sh" update "$@"

# If secondary instance exists, automatically keep its engine and ecosystem in sync
if { [ -d "$HOME/.local/opt/antigravity2" ] || [ -d "$HOME/.local/opt/antigravity-ide2" ]; } && [ -f "${SCRIPT_DIR}/setup-secondary.sh" ]; then
    printf "\n\033[1;34m[INFO]\033[0m Synchronizing Second instance assets and ecosystem with updated engine...\n"
    "${SCRIPT_DIR}/setup-secondary.sh" install
    printf "\033[1;32m[SUCCESS]\033[0m Both instances (Antigravity & Antigravity 2) are now running the latest version!\n"
fi
