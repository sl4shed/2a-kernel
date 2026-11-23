#!/usr/bin/env python3
"""Check that stock vendor modules can link against a freshly built kernel.

Usage: check_module_abi.py <Module.symvers> <dir with stock .ko files>

For every .ko it reads the __versions table (symbol name + CRC the module was
built against) and compares it with the exports in Module.symvers (vmlinux
plus in-tree GKI modules) and the symbols the other stock modules export.
A missing symbol or CRC mismatch means the module would fail to load
("disagrees about version of symbol" / "Unknown symbol") on the phone.

Needs llvm-objcopy and llvm-nm on PATH.
"""
import os
import struct
import subprocess
import sys
import tempfile


def read_symvers(path):
    exports = {}
    with open(path) as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 2:
                exports[parts[1]] = int(parts[0], 16)
    return exports


def module_versions(ko, tmp):
    out = os.path.join(tmp, "versions.bin")
    if os.path.exists(out):
        os.unlink(out)
    r = subprocess.run(["llvm-objcopy", "--dump-section", f"__versions={out}", ko, os.path.join(tmp, "junk.o")],
                       capture_output=True)
    if r.returncode != 0 or not os.path.exists(out):
        return {}
    data = open(out, "rb").read()
    versions = {}
    for off in range(0, len(data) - 63, 64):
        crc = struct.unpack_from("<Q", data, off)[0] & 0xFFFFFFFF
        name = data[off + 8:off + 64].split(b"\0", 1)[0].decode()
        if name:
            versions[name] = crc
    return versions


def module_exports(ko):
    r = subprocess.run(["llvm-nm", "--defined-only", ko], capture_output=True, text=True)
    syms = set()
    for line in r.stdout.splitlines():
        name = line.split()[-1]
        if name.startswith("__ksymtab_"):
            syms.add(name[len("__ksymtab_"):])
    return syms


def main():
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    kernel = read_symvers(sys.argv[1])
    kos = []
    for root, _, files in os.walk(sys.argv[2]):
        kos += [os.path.join(root, f) for f in files if f.endswith(".ko")]
    stock_exports = set()
    for ko in kos:
        stock_exports |= module_exports(ko)

    bad_crc, missing, checked = [], [], 0
    with tempfile.TemporaryDirectory() as tmp:
        for ko in sorted(kos):
            name = os.path.basename(ko)
            for sym, crc in module_versions(ko, tmp).items():
                checked += 1
                if sym in kernel:
                    if kernel[sym] != crc:
                        bad_crc.append((name, sym, crc, kernel[sym]))
                elif sym not in stock_exports:
                    missing.append((name, sym))

    print(f"{len(kos)} modules, {checked} versioned symbol references checked")
    for name, sym, want, got in bad_crc:
        print(f"CRC MISMATCH {name}: {sym} module=0x{want:08x} kernel=0x{got:08x}")
    for name, sym in missing:
        print(f"MISSING {name}: {sym}")
    if bad_crc or missing:
        print(f"FAIL: {len(bad_crc)} CRC mismatches, {len(missing)} missing symbols")
        return 1
    print("OK: every symbol matches")
    return 0


if __name__ == "__main__":
    sys.exit(main())
