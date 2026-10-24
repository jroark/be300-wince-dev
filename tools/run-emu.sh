#!/usr/bin/env bash
# Boot the BE-300 emulator on a scratch copy of a NAND image, optionally
# with .cbea packages installed into it and/or a CF card attached.
#   run-emu.sh [-o OUT_NAND] [--cf CF.img] [--no-run] [PKG.cbea...] [-- be300 args...]
# The base NAND is never modified. The emulator saves its exit screenshot
# next to OUT_NAND.
# Environment:
#   BE300_EMU   emulator checkout (default: ../be300 next to this repo)
#   BE300_NAND  base NAND image (default: $BE300_EMU/ce/restore_images/All_nand_300.bin)
set -euo pipefail

abspath() { (cd "$(dirname "$1")" && printf '%s/%s\n' "$(pwd)" "$(basename "$1")"); }

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
emu="${BE300_EMU:-$root/../be300}"
base="${BE300_NAND:-$emu/ce/restore_images/All_nand_300.bin}"
out="$root/build/nand.run.bin"
cf=""
run=1
pkgs=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -o) out=$2; shift 2 ;;
        --cf) cf=$2; shift 2 ;;
        --no-run) run=0; shift ;;
        --) shift; break ;;
        -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) pkgs+=("$1"); shift ;;
    esac
done

[[ -x "$emu/build-host/be300" ]] || { echo "error: emulator not found at $emu/build-host/be300 (set BE300_EMU)" >&2; exit 1; }
[[ -f "$base" ]] || { echo "error: base NAND $base not found (set BE300_NAND)" >&2; exit 1; }
mkdir -p "$(dirname "$out")"
out="$(abspath "$out")"

if [[ ${#pkgs[@]} -gt 0 ]]; then
    installer="$emu/build-host/be300-install"
    [[ -x "$installer" ]] || { echo "error: $installer missing (cd $emu/build-host && make be300-install)" >&2; exit 1; }
    "$installer" --force --output "$out" "$base" "${pkgs[@]}"
else
    cp "$base" "$out"
fi
[[ $run -eq 1 ]] || exit 0

args=(--nand "$out" --rtc-host-time)
[[ -n "$cf" ]] && args+=(--cf "$(abspath "$cf")")
cd "$(dirname "$out")"
exec "$emu/build-host/be300" "${args[@]}" "$@"
