#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 Dracen-W
"""Check which symbols of the donor libGLES_mali.so your device's own libraries lack.

Pull the device's MediaTek GPU libraries first (they are not modified by this module):

    adb shell su -c 'mkdir -p /data/local/tmp/devlibs && for f in libgpud libgpu_aux libged \
        libgralloc_extra libgralloc_metadata libgralloctypes_mtk libgralloctypes libdmabufheap \
        libion libladder; do cp /vendor/lib64/$f.so /data/local/tmp/devlibs/; done'
    adb pull /data/local/tmp/devlibs

then:

    check_device_symbols.py --mali donor/files/lib64/egl/libGLES_mali.so \
        --donor-libs DIR_WITH_DONOR_LIBS --device-libs devlibs

Needs `readelf` (binutils). Prints, per library, how many symbols libGLES_mali.so imports that the
device copy does not export. A non-zero count is exactly what the shim and the private libgpud
copy in this module exist to cover. A count for a library this module does NOT cover means the
module will not load on your vendor.
"""
import argparse
import os
import subprocess
import sys

LIBS = ['libgpud', 'libgpu_aux', 'libged', 'libladder', 'libgralloc_extra',
        'libgralloc_metadata', 'libgralloctypes_mtk', 'libgralloctypes', 'libdmabufheap', 'libion']


def symbols(path):
    out = subprocess.run(['readelf', '-Ws', '--dyn-syms', '-W', path],
                         capture_output=True, text=True, check=True).stdout
    undefined, defined = set(), set()
    for line in out.splitlines():
        f = line.split()
        if len(f) < 8 or not f[0].endswith(':'):
            continue
        name = f[7].split('@')[0]
        if f[6] == 'UND':
            if f[4] != 'WEAK':
                undefined.add(name)
        elif f[3] in ('FUNC', 'OBJECT', 'NOTYPE', 'TLS', 'IFUNC'):
            defined.add(name)
    return undefined, defined


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--mali', required=True, help='donor libGLES_mali.so')
    ap.add_argument('--donor-libs', required=True, help='directory with the donor copies of the MediaTek libs')
    ap.add_argument('--device-libs', required=True, help='directory with the device copies')
    a = ap.parse_args()

    mali_und, _ = symbols(a.mali)
    donor = {m: symbols(os.path.join(a.donor_libs, m + '.so'))[1]
             for m in LIBS if os.path.exists(os.path.join(a.donor_libs, m + '.so'))}
    device = {m: symbols(os.path.join(a.device_libs, m + '.so'))[1]
              for m in LIBS if os.path.exists(os.path.join(a.device_libs, m + '.so'))}

    needed = {m: {s for s in mali_und if s in donor[m]} for m in donor}
    total = 0
    print(f'{"library":22s}{"needed":>8s}{"on device":>11s}{"MISSING":>9s}')
    for m in LIBS:
        if m not in donor or not needed[m]:
            continue
        if m not in device:
            print(f'{m:22s}{len(needed[m]):8d}{"(lib absent on device)":>20s}')
            continue
        missing = sorted(s for s in needed[m] if not any(s in d for d in device.values()))
        total += len(missing)
        print(f'{m:22s}{len(needed[m]):8d}{len(needed[m]) - len(missing):11d}{len(missing):9d}')
        for s in missing[:3]:
            print(f'    e.g. {s}')
    print(f'\nTOTAL symbols libGLES_mali.so needs that the device libraries do not export: {total}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
