#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 Dracen-W
#
# Build the Magisk module zip.
#
#   scripts/build.sh --version 0.1.0 --installer FILE [--donor DIR] [--out DIR]
#
#   --installer  Magisk's scripts/module_installer.sh (CI fetches a pinned copy, see
#                third_party/README.md)
#   --donor      donor directory (default: donor/ in this repository; see docs/DONOR.md)
#
# Needs: bash, python3, zip, xz, sha256sum, aarch64-linux-gnu-gcc.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION=""; DONOR="$ROOT/donor"; INSTALLER=""; OUT="$ROOT/dist"
while [ $# -gt 0 ]; do
  case "$1" in
    --version)   VERSION=$2; shift 2 ;;
    --donor)     DONOR=$2; shift 2 ;;
    --installer) INSTALLER=$2; shift 2 ;;
    --out)       OUT=$2; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "--version must look like 1.2.3" >&2; exit 2; }
[ -d "$DONOR/files" ] || { echo "--donor must contain a files/ directory" >&2; exit 2; }
[ -f "$INSTALLER" ]   || { echo "--installer file not found" >&2; exit 2; }
for t in python3 zip xz sha256sum aarch64-linux-gnu-gcc; do
  command -v "$t" >/dev/null || { echo "missing tool: $t" >&2; exit 1; }
done

IFS=. read -r MAJ MIN PAT <<<"$VERSION"
VERSIONCODE=$((MAJ * 10000 + MIN * 100 + PAT))
SDE=${SOURCE_DATE_EPOCH:-$(git -C "$ROOT" log -1 --format=%ct 2>/dev/null || echo 0)}
NAME="Mali-r49p1-MT6768-v$VERSION"

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
M="$WORK/module"; V="$M/system/vendor"; F="$WORK/donor"

echo "==> unpacking donor files (*.xz are decompressed) and verifying them against donor/SHA256SUMS"
mkdir -p "$F"
(cd "$DONOR/files" && find . -type f) | while read -r f; do
  mkdir -p "$F/$(dirname "$f")"
  case "$f" in
    *.xz) xz -dc "$DONOR/files/$f" > "$F/${f%.xz}" ;;
    *)    cp "$DONOR/files/$f" "$F/$f" ;;
  esac
done
(cd "$F" && sha256sum --strict -c "$ROOT/donor/SHA256SUMS")
# nothing may be present that is not listed in SHA256SUMS
[ "$(cd "$F" && find . -type f | wc -l)" -eq "$(wc -l < "$ROOT/donor/SHA256SUMS")" ] \
  || { echo "donor/files contains files not listed in donor/SHA256SUMS" >&2; exit 1; }
mkdir -p "$V/lib64/egl" "$V/lib64/hw" "$V/etc/permissions" "$M/docs" "$M/META-INF/com/google/android"

echo "==> patch: libGLES_mali.so  (DT_NEEDED libgpud.so -> libgp49.so)"
python3 "$ROOT/tools/patch_elf.py" needed "$F/lib64/egl/libGLES_mali.so" "$V/lib64/egl/libGLES_mali.so" libgpud.so libgp49.so
echo "==> patch: libgpud.so -> libgpd9.so  (DT_SONAME)"
python3 "$ROOT/tools/patch_elf.py" soname "$F/lib64/libgpud.so" "$V/lib64/libgpd9.so" libgpud.so libgpd9.so

echo "==> build: libgp49.so (shim)"
aarch64-linux-gnu-gcc -O2 -shared -fPIC -nostdlib -ffreestanding -fno-stack-protector \
  -fno-asynchronous-unwind-tables -ffile-prefix-map="$ROOT"=. \
  -Wl,-soname,libgp49.so -Wl,--hash-style=both -Wl,-z,noexecstack \
  -Wl,-z,max-page-size=4096 -Wl,-z,common-page-size=4096 -Wl,--no-as-needed \
  "$ROOT/src/shim/shim.c" "$V/lib64/libgpd9.so" -o "$V/lib64/libgp49.so"
# the shim must not pull in anything but libgpd9.so
NEEDED=$(aarch64-linux-gnu-readelf -d "$V/lib64/libgp49.so" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p' | tr '\n' ' ')
[ "$NEEDED" = "libgpd9.so " ] || { echo "unexpected NEEDED in shim: $NEEDED" >&2; exit 1; }
[ -z "$(aarch64-linux-gnu-readelf --dyn-syms -W "$V/lib64/libgp49.so" | awk '$7=="UND" && $8!=""')" ] \
  || { echo "shim has undefined symbols" >&2; exit 1; }

echo "==> copy: unmodified donor files"
cp "$F/lib64/hw/vulkan.mali.so" "$V/lib64/hw/"
cp "$F/lib64/android.hardware.graphics.common-V5-ndk.so" "$F/lib64/android.hardware.common-V2-ndk.so" "$V/lib64/"
for x in "$F"/etc/permissions/*.prebuilt.xml; do
  cp "$x" "$V/etc/permissions/$(basename "$x" .prebuilt.xml).xml"
done
cp "$F/arm_props.txt" "$M/docs/arm_props.txt"

echo "==> assemble module"
cp "$ROOT/module/customize.sh" "$M/customize.sh"
sed -e "s/@VERSION@/$VERSION/" -e "s/@VERSIONCODE@/$VERSIONCODE/" "$ROOT/module/module.prop.in" > "$M/module.prop"
cp "$INSTALLER" "$M/META-INF/com/google/android/update-binary"; chmod 0755 "$M/META-INF/com/google/android/update-binary"
echo '#MAGISK' > "$M/META-INF/com/google/android/updater-script"
cp "$ROOT/LICENSE" "$ROOT/NOTICE" "$ROOT/THIRD_PARTY_NOTICES.md" "$M/"
cp "$ROOT/third_party/Magisk-LICENSE.txt" "$M/LICENSE.Magisk-installer"
cp "$ROOT/docs/PATCHES.md" "$ROOT/docs/DONOR.md" "$ROOT/docs/KERNEL.md" "$M/docs/"
cp "$ROOT/src/shim/shim.c" "$ROOT/tools/patch_elf.py" "$M/docs/"
cp "$ROOT/donor/PROVENANCE.txt" "$M/docs/DONOR_PROVENANCE.txt"
(cd "$M" && find system -type f | LC_ALL=C sort | xargs sha256sum > MANIFEST.sha256)

echo "==> zip (deterministic: sorted, mtime=$SDE, no extra attributes)"
find "$M" -type d -exec chmod 0755 {} + ; find "$M" -type f -exec chmod 0644 {} +
chmod 0755 "$M/META-INF/com/google/android/update-binary"
find "$M" -exec touch -h -d "@$SDE" {} +
mkdir -p "$OUT"; rm -f "$OUT/$NAME.zip"
(cd "$M" && find . -type f | sed 's#^\./##' | LC_ALL=C sort | zip -X -9 -q -@ "$OUT/$NAME.zip")
(cd "$OUT" && sha256sum "$NAME.zip" > "$NAME.zip.sha256")
echo "==> $OUT/$NAME.zip"; cat "$OUT/$NAME.zip.sha256"
