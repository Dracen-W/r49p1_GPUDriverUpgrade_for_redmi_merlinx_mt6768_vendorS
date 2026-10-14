#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 Dracen-W
#
# (Re)create donor/ from a donor vendor image: copies ONLY the files listed below, stores files
# larger than 10 MB xz-compressed, writes donor/PROVENANCE.txt and regenerates donor/SHA256SUMS
# (hashes of the uncompressed originals).
#
#   tools/import_donor.sh --vendor-img vendor.img [--firmware NAME]
#   tools/import_donor.sh --vendor-dir DIR        [--firmware NAME]
#
# --vendor-img needs erofs-utils (fsck.erofs) and xz.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
FIRMWARE="gale_global_images_OS2.0.208.0.VGPMIXM_20260713.0000.00_15.0_global_de08624a11"
IMG=""; DIR=""
FILES=(
  lib64/egl/libGLES_mali.so
  lib64/hw/vulkan.mali.so
  lib64/libgpud.so
  lib64/android.hardware.graphics.common-V5-ndk.so
  lib64/android.hardware.common-V2-ndk.so
  etc/permissions/android.hardware.vulkan.compute-0.prebuilt.xml
  etc/permissions/android.hardware.vulkan.level-1.prebuilt.xml
  etc/permissions/android.hardware.vulkan.version-1_3.prebuilt.xml
  etc/permissions/android.software.vulkan.deqp.level-2024-03-01.prebuilt.xml
)
COMPRESS_OVER=$((10 * 1024 * 1024))

while [ $# -gt 0 ]; do
  case "$1" in
    --vendor-img) IMG=$2; shift 2 ;;
    --vendor-dir) DIR=$2; shift 2 ;;
    --firmware)   FIRMWARE=$2; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$IMG" ] || [ -n "$DIR" ] || { echo "need --vendor-img or --vendor-dir" >&2; exit 2; }
command -v xz >/dev/null || { echo "xz not found" >&2; exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
if [ -n "$IMG" ]; then
  command -v fsck.erofs >/dev/null || { echo "fsck.erofs not found (apt install erofs-utils)" >&2; exit 1; }
  mkdir -p "$TMP/vendor"
  fsck.erofs --extract="$TMP/vendor" "$IMG" >/dev/null
  DIR="$TMP/vendor"
  IMG_SHA=$(sha256sum "$IMG" | cut -d' ' -f1); IMG_SIZE=$(stat -c%s "$IMG")
else
  IMG_SHA="(extracted directory, image hash not available)"; IMG_SIZE="n/a"
fi

OUT="$ROOT/donor"; rm -rf "$OUT/files"; mkdir -p "$OUT/files"
: > "$TMP/sums"
for f in "${FILES[@]}"; do
  [ -f "$DIR/$f" ] || { echo "missing in donor image: $f" >&2; exit 1; }
  mkdir -p "$OUT/files/$(dirname "$f")"
  if [ "$(stat -c%s "$DIR/$f")" -gt "$COMPRESS_OVER" ]; then
    xz -9e -T1 -c "$DIR/$f" > "$OUT/files/$f.xz"
  else
    cp "$DIR/$f" "$OUT/files/$f"
  fi
  (cd "$DIR" && sha256sum "$f") >> "$TMP/sums"
done
grep '^ro\.vendor\.arm\.' "$DIR/build.prop" | LC_ALL=C sort > "$OUT/files/arm_props.txt"
[ -s "$OUT/files/arm_props.txt" ] || { echo "no ro.vendor.arm.* properties in build.prop" >&2; exit 1; }
(cd "$OUT/files" && sha256sum arm_props.txt) >> "$TMP/sums"
LC_ALL=C sort -k2 "$TMP/sums" > "$OUT/SHA256SUMS"

prop() { grep -m1 "^$1=" "$DIR/build.prop" | cut -d= -f2-; }
cat > "$OUT/PROVENANCE.txt" <<EOP
Donor firmware package : $FIRMWARE
Partition              : vendor.img (EROFS)
vendor.img size/sha256 : $IMG_SIZE / $IMG_SHA
ro.vendor.build.fingerprint        : $(prop ro.vendor.build.fingerprint)
ro.vendor.build.version.incremental: $(prop ro.vendor.build.version.incremental)
ro.vendor.build.date               : $(prop ro.vendor.build.date)
Files copied unmodified from the image: see donor/SHA256SUMS in the source repository.
These files are proprietary or third-party works; see THIRD_PARTY_NOTICES.md.
EOP
echo "donor/ written; review with 'git status' and 'git diff donor/SHA256SUMS'"
