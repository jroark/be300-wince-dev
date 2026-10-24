# be300-dev: build Casio BE-300 apps on macOS

This builds native C Win32 apps for the Casio CASSIOPEIA BE-300 (Windows CE 3.0, NEC VR41xx MIPS with no FPU) from the macOS command line. You can run them in the [BE-300 emulator](../be300), install them as Casio `.cbea` packages, or auto-launch them from a CompactFlash card. No Windows, Wine or eMbedded Visual C++ install is needed.

```
hello.c ─be300-cc─> hello.o ─be300-ld─> Hello.exe ─┬─mkcbea.py─> Hello.cbea    (launcher install)
         clang,                MIPS PE              └─mkcf.sh───> Hello-cf.img  (\CE\R4100\AutoRun.exe)
         Casio SDK headers     linker
```

## Quick start

```bash
git clone <this repo> be300-dev && cd be300-dev
cp ~/Downloads/BE300SDK_1012.zip .          # required
cp ~/Downloads/EMBEDVT3_CD*.iso .           # optional, see Inputs
./setup.sh
cd samples/hello && make                    # build/Hello.exe, Hello.cbea
```

You can put the inputs in the repo root or in `inputs/`. `setup.sh` identifies them by their contents, not their file names. `.gitignore` keeps them, and everything extracted from them, out of git.

## Inputs

You have to supply these yourself. They are licensed Casio and Microsoft media that this repo can't distribute.

| File | Needed? | What setup.sh takes from it |
| --- | --- | --- |
| **BE-300 SDK** (`BE300SDK_1012.zip`, which contains `CASIO_BE300.exe`) | **Required** | The BE-300 platform headers and MIPS libraries (`coredll.lib`, `commctrl.lib`, `winsock.lib`, Casio APIs), go to `sdk/Include` and `sdk/Lib`. The rest of the SDK goes to `sdk/be300sdk/`: docs (`CasioAPIs.chm`, PDFs), samples, on-device tools (`MEM.exe`, `gi.exe`…) and installer references. |
| **eVC++ 3.0 disc 2** (`EMBEDVT3_CD2.iso`) | Optional | H/PC Pro 3.0 SDK headers go to `sdk/hpc/Include`. They're used only as a fallback for headers the Casio SDK lacks, such as `ce_setup.h`, `version.h`, `winver.h` and `cpl.h`. The H/PC MIPS libs go to `sdk/hpc/Lib`, and the Win32 samples to `sdk/samples/hpc-win32`. |
| **eVC++ 3.0 disc 1** (`EMBEDVT3_CD1.iso`) | Optional | Microsoft's original WCE300 compiler and linker (`CLMIPS.EXE`, `LINK.EXE`, `DUMPBIN.EXE`…) go to `sdk/evc3/bin`, for reference or for use under Wine. The MIPS remote debug monitor `CEMON.EXE` goes to `sdk/evc3/target/mips`. |

The build doesn't need either eVC disc. eVC++ 4.0 media targets CE.NET 4.x, so it isn't used. Auto-detection ignores it, and passing it with `--evc` gets a warning.

## What `setup.sh` does

1. **Host tools.** It checks for Homebrew `llvm` (clang, llvm-rc, llvm-ar), `p7zip` (or `sevenzip`), `mtools`, `python3` and `make`, and installs any missing brew packages. Pass `--no-deps` to only report them.
2. **Inputs.** It finds the SDK zip and eVC ISOs. You can also name them with `--sdk ZIP` and `--evc ISO` (repeatable).
3. **Extraction.** It rebuilds `sdk/` from scratch, so re-running is safe. On a case-sensitive file system it adds lower-case header links, because the SDK writes `KFUNCS.H` but includes `kfuncs.h`.
4. **Build check.** It builds the runtime library (`build/rt/libbe300rt.a`), `samples/hello` and `samples/selftest`.
5. **Environment.** It writes `env.sh`. Run `. ./env.sh` to put `tools/` on `PATH`.
6. **Emulator check.** It reports whether the emulator is available. With `--selftest` it also runs the end-to-end emulator test.

```
sdk/
  Include/ Lib/          BE-300 platform SDK (the target)
  be300sdk/              Casio SDK docs, samples, device tools
  hpc/Include hpc/Lib    H/PC Pro 3.0 SDK fallback   (eVC disc 2)
  samples/hpc-win32/     Microsoft Win32 samples      (eVC disc 2)
  evc3/                  original eVC3 binaries, CEMON (eVC disc 1)
```

## Writing an app

Copy `samples/hello` and edit its `Makefile`:

```make
APP     := MyApp            # exe name, package/launcher key, install folder
CAPTION := My App           # launcher caption
LIBS    := coredll commctrl # import libs (default: coredll)
include ../../be300.mk
```

| Target | Result |
| --- | --- |
| `make` | `build/MyApp.exe`, `build/MyApp.cbea`, and `build/Setup.ini` for Casio's PC installer |
| `make cf` | `build/MyApp-cf.img`: a FAT16 CF image with the exe as `\CE\R4100\AutoRun.exe` |
| `make run` | Installs the `.cbea` into a scratch copy of the NAND image and boots the emulator. The app appears in the launcher. |
| `make cf-run` | Boots a scratch NAND copy with the CF image inserted. The app starts by itself. |
| `make clean` | Removes `build/` |

