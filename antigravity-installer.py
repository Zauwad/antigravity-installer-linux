#!/usr/bin/env python3
"""
Antigravity Universal Linux Installer & Updater
https://github.com/Zauwad/my-antigravity-installer

Universal installer and updater for Antigravity IDE and Antigravity Desktop
on any Linux distribution (Ubuntu, Debian, Fedora, Arch, openSUSE, etc.).
No root or sudo privileges required by default.
"""

import argparse
import json
import os
import platform
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import urllib.request
import urllib.error

VERSION = "1.0.0"
PAGE_URL = "https://antigravity.google/download?os=linux"

# Known fallback URLs in case the download page markup changes
FALLBACK_RELEASES = {
    "linux-x64": {
        "ide": {
            "url": "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.6.0-5526304964083712/linux-x64/Antigravity%20IDE.tar.gz",
            "version": "2.6.0-5526304964083712",
        },
        "desktop": {
            "url": "https://storage.googleapis.com/antigravity-public/antigravity-hub/2.29.0-5723181030440960/linux-x64/Antigravity.tar.gz",
            "version": "2.29.0-5723181030440960",
        },
    },
    "linux-arm": {
        "ide": {
            "url": "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.6.0-5526304964083712/linux-arm/Antigravity%20IDE.tar.gz",
            "version": "2.6.0-5526304964083712",
        },
        "desktop": {
            "url": "https://storage.googleapis.com/antigravity-public/antigravity-hub/2.29.0-5723181030440960/linux-arm/Antigravity.tar.gz",
            "version": "2.29.0-5723181030440960",
        },
    },
}


def log(msg, level="INFO"):
    prefixes = {
        "INFO": "\033[1;34m[INFO]\033[0m",
        "SUCCESS": "\033[1;32m[SUCCESS]\033[0m",
        "WARN": "\033[1;33m[WARN]\033[0m",
        "ERROR": "\033[1;31m[ERROR]\033[0m",
    }
    prefix = prefixes.get(level, f"[{level}]")
    print(f"{prefix} {msg}")


def detect_architecture():
    machine = platform.machine().lower()
    if machine in ("x86_64", "amd64"):
        return "linux-x64"
    elif machine in ("aarch64", "arm64", "armv8l"):
        return "linux-arm"
    else:
        log(f"Unsupported processor architecture: {machine}", "ERROR")
        log("Antigravity currently supports linux-x64 (x86_64) and linux-arm (aarch64).", "ERROR")
        sys.exit(1)


def fetch_release_info(arch_tag):
    log(f"Fetching release metadata from {PAGE_URL}...")
    headers = {
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0"
    }
    html = None
    try:
        req = urllib.request.Request(PAGE_URL, headers=headers)
        with urllib.request.urlopen(req, timeout=15) as resp:
            html = resp.read().decode("utf-8")
    except Exception as e:
        log(f"Failed to fetch live download page: {e}", "WARN")
        log("Falling back to embedded release endpoints...", "WARN")

    if html:
        tar_links = set(re.findall(r"https://[^\s\"\'<>]+\.tar\.gz", html))
        ide_links = [l for l in tar_links if "Antigravity%20IDE" in l and arch_tag in l]
        desktop_links = [l for l in tar_links if "Antigravity.tar.gz" in l and arch_tag in l]

        if ide_links and desktop_links:
            ide_url = ide_links[0]
            desktop_url = desktop_links[0]

            ide_m = re.search(r"/(?:stable|releases?)/([^/]+)/" + re.escape(arch_tag), ide_url)
            desktop_m = re.search(r"/antigravity-hub/([^/]+)/" + re.escape(arch_tag), desktop_url)

            return {
                "ide": {"url": ide_url, "version": ide_m.group(1) if ide_m else "latest"},
                "desktop": {"url": desktop_url, "version": desktop_m.group(1) if desktop_m else "latest"},
            }

    # Fallback to predefined catalogue
    if arch_tag in FALLBACK_RELEASES:
        return FALLBACK_RELEASES[arch_tag]

    log("Could not resolve download links for architecture: " + arch_tag, "ERROR")
    sys.exit(1)


