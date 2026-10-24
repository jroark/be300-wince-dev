#!/usr/bin/env python3
"""
mkcbea: build a Casio CASSIOPEIA .cbea install package (what MkArch.exe
makes) for a BE-300 application, plus the Setup.ini Casio's PC-side
Setup.exe reads.

Layout, matched against REQ, AIM, OTKJ, casiopims and WMP 1.1 packages:
  +0x00 u16 0x0100, +0x02 u32 file count, +0x08 UTF-16 target string
  +0x80..0xFF constant MkArch block; byte 0xDC = Destination
            (1 MAINMEM_ONLY, 2 STORAGE_ONLY, 3 ALTERNATIVE)
  +0x100 entries: u32 next (bytes after this field), u8[3] kind
            (00 00 01 .inf, 00 00 02 PE image, 00 00 03 other),
            u8 name_len, name\\0, u32 size, data
  last byte: XOR of every preceding byte
Install.inf must be the first entry.
"""

import argparse
import os
import struct
import sys
from functools import reduce

TARGET = "Casio Jx740 CE3.00"
HEADER_BLOCK = bytes.fromhex(
    "0000000000000000040000001a000000"
    "00000000000000c01401000003000000"
    "000000007e0000000300000000000000"
    "00000000010000000010000000000100"
    "ffffff7f0100000001000000a00f0000"
    "000001000400800c0000000003000000"
    + "00" * 0x20)
assert len(HEADER_BLOCK) == 0x80
DESTINATIONS = {"MAINMEM_ONLY": 1, "STORAGE_ONLY": 2, "ALTERNATIVE": 3}


def kind_for(name):
    ext = os.path.splitext(name)[1].lower()
    if ext == ".inf":
        return 1
    if ext in (".exe", ".dll"):
        return 2
    return 3


def crlf(text):
    return text.replace("\r\n", "\n").replace("\n", "\r\n").encode("latin-1")


def build_cbea(entries, destination):
    out = bytearray(0x100)
    struct.pack_into("<HI", out, 0, 0x0100, len(entries))
    tgt = TARGET.encode("utf-16-le")
    out[8:8 + len(tgt)] = tgt
    out[0x80:0x100] = HEADER_BLOCK
    out[0xDC] = DESTINATIONS[destination]
    for name, data in entries:
        nb = name.encode("latin-1")
        if len(nb) > 255:
            raise SystemExit("mkcbea: archive name too long: %s" % name)
        out += struct.pack("<I", 4 + len(nb) + 1 + 4 + len(data))
        out += bytes((0, 0, kind_for(name), len(nb)))
        out += nb + b"\0" + struct.pack("<I", len(data)) + data
    out.append(reduce(lambda a, b: a ^ b, out, 0))
    return bytes(out)


def main():
    ap = argparse.ArgumentParser(description="Build a BE-300 .cbea package")
    ap.add_argument("-o", "--output", required=True, help="output .cbea path")
    ap.add_argument("--program", required=True, help="program name (registry key, folder)")
    ap.add_argument("--caption", help="launcher caption (default: program)")
    ap.add_argument("--maker", default="be300-dev")
    ap.add_argument("--version", default="1.0")
    ap.add_argument("--exe", required=True, help="main executable")
    ap.add_argument("--file", action="append", default=[],
                    help="extra file to install next to the exe")
    ap.add_argument("--destination", default="ALTERNATIVE", choices=sorted(DESTINATIONS))
    ap.add_argument("--setup-ini", help="also write a Setup.ini here")
    ap.add_argument("--reg", action="append", default=[], metavar="ROOT,KEY,NAME,TYPE,VALUE",
                    help='extra [Add Registry] entry, e.g. HKLM,Software\\Foo,Bar,REG_DWORD,1')
    ap.add_argument("--autostart", metavar="LaunchNN",
                    help="launch the exe at boot via HKLM\\Init\\<LaunchNN> (testing aid)")
    args = ap.parse_args()

    prog = args.program
    caption = args.caption or prog
    exe_name = os.path.basename(args.exe)
    uninst = "Un%s.inf" % prog
    files = [args.exe] + args.file
    names = [os.path.basename(f) for f in files]
    if len(set(n.lower() for n in names)) != len(names):
        raise SystemExit("mkcbea: duplicate file names in package")

    copy_lines = ['"?Drive?\\Program Files\\%s" , "%s", COPYFLG_REPLACEONLY' % (uninst, uninst)]
    copy_lines += ['"%%INSTALL_DIR%%\\%s" , "%s", COPYFLG_REPLACEONLY' % (n, n) for n in names]
    install_inf = "\n".join([
        "; %s" % prog,
        "[App Information]",
        'Maker       = "%s"' % args.maker,
        'Program     = "%s"' % prog,
        "Version     = %s" % args.version,
        'InstallDir  = "?Drive?\\Program Files\\%s"' % prog,
        'ExeFile     = "\\Program Disk\\%s\\%s"' % (prog, exe_name),
        "Destination = %s" % args.destination,
        "Unload      = 1",
        'Uninstall   = "%s"' % uninst,
        'Caption     = "%s"' % caption,
        "[Copy Files]",
    ] + copy_lines)
    regs = []
    for r in args.reg:
        root, key, name, typ, value = r.split(",", 4)
        if typ.upper() in ("REG_SZ", "REG_EXPAND_SZ", "REG_MULTI_SZ"):
            value = '"%s"' % value
        regs.append('%s, "%s", "%s", %s, 0, %s' % (root, key, name, typ, value))
    if args.autostart:
        # \Program Disk is the launcher's compressed-file view; Init needs
        # the real FAT path.
        regs.append('HKEY_LOCAL_MACHINE, "Init", "%s", REG_SZ, 0, '
                    '"\\Nand Disk\\Program Files\\%s\\%s"' % (args.autostart, prog, exe_name))
    if regs:
        install_inf += "\n[Add Registry]\n" + "\n".join(regs)
    install_inf += "\n; End\n"
    uninstall_inf = "\n".join([
        "; %s" % prog,
        "[Uninstall Information]",
        'Maker   = "%s"' % args.maker,
        'Program = "%s"' % prog,
        "[Delete Files]",
        '"?Drive?\\Program Files\\%s"' % uninst,
        "[Delete Dirs]",
        '"?Drive?\\Program Files\\%s"' % prog,
        "; End",
        "",
    ])

    entries = [("Install.inf", crlf(install_inf)), (uninst, crlf(uninstall_inf))]
    for path, name in zip(files, names):
        with open(path, "rb") as f:
            entries.append((name, f.read()))

    pkg = build_cbea(entries, args.destination)
    with open(args.output, "wb") as f:
        f.write(pkg)

    if args.setup_ini:
        ini = "\n".join([
            "[APPNAME]",
            "appname = %s" % prog,
            "file = %s" % os.path.basename(args.output),
            "[REGISTRY]",
            "byte = 65536",
            "[RAM]",
            "byte = %d" % max(262144, len(pkg) * 2),
            "[PLACE]",
            "drive = 1",
            "",
        ])
        with open(args.setup_ini, "wb") as f:
            f.write(crlf(ini))


if __name__ == "__main__":
    main()
