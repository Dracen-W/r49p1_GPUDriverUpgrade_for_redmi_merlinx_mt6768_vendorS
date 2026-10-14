<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2026 Dracen-W
-->
# Third-party notices

Everything in the first table is **not** covered by this repository's Apache-2.0 licence. It is
redistributed unmodified, or with the minimal documented edits, so that the module works. The licence
terms below are stated to the best of the maintainer's knowledge; they were **not** verified with the
rights holders, and the maintainer is not a lawyer. If you are a rights holder and want something
removed, open an issue.

These files are also **stored in this repository**, under `donor/files/` (only the ones the build uses,
listed in `donor/SHA256SUMS`; `libGLES_mali.so` as `.xz`), because the build needs them. Storing them here
does not make them part of this project's licence.

Origin of every binary: the `vendor` partition of
`gale_global_images_OS2.0.208.0.VGPMIXM_20260713.0000.00_15.0_global_de08624a11` (Xiaomi). See
[docs/DONOR.md](docs/DONOR.md) for hashes.

| Component | Owner / terms (as far as known) | Edit made here | Source |
|---|---|---|---|
| `libGLES_mali.so` | Arm Mali GPU userspace driver (DDK r49p1), MediaTek-integrated build, shipped by Xiaomi. Proprietary; no licence is granted by this project. | 2 bytes: `DT_NEEDED` name (`tools/patch_elf.py`) | none available to the maintainer; the edit is reproducible from this repository |
| `libgpud.so` (shipped as `libgpd9.so`) | MediaTek, proprietary. | 2 bytes: `DT_SONAME` | as above |
| `vulkan.mali.so` | Arm / MediaTek, proprietary. | none | none available |
| `android.hardware.graphics.common-V5-ndk.so`, `android.hardware.common-V2-ndk.so` | Built from Android Open Source Project AIDL interface definitions (Apache-2.0); compiled binaries from the vendor build. | none | AOSP (Apache-2.0) |
| `android.hardware.vulkan.*.xml`, `android.software.vulkan.deqp.level-*.xml` | Copyright The Android Open Source Project, Apache-2.0 (licence header kept in each file). | renamed (`.prebuilt` removed) | AOSP |
| `system.prop` values (`ro.vendor.arm.*`) | Configuration data from the donor `build.prop` (Xiaomi / Arm / MediaTek). | none | donor image |
| `META-INF/com/google/android/update-binary` | Magisk `scripts/module_installer.sh` by John Wu (topjohnwu) and contributors. Magisk is distributed under **GPL-3.0** (`third_party/Magisk-LICENSE.txt`). The maintainer could not confirm whether this single file carries a different notice, so GPL-3.0 is assumed. | none (hash-checked) | <https://github.com/topjohnwu/Magisk/blob/cf47214ee4912ed1538fbea3d09ba9dd9b5746b0/scripts/module_installer.sh> |

The installer script is only *aggregated* into the zip next to the module's own files; it is a
separate program, run by Magisk, and the module's own files do not link against it. Its full source is
the file at the URL above; the zip carries it unmodified and includes the licence text as
`LICENSE.Magisk-installer`.

## Trademarks

"Arm", "Mali", "MediaTek", "Helio", "Xiaomi", "HyperOS", "Android", "Vulkan" and "Magisk" are
trademarks of their respective owners. This project is not affiliated with or endorsed by any of them.