def download_with_progress(url, dest_path):
    log(f"Downloading: {url}")
    headers = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64)"}
    req = urllib.request.Request(url, headers=headers)

    with urllib.request.urlopen(req) as resp, open(dest_path, "wb") as out:
        total_len = resp.getheader("Content-Length")
        total_bytes = int(total_len) if total_len else None
        downloaded = 0
        chunk_size = 1024 * 1024  # 1MB

        while True:
            chunk = resp.read(chunk_size)
            if not chunk:
                break
            out.write(chunk)
            downloaded += len(chunk)

            if total_bytes:
                pct = (downloaded / total_bytes) * 100
                mb = downloaded / (1024 * 1024)
                tot_mb = total_bytes / (1024 * 1024)
                sys.stdout.write(f"\r  \033[36mProgress:\033[0m {mb:.1f} MB / {tot_mb:.1f} MB ({pct:.1f}%)")
            else:
                mb = downloaded / (1024 * 1024)
                sys.stdout.write(f"\r  \033[36mDownloaded:\033[0m {mb:.1f} MB")
            sys.stdout.flush()
        print()


def extract_desktop_asar_icon(asar_path, dest_icon):
    """
    Parses Electron's app.asar header to extract icon.png directly,
    avoiding any dependencies on node, npm, or external utilities.
    """
    try:
        with open(asar_path, "rb") as f:
            buf = f.read(16)
            magic, size1, size2, json_len = struct.unpack("<IIII", buf)
            json_header = f.read(json_len).decode("utf-8")
            data = json.loads(json_header)
            icon_entry = data.get("files", {}).get("icon.png")
            if not icon_entry:
                return False
            offset = int(icon_entry["offset"])
            size = int(icon_entry["size"])
            f.seek(16 + json_len + offset)
            icon_data = f.read(size)
            os.makedirs(os.path.dirname(dest_icon), exist_ok=True)
            with open(dest_icon, "wb") as out:
                out.write(icon_data)
        return True
    except Exception as e:
        log(f"Could not extract icon from asar: {e}", "WARN")
        return False


def get_installed_version(opt_dir, app_name):
    ver_file = os.path.join(opt_dir, app_name, ".version")
    if os.path.isfile(ver_file):
        try:
            with open(ver_file, "r") as f:
                return f.read().strip()
        except OSError:
            pass
    return "Not Installed"


def ensure_path_configured(bin_dir):
    current_path = os.environ.get("PATH", "").split(":")
    normalized_bin = os.path.abspath(os.path.expanduser(bin_dir))

    if normalized_bin in [os.path.abspath(p) for p in current_path if p]:
        return True

    log(f"Notice: '{bin_dir}' is not currently in your system $PATH.", "WARN")
    home = os.path.expanduser("~")
    rc_candidates = [
        os.path.join(home, ".bashrc"),
        os.path.join(home, ".zshrc"),
        os.path.join(home, ".profile"),
    ]

    export_line = f'\n# Added by Antigravity Installer\nexport PATH="{bin_dir}:$PATH"\n'
    for rc in rc_candidates:
        if os.path.isfile(rc):
            try:
                with open(rc, "r") as f:
                    if bin_dir in f.read():
                        return True
                with open(rc, "a") as f:
                    f.write(export_line)
                log(f"Added '{bin_dir}' to {rc}", "SUCCESS")
                log(f"Run 'source {rc}' or restart your terminal to activate it.", "INFO")
                return True
            except OSError:
                pass
    return False


