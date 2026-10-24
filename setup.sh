#!/usr/bin/env bash
# One-time setup of the BE-300 development environment.
#
# Put your Casio BE-300 SDK zip (BE300SDK_1012.zip) and, optionally, your
# eMbedded Visual C++ 3.0 ISO(s) in this directory (or inputs/), then run:
#
#     ./setup.sh
#
# It installs the host tools (Homebrew), extracts the BE-300 platform
# headers and MIPS libraries into sdk/, pulls extras out of the eVC ISOs,
# builds the runtime library and compiles a sample to prove the toolchain.
# See README.md. Re-running is safe; it rebuilds sdk/ from the inputs.
#
# Options:
#   --sdk ZIP       BE-300 SDK zip (default: search . and inputs/)
#   --evc ISO       eVC 3.0 ISO; may be given more than once (default: search)
#   --no-deps       don't install missing Homebrew packages, just report them
#   --selftest      also run tools/selftest.sh in the emulator (needs ../be300)
#   -h, --help      show this help
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sdk="$root/sdk"
sdk_zip=""
evc_isos=()
install_deps=1
run_selftest=0

say()  { printf '\033[1m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
    case $1 in
        --sdk) sdk_zip=$2; shift 2 ;;
        --evc) evc_isos+=("$2"); shift 2 ;;
        --no-deps) install_deps=0; shift ;;
        --selftest) run_selftest=1; shift ;;
        -h|--help) sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown option $1 (see --help)" ;;
    esac
done

# --------------------------------------------------------------------------
say "Checking host tools"

brew_pkgs=()
need() {  # need <command> <brew formula>
    command -v "$1" >/dev/null 2>&1 || brew_pkgs+=("$2")
}
llvm_prefix=""
if command -v brew >/dev/null 2>&1; then
    llvm_prefix="$(brew --prefix llvm 2>/dev/null || true)"
fi
[[ -n "$llvm_prefix" && -x "$llvm_prefix/bin/clang" ]] || brew_pkgs+=(llvm)
command -v 7zz >/dev/null 2>&1 || need 7z p7zip
need mformat mtools
command -v python3 >/dev/null 2>&1 || die "python3 not found (install Xcode Command Line Tools: xcode-select --install)"
command -v make >/dev/null 2>&1 || die "make not found (install Xcode Command Line Tools: xcode-select --install)"

