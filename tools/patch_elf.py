#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 Dracen-W
"""Rename one DT_NEEDED or DT_SONAME entry of an ELF shared object, in place.

The new name must have exactly the same length as the old one, so only the bytes of one
string in .dynstr change; no section, segment or offset moves. The tool refuses to run
unless the string is referenced by exactly one dynamic entry and no symbol name or other
dynamic entry points into the middle of it (suffix sharing).

    patch_elf.py needed IN OUT OLD NEW
    patch_elf.py soname IN OUT OLD NEW
"""
import struct
import sys

DT_NEEDED, DT_SONAME, DT_RPATH, DT_RUNPATH = 1, 14, 15, 29


def _sections(d):
    shoff = struct.unpack_from('<Q', d, 0x28)[0]
    shentsize, shnum, shstrndx = struct.unpack_from('<HHH', d, 0x3a)
    secs = []
    for i in range(shnum):
        name, _typ, _flags, _addr, off, size, _link, _info, _align, _entsize = \
            struct.unpack_from('<IIQQQQIIQQ', d, shoff + i * shentsize)
        secs.append({'name': name, 'off': off, 'size': size})
    shstr = secs[shstrndx]
    for s in secs:
        end = d.index(b'\0', shstr['off'] + s['name'])
        s['n'] = d[shstr['off'] + s['name']:end].decode()
    return secs


def rename(src, dst, tag, old, new):
    if len(old) != len(new):
        raise SystemExit('error: old and new names must have the same length')
    d = bytearray(open(src, 'rb').read())
    if d[:4] != b'\x7fELF' or d[4] != 2 or d[5] != 1:
        raise SystemExit('error: only little-endian ELF64 is supported')
    secs = {s['n']: s for s in _sections(d)}
    dyn, dstr, dsym = secs['.dynamic'], secs['.dynstr'], secs['.dynsym']
    hits, string_refs = [], set()
    for o in range(dyn['off'], dyn['off'] + dyn['size'], 16):
        t, v = struct.unpack_from('<qQ', d, o)
        if t in (DT_NEEDED, DT_SONAME, DT_RPATH, DT_RUNPATH):
            string_refs.add(v)
        if t == tag:
            end = d.index(b'\0', dstr['off'] + v)
            if bytes(d[dstr['off'] + v:end]) == old.encode():
                hits.append(v)
    if len(hits) != 1:
        raise SystemExit(f'error: expected exactly one {old!r} entry, found {len(hits)}')
    lo = hits[0]
    hi = lo + len(old)
    shared = [r for r in string_refs if lo < r < hi]
    for o in range(dsym['off'], dsym['off'] + dsym['size'], 24):
        st_name = struct.unpack_from('<I', d, o)[0]
        if lo <= st_name < hi:
            shared.append(st_name)
    if shared:
        raise SystemExit(f'error: string is shared with other references: {shared}')
    d[dstr['off'] + lo:dstr['off'] + hi] = new.encode()
    open(dst, 'wb').write(d)
    return lo


def main(argv):
    if len(argv) != 6 or argv[1] not in ('needed', 'soname'):
        raise SystemExit(__doc__)
    kind, src, dst, old, new = argv[1:]
    off = rename(src, dst, DT_NEEDED if kind == 'needed' else DT_SONAME, old, new)
    print(f'{src}: DT_{kind.upper()} {old!r} -> {new!r} (.dynstr+{off:#x}) => {dst}')


if __name__ == '__main__':
    main(sys.argv)