def install_ide(tar_path, version, opt_dir, bin_dir, apps_dir, icons_dir, desktop_dir, skip_desktop):
    log(f"Installing Antigravity IDE (v{version})...")
    target_dir = os.path.join(opt_dir, "antigravity-ide")

    with tempfile.TemporaryDirectory() as tmp_dir:
        subprocess.run(["tar", "-xzf", tar_path, "-C", tmp_dir], check=True)
        extracted = [d for d in os.listdir(tmp_dir) if os.path.isdir(os.path.join(tmp_dir, d))]
        if not extracted:
            raise RuntimeError("Extraction failed: archive contained no directory.")
        src_dir = os.path.join(tmp_dir, extracted[0])

        # Patch bin script for Linux sandbox compatibility
        bin_script = os.path.join(src_dir, "bin", "antigravity-ide")
        if os.path.isfile(bin_script):
            with open(bin_script, "r") as f:
                content = f.read()

            patch = (
                'ELECTRON="$VSCODE_PATH/antigravity-ide"\n'
                'CLI="$VSCODE_PATH/resources/app/out/cli.js"\n\n'
                '# Linux AppArmor / unprivileged user namespace sandbox compatibility\n'
                'SANDBOX_ARG=""\n'
                'if [ -f "$VSCODE_PATH/chrome-sandbox" ] && [ ! -u "$VSCODE_PATH/chrome-sandbox" ]; then\n'
                '\tSANDBOX_ARG="--no-sandbox"\n'
                'fi\n\n'
                'ELECTRON_RUN_AS_NODE=1 "$ELECTRON" "$CLI" $SANDBOX_ARG "$@"\n'
                "exit $?"
            )
            target = (
                'ELECTRON="$VSCODE_PATH/antigravity-ide"\n'
                'CLI="$VSCODE_PATH/resources/app/out/cli.js"\n'
                'ELECTRON_RUN_AS_NODE=1 "$ELECTRON" "$CLI" "$@"\n'
                "exit $?"
            )
            if target in content and 'SANDBOX_ARG=""' not in content:
                content = content.replace(target, patch)
                with open(bin_script, "w") as f:
                    f.write(content)
                os.chmod(bin_script, 0o755)

        # Write version file
        with open(os.path.join(src_dir, ".version"), "w") as f:
            f.write(version + "\n")

        # Replace existing directory
        os.makedirs(opt_dir, exist_ok=True)
        if os.path.exists(target_dir):
            shutil.rmtree(target_dir)
        shutil.move(src_dir, target_dir)

    # Binaries & Symlinks
    os.makedirs(bin_dir, exist_ok=True)
    ide_bin = os.path.join(target_dir, "bin", "antigravity-ide")
    for link_name in ["antigravity-ide", "agy-ide"]:
        link_path = os.path.join(bin_dir, link_name)
        if os.path.islink(link_path) or os.path.exists(link_path):
            os.remove(link_path)
        os.symlink(ide_bin, link_path)

    # Icons & Desktop Entry
    src_icon = os.path.join(target_dir, "resources", "app", "resources", "linux", "code.png")
    dest_icon = os.path.join(target_dir, "icon.png")
    if os.path.isfile(src_icon):
        shutil.copy2(src_icon, dest_icon)
        for sz in ["512x512", "1024x1024"]:
            hicolor = os.path.join(icons_dir, sz, "apps", "antigravity-ide.png")
            os.makedirs(os.path.dirname(hicolor), exist_ok=True)
            shutil.copy2(dest_icon, hicolor)

    if not skip_desktop and apps_dir:
        os.makedirs(apps_dir, exist_ok=True)
        desktop_file = os.path.join(apps_dir, "antigravity-ide.desktop")
        icon_ref = os.path.join(icons_dir, "512x512", "apps", "antigravity-ide.png")
        if not os.path.isfile(icon_ref):
            icon_ref = dest_icon

        desktop_entry = (
            "[Desktop Entry]\n"
            "Name=Antigravity IDE\n"
            "Comment=AI-first Integrated Development Environment\n"
            "GenericName=Text Editor\n"
            f"Exec={os.path.join(bin_dir, 'antigravity-ide')} %F\n"
            f"Icon={icon_ref}\n"
            "Type=Application\n"
            "StartupNotify=true\n"
            "StartupWMClass=antigravity-ide\n"
            "Categories=Development;IDE;\n"
            "MimeType=text/plain;inode/directory;\n"
            "Actions=new-empty-window;\n\n"
            "[Desktop Action new-empty-window]\n"
            "Name=New Empty Window\n"
            f"Exec={os.path.join(bin_dir, 'antigravity-ide')} --new-window %F\n"
            f"Icon={icon_ref}\n"
        )
        with open(desktop_file, "w") as f:
            f.write(desktop_entry)
        os.chmod(desktop_file, 0o755)

        if desktop_dir and os.path.isdir(desktop_dir):
            u_desktop = os.path.join(desktop_dir, "antigravity-ide.desktop")
            shutil.copy2(desktop_file, u_desktop)
            os.chmod(u_desktop, 0o755)
            subprocess.run(["gio", "set", u_desktop, "metadata::trusted", "true"], stderr=subprocess.DEVNULL)

    log(f"Antigravity IDE ({version}) installed successfully.", "SUCCESS")


