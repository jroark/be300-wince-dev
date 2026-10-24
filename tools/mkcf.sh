#!/usr/bin/env bash
# Build a FAT16 CompactFlash image that auto-launches an app on the BE-300.
# On card insertion (and at boot with the card present) WinCE runs
# \Storage Card\CE\R4100\AutoRun.exe -- the mechanism the Linux4.BE CyaCE
# loader used. Extra files land next to AutoRun.exe.
#
#   mkcf.sh [-s SIZE_MB] [-l LABEL] OUT.img APP.exe [EXTRA_FILE...]
set -euo pipefail

size=16
label=BE300CF
while getopts "s:l:" opt; do
    case $opt in
        s) size=$OPTARG ;;
        l) label=$OPTARG ;;
        *) exit 1 ;;
    esac
done
shift $((OPTIND - 1))
[[ $# -ge 2 ]] || { echo "usage: $0 [-s SIZE_MB] [-l LABEL] OUT.img APP.exe [EXTRA...]" >&2; exit 1; }
out=$1
exe=$2
shift 2

for tool in mformat mmd mcopy; do
    command -v $tool >/dev/null || { echo "error: $tool not found (brew install mtools)" >&2; exit 1; }
done
if (( size < 8 || size > 1024 )); then
    echo "error: size must be 8..1024 MB" >&2
    exit 1
fi

export MTOOLS_SKIP_CHECK=1
mkdir -p "$(dirname "$out")"
rm -f "$out"
dd if=/dev/zero of="$out" bs=1048576 count="$size" 2>/dev/null
# Bare FAT16 "superfloppy" (no MBR), 16 heads x 32 sectors/track, 512 root
# entries: the layout the emulator's CF model and tools/make_cf_image.sh use.
mformat -i "$out" -v "$label" -h 16 -s 32 -c 4 -r 512 -T $((size * 2048)) ::
mmd -i "$out" ::/CE ::/CE/R4100
mcopy -i "$out" -- "$exe" ::/CE/R4100/AutoRun.exe
for f in "$@"; do
    mcopy -i "$out" -s -- "$f" ::/CE/R4100/
done
echo "[+] $out: \\CE\\R4100\\AutoRun.exe <- $(basename "$exe")"
