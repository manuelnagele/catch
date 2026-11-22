#!/usr/bin/env bash
# Keeps ~/catch at origin/main. On change: re-links the addon and pops a desktop notification
# so you know to /reload (or restart the client when the TOC's file list changed). Same loop as grimoire-sync.
set -u

REPO="${CATCH_REPO:-$HOME/catch}"
INTERVAL="${CATCH_SYNC_INTERVAL:-15}"
WOW_DIR="${CATCH_WOW_DIR:-$HOME/Faugus/battlenet/drive_c/Program Files (x86)/World of Warcraft}"
FLAVORS="${CATCH_FLAVORS:-_forever_}"

notify() {
    echo "$1"
    command -v notify-send >/dev/null && notify-send -a Catch -i applications-games "Catch" "$1" || true
}

link_addon() {
    local IFS=,
    for flavor in $FLAVORS; do
        local addons="$WOW_DIR/$flavor/Interface/AddOns"
        [ -d "$WOW_DIR/$flavor" ] || continue
        [ "$(readlink "$addons/Catch")" = "$REPO/Catch" ] && continue
        mkdir -p "$addons"
        [ -d "$addons/Catch" ] && [ ! -L "$addons/Catch" ] && rm -rf "$addons/Catch"   # a hand-copied install
        ln -sfn "$REPO/Catch" "$addons/Catch"
        notify "Catch linked into $flavor"
    done
}

link_addon
while true; do
    link_addon
    if git -C "$REPO" fetch -q origin main 2>/dev/null; then
        local_rev=$(git -C "$REPO" rev-parse HEAD)
        remote_rev=$(git -C "$REPO" rev-parse origin/main)
        if [ "$local_rev" != "$remote_rev" ]; then
            changed=$(git -C "$REPO" diff --name-only "$local_rev" "$remote_rev")
            git -C "$REPO" reset -q --hard origin/main
            link_addon
            subject=$(git -C "$REPO" log -1 --format=%s)
            toc_lines=$(git -C "$REPO" diff "$local_rev" "$remote_rev" -- '*.toc' | grep -E '^[+-][^+-]' | grep -v '## Version' || true)
            if [ -n "$toc_lines" ]; then
                notify "Updated: $subject — TOC changed, restart the WoW client (a /reload is not enough)"
            elif grep -q '^Catch/' <<<"$changed"; then
                notify "Updated: $subject — /reload to apply"
            fi
            if grep -q '^deploy/' <<<"$changed"; then
                "$REPO/deploy/install.sh" --units-only
                systemctl --user --no-block restart catch-sync.service
            fi
        fi
    fi
    sleep "$INTERVAL"
done
