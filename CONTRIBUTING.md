<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2026 Dracen-W
-->
# Contributing

Bug reports with logs are the most useful contribution. Test **with and without** the module first.

## Pull requests

- Keep a change to one topic. Explain the *why*, not just the *what*.
- Commit messages follow the kernel style: a subject of the form `area: summary` (≤ 72 chars), a blank
  line, then a body that explains the problem and the evidence. Example:
  `shim: return an error from GpuAuxBlitAHardwareBuffer`.
- **Sign off every commit** (`git commit -s`). That certifies the
  [Developer Certificate of Origin 1.1](https://developercertificate.org/): you wrote the change or
  have the right to submit it under this project's licence (Apache-2.0).
- Every new source file needs SPDX headers (`SPDX-License-Identifier`, `SPDX-FileCopyrightText`);
  CI runs `reuse lint`.
- Shell must pass `shellcheck`; Python must compile; the build must stay deterministic.
- **Keep the proprietary content minimal.** The only third-party binaries allowed in the repository are the
  ones listed in `donor/SHA256SUMS`, under `donor/files/`. Do not add other firmware content, firmware images
  or build outputs. A change to which donor files are used must update `donor/SHA256SUMS`, `docs/DONOR.md`
  and `THIRD_PARTY_NOTICES.md` together (use `tools/import_donor.sh`).
- Claims in the docs must be things that were actually observed. Mark the rest as "not verified".

## Supporting another vendor image or SoC

Start with `tools/check_device_symbols.py`. If it reports missing symbols outside the three libraries this
module covers, the driver will not load there; say so in the issue instead of widening the shim blindly.
