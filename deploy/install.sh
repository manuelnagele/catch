#!/usr/bin/env bash
# One-time setup on the gaming box (also re-run by catch-sync when deploy/ changes):
#   git clone github-catch:manuelnagele/catch ~/catch && ~/catch/deploy/install.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
UNITS="$HOME/.config/systemd/user"
mkdir -p "$UNITS"
sed "s|@REPO@|$REPO|g" "$REPO/deploy/catch-sync.service" > "$UNITS/catch-sync.service"
systemctl --user daemon-reload

[ "${1:-}" = "--units-only" ] && exit 0

systemctl --user enable --now catch-sync.service
systemctl --user --no-pager status catch-sync.service | grep -E '●|Active'