def install_desktop(tar_path, version, opt_dir, bin_dir, apps_dir, icons_dir, desktop_dir, skip_desktop):
    log(f"Installing Antigravity 2.0 Desktop (v{version})...")
    target_dir = os.path.join(opt_dir, "antigravity")

    with tempfile.TemporaryDirectory() as tmp_dir:
        subprocess.run(["tar", "-xzf", tar_path, "-C", tmp_dir], check=True)
        extracted = [d for d in os.listdir(tmp_dir) if os.path.isdir(os.path.join(tmp_dir, d))]
        if not extracted:
            raise RuntimeError("Extraction failed: archive contained no directory.")
        src_dir = os.path.join(tmp_dir, extracted[0])

        with open(os.path.join(src_dir, ".version"), "w") as f:
            f.write(version + "\n")

        os.makedirs(opt_dir, exist_ok=True)
        if os.path.exists(target_dir):
            shutil.rmtree(target_dir)
        shutil.move(src_dir, target_dir)

    # Extract icon from asar
    asar_path = os.path.join(target_dir, "resources", "app.asar")
    dest_icon = os.path.join(target_dir, "icon.png")
    if os.path.isfile(asar_path):
        if extract_desktop_asar_icon(asar_path, dest_icon):
            hicolor = os.path.join(icons_dir, "512x512", "apps", "antigravity.png")
            os.makedirs(os.path.dirname(hicolor), exist_ok=True)
            shutil.copy2(dest_icon, hicolor)

    # Wrapper script in bin
    os.makedirs(bin_dir, exist_ok=True)
    wrapper_script = os.path.join(bin_dir, "antigravity")
    wrapper_content = (
        "#!/usr/bin/env bash\n"
        "# Wrapper script for Antigravity Desktop Application\n"
        f'APP_DIR="{target_dir}"\n\n'
        'SANDBOX_ARG=""\n'
        'if [ -f "$APP_DIR/chrome-sandbox" ] && [ ! -u "$APP_DIR/chrome-sandbox" ]; then\n'
        '    SANDBOX_ARG="--no-sandbox"\n'
        "fi\n\n"
        'exec "$APP_DIR/antigravity" $SANDBOX_ARG "$@"\n'
    )
    with open(wrapper_script, "w") as f:
        f.write(wrapper_content)
    os.chmod(wrapper_script, 0o755)

    if not skip_desktop and apps_dir:
        os.makedirs(apps_dir, exist_ok=True)
        desktop_file = os.path.join(apps_dir, "antigravity.desktop")
        icon_ref = os.path.join(icons_dir, "512x512", "apps", "antigravity.png")
        if not os.path.isfile(icon_ref):
            icon_ref = dest_icon

        desktop_entry = (
            "[Desktop Entry]\n"
            "Name=Antigravity\n"
            "Comment=Antigravity - Agentic Desktop Application\n"
            "GenericName=AI Agent Platform\n"
            f"Exec={os.path.join(bin_dir, 'antigravity')} %U\n"
            f"Icon={icon_ref}\n"
            "Type=Application\n"
            "StartupNotify=true\n"
            "StartupWMClass=antigravity\n"
            "Categories=Development;\n"
        )
        with open(desktop_file, "w") as f:
            f.write(desktop_entry)
        os.chmod(desktop_file, 0o755)

        if desktop_dir and os.path.isdir(desktop_dir):
            u_desktop = os.path.join(desktop_dir, "antigravity.desktop")
            shutil.copy2(desktop_file, u_desktop)
            os.chmod(u_desktop, 0o755)
            subprocess.run(["gio", "set", u_desktop, "metadata::trusted", "true"], stderr=subprocess.DEVNULL)

    log(f"Antigravity Desktop ({version}) installed successfully.", "SUCCESS")


