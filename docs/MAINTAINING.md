<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2026 Dracen-W
-->
# Maintaining and releasing

## One-time setup

1. Create the GitHub repository and push. Keep the repository name in sync with the badge and links in
   `README.md` / `README.zh-CN.md`.
2. Resolve every `TODO(maintainer)` marker (`grep -rn "TODO(maintainer)" .`): device model, ROM and
   Magisk version in the README; the exact kernel branch or release asset in `docs/KERNEL.md`.
3. Decide, knowingly, whether to publish this repository and the module zip: both contain third-party
   binaries (`donor/files/` and the zip, see `THIRD_PARTY_NOTICES.md`). Once a binary is in git history it can
   only be removed by rewriting history, so be sure before the first public push (a private repository is
   a good place for the first CI run). Keep `donor/` limited to the files in `donor/SHA256SUMS`.

## Releasing

1. Move the `[Unreleased]` entries of `CHANGELOG.md` under a new version heading, commit.
2. Tag and push: `git tag -s v0.1.0 -m "v0.1.0" && git push origin v0.1.0`.
3. The workflow lints, builds from `donor/`, and creates the GitHub Release (pre-release while the
   major version is 0) with the zip and its `.sha256`.
4. Download the released zip once and install it on a test device before announcing it.

## Changing the donor firmware

New firmware means new hashes and possibly a different symbol gap. Run `tools/import_donor.sh`, update
`docs/DONOR.md` and `THIRD_PARTY_NOTICES.md`, re-run `tools/check_device_symbols.py`, and re-read
`docs/PATCHES.md` before trusting the result.

## Housekeeping

- Actions are referenced by major-version tags and kept current by Dependabot. For stricter supply-chain
  hygiene, pin them to full commit SHAs.
- The pinned Magisk installer commit and its hash must be changed together (`third_party/README.md`).
