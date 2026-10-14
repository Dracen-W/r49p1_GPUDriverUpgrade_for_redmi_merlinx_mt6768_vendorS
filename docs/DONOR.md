<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2026 Dracen-W
-->
# Donor image: provenance and hashes

## Source

| | |
|---|---|
| Package | `gale_global_images_OS2.0.208.0.VGPMIXM_20260713.0000.00_15.0_global_de08624a11` |
| What it is | Xiaomi HyperOS 2.0 global fastboot package, codename `gale`, Android 15 |
| Partition used | `vendor` → `vendor.img` (EROFS, 463 032 320 bytes) |
| `vendor.img` SHA-256 | `864631def5bde66f17db80e908da35f9bf4c5fed492163481585baccc99cc54e` |
| `ro.vendor.build.fingerprint` | `alps/vnd_gale/gale:15/AP3A.240905.015.A2/OS2.0.208.0.VGPMIXM:user/release-keys` |
| `ro.vendor.build.date` | Mon Jul 13 11:25:40 UTC 2026 |

The package is Xiaomi's; obtain it from Xiaomi. The Mali kernel driver in the paired kernel tree is
separate and not taken from this package.

## Files taken (and only these)

Paths are inside `vendor.img`; hashes are those in [`donor/SHA256SUMS`](../donor/SHA256SUMS), which
`scripts/build.sh` enforces.

| Path | Size (bytes) | SHA-256 | Used as |
|---|---|---|---|
| `/lib64/egl/libGLES_mali.so` | 55 036 616 | `1fddbd79…769d6` | patched (2 bytes), see PATCHES.md |
| `/lib64/libgpud.so` | 330 168 | `a6c40be6…a473b` | patched (2 bytes), shipped as `libgpd9.so` |
| `/lib64/hw/vulkan.mali.so` | 133 152 | `c34703d3…ce71` | as is |
| `/lib64/android.hardware.graphics.common-V5-ndk.so` | 31 520 | `3dfe2d47…6342` | as is, conditional |
| `/lib64/android.hardware.common-V2-ndk.so` | 18 776 | `b95fc08d…0c39` | as is, conditional |
| `/etc/permissions/android.hardware.vulkan.compute-0.prebuilt.xml` | 866 | `65e26b6a…4561` | renamed |
| `/etc/permissions/android.hardware.vulkan.level-1.prebuilt.xml` | 865 | `8d78cbae…13bc` | renamed |
| `/etc/permissions/android.hardware.vulkan.version-1_3.prebuilt.xml` | 902 | `e4674544…5959` | renamed |
| `/etc/permissions/android.software.vulkan.deqp.level-2024-03-01.prebuilt.xml` | 915 | `361ea806…c668` | renamed |
| `/build.prop` (only the 56 `ro.vendor.arm.*` lines) | — | `35b84062…e638` (the extracted file) | `system.prop` |

Full hashes are in `donor/SHA256SUMS` and are of the **uncompressed originals**.

Nothing else from the vendor image is stored in this repository. The files live under `donor/files/` with
the same relative paths; `libGLES_mali.so` is stored as `libGLES_mali.so.xz` (`xz -9e`, 14 645 012 bytes)
because the original is 55 MB. `donor/PROVENANCE.txt` records the source package and image hash.
`scripts/build.sh` decompresses, checks every file against `SHA256SUMS`, and fails if a file is missing,
different, or present but not listed.

## Refreshing or auditing `donor/`

```sh
# 1. Get vendor.img from the package named above (unpack super.img yourself, e.g. with lpunpack).
# 2. Check:  sha256sum vendor.img   -> must match the hash above
# 3. Re-create donor/ from it (needs erofs-utils and xz):
tools/import_donor.sh --vendor-img vendor.img
# 4. Compare:
git diff --stat donor/SHA256SUMS      # empty for the same firmware
```

`donor/SHA256SUMS` is the source of truth. The bytes of `libGLES_mali.so.xz` may differ between xz versions;
that is harmless as long as the decompressed file hashes the same.

A different firmware means different hashes and possibly a different symbol gap: review
`docs/PATCHES.md`, update `THIRD_PARTY_NOTICES.md`, and re-run `tools/check_device_symbols.py`
before trusting the result.

## Licensing note

The donor binaries are not this project's to license. See [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
The files are committed to this repository, so every clone contains them; decide that knowingly.
