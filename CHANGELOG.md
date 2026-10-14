<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2026 Dracen-W
-->
# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [SemVer](https://semver.org/);
`0.x` releases are pre-releases.

## [Unreleased]

## [0.1.0]
### Added
- First public version: Mali r49p1 `libGLES_mali.so` / `vulkan.mali.so` for MT6768 with a private donor
  `libgpud` (`libgpd9.so`), a three-symbol shim (`libgp49.so`), the AIDL libraries `common-V5` / `common-V2`
  (conditional), the Vulkan feature declarations and the 56 `ro.vendor.arm.*` properties.
- Deterministic CI build from the donor files stored in `donor/` (only the ten files the build uses); releases are created from tags.
- `tools/check_device_symbols.py` to test a vendor image before installing.
