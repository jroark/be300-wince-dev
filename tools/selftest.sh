#!/usr/bin/env bash
# End-to-end toolchain check in the emulator: build samples/selftest, boot
# it headlessly for a fixed time, then read \Nand Disk\selftest.log back
# out of the NAND. Exits 0 only when the log reports fail=0.
#   selftest.sh          install the .cbea with an HKLM\Init autostart
#   selftest.sh --cf     launch it from a CF card as \CE\R4100\AutoRun.exe
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
secs="${SELFTEST_SECS:-60}"
work="$root/build/selftest-run"
mode=nand
[[ ${1:-} == --cf ]] && mode=cf

make -C "$root/samples/selftest" all cf >/dev/null
rm -rf "$work"
mkdir -p "$work"
if [[ $mode == cf ]]; then
    args=(--cf "$root/samples/selftest/build/SelfTest-cf.img")
else
    args=("$root/samples/selftest/build/SelfTest.cbea")
fi
BE300_AUTOSTOP_SEC="$secs" "$root/tools/run-emu.sh" -o "$work/nand.bin" "${args[@]}" \
    >"$work/serial.txt" 2>"$work/diag.txt" || true

if ! "$root/tools/nand-cat.sh" "$work/nand.bin" selftest.log >"$work/selftest.log" 2>/dev/null; then
    echo "selftest: no selftest.log on the NAND (app did not run?); see $work/serial.txt" >&2
    exit 1
fi
cat "$work/selftest.log"
grep -q "SELFTEST END .* fail=0" "$work/selftest.log"
