<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2026 Dracen-W
-->
# MT6768 的 Mali-G52 r49p1 用户态驱动（Magisk 模块）

[English](README.md)

这是一个 Magisk 模块：把较旧的联发科 **MT6768**（Helio G85，Mali-G52）vendor 里的 Arm Mali 用户态驱动
（`libGLES_mali.so`、Vulkan）替换成取自 Android 15 vendor 镜像的 **r49p1**。

> ## ⚠️ 实验性项目，请先读这段
>
> **目前我没有遇到过 bug，这句话的意思仅此而已。** 只有一个人、在一台设备上、测了很短的时间。
> “没发现 bug”不等于“没有 bug”。这是业余项目：不提供担保，不承诺支持，刷错了可能卡在开机 logo
> （可以恢复，见[恢复方法](#恢复方法)）。请确认你能接受这一点，并保留刷回原状的手段。
>
> **必须先刷入配套的内核**，见[前置条件](#前置条件)。没有先刷内核就装模块，预期会导致无法开机。

## 实际测试过什么

由维护者测试（设备：Redmi Note 9 (Merlinx), vendor 为 Vendor S，system 为 Infinity X 4.0 (Android 17)）：

| 项目 | 结果 |
|---|---|
| 能进入桌面 | 是 |
| 视频播放 | 是 |
| 相机预览 | 是 |
| 驱动自报的 Vulkan 版本（devcheck） | 1.3.278 |
| 游戏 / 长时间 Vulkan 负载 / HDR / 录屏 | **尚未完全测试** 简单测试没遇见bug |

表格以外的一切都没有测过。

## 前置条件

1. **r49p1 内核。** 使用
   <https://github.com/Dracen-W/android_kernel_xiaomi_mt6768_S> 中带有 `r49p1` 标记的分支
   （例如 `droidspaces-r49p1-mt6768`）。该内核包含 Mali **kbase r49p1** 内核驱动，以及它所需的联发科平台钩子。
   它**向后兼容**：刷入后设备仍可用原来的 r32 用户态正常启动，所以可以先单独验证内核，再动用户态。
   详见 [docs/KERNEL.md](docs/KERNEL.md)。
2. MT6768 设备（安装脚本会拒绝其他 `ro.board.platform`）。
3. 64 位用户态。本模块不含任何 32 位文件。
4. Magisk v20.4 或更新（安装脚本的要求）。

## 安装步骤

1. **先刷 r49p1 内核，并且此时不要安装模块**，确认能正常开机，且内核驱动是 r49p1：

   ```sh
   adb shell su -c "dmesg | grep -i -E 'Kernel DDK version|Probed as'"
   # 预期：Kernel DDK version r49p1-…  以及  Probed as mali0
   ```

2. 从 [Releases](../../releases) 下载 `Mali-r49p1-MT6768-vX.Y.Z.zip`，用同名 `.sha256` 校验，然后在 Magisk 里
   安装（*模块 → 从本地安装*）。
3. 重启。安装日志会列出驱动仍依赖设备上的哪些库；出现 `[MISSING]` 说明你的 vendor 不兼容。
4. 验证：

   ```sh
   adb shell getprop ro.vendor.arm.egl.configs.nv12.hal_format       # 0x200
   adb shell su -c "dumpsys SurfaceFlinger | grep -i GLES"            # Mali-G52 … r49p1
   adb shell cmd gpu vkjson | head
   ```

## 恢复方法

如果开机卡住，`adb` 通常仍然可用（内核和 init 已经起来，只是 SurfaceFlinger 在崩溃循环）：

```sh
adb shell su -c 'rm -rf /data/adb/modules/mali_r49p1_mt6768_slim' && adb reboot
```

也可以进入 Magisk 安全模式，或在 recovery 里删除模块目录。

## 模块里有什么

全部由 CI 从 donor 镜像构建。原理见 [docs/PATCHES.md](docs/PATCHES.md)，来源与哈希见 [docs/DONOR.md](docs/DONOR.md)。

| zip 内文件（`system/vendor/…`） | 来源 | 是否修改 |
|---|---|---|
| `lib64/egl/libGLES_mali.so` | donor vendor 镜像 | **是，2 个字节**：`DT_NEEDED libgpud.so` → `libgp49.so` |
| `lib64/libgpd9.so` | donor 的 `libgpud.so` | **是，2 个字节**：`DT_SONAME libgpud.so` → `libgpd9.so` |
| `lib64/libgp49.so` | **由 [`src/shim/shim.c`](src/shim/shim.c) 编译** | 本项目自己的代码 |
| `lib64/hw/vulkan.mali.so` | donor vendor 镜像 | 否 |
| `lib64/android.hardware.graphics.common-V5-ndk.so` | donor vendor 镜像 | 否；仅在设备缺少时安装 |
| `lib64/android.hardware.common-V2-ndk.so` | donor vendor 镜像 | 否；仅在设备缺少时安装 |
| `etc/permissions/android.hardware.vulkan.*.xml`、`android.software.vulkan.deqp.level-*.xml` | donor vendor 镜像 | 仅改名（去掉 `.prebuilt`） |
| `system.prop`（安装时生成） | donor `build.prop` 里的 56 行 `ro.vendor.arm.*` | 否；设备已定义且值不同的属性不会被覆盖 |

设备自带的 `libgpud.so`、`libged.so`、`libgpu_aux.so` **没有被替换**。其他 vendor 组件（allocator/mapper HAL、
`vulkan.mt6768.so`）还在用它们，而且它们比 r49p1 驱动需要的版本旧，所以驱动拿到的是 donor `libgpud` 的私有改名副本，
外加一个只补剩余 3 个符号的小垫片。

## Donor 镜像（厂商提供的二进制）

所有驱动二进制（除上面列出的改动外保持原样）都来自下面这个包的 **vendor 分区**：

> **`gale_global_images_OS2.0.208.0.VGPMIXM_20260713.0000.00_15.0_global_de08624a11`**
> （小米 HyperOS 2.0 国际版线刷包，代号 `gale`，Android 15，
> `ro.vendor.build.fingerprint=alps/vnd_gale/gale:15/AP3A.240905.015.A2/OS2.0.208.0.VGPMIXM:user/release-keys`）

`vendor.img`（EROFS，463 032 320 字节）SHA-256：
`864631def5bde66f17db80e908da35f9bf4c5fed492163481585baccc99cc54e`。每个文件的哈希见
[`donor/SHA256SUMS`](donor/SHA256SUMS)，任何一个对不上，构建都会中止。

这些文件是 **Arm、联发科和/或小米的专有作品**（见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)）。
因为构建需要，它们存放在本仓库的 `donor/files/` 下，但**本仓库的许可证不覆盖它们**。

## 已知限制

- **需要 YUV/AHardwareBuffer blit 路径的 Vulkan swapchain**（`GpuAuxBlitAHardwareBuffer`）不受支持：垫片返回错误，
  驱动会把它当作失败处理并记录日志。真实实现依赖 Android 15 的联发科服务，旧 vendor 没有。
- **驱动是针对 donor 的 gralloc 和联发科 GED 库构建的。** 在测试设备上，它需要的符号旧 vendor 的库里都有，
  但各条代码路径在这些库上的实际行为，除上面的测试外**没有验证过**。
- **Vulkan 特性声明直接拷自 donor**（Vulkan 1.3、deqp level 2024-03-01）。测试设备上驱动自报 1.3.278，
  但没有跑过 Vulkan CTS。
- 在按板名选择 Vulkan HAL（`vulkan.mt6768.so`）的设备上，模块自带的 `vulkan.mali.so` 可能根本没被加载；
  不管哪个壳，实现都在 `libGLES_mali.so` 里（具体加载的是哪个壳**未验证**）。
- 只研究过 MT6768 / Mali-G52 和一份 vendor 镜像。

## 构建

不需要在本地构建，CI 负责构建和发布。

- 推送 `vX.Y.Z` 标签 → [工作流](.github/workflows/build.yml) 构建 zip 并创建 GitHub Release
  （主版本号为 0 时标记为 *pre-release*）。
- 构建所需的 donor 文件放在 [`donor/`](donor/)：**只有 [`donor/SHA256SUMS`](donor/SHA256SUMS) 里列出的十个文件**，
  vendor 镜像里的其他内容一概没有。唯一的大文件 `libGLES_mali.so`（55 MB）以 xz 压缩存放（14.6 MB），
  哈希针对的是解压后的原始文件。要从 vendor 镜像刷新它们：[`tools/import_donor.sh`](tools/import_donor.sh)，
  见 [docs/DONOR.md](docs/DONOR.md)。
- 本地构建：`scripts/build.sh --version 0.1.0 --installer <Magisk 的 module_installer.sh>`
  （需要 `aarch64-linux-gnu-gcc`、`python3`、`zip`、`xz`），构建结果是确定性的。

想在尝试之前确认别的 vendor 是否兼容，先运行 [`tools/check_device_symbols.py`](tools/check_device_symbols.py)。

## 反馈问题

请按模板提 issue，并附上内核版本、安装日志、`dmesg | grep -i -E 'kbase|mali'`，以及 SurfaceFlinger 崩溃时
`/data/tombstones/` 里最新的文件。**提交前请先对比启用和禁用模块两种情况**：禁用模块（原厂 r32 驱动）下同样会出现的
崩溃，不是本模块的问题。

## 许可证

- 本仓库里的代码（脚本、`shim.c`、`patch_elf.py`、`customize.sh`、文档）采用 **Apache License 2.0**（[LICENSE](LICENSE)）。
- 上面列出的二进制**不**适用该许可证。它们仅为让模块可用而随附，仍归各自权利人所有，来源见
  [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
- 模块 zip 里还包含 Magisk 的 `module_installer.sh`（GPL-3.0，见声明文件）。
- 与 Arm、联发科、小米、Google 及 Magisk 项目无任何关联，也未获得它们的认可。如果你是权利人并希望移除某个组件，
  请提 issue，会尽快处理。

## 致谢

模块的目录结构参考了
[elitetest1/GpuDriverUpdate_Exynos2100](https://github.com/elitetest1/GpuDriverUpdate_Exynos2100)
（仅参考结构，没有使用其中任何代码或文件）。