def refresh_desktop_databases(apps_dir, icons_dir):
    if apps_dir and os.path.isdir(apps_dir):
        subprocess.run(["update-desktop-database", apps_dir], stderr=subprocess.DEVNULL)
    if icons_dir and os.path.isdir(icons_dir):
        subprocess.run(["gtk-update-icon-cache", "-f", "-t", icons_dir], stderr=subprocess.DEVNULL)


def find_local_tarballs(tar_dir):
    ide_tar = None
    desktop_tar = None
    if os.path.isdir(tar_dir):
        for f in os.listdir(tar_dir):
            low = f.lower()
            full = os.path.join(tar_dir, f)
            if "antigravity" in low and "ide" in low and (low.endswith(".tar.gz") or low.endswith(".tgz")):
                ide_tar = full
            elif "antigravity" in low and "ide" not in low and (low.endswith(".tar.gz") or low.endswith(".tgz")):
                desktop_tar = full
    return ide_tar, desktop_tar


def do_uninstall(opt_dir, bin_dir, apps_dir, icons_dir, desktop_dir):
    log("Uninstalling Antigravity packages...")
    for target in ["antigravity-ide", "antigravity"]:
        path = os.path.join(opt_dir, target)
        if os.path.exists(path):
            shutil.rmtree(path)
            log(f"Removed: {path}", "SUCCESS")

    for binary in ["antigravity", "antigravity-ide", "agy-ide"]:
        path = os.path.join(bin_dir, binary)
        if os.path.islink(path) or os.path.isfile(path):
            os.remove(path)
            log(f"Removed binary launcher: {path}", "SUCCESS")

    if apps_dir:
        for desk in ["antigravity.desktop", "antigravity-ide.desktop"]:
            path = os.path.join(apps_dir, desk)
            if os.path.isfile(path):
                os.remove(path)
                log(f"Removed desktop shortcut: {path}", "SUCCESS")

    if desktop_dir and os.path.isdir(desktop_dir):
        for desk in ["antigravity.desktop", "antigravity-ide.desktop"]:
            path = os.path.join(desktop_dir, desk)
            if os.path.isfile(path):
                os.remove(path)

    if icons_dir and os.path.isdir(icons_dir):
        for sz in ["512x512", "1024x1024"]:
            for name in ["antigravity.png", "antigravity-ide.png"]:
                p = os.path.join(icons_dir, sz, "apps", name)
                if os.path.isfile(p):
                    os.remove(p)

    refresh_desktop_databases(apps_dir, icons_dir)
    log("Antigravity uninstalled successfully.", "SUCCESS")


