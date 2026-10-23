#!/usr/bin/env bash
# Mount a Windows (NTFS) partition read-write from Linux, with clear help when Windows
# hibernation / Fast Startup is blocking it.
#
# Usage:  ./mount-windows-drive.sh [-r] [-p MOUNTPOINT] [DEVICE]
#   DEVICE        e.g. /dev/nvme0n1p3  (omit it to list NTFS partitions)
#   -p MOUNTPOINT where to mount (default: /mnt/windows)
#   -r            mount read-only (safe fallback)
set -euo pipefail

[ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"

MOUNTPOINT="/mnt/windows"
READONLY=0

usage() {
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while getopts ":rp:h" opt; do
  case "$opt" in
    r) READONLY=1 ;;
    p) MOUNTPOINT="$OPTARG" ;;
    h) usage 0 ;;
    *) usage 1 ;;
  esac
done
shift $((OPTIND - 1))
DEVICE="${1:-}"

list_ntfs() { lsblk -rno PATH,FSTYPE,SIZE,LABEL | awk '$2=="ntfs"{print "  " $1 "  " $3 "  " $4}'; }

if ! command -v mount.ntfs-3g >/dev/null 2>&1 && ! command -v ntfs-3g >/dev/null 2>&1; then
  echo "ntfs-3g is not installed. Install it with:  sudo apt install ntfs-3g" >&2
  exit 1
fi

if [ -z "$DEVICE" ]; then
  COUNT=$(lsblk -rno PATH,FSTYPE | awk '$2=="ntfs"' | wc -l)
  if [ "$COUNT" -eq 1 ]; then
    DEVICE=$(lsblk -rno PATH,FSTYPE | awk '$2=="ntfs"{print $1}')
    echo "Only one NTFS partition found, using $DEVICE"
  else
    echo "NTFS partitions found (device  size  label):"
    list_ntfs
    echo
    echo "Pick one and run:  $0 /dev/<device>"
    echo "(Windows' small 'Recovery' partition is NTFS too; your C: drive is usually the biggest one.)"
    exit 1
  fi
fi

FSTYPE=$(lsblk -no FSTYPE "$DEVICE" 2>/dev/null | head -n1 || true)
if [ -z "$FSTYPE" ]; then
  echo "Device $DEVICE not found. Run 'lsblk -f' to see your partitions." >&2
  exit 1
fi
if [ "$FSTYPE" != "ntfs" ]; then
  echo "$DEVICE is '$FSTYPE', not NTFS. Nothing to do." >&2
  exit 1
fi

if findmnt -rn -S "$DEVICE" >/dev/null 2>&1; then
  echo "$DEVICE is already mounted at: $(findmnt -rn -S "$DEVICE" -o TARGET | head -n1)"
  exit 0
fi

OWNER_UID="${SUDO_UID:-0}"
OWNER_GID="${SUDO_GID:-0}"
OPTS="uid=$OWNER_UID,gid=$OWNER_GID,umask=022,windows_names"
if [ "$READONLY" -eq 1 ]; then OPTS="ro,$OPTS"; else OPTS="rw,$OPTS"; fi

mkdir -p "$MOUNTPOINT"

if OUT=$(mount -t ntfs-3g -o "$OPTS" "$DEVICE" "$MOUNTPOINT" 2>&1); then
  [ -n "$OUT" ] && echo "$OUT"
  if echo "$OUT" | grep -qi "daemon-reload"; then
    echo "Reloading systemd (fstab changed)..."
    systemctl daemon-reload
  fi
  echo "Mounted $DEVICE at $MOUNTPOINT ($([ "$READONLY" -eq 1 ] && echo read-only || echo read-write))."
  exit 0
fi

echo "$OUT" >&2
echo >&2
if echo "$OUT" | grep -qiE "hibernat|unsafe state|unclean file system|fast restart"; then
  cat >&2 <<MSG
Windows left this drive locked (hibernation / Fast Startup).
Fix it once, permanently:
  1. Boot Windows, open Command Prompt as Administrator and run:  powercfg /h off
  2. Do a full SHUT DOWN of Windows, then boot Linux.
Need the files right now without fixing Windows?  Read-only is always safe:
  $0 -r $DEVICE
MSG
fi
exit 1
