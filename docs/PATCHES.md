<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2026 Dracen-W
-->
# What this module changes, and why

Measured on the maintainer's device (MT6768, MIUI 13 / Android 12 vendor). Numbers come from
[`tools/check_device_symbols.py`](../tools/check_device_symbols.py); run it yourself for another vendor.

## Problem

The donor `libGLES_mali.so` (r49p1) is a MediaTek-instrumented build. Loaded on the older vendor it fails
in three stages, each of which was found from the log line the system printed:

| # | Symptom (log) | Cause | Fix in this module |
|---|---|---|---|
| 1 | `dlopen failed: library "android.hardware.graphics.common-V5-ndk.so" not found` | AIDL lib of that version absent on the device (V7 exists, but the version is part of the library name) | ship the donor copy (and `common-V2-ndk` if absent) |
| 2 | `dlopen failed: cannot locate symbol "gpudVkCreateBuffer"` | 214 imported symbols missing from the device's MediaTek libraries: **211** in `libgpud`, **2** in `libged`, **1** in `libgpu_aux` | patches 1–3 below |
| 3 | SurfaceFlinger abort, `bad_optional_access` in `eglInitialize` | the driver builds its EGL config table from `ro.vendor.arm.*` properties; the older vendor does not define them | `system.prop` (56 lines) |

## Patches

### 1. `libGLES_mali.so`: `DT_NEEDED libgpud.so` → `libgp49.so` (2 bytes)

Same-length rename inside `.dynstr`, done by [`tools/patch_elf.py`](../tools/patch_elf.py), which refuses
to run unless exactly one dynamic entry references the string and nothing else points into it.
Reproduce the check: `readelf -d libGLES_mali.so | grep NEEDED` and `cmp -l` against the donor file shows
exactly two differing bytes.

### 2. donor `libgpud.so` → `libgpd9.so`: `DT_SONAME` (2 bytes)

A private copy for the Mali driver only. The device's own `libgpud.so` is **not replaced** because other
vendor components link it and it exports 95 symbols the donor version does not (mostly the
`GPUDBufferMapper` / `GrallocHalWrapper` gralloc-mapper classes). The donor `libgpud` itself needs only one
symbol from another MediaTek library (`libgralloc_extra`), present on the tested device.

### 3. `libgp49.so`: three-symbol shim, [`src/shim/shim.c`](../src/shim/shim.c)

Sits between `libGLES_mali.so` and the private `libgpd9.so` (it depends on it, so the driver's lookups
reach the donor `libgpud`), and defines:

| Symbol | Why a stub is acceptable (from the call sites in `libGLES_mali.so`) |
|---|---|
| `GpuAuxBlitAHardwareBuffer` | one call site, in the Vulkan swapchain format-conversion path; the caller treats a non-zero return as failure and logs it. Returns `-1`. **Effect: that conversion is unavailable.** |
| `ged_fr_swd_mark_frame` | frame-rate "software watchdog" debug hook, return value unused. No-op. |
| `ged_fr_swd_frame_destroy` | same family, return value unused. No-op. |

The argument lists in the shim are what the call sites pass; they are not a documented ABI.

### 4. `system.prop`: the 56 `ro.vendor.arm.*` properties

Taken verbatim from the donor `build.prop` (EGL config `hal_format` / `framebuffer_target` /
`recordable`, and gralloc usage-flag masks). `customize.sh` writes a property only when the device has
no value or already has the same one; a different device value is kept and reported in the install log.
The gralloc usage-flag values follow the donor's Android 15 gralloc conventions; their effect on an older
gralloc is not verified.

### 5. Install-time behaviour of `customize.sh`

- refuses to install on any `ro.board.platform` other than `mt6768`;
- refuses if the early broad module `mali_gpu_driver_mt6768` is present (same overlaid files);
- keeps its AIDL libs only when the device lacks them or already has an identical copy (so re-installs
  work, and a device's own copy is never overridden);
- prints which device libraries the driver still depends on (`[bundled]` / `[vendor]` / `[system]` /
  `[MISSING]`); informational, never aborts;
- sets SELinux labels: libraries `same_process_hal_file` (they are loaded into app and SurfaceFlinger
  processes), permission XMLs `vendor_configs_file`.

## Deliberately not done

- No change to the device's `libgpud.so`, `libged.so`, `libgpu_aux.so`, gralloc/allocator/mapper HALs,
  `libGLES_meow.so` or any init script.
- No 32-bit files: the tested vendor has no 32-bit `libgpud` / `libged` / `libgpu_aux`.
- No shader-cache clearing (an earlier reference module used a broad `find /data … *shader*` delete; this
  one does not touch `/data`).

## Verification status

Offline, in CI: donor hashes, patched-file byte differences, shim has no undefined symbols and depends only
on `libgpd9.so`, shell scripts pass `shellcheck`. On a device: the sequence in the README's *What was
actually tested* table, on one device. Nothing else.
