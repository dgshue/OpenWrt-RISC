# Contributing to OpenWrt-RISC

Thanks for your interest. This repo adds an **OpenWrt target for the Orange Pi
RV2** (SpacemiT K1 / Ky X1, RISC-V `rv64gc`) — `target/linux/spacemit` on top of
OpenWrt `main`. It's a hobbyist hardware port, and the most useful contribution
is usually **testing on a real board and reporting what happened**. Please read
this before opening an issue or PR.

## Ground rules

- **This is a personal fork; upstreaming is out of scope here.** Do **not** send
  changes from this repo to OpenWrt or the Linux kernel (OpenWrt PRs/patches,
  `openwrt-devel@`, kernel mailing lists, etc.). If something looks
  upstreamable, note it in your PR/issue and let the maintainer coordinate it —
  open an issue first.
- **License: GPL-2.0-only.** Target files and patches match OpenWrt and the
  Linux kernel they derive from. Backported kernel patches keep their upstream
  authorship and license — cite the upstream commit hash in the patch header
  (patch `0002` is the model to follow). See `LICENSE`.
- **Author identity:** commit as yourself; no `Co-Authored-By` trailers.

## Building

Full build instructions are in the [README](README.md#build-from-source).
In short:

- **OpenWrt must not be built as root** — use a normal user on a Debian/Ubuntu-like host.
- Clone OpenWrt `main` (it pins Linux 6.18), drop this repo's
  `target/linux/spacemit` into `target/linux/`, update/install feeds, then
  `make defconfig && make -j"$(nproc)"`.
- Output images land in `bin/targets/spacemit/generic/`.
- Optional profiles: LuCI web UI and the full router build
  (`config/rv2-router.config`) — see the README and
  [`docs/router-build.md`](docs/router-build.md).

Relevant docs: [`docs/openwrt-sd-mmc-fix.md`](docs/openwrt-sd-mmc-fix.md) (the
load-bearing microSD pad-clock fix), [`docs/router-build.md`](docs/router-build.md),
and [`docs/gate1-kernel-research.md`](docs/gate1-kernel-research.md).

## Coding conventions

- **Target files** (`Makefile`, `config-6.18`, `image/`, `base-files/`) should
  match OpenWrt's style for target files and stay buildable against OpenWrt `main`.
- **Kernel patches** live in `patches-6.18/`. Keep them minimal and, wherever
  possible, make them **backports of merged mainline commits** — cite the
  upstream hash in the patch header (see `0002-…-enable-pad-clock`). New
  functional patches should explain *why* in the header, as the existing ones do.
- **Board-specific defaults** (e.g. `base-files/etc/uci-defaults/99-rv2-lan`,
  which hard-codes a static LAN address for the author's network) must be clearly
  flagged as author-specific in the README so downstream builders know to change
  them. Don't bake personal network settings into shared defaults silently.
- Update `STATUS.md` with a newest-at-top entry: what you changed, what you
  tested, what's still open.

## Branch & PR flow

- The default branch is `master`. Branch from it and open your PR against it.
- Use short descriptive branch names (e.g. `sd-uhs-backport`, `usb-enable`).
- Keep PRs scoped to one logical change; rebase on the latest `master` before
  submitting.
- Fill in `.github/PULL_REQUEST_TEMPLATE.md`, especially the hardware-test boxes.

## Reporting hardware-test results (important)

This is a hardware port, so **"it builds" is not "it works."** Many changes can
only be validated on a real board. When you open a PR or bug report, please state:

- **What you actually ran:** build-only? flashed and booted on real hardware?
  ran under load?
- **Board** and connection (serial console `115200 8N1`, SD card model — SD
  quality matters a lot on this board).
- **The image build** you tested (target/profile, kernel version, git commit).
- **A serial console log** covering the relevant boot lines — paste the actual
  lines (`Starting kernel …` through the failure or the login prompt), not a
  paraphrase. For the SD/root path especially, the console log is essential.
- For a regression, the last known-good build and the first bad one.

Build-only contributions are welcome — just label them honestly so the
maintainer knows they still need on-board validation.

## Security-relevant findings

If you find something sensitive (a leaked credential or key), please report it
privately to the maintainer rather than opening a public issue.
