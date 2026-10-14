// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 Dracen-W
/*
 * libgp49.so - three-symbol compatibility shim for the Mali r49p1 libGLES_mali.so
 * running on an older MediaTek vendor image.
 *
 * libGLES_mali.so (from the Android 15 donor vendor) imports three symbols that the
 * device's own libged.so / libgpu_aux.so do not export:
 *
 *   GpuAuxBlitAHardwareBuffer   One call site, in the Vulkan swapchain format-conversion
 *                               path. The caller does `if (ret != 0) { log; fail path }`,
 *                               so returning an error is handled by the driver. The real
 *                               implementation needs the Android 15 MMS AIDL service
 *                               (vendor.mediatek.hardware.mms-V1), which older vendors lack.
 *                               Effect: that format conversion is unavailable.
 *
 *   ged_fr_swd_mark_frame       Frame-rate "software watchdog" debug hook. The return
 *   ged_fr_swd_frame_destroy    value is unused at every call site. No-op.
 *
 * Everything else the driver needs from the donor's libgpud.so is satisfied by the private
 * copy libgpd9.so, on which this library depends (see docs/PATCHES.md).
 *
 * The argument lists below are what the call sites pass; they are not a documented ABI.
 */
#define EXPORT __attribute__((visibility("default")))

EXPORT int GpuAuxBlitAHardwareBuffer(void *ctx, void *ahb)
{
	(void)ctx;
	(void)ahb;
	return -1; /* "not supported" */
}

EXPORT void ged_fr_swd_mark_frame(int a, int b, void *c, void *d)
{
	(void)a;
	(void)b;
	(void)c;
	(void)d;
}

EXPORT void ged_fr_swd_frame_destroy(void)
{
}
