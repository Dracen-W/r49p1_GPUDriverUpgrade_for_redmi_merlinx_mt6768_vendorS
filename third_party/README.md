<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2026 Dracen-W
-->
# third_party

Nothing from other projects is committed here except a licence text and a checksum.

| File | Purpose |
|---|---|
| `module_installer.sha256` | SHA-256 of Magisk's `scripts/module_installer.sh` at the pinned commit below. CI downloads the script and refuses to build if the hash differs. |
| `Magisk-LICENSE.txt` | Magisk's licence (GPL-3.0), shipped inside the module zip as `LICENSE.Magisk-installer`. |

Pinned source:
`https://raw.githubusercontent.com/topjohnwu/Magisk/cf47214ee4912ed1538fbea3d09ba9dd9b5746b0/scripts/module_installer.sh`
(commit `cf47214e…`, "Require Magisk v20.4 for modules", 2020-10-28, the last commit touching that file when pinned).
To update, change the commit in `.github/workflows/build.yml` and the hash in `module_installer.sha256`
together, and read the diff first.
