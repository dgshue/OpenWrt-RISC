# STATUS — OpenWrt on Orange Pi RV2 (newest at top)

## 2026-07-03 — Kernel phase reached; DTS patch applied CLEAN; fixed a config-completeness gap
Build on openclaw cleared toolchain + reached the KERNEL phase. **Our DTS patch applied cleanly**
(build-openclaw-01.log:97323) and the 6.18.37 kernel prepared — the target scaffold is sound.
It then FAILED at kernel `syncconfig`: a newly-visible K1 symbol
`RTC_DRV_SPACEMIT_P1 (NEW) [Y/n/m/?]` prompted, which aborts a non-interactive build. Cause: our
config-6.18 enabled MFD/REGULATOR_SPACEMIT_P1 but not the P1 RTC sub-driver, so kconfig found it
newly-reachable (it `default ARCH_SPACEMIT` -> wants =y). Fix (all NEW symbols in one pass):
- Added `CONFIG_RTC_DRV_SPACEMIT_P1=y` (we want the P1 RTC — matches full-HW intent).
- Ran `make kernel_oldconfig` (olddefconfig-accepted all other NEW kernel symbols with their
  defaults) then `make target/linux/refresh` to regenerate config-6.18. Net diff vs prior: exactly
  ONE line (+CONFIG_RTC_DRV_SPACEMIT_P1=y); no other NEW symbol needed a non-default -> the earlier
  TRACE/KUNIT/etc `(NEW)` prompts all took defaults cleanly. config-6.18 now 447 lines.
- config-6.18 synced to BOTH openclaw and this repo (byte-identical MD5). Committed.
- RESUMED `make -j6 V=s` (toolchain cached; only kernel+packages+image re-run). Disk was ~17 GB
  free and dropping as the kernel builds — watching closely.

## 2026-07-03 — Build host migrated: WSL -> independent Ubuntu KVM VM "openclaw"
The build moved OFF WSL onto the user's dedicated Ubuntu KVM VM **openclaw** (192.168.1.20). The
WSL tree (/home/builder/openwrt) is ABANDONED. openclaw is the build host from now on.
- SSH: `ssh -i ~/.ssh/id_ed25519 openclaw@192.168.1.20` (user `openclaw`, non-root — no OpenWrt
  root-refusal). Buildroot at **~/openwrt**. Our target/linux/spacemit (config-6.18 + DTS patch +
  image profile) transferred verbatim from this repo; `make defconfig` CLEAN, target still
  spacemit/generic/orangepi-rv2.
- Build RUNNING: `make -j6 V=s`, detached, log `~/buildlogs/build-openclaw-01.log`. In host-tools;
  toolchain + kernel 6.18.37 ahead.
- **CONSTRAINTS to watch:** disk ~25 GB free (116 GB vg, 78% used) — TIGHT for a full OpenWrt build;
  polling df, will alert if free approaches ~5 GB. RAM 7.8 GB + 8 GB swap, -j6 (drop to -j4 if OOM).
- Monitoring disk + kernel-phase + errors over SSH. Report gates: kernel patch/config applied,
  then first image at `bin/targets/spacemit/generic/*.img.gz`.

## 2026-07-03 — Build env fix: OpenWrt won't build as root -> moved tree to non-root `builder`
First build (as root at /root/openwrt) FAILED early in host-tools: `tools/tar` configure aborts
with "you should not run configure as root" (build-01.log line 4788). OpenWrt's buildroot does NOT
support building as root (multiple components refuse; FORCE_UNSAFE_CONFIGURE is the wrong fix).
Fix applied the supported way:
- Created non-root WSL user `builder` (uid 1001).
- **Moved the whole tree: `/root/openwrt` -> `/home/builder/openwrt`, chown -R builder:builder.**
  My target/linux/spacemit files, feeds/, and dl/ cache all moved with it (nothing re-cloned).
- Cleaned the partial root-owned build_dir/staging_dir/tmp from the failed run.
- `make defconfig` re-run as builder: clean, target still spacemit/generic/orangepi-rv2.
- **Relaunched `make -j24 V=s` as builder** (log: /home/builder/buildlogs/build-02.log). Confirmed
  running as USER=builder and already past the previous tar failure point (compiling host tools).
- NOTE for all future build ops: the buildroot now lives at **/home/builder/openwrt** and must be
  driven as the builder user (`sudo -u builder -H bash -c '...'`). The vendor ref image stays at
  /root/owrt (read-only). Scaffold commit 449f8ac unchanged/valid.

## 2026-07-03 — GATE 1 APPROVED; target/linux/spacemit scaffolded (config-clean, DTS validated)
Coordinator approved the 6.18 + carry-master-DTS plan. Built the target skeleton (in the WSL
buildroot at /root/openwrt and mirrored into this repo under `target/linux/spacemit/`):
- **Target Makefile**: BOARD=spacemit, ARCH=riscv64, KERNEL_PATCHVER=6.18, SUBTARGETS=generic,
  FEATURES=ext4 squashfs fpu. `generic/target.mk` subtarget.
