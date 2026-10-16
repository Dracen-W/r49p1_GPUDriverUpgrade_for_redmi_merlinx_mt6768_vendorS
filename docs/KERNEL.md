<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2026 Dracen-W
-->
# Kernel requirement

This module only replaces **userspace** files. The Mali **kernel** driver (kbase) must already be
r49p1, otherwise the r49p1 userspace has no matching kernel side.

## Which kernel

<https://github.com/Dracen-W/android_kernel_xiaomi_mt6768_S/>, branch/build carrying the `r49p1` tag.
The specific branch of r49p1 is <https://github.com/Dracen-W/android_kernel_xiaomi_mt6768_S/> and the current release for the kernel `r49p1 driver (kbase)` is <https://github.com/Dracen-W/android_kernel_xiaomi_mt6768_S/releases/tag/202610150654-a06e6c-r49p1/>.

## What that kernel changes

The r49p1 kbase drop replaced `kbase_platform_device_probe()` with the upstream version, which lost
the MediaTek calls that the r32p1 tree makes around `kbase_device_init()`. Without them,
`pm_callback_power_on()` dereferences MFG register and `kbdev` globals that were never initialised, and
the kernel stalls in `kernel_init` (no adb, boot logo never advances). The kernel tree restores, in
the same order as r32p1:

```
mtk_common_device_init(kbdev);      /* stores kbdev, registers the GED DVFS callbacks   */
mtk_platform_device_init(kbdev);    /* maps the MFG config registers; before kbase init */
err = kbase_device_init(kbdev);
mtk_common_procfs_init();           /* after a successful probe                         */
```

and adds the includes `platform/mtk_platform_common.h` and `<mtk_gpufreq.h>`.

## Compatibility, and what was observed

- **Observed:** the r49p1 kernel boots to the desktop with the device's original **r32 userspace**
  and no module installed (kbase accepts older userspace). That is why the kernel can and should be
  validated first.
- **Not tested, expected:** installing this module on a kernel whose kbase is older than r49p1. The
  userspace/kernel version check would fail, the driver would get no GPU, SurfaceFlinger would be
  unable to create an EGL display and crash-loop at the boot logo. `adb` stays up in that state; use
  the recovery command in the README.

## Order of operations

1. Flash the r49p1 kernel, **without** the module. Boot. Check `dmesg` for `Kernel DDK version r49p1`
   and `Probed as mali0`.
2. Only then install the module and reboot.
3. If you ever flash a different kernel, disable the module first.