if [[ ${#brew_pkgs[@]} -gt 0 ]]; then
    command -v brew >/dev/null 2>&1 || die "missing ${brew_pkgs[*]} and Homebrew is not installed (https://brew.sh)"
    if [[ $install_deps -eq 1 ]]; then
        info "brew install ${brew_pkgs[*]}"
        brew install "${brew_pkgs[@]}"
    else
        die "missing Homebrew packages: ${brew_pkgs[*]} (run: brew install ${brew_pkgs[*]})"
    fi
    llvm_prefix="$(brew --prefix llvm)"
fi
sevenz="$(command -v 7zz || command -v 7z)"
python3 -c 'import sys; sys.exit(sys.version_info < (3, 6))' || die "python3 >= 3.6 required"
"$llvm_prefix/bin/clang" --target=mipsel-windows-msvc -x c -c /dev/null -o /dev/null 2>/dev/null ||
    die "$llvm_prefix/bin/clang cannot target mipsel-windows-msvc (LLVM too old?)"
info "clang:  $("$llvm_prefix/bin/clang" --version | head -1)"
info "7-Zip:  $sevenz"
info "python: $(python3 --version)"

# --------------------------------------------------------------------------
say "Locating inputs"

has() {  # has <archive> <ERE>: does the archive list a matching path?
    # Listings are cached; grep reads the file directly (piping into
    # grep -q would trip pipefail with SIGPIPE).
    local key
    key="$(printf '%s' "$1" | shasum | cut -c1-16)"
    if [[ ! -f "$tmp/list-$key" ]]; then
        "$sevenz" l -slt "$1" 2>/dev/null | sed -n 's/^Path = //p' | tr '\\' '/' >"$tmp/list-$key" || true
    fi
    grep -q -i -E "$2" "$tmp/list-$key"
}

tmp="$(mktemp -d "${TMPDIR:-/tmp}/be300-setup.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

candidates=()
for dir in "$root" "$root/inputs"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r -d '' f; do
        candidates+=("$f")
    done < <(find -L "$dir" -maxdepth 1 -type f \( -iname '*.zip' -o -iname '*.iso' \) -print0)
done

if [[ -z "$sdk_zip" ]]; then
    for f in "${candidates[@]+"${candidates[@]}"}"; do
        [[ $f == *.[zZ][iI][pP] ]] || continue
        if has "$f" '(^|/)CASIO_BE300\.exe$'; then
            sdk_zip=$f
            break
        fi
    done
fi
[[ -n "$sdk_zip" ]] || die "no BE-300 SDK zip found. Copy BE300SDK_1012.zip (it contains CASIO_BE300.exe) into $root or $root/inputs, or pass --sdk"
[[ -f "$sdk_zip" ]] || die "$sdk_zip not found"
info "BE-300 SDK: $sdk_zip"

if [[ ${#evc_isos[@]} -eq 0 ]]; then
    for f in "${candidates[@]+"${candidates[@]}"}"; do
        [[ $f == *.[iI][sS][oO] ]] || continue
        if has "$f" '^(HPC30SDK/INCLUDE/|WCE/WCE300/BIN/CLMIPS\.EXE$)'; then
            evc_isos+=("$f")
        fi
    done
fi
for f in "${evc_isos[@]+"${evc_isos[@]}"}"; do
    info "eVC 3.0 ISO: $f"
done
[[ ${#evc_isos[@]} -gt 0 ]] || warn "no eVC 3.0 ISO found; continuing with the BE-300 SDK only (see README: Inputs)"

# --------------------------------------------------------------------------
say "Extracting the BE-300 platform SDK"

rm -rf "$sdk"
mkdir -p "$sdk"
"$sevenz" x -y -o"$tmp/zip" "$sdk_zip" >/dev/null
installer="$(find "$tmp/zip" -iname 'CASIO_BE300.exe' -print -quit)"
[[ -n "$installer" ]] || die "CASIO_BE300.exe not found inside $sdk_zip"
"$sevenz" x -y -o"$tmp/plat" "$installer" 'WCE300/CASIO_BE300/Include/*' 'WCE300/CASIO_BE300/Lib/MIPS/*' >/dev/null
[[ -f "$tmp/plat/WCE300/CASIO_BE300/Lib/MIPS/coredll.lib" ]] || die "unexpected CASIO_BE300.exe layout (no Lib/MIPS/coredll.lib)"
mv "$tmp/plat/WCE300/CASIO_BE300/Include" "$sdk/Include"
mv "$tmp/plat/WCE300/CASIO_BE300/Lib/MIPS" "$sdk/Lib"
info "headers: $(find "$sdk/Include" -type f | wc -l | tr -d ' ') -> sdk/Include"
info "libs:    $(find "$sdk/Lib" -type f | wc -l | tr -d ' ') -> sdk/Lib"

# Everything else in the zip: docs (CasioAPIs.chm, PDFs), samples, the
# on-device development tools (MEM.exe, gi.exe, ...), installer references.
sdk_dir="$(dirname "$installer")"
rm -f "$installer"
mv "$sdk_dir" "$sdk/be300sdk"
info "docs, samples, device tools -> sdk/be300sdk"

# The SDK spells some headers in upper case (KFUNCS.H) and includes them in
# lower case. Add lower-case links when the file system is case sensitive.
if [[ ! "$sdk/Include/windows.h" -ef "$sdk/Include/WINDOWS.H" ]]; then
    for f in "$sdk/Include"/*; do
        base="$(basename "$f")"
        lower="$(printf '%s' "$base" | tr 'A-Z' 'a-z')"
        [[ -e "$sdk/Include/$lower" ]] || ln -s "$base" "$sdk/Include/$lower"
    done
    info "added lower-case header links (case-sensitive file system)"
fi

# --------------------------------------------------------------------------
for iso in "${evc_isos[@]+"${evc_isos[@]}"}"; do
    say "Extracting from $(basename "$iso")"
    found=0
    if has "$iso" '^HPC30SDK/INCLUDE/'; then
        found=1
        "$sevenz" x -y -o"$tmp/hpc" "$iso" 'HPC30SDK/INCLUDE/*' 'HPC30SDK/LIB/MIPS/*' \
            'HPC30SDK/SAMPLES/WIN32/*' >/dev/null
        mkdir -p "$sdk/hpc" "$sdk/samples"
        mv "$tmp/hpc/HPC30SDK/INCLUDE" "$sdk/hpc/Include"
        mv "$tmp/hpc/HPC30SDK/LIB/MIPS" "$sdk/hpc/Lib"
        mv "$tmp/hpc/HPC30SDK/SAMPLES/WIN32" "$sdk/samples/hpc-win32"
        info "H/PC Pro 3.0 SDK headers (fallback includes) -> sdk/hpc/Include"
        info "H/PC Pro 3.0 MIPS libs (opt-in, see README) -> sdk/hpc/Lib"
        info "Win32 samples -> sdk/samples/hpc-win32"
    fi
    if has "$iso" '^WCE/WCE300/BIN/CLMIPS\.EXE$'; then
        found=1
        "$sevenz" x -y -o"$tmp/evc" "$iso" 'WCE/WCE300/BIN/*' 'WCE/WCE300/TARGET/MIPS/*' \
            'COMMON/EVC/BIN/MSPDB60.DLL' 'COMMON/EVC/BIN/RC.EXE' 'COMMON/EVC/BIN/RCDLL.DLL' \
            'COMMON/EVC/INCLUDE/WIN32/*' >/dev/null
        mkdir -p "$sdk/evc3/target"
        mv "$tmp/evc/WCE/WCE300/BIN" "$sdk/evc3/bin"
        mv "$tmp/evc/COMMON/EVC/BIN/"* "$sdk/evc3/bin/"
        mv "$tmp/evc/WCE/WCE300/TARGET/MIPS" "$sdk/evc3/target/mips"
        mv "$tmp/evc/COMMON/EVC/INCLUDE/WIN32" "$sdk/evc3/include"
        info "eVC3 WCE300 compiler/linker binaries (reference, Wine) -> sdk/evc3/bin"
        info "CEMON.EXE (MIPS debug monitor) -> sdk/evc3/target/mips"
    fi
    [[ $found -eq 1 ]] || warn "$(basename "$iso") is not an eVC 3.0 disc with known content; skipped"
done

# --------------------------------------------------------------------------
say "Building the runtime library and the hello sample"

make -C "$root/samples/hello" clean >/dev/null
if ! make -C "$root/samples/hello" >"$tmp/build.log" 2>&1; then
    cat "$tmp/build.log" >&2
    die "sample build failed"
fi
make -C "$root/samples/selftest" >/dev/null
info "built samples/hello/build/Hello.exe and Hello.cbea"

cat >"$root/env.sh" <<EOF
# Source this to put the BE-300 tools on PATH:  . ./env.sh
export BE300_DEV="$root"
case ":\$PATH:" in *":$root/tools:"*) ;; *) export PATH="$root/tools:\$PATH" ;; esac
EOF

emu="${BE300_EMU:-$root/../be300}"
emu_state="not found (optional; set BE300_EMU or clone it to ../be300)"
if [[ -x "$emu/build-host/be300" ]]; then
    emu_state="$emu/build-host/be300"
    [[ -x "$emu/build-host/be300-install" ]] || emu_state="$emu_state (be300-install not built: cd $emu/build-host && make be300-install)"
    [[ -f "$emu/ce/restore_images/All_nand_300.bin" ]] || emu_state="$emu_state (no NAND image at ce/restore_images/All_nand_300.bin)"
fi

if [[ $run_selftest -eq 1 ]]; then
    say "Running the emulator selftest (about a minute)"
    "$root/tools/selftest.sh" | tail -1
fi

say "Done"
cat <<EOF
    sdk/         BE-300 headers + libs$( [[ -d $sdk/hpc ]] && echo ", H/PC 3.0 extras" )$( [[ -d $sdk/evc3 ]] && echo ", eVC3 binaries" )
    emulator:    $emu_state

    Next:
      . ./env.sh            # optional: put tools/ on PATH
      cd samples/hello
      make run              # install into a scratch NAND copy and boot
      make cf-run           # or boot with the app auto-launching from a CF card
EOF