- **config-6.18** (446 lines): derived from the proven d1 riscv64 6.18 config minus all
  Allwinner/sunxi symbols, plus the K1 stack built-in (=y): ARCH_SPACEMIT, SPACEMIT_CCU,
  RESET_SPACEMIT, PINCTRL_SPACEMIT_K1, GPIO_SPACEMIT_K1, MMC_SDHCI_OF_K1, NET_VENDOR_SPACEMIT +
  SPACEMIT_K1_EMAC, MOTORCOMM_PHY (RV2's RGMII PHY), I2C_K1, MFD_SPACEMIT_P1, REGULATOR_SPACEMIT_P1,
  8250 console. Drivers built INTO the kernel (no kmod pkgs exist upstream yet).
- **DTS patch** `patches-6.18/0001-...backport-k1-board-enablement...patch`: replaces the minimal
  6.18 K1 DTS (RV2 = UART+LED only) with the mainline-MASTER trio VERBATIM (k1.dtsi 870->1345,
  k1-pinctrl.dtsi 79->633, k1-orangepi-rv2.dts 40->386; + bananapi-f3/milkv-jupiter kept
  consistent). This wires dual-GbE EMAC + microSD root + USB/PCIe/PMIC. DELTA VALIDATED: the
  clock/reset dt-bindings header is byte-identical 6.18 vs master (366 defines); all 3 K1 boards
  compile clean (cpp->dtc exit 0, zero warnings, 32 KB DTB) against 6.18 headers. Full delta
  documented in the patch header per coordinator instruction. Flagged upstreamable (NOT submitted).
- **Image recipe** (`image/Makefile` + `boot.scr.txt` + `gen_spacemit_sdcard_img.sh` + `Config.in`):
  `orangepi-rv2` device profile (DEVICE_DTS=spacemit/k1-orangepi-rv2). 2-partition MBR SD image
  (FAT boot p1 + rootfs p2), boot.scr MIRRORS the vendor ky flow exactly (booti Image+dtb,
  console=ttyS0,115200, root=PARTUUID resolved dynamically from p2, rootwait). No embedded U-Boot
  (bootloader is in SPI-NOR). SD_BOOT_PARTSIZE default 64 MB.
- **base-files**: `02_network` sets eth0=LAN / eth1=WAN (NOTE: flippable — swap in board.d if
  wiring differs); inittab console on ttyS0.
- **`make defconfig` CLEAN**: target auto-discovered, profile selected, riscv64_generic arch,
  both partsize knobs honored. Next: full kernel/image build.

## 2026-07-03 — GATE 1: kernel-version research complete (see docs/gate1-kernel-research.md)
- **OpenWrt `main` already pins Linux 6.18.37** (not 6.12). d1/sifiveu/starfive RISC-V targets all
  run `KERNEL_PATCHVER:=6.18`. So OpenWrt's kernel == the kernel we need.
- **6.18 is the minimum mainline kernel with the K1 EMAC driver merged** (the gate). Verified vs
  torvalds/linux tags: `drivers/net/ethernet/spacemit/k1_emac.c` is 404@v6.17, 200@v6.18.
  Router-critical support by version: EMAC 6.18 · MMC/SD (`sdhci-of-k1`) 6.17 · CCU clk (full PLL
  tree) 6.16 · pinctrl 6.15 · reset (`reset-spacemit`) present@6.18 · UART pre-6.15.
- **Upstream RV2 DTS exists** (`k1-orangepi-rv2.dts`, by Yangyu Chen + Hendrik Hamerlinck) but board
  enablement is staged: 6.18 = UART+LED only; 6.19-rc1 adds dual EMAC; **master** adds SD+USB+PCIe.
  Plan: build on in-tree 6.18 (zero kernel lift) and carry the mainline master DTS ourselves
  (dual-GbE + SD + USB), validating each node against the 6.18 drivers.
- Mined vendor boot flow from `/root/owrt/disk.img` (boot.scr: `booti` Image+ky.dtb,
  `console=ttyS0,115200`, `root=PARTUUID=`, `rootwait`; 2-part SD, bootloader in SPI-NOR).
- Vendor reference tree: `github.com/orangepi-xunlong/openwrt` branch `openwrt-24.10` (6.6.73 BSP) —
  reference only, not shipped.
- **Reported to main; awaiting go before building `target/linux/spacemit`.**

## 2026-07-03 — Project spun up (forked from the FreeBSD/OPNsense RV2 work)
- New, separate project created at `F:\GitHub\OpenWrt-RISC` (git init'd). `../OPNsense-RISC`
  is a read-only hardware reference and must not be modified.
- Located the vendor prebuilt OpenWrt image in `~/Downloads`:
  `openwrt-ky-riscv64-x1_orangepi-rv2-ext4-sysupgrade.img.gz` (~115 MB).
  - MBR inspected: `OWRT` signature @0x1b0, boot partition + ext4 rootfs, valid `0x55aa`.
  - Target triplet: **`ky` / `riscv64` / `x1_orangepi-rv2`** (SpacemiT/Ky vendor OpenWrt tree).
  - Note: only ONE OpenWrt image found; the "second image" the user recalled is likely the
    Ubuntu/vendor Linux image (`Orangepirv2_headless_ready.img` / the noble server 7z).
- Wrote `PROJECT.md` (goal, transferable K1 hardware knowledge, phased approach).
- **Next:** extract + analyze the vendor rootfs (OpenWrt version, kernel version, DTB, target
  `.config`, package set) → identify the upstream source tree → stand up an OpenWrt buildroot.
