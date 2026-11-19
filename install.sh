#!/usr/bin/env bash
# Install or update "Application Launcher (with Folders)" for KDE Plasma 6.
#
#   ./install.sh                 install / update the widget
#   ./install.sh --replace       also swap it in for the stock Application Launcher
#                                on your panel, keeping your favourites and settings
#   ./install.sh --restore       put the stock Application Launcher back
#   ./install.sh --uninstall     remove the widget (run --restore first if it's on your panel)
#
# SPDX-License-Identifier: GPL-2.0-or-later

set -euo pipefail

ID="com.opusmatic.launcherfolders"
STOCK="org.kde.plasma.kickoff"
CONFIG="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
HERE="$(cd "$(dirname "$0")" && pwd)"

die() { echo "error: $*" >&2; exit 1; }
command -v kpackagetool6 >/dev/null || die "kpackagetool6 not found (this needs KDE Plasma 6)"

restart_plasma() {
    echo "Restarting Plasma (your panel disappears for a few seconds)..."
    if systemctl --user is-active --quiet plasma-plasmashell; then
        systemctl --user restart plasma-plasmashell
    else
        kquitapp6 plasmashell 2>/dev/null || true
        (kstart plasmashell >/dev/null 2>&1 &)
    fi
}

# Swap the plugin of existing launcher widgets in place. Keeping the widget id
# keeps its favourites (they are stored per widget id) and its settings.
swap_plugin() {
    local from="$1" to="$2"
    [ -f "$CONFIG" ] || die "$CONFIG not found"
    grep -q "^plugin=$from$" "$CONFIG" || die "no '$from' widget found in your Plasma config"
    local backup="$CONFIG.bak-$(date +%Y%m%d-%H%M%S)"
    cp "$CONFIG" "$backup"
    echo "Backed up your Plasma config to $backup"
    # plasmashell rewrites this file when it quits, so edit it while it is stopped
    if systemctl --user is-active --quiet plasma-plasmashell; then
        systemctl --user stop plasma-plasmashell
        sed -i "s/^plugin=$from$/plugin=$to/" "$CONFIG"
        systemctl --user start plasma-plasmashell
    else
        kquitapp6 plasmashell 2>/dev/null || true
        sleep 1
        sed -i "s/^plugin=$from$/plugin=$to/" "$CONFIG"
        (kstart plasmashell >/dev/null 2>&1 &)
    fi
}

case "${1:-}" in
    ""|--replace)
        if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -qx "$ID"; then
            kpackagetool6 -t Plasma/Applet -u "$HERE"
        else
            kpackagetool6 -t Plasma/Applet -i "$HERE"
        fi
        if [ "${1:-}" = "--replace" ]; then
            swap_plugin "$STOCK" "$ID"
            echo "Done: your Application Launcher now has folders in Favourites."
        else
            restart_plasma
            echo "Installed. Add it via right-click on your launcher -> Show Alternatives,"
            echo "or run ./install.sh --replace to swap it in and keep your favourites."
        fi
        ;;
    --restore)
        swap_plugin "$ID" "$STOCK"
        echo "Done: the stock Application Launcher is back."
        ;;
    --uninstall)
        if [ -f "$CONFIG" ] && grep -q "^plugin=$ID$" "$CONFIG"; then
            die "it's still on your panel; run ./install.sh --restore first"
        fi
        kpackagetool6 -t Plasma/Applet -r "$ID"
        echo "Removed."
        ;;
    -h|--help)
        sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
        ;;
    *)
        die "unknown option '$1' (try --help)"
        ;;
esac