def main():
    parser = argparse.ArgumentParser(
        description="Universal Antigravity Linux Installer & Updater",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Examples:
  ./antigravity-installer.py install             # Download and install both apps
  ./antigravity-installer.py update              # Check and update if newer version exists
  ./antigravity-installer.py check               # View local vs remote versions
  ./antigravity-installer.py install --ide-only  # Install only Antigravity IDE
  ./antigravity-installer.py uninstall          # Remove all installed Antigravity components
""",
    )

    parser.add_argument(
        "action",
        nargs="?",
        default="install",
        choices=["install", "update", "check", "uninstall"],
        help="Action to perform (default: install)",
    )
    parser.add_argument("--prefix", default=None, help="Installation prefix (default: ~/.local)")
    parser.add_argument("--ide-only", action="store_true", help="Target only Antigravity IDE")
    parser.add_argument("--desktop-only", action="store_true", help="Target only Antigravity Desktop")
    parser.add_argument("--force", action="store_true", help="Force reinstall even if versions match")
    parser.add_argument("--no-desktop", action="store_true", help="Skip creating desktop shortcuts and menu entries")
    parser.add_argument("--tar-dir", help="Directory containing existing .tar.gz files to install from")
    parser.add_argument("--ide-tar", help="Path to specific Antigravity IDE tar.gz archive")
    parser.add_argument("--desktop-tar", help="Path to specific Antigravity Desktop tar.gz archive")
    parser.add_argument("--version", action="version", version=f"Antigravity Installer v{VERSION}")

    args = parser.parse_args()

    # Paths configuration
    if args.prefix:
        prefix = os.path.abspath(os.path.expanduser(args.prefix))
    else:
        prefix = os.path.expanduser("~/.local")

    opt_dir = os.path.join(prefix, "opt")
    bin_dir = os.path.join(prefix, "bin")
    apps_dir = os.path.join(prefix, "share", "applications")
    icons_dir = os.path.join(prefix, "share", "icons", "hicolor")
    desktop_dir = os.path.expanduser("~/Desktop") if os.path.isdir(os.path.expanduser("~/Desktop")) else None

    if args.action == "uninstall":
        do_uninstall(opt_dir, bin_dir, apps_dir, icons_dir, desktop_dir)
        return

    arch_tag = detect_architecture()
    releases = fetch_release_info(arch_tag)

    ide_remote = releases["ide"]
    desktop_remote = releases["desktop"]

    ide_cur = get_installed_version(opt_dir, "antigravity-ide")
    desktop_cur = get_installed_version(opt_dir, "antigravity")

    print("\n" + "=" * 62)
    print("      Antigravity Universal Linux Installer / Updater")
    print("=" * 62)
    print(f" Architecture:        \033[1m{arch_tag}\033[0m")
    print(f" Install Prefix:      \033[1m{prefix}\033[0m")
    print(f" Antigravity IDE:     Installed: {ide_cur} | Latest: {ide_remote['version']}")
    print(f" Antigravity Desktop: Installed: {desktop_cur} | Latest: {desktop_remote['version']}")
    print("=" * 62 + "\n")

    if args.action == "check":
        has_update = (ide_cur != ide_remote["version"]) or (desktop_cur != desktop_remote["version"])
        if has_update:
            log("Updates are available! Run with 'update' to apply them.", "INFO")
        else:
            log("All installed applications are up to date.", "SUCCESS")
        return

    # Determine what to install / update
    target_ide = not args.desktop_only
    target_desktop = not args.ide_only

    if args.action == "update" and not args.force:
        target_ide = target_ide and (ide_cur != ide_remote["version"])
        target_desktop = target_desktop and (desktop_cur != desktop_remote["version"])

        if not target_ide and not target_desktop:
            log("All components are already at the latest version.", "SUCCESS")
            log("Use --force to reinstall anyway.", "INFO")
            return

    # Discover local tarballs if provided
    local_ide_tar = args.ide_tar
    local_desktop_tar = args.desktop_tar
    if args.tar_dir:
        d_ide, d_desk = find_local_tarballs(os.path.abspath(os.path.expanduser(args.tar_dir)))
        local_ide_tar = local_ide_tar or d_ide
        local_desktop_tar = local_desktop_tar or d_desk

    with tempfile.TemporaryDirectory() as dl_dir:
        # Install IDE
        if target_ide:
            if local_ide_tar and os.path.isfile(local_ide_tar):
                ide_archive = local_ide_tar
                log(f"Using local archive: {ide_archive}")
            else:
                ide_archive = os.path.join(dl_dir, "Antigravity_IDE.tar.gz")
                download_with_progress(ide_remote["url"], ide_archive)

            install_ide(
                ide_archive,
                ide_remote["version"],
                opt_dir,
                bin_dir,
                apps_dir,
                icons_dir,
                desktop_dir,
                args.no_desktop,
            )

        # Install Desktop App
        if target_desktop:
            if local_desktop_tar and os.path.isfile(local_desktop_tar):
                desktop_archive = local_desktop_tar
                log(f"Using local archive: {desktop_archive}")
            else:
                desktop_archive = os.path.join(dl_dir, "Antigravity.tar.gz")
                download_with_progress(desktop_remote["url"], desktop_archive)

            install_desktop(
                desktop_archive,
                desktop_remote["version"],
                opt_dir,
                bin_dir,
                apps_dir,
                icons_dir,
                desktop_dir,
                args.no_desktop,
            )

    refresh_desktop_databases(apps_dir, icons_dir)
    ensure_path_configured(bin_dir)

    print()
    log("All requested components were installed successfully!", "SUCCESS")
    print("\nYou can launch them using:")
    print("  • antigravity-ide   (Antigravity IDE)")
    print("  • antigravity       (Antigravity 2.0 Desktop Application)\n")


if __name__ == "__main__":
    main()