Other variables: `SRCS`, `RCS` (`.rc` files, compiled with llvm-rc), `EXTRA_FILES` (installed or copied next to the exe), `CBEA_FLAGS` (extra `mkcbea.py` options), `CF_SIZE` (MB) and `CFLAGS`.

To build every sample from the repo root, run `make`. `make selftest` runs the emulator test, and `make selftest-cf` runs it from a CF card.

### Auto-launch from CompactFlash

When a card is inserted, and at boot with a card present, the BE-300 runs `\Storage Card\CE\R4100\AutoRun.exe`. The Linux4.BE project used this to start its CyaCE loader. `make cf` uses the same mechanism:

- **Emulator:** run `make cf-run`. The stock NAND image boots unmodified, apart from a scratch copy the emulator may write to.
- **Real hardware:** copy the exe to the card as `CE/R4100/AutoRun.exe`, along with any extra files, using Finder or `cp`. You can also write the whole image to a card of the same size or larger with `sudo dd if=build/MyApp-cf.img of=/dev/rdiskN bs=1m`.

## Emulator (optional)

The `run`, `cf-run` and selftest targets use the emulator at `../be300`. Override the paths with `BE300_EMU` (emulator checkout) and `BE300_NAND` (base NAND image, default `$BE300_EMU/ce/restore_images/All_nand_300.bin`). Set the emulator up once:

```bash
cd ../be300 && mkdir -p build-host && cd build-host && cmake .. && make be300 be300-install
```

These targets never modify the base NAND image; they boot a copy in `build/`. When the emulator exits it flushes guest writes to that copy and saves a `screenshot_*.bmp` next to it.

## Tools

| Tool | What it does |
| --- | --- |
| `tools/be300-cc` | Runs clang with `--target=mipsel-windows-msvc -march=mips2 -msoft-float -G0` and the SDK defines. Headers are searched in this order: Casio SDK, clang builtins (`stddef.h`, `stdint.h`, `stdbool.h`), then the H/PC fallback. |
| `tools/be300-ld` | MIPS PE linker for clang's COFF objects, `.lib` archives, import libs and `.res` files. Output uses base 0x10000 and subsystem `WINDOWS_CE_GUI` 3.00, with relocations stripped, the same layout as eVC3's LINK.EXE. `--map` writes a symbol map. (lld-link can read MIPS COFF but can't apply MIPS relocations, so it can't be used.) |
| `tools/mkcbea.py` | Builds `.cbea` install packages in the same format as Casio's MkArch: repacking Casio's REQ.cbea reproduces it byte for byte. `--reg` adds registry values and `--autostart LaunchNN` adds an `HKLM\Init` boot launch. |
| `tools/mkcf.sh` | Builds a CF image with `\CE\R4100\AutoRun.exe`. |
| `tools/run-emu.sh` | Boots the emulator on a scratch NAND copy, optionally installing packages first and/or attaching `--cf IMG`. |
| `tools/nand-cat.sh` | Lists or reads files on the NAND's `\Nand Disk` volume, or on a bare FAT16 CF image. |
| `tools/selftest.sh` | End-to-end test: runs `samples/selftest` in the emulator and checks the log it writes. Add `--cf` to launch it from a CF card instead. |

`rt/` is the small runtime linked into every app. It provides `WinMainCRTStartup` and `DebugBreak`, and forwards clang's soft-float and 64-bit division helpers to Microsoft's versions in COREDLL (`__dpadd`, `__ll_div`, …).

## Debugging tips

- `OutputDebugStringW` output appears on the emulator's stdout, interleaved with the guest serial log.
- Write logs to `\Nand Disk\…` and read them back after the emulator exits with `tools/nand-cat.sh build/nand.run.bin mylog.txt`.
- `BE300_AUTOSTOP_SEC=N make cf-run` stops the emulator after N seconds and saves a screenshot, which is handy for scripted checks.
- `HKLM\Init` autostart (`--autostart`) launches the app before the Casio shell starts, so the shell's launcher then covers its window. CF autorun launches it after the shell is up.

## Limits

- Only C is supported: no C++ (EH/RTTI), MFC or ATL, and no DLLs. The linker doesn't emit exports or base relocations yet. Many eVC samples are C++ and need porting.
- `be300-cc` compiles with `-G0` because GP-relative data isn't supported. MIPS16 isn't supported either.
- The C runtime is whatever COREDLL exports (`malloc`, `memcpy`, `wcslen`, `swprintf`, …). `corelibc.lib` isn't linked.
- The H/PC Pro libs in `sdk/hpc/Lib` include DLLs the BE-300 doesn't ship, such as `ceshell` and `htmlview`. Link against them only if you know the DLL exists on the device.
- What's been verified, all in the emulator: `.cbea` installs, CF autorun and the selftest. Casio's PC-side Setup.exe hasn't been tested with these packages on real hardware.
