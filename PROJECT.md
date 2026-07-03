# OpenWrt on Orange Pi RV2 (SpacemiT K1 / Ky X1) — RISC-V

Porting / building a proper, reproducible **OpenWrt** (Linux) image for the **Orange Pi RV2**
(SpacemiT K1 = "Ky X1", RISC-V rv64gc, 8-core, dual GbE). Sibling to — but fully separate
from — the FreeBSD/OPNsense port in `../OPNsense-RISC` (that folder is a **read-only reference**
here; do not modify it).

## Why
We reverse-engineered a lot of the K1 SoC during the FreeBSD port (register maps, clock tree,
DTB layout, board bring-up quirks). OpenWrt is Linux-based, so the *drivers* differ, but the
**hardware knowledge and board-ops knowledge transfer**. Orange Pi already ships a prebuilt
OpenWrt image; the goal here is a **source-built, controllable, ideally upstream-quality port**
rather than depending on a vendor blob.

## Working goal (confirm/refine)
Produce a **reproducible from-source OpenWrt build** for the RV2 that we control:
buildable target + device profile + kernel/DTB config, understood delta from upstream OpenWrt,
booting on real hardware. (Scope — vendor-parity vs. mainline-clean vs. customized — TBD.)

## What we have
- **Vendor prebuilt image:** `openwrt-ky-riscv64-x1_orangepi-rv2-ext4-sysupgrade.img.gz`
  (~115 MB, in `~/Downloads`). MBR layout: `OWRT` metadata signature + boot partition + ext4
  rootfs. Target triplet: **`ky` / `riscv64` / `x1_orangepi-rv2`** (a SpacemiT/Ky vendor OpenWrt tree).
- **K1 hardware reference** (from the FreeBSD port, read-only): `../OPNsense-RISC/docs/hardware/`
  — SoC device map, register maps, clock/reset IDs, vendor boot logs, the DTB, the schematic +
  chip manual PDFs. The definitive hardware audit is `../OPNsense-RISC/docs/hardware/hardware-audit.md`.
- **Board-ops knowledge (transferable):** serial console on **COM9** (115200); watchdog-based
  reset; **marginal microSD** (keep quality cards; caused fs panics under heavy I/O on FreeBSD);
  U-Boot/OpenSBI live in SPI-NOR (SD flash doesn't touch the bootloader); board bring-up needs
  HDMI or `nodevice`-style console care.

## Approach (phased — to refine)
1. **Analyze the vendor image** — extract rootfs; capture OpenWrt version, kernel version, DTB,
   `.config`/target, banner, package set. Learn exactly what Orange Pi built.
2. **Identify the source tree** — which OpenWrt fork/branch the `ky` target came from
   (SpacemiT "bianbu" OpenWrt? Orange Pi's? mainline OpenWrt K1 status?).
3. **Stand up a build environment** — OpenWrt buildroot on a Linux host/VM (not the FreeBSD VMs).
4. **Reproduce the build** — target + device profile → a bootable image we built ourselves.
5. **Understand + clean the delta** — vendor patches vs. upstream; document; work toward a
   clean/upstreamable port.

## Constraints (inherited)
Author: **dgshue** / dgshue@gmail.com, no `Co-Authored-By`. All work on dgshue's own forks /
local only; **no upstream submission** (OpenWrt PRs, patches, mailing lists) without explicit
approval. `.claude/` stays git-ignored. **Do not modify `../OPNsense-RISC`.**

## Layout
- `STATUS.md` — living worklog (newest at top)
- `docs/` — analysis, build notes, hardware cross-references
