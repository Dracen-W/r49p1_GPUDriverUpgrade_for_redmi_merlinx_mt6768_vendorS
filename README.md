<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2026 Dracen-W
-->
# Mali-G52 r49p1 userspace driver for MT6768 (Magisk module)

[![build](https://github.com/Dracen-W/magisk-mali-r49p1-mt6768/actions/workflows/build.yml/badge.svg)](https://github.com/Dracen-W/magisk-mali-r49p1-mt6768/actions/workflows/build.yml)
[中文说明](README.zh-CN.md)

A Magisk module that replaces the Arm Mali userspace driver (`libGLES_mali.so`, Vulkan) of an
older MediaTek **MT6768** (Helio G85, Mali-G52) vendor image with **r49p1** taken from an Android 15
vendor image.

> ## ⚠️ Experimental — read this first
>
> **I have not run into a bug so far. That is all this means.** It was tested by one person, on
> one device, for a short time. "No known bugs" is not "no bugs". This is a hobby project: no
> warranty, no support promise, and a bad flash can leave your device stuck at the boot logo
> (recoverable, see [Recovery](#recovery)). Use it only if you are comfortable with that, and keep
> a way to flash your device back.
>
> **You must flash the matching kernel first** — see [Requirements](#requirements). Installing the
> module without it is expected to break boot.
> 
> **Some times** the kernel **may have booting problem** (e.g. stuck at system loading page), **just reboot** and everything will be fine.

## What was actually tested

Tested by the maintainer (device: Redmi note 9 (Merlinx) with vendor S by and an Infinity X 4.0 system (Android 17)):

| Checked | Result |
|---|---|
| Boots to the desktop | yes |
| Video playback | yes |
| Camera preview | yes |
| Vulkan version reported by the driver (devcheck) | 1.3.278 |
| Games / long Vulkan workloads / HDR / screen recording | **not yet fully tested** but no bugs have been see currently |

Anything outside this table is untested.

## Requirements

1. **The r49p1 kernel.** Use the build from
   <https://github.com/Dracen-W/android_kernel_xiaomi_mt6768_S> on the branch whose name carries the
   `r49p1` tag (for example `droidspaces-r49p1-mt6768`). That kernel contains the Mali **kbase r49p1**
   kernel driver plus the MediaTek platform hooks it needs. It is **backward compatible**: with it
   flashed, the device still boots with its original r32 userspace, so you can verify the kernel on
   its own before touching userspace. Details: [docs/KERNEL.md](docs/KERNEL.md).
2. An MT6768 device (the installer refuses any other `ro.board.platform`).
3. 64-bit userspace. This module ships no 32-bit files.
4. Magisk v20.4 or newer (the installer script requires it).

## Installation

1. **Flash the r49p1 kernel and boot with the module NOT installed.** Confirm it boots and the
   kernel driver is r49p1:

   ```sh
   adb shell su -c "dmesg | grep -i -E 'Kernel DDK version|Probed as'"
   # expect: Kernel DDK version r49p1-…   and   Probed as mali0
   ```

2. Download `Mali-r49p1-MT6768-vX.Y.Z.zip` from the [Releases](../../releases), check it against the
   `.sha256` file, and install it in Magisk (*Modules → Install from storage*).
3. Reboot. The install log lists which device libraries the driver still relies on; a
   `[MISSING]` line there means your vendor image is not compatible.
4. Verify:

   ```sh
   adb shell getprop ro.vendor.arm.egl.configs.nv12.hal_format       # 0x200
   adb shell su -c "dumpsys SurfaceFlinger | grep -i GLES"            # Mali-G52 … r49p1
   adb shell cmd gpu vkjson | head
   ```

## Recovery

If boot hangs, `adb` normally still works (the kernel and init are up; SurfaceFlinger is crash-looping):

```sh
adb shell su -c 'rm -rf /data/adb/modules/mali_r49p1_mt6768_slim' && adb reboot
```

or boot into Magisk safe mode, or delete the module directory from recovery.

## What is inside

Everything is built from a donor image by CI; see [docs/PATCHES.md](docs/PATCHES.md) for the reasoning
and [docs/DONOR.md](docs/DONOR.md) for provenance and hashes.

| File in the zip (`system/vendor/…`) | Origin | Modified? |
|---|---|---|
| `lib64/egl/libGLES_mali.so` | donor vendor image | **yes — 2 bytes**: `DT_NEEDED libgpud.so` → `libgp49.so` |
| `lib64/libgpd9.so` | donor `libgpud.so` | **yes — 2 bytes**: `DT_SONAME libgpud.so` → `libgpd9.so` |
| `lib64/libgp49.so` | **built from [`src/shim/shim.c`](src/shim/shim.c)** | this project's own code |
| `lib64/hw/vulkan.mali.so` | donor vendor image | no |
| `lib64/android.hardware.graphics.common-V5-ndk.so` | donor vendor image | no — installed only if the device lacks it |
| `lib64/android.hardware.common-V2-ndk.so` | donor vendor image | no — installed only if the device lacks it |
| `etc/permissions/android.hardware.vulkan.*.xml`, `android.software.vulkan.deqp.level-*.xml` | donor vendor image | renamed only (`.prebuilt` removed) |
| `system.prop` (generated at install) | 56 `ro.vendor.arm.*` lines of the donor `build.prop` | no; a property the device already defines with another value is never overridden |

The device's own `libgpud.so`, `libged.so` and `libgpu_aux.so` are **not replaced**. They are used by
other vendor components (allocator/mapper HALs, `vulkan.mt6768.so`) and are older than what the r49p1
driver imports, so the driver gets a private renamed copy of the donor `libgpud` plus a small shim for
the remaining three symbols.

## Donor image (vendor-supplied binaries)

All driver binaries come, unchanged apart from the edits listed above, from the **vendor partition** of:

> **`gale_global_images_OS2.0.208.0.VGPMIXM_20260713.0000.00_15.0_global_de08624a11`**
> (Xiaomi HyperOS 2.0 global fastboot package, codename `gale`, Android 15,
> `ro.vendor.build.fingerprint=alps/vnd_gale/gale:15/AP3A.240905.015.A2/OS2.0.208.0.VGPMIXM:user/release-keys`)

`vendor.img` (EROFS, 463 032 320 bytes) SHA-256
`864631def5bde66f17db80e908da35f9bf4c5fed492163481585baccc99cc54e`. Per-file hashes are in
[`donor/SHA256SUMS`](donor/SHA256SUMS); the build refuses to continue if any of them differs.

These files are **proprietary works of Arm, MediaTek and/or Xiaomi** (see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)). They are stored in this repository under `donor/files/`
because the build needs them, and **this repository's licence does not cover them**.

## Known limitations

- **Vulkan swapchains that need the YUV/AHardwareBuffer blit path** (`GpuAuxBlitAHardwareBuffer`) are
  not supported: the shim returns an error, which the driver reports and handles as a failure. The
  real implementation needs an Android 15 MediaTek service older vendors do not have.
- **The driver was built against the donor's gralloc and MediaTek GED libraries.** It resolves against
  the older vendor's copies of those libraries (all required symbols are present on the tested
  device), but how every code path behaves against them is **not verified** beyond the tests above.
- **The Vulkan feature declarations are copied from the donor** (Vulkan 1.3, deqp level 2024-03-01).
  The driver itself reports 1.3.278 on the tested device, but it has not been run through the Vulkan CTS.
- On devices that select the Vulkan HAL by board name (`vulkan.mt6768.so`), the bundled
  `vulkan.mali.so` may simply not be used; the implementation lives in `libGLES_mali.so` either way
  (not verified which shim is loaded).
- Only MT6768 / Mali-G52 and one vendor image have been looked at.

## Building

CI builds and publishes releases; you do not need to build locally.

- Push a tag `vX.Y.Z` → the [workflow](.github/workflows/build.yml) builds the zip and creates a
  GitHub Release (marked *pre-release* while the major version is 0).
- The donor files the build needs are stored in [`donor/`](donor/): **only the ten files listed in
  [`donor/SHA256SUMS`](donor/SHA256SUMS)**, nothing else from the vendor image. The one large file,
  `libGLES_mali.so` (55 MB), is stored xz-compressed (14.6 MB); the hashes are of the uncompressed originals.
  To refresh them from a vendor image: [`tools/import_donor.sh`](tools/import_donor.sh), see
  [docs/DONOR.md](docs/DONOR.md).
- Local build: `scripts/build.sh --version 0.1.0 --installer <Magisk module_installer.sh>`
  (needs `aarch64-linux-gnu-gcc`, `python3`, `zip`, `xz`). The build is deterministic.

To check whether a different vendor image is compatible *before* trying anything, run
[`tools/check_device_symbols.py`](tools/check_device_symbols.py).

## Reporting problems

Open an issue using the template and attach the kernel version, the install log, `dmesg | grep -i -E
'kbase|mali'`, and the newest `/data/tombstones/` file if SurfaceFlinger crashed. **Test with and without
the module** before reporting: a crash that also happens with the stock r32 driver is not this module's.

## Licence

- The code in this repository (scripts, `shim.c`, `patch_elf.py`, `customize.sh`, documentation) is
  licensed under the **Apache License 2.0** ([LICENSE](LICENSE)).
- The binaries listed above are **not** under that licence. They are redistributed only so the
  module is usable, remain the property of their owners, and are listed with their provenance in
  [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- The module zip also contains Magisk's `module_installer.sh` (GPL-3.0, see the notices).
- Not affiliated with or endorsed by Arm, MediaTek, Xiaomi, Google or the Magisk project. If you are
  a rights holder and want a component removed, open an issue and it will be handled promptly.

## Acknowledgements

The module layout was inspired by
[elitetest1/GpuDriverUpdate_Exynos2100](https://github.com/elitetest1/GpuDriverUpdate_Exynos2100)
(structure only; no code or files were taken from it).
