#!/usr/bin/env bash
# Safely unmount the Windows drive before you shut down or switch OS.
# Usage:  ./unmount-windows-drive.sh [MOUNTPOINT]     (default: /mnt/windows)
set -euo pipefail

[ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"

MOUNTPOINT="${1:-/mnt/windows}"

if ! findmnt -rn "$MOUNTPOINT" >/dev/null 2>&1; then
  echo "$MOUNTPOINT is not mounted. Nothing to do."
  exit 0
fi

sync
if umount "$MOUNTPOINT"; then
  echo "Unmounted $MOUNTPOINT. Safe to shut down."
else
  echo "Could not unmount (probably busy). Close files/terminals using it, then retry." >&2
  echo "See what is using it:  fuser -vm $MOUNTPOINT" >&2
  exit 1
fi
