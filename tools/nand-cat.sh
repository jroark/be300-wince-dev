#!/usr/bin/env bash
# List or read files on a BE-300 NAND image's \Nand Disk FAT16 volume.
#   nand-cat.sh IMAGE                 list the volume root (recursive with -s)
#   nand-cat.sh IMAGE -s              recursive listing
#   nand-cat.sh IMAGE 'path\to\file'  write the file to stdout
# Paths are relative to \Nand Disk, with \ or / separators.
set -euo pipefail

[[ $# -ge 1 ]] || { echo "usage: $0 IMAGE [-s | PATH]" >&2; exit 1; }
img=$1
command -v mtype >/dev/null || { echo "error: mtools not found (brew install mtools)" >&2; exit 1; }

# Block-0 partition table: 16-byte entries of 8 x 0xFF, u32 start sector,
# u32 sector count; entry 3 is the FAT16 volume. A bare FAT16 image
# (CF card) has no table and starts at sector 0.
off=$(python3 -I -c '
import struct, sys
d = open(sys.argv[1], "rb").read(64)
if d[48:56] == b"\xff" * 8:
    print(struct.unpack_from("<I", d, 56)[0] * 512)
else:
    print(0)
' "$img")

export MTOOLS_SKIP_CHECK=1
if [[ $# -eq 1 ]]; then
    exec mdir -i "$img@@$off" ::
elif [[ $2 == -s ]]; then
    exec mdir -i "$img@@$off" -/ ::
else
    exec mtype -i "$img@@$off" "::${2//\\//}"
fi
