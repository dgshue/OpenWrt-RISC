# STATUS — OpenWrt on Orange Pi RV2 (newest at top)

## 2026-07-10 — *** ONBOARD WIFI WORKING *** AP6256 SDIO bring-up (Linux)
The board's **Ampak AP6256 (Broadcom BCM43456C5)** Wi-Fi module is up under our mainline-6.18 port —
a **WPA2 STA join on 5 GHz at 433.3 Mbit/s (VHT80, −41 dBm) with a DHCP lease**. Mainline had no DTS
node for it; three patches + firmware make it work. Full writeup: `docs/wifi-ap6256.md`.
- **`patches-6.18/0004-…-enable-ap6256-sdio-wifi`** (DTS): the K1 `SDH1` node (`0xd4280800`, IRQ 100),
  `mmc2` pin group (GPIO_15..20, all pads pulled up incl. CLK), WL_REG_ON = GPIO 67 via
  `mmc-pwrseq-simple`. **Key finding:** `vmmc-supply = <&pcie_vcc3v3>` — **EXT_PWR_EN (GPIO 116)**
  gates the shared EXT_3V3 buck feeding the module VBAT (same rail as PCIe 3.3 V); without it the
  module has no VBAT and is mute to every SDIO command. `vqmmc = buck3_1v8`.
- **`patches-6.18/0005-…-fix-unaligned-HOST_CONTROL2-access`** (driver, upstream-worthy): mainline
  `sdhci-of-k1` does a **32-bit RMW of the 16-bit `HOST_CONTROL2`** (offset `0x3E`) → misaligned
  device load → **RISC-V access fault → kernel panic** in IRQ. Guarded by `!MMC_CAP2_NO_SDIO`, and
  every upstream K1 board is `no-sdio`, so **our Wi-Fi slot was the first to ever execute it** —
  100 % reproducible panic before, clean after. Fix: 16-bit `sdhci_readw/writew`.
- **`patches-6.18/0006-rtc-spacemit-p1-enable-…-32KOUT`** (PMIC RTC): SPM8821 `RTC_CTRL` powers up
  `0x00`; mainline only toggles `RTC_EN`, leaving the PMIC **32KOUT** pin dead — the board's only
  32.768 kHz source and the AP6256 **LPO**, without which brcmfmac hits `clock enable timeout`. Fix
  enables `crystal_en|out_32k_en|rtc_en|rtc_clk_sel` at probe (also fixes the RTC/`hctosys`).
- **Firmware/NVRAM:** `brcmfmac43456-sdio.{bin,clm_blob}` (RPi-Distro set, fw 7.84.17.1) + vendor
  board NVRAM + `LICENSE.brcm80211`, shipped in `base-files/lib/firmware/brcm/` (installed under both
  generic and `xunlong,orangepi-rv2` names). Packages added to `config/rv2-router.config`
  (`kmod-brcmfmac`, `BRCMFMAC_SDIO`, `wpad-mbedtls`, `iw`).
- **uci-defaults** ship a template STA config (`99-rv2-wifi-sta`) that retries each boot until the
  radio exists; uplink lands on `wwan` (DHCP, `wan` firewall zone). `brcmfmac` has no 4-addr/WDS, so
  L2-bridging the uplink needs `relayd`.
- **Sanitized for the public repo:** the shipped `99-rv2-wifi-sta` uses placeholder `ssid=YOUR-SSID`
  / `key=CHANGE-ME` (no real credentials committed); `99-rv2-lan` static IP moved to
  `192.168.1.250` (author-specific — edit for your LAN).
- **Credit:** the hardware root causes (VBAT/EXT_PWR_EN GPIO 116, PMIC 32KOUT LPO, pad config) were
  discovered during the sibling **FreeBSD/OPNsense** port's ~50-round bring-up; this port reused them.

## 2026-07-03 — Full "router" image: VPN + DNS-sink tooling + IPv6 + SMB + diagnostics
Built and flashed a complete router feature set (279 packages, ~18 MB squashfs, rootfs 13 MB) and
documented it as a reproducible profile.
- **Added:** WireGuard (`kmod-wireguard`/`wireguard-tools`/`luci-proto-wireguard`) + OpenVPN
  (`openvpn-openssl`/`openvpn-easy-rsa`/`luci-proto-openvpn`); `dnsmasq-full` (swapped for base
  dnsmasq) + `adblock` + `https-dns-proxy` + `bind-dig`; full IPv6 (`luci-proto-ipv6`, 6in4/6rd/
  ds-lite); SQM, DDNS, ACME, statistics/collectd, nlbwmon, irqbalance, upnp, ttyd; SMB
  (`ksmbd-server`); USB/ext4/f2fs/exfat storage; diagnostics (htop/tcpdump/ethtool/iperf3/…). Themes
  material + openwrt-2020 baked in.
- **Gotcha documented:** current LuCI has **no standalone VPN app pages** — WireGuard/OpenVPN are
  configured as **interface protocols** (Network → Interfaces → Protocol), via `luci-proto-*`. The
  old `luci-app-openvpn`/`luci-app-wireguard` were removed from the feed (defconfig silently dropped
  them); `luci-proto-openvpn` added in their place.
- **Profile + docs:** `config/rv2-router.config` (append + `make defconfig` to reproduce) and
  `docs/router-build.md` (package list, VPN-protocol note, and the **force-DNS/sinkhole recipe** that
  explains why AdGuard was missing queries — hardcoded DNS, DoH/DoT, and especially IPv6 RA DNS).
- Image ships with packages present but **no forced DNS/VPN config** (operator configures in LuCI).
- `mtr` didn't pull cleanly from the feed on riscv64 → omitted (busybox `traceroute` instead).

## 2026-07-03 — *** BOOTS ON HARDWARE *** + LuCI web UI; SD root fixed; repo published
First full boot to userspace on the real board, and the port is now published for contributors.
- **On-board boot confirmed** (serial COM9): kernel 6.18.37, 8 CPUs, CCU clock driver, **dual-GbE
  via `k1_emac` (eth0+eth1, 1 Gbps)**, microSD rootfs, F2FS overlay, `procd`, console. Our
  from-source, mainline-based image — no vendor blob.
- **microSD root: the load-bearing fix.** The kernel hung at `Waiting for root device …` because
  6.18's `sdhci-of-k1` never enables the SD **pad clock**, so card-init times out silently while
  U-Boot reads the same card fine. Backported upstream **`f87b273e4b6d`** as
  `patches-6.18/0002-…-enable-pad-clock`. Card then enumerates (`SD128 119 GiB`, high-speed) and
  squashfs root mounts. Full writeup: `docs/openwrt-sd-mmc-fix.md`.
- **`patches-6.18/0003-…-sd-high-speed-only`**: drop `sd-uhs-*` + add `no-1-8-v` (UHS voltage-switch/
  tuning commits not yet backported → keep the proven 3.3 V high-speed path).
- **LuCI added** (uhttpd + luci + rpcd, `apk` image) and **material/openwrt-2020 themes** installed
  live onto the running board over the serial console (base64 → `ucode b64dec` → `apk add`), no
  reflash. Web UI reachable.
- **`base-files/etc/uci-defaults/99-rv2-lan`**: bakes LAN static **192.168.1.35**, gateway/DNS `.1`,
  LAN DHCP disabled (well-behaved host, not a rogue router). Flagged in README as author-specific.
- Debug notes: card-detect gating was a red herring (removable cards fail init silently); the DTB is
  a standalone FAT file so `Image`/`dtb` can be swapped without reflashing — used heavily to iterate.
- **Published to GitHub (`dgshue/OpenWrt-RISC`)** with `README.md` + docs so others can build/contribute.

## 2026-07-03 — *** FIRST BOOTABLE IMAGE BUILT *** (ext4 + squashfs SD images)
The build now produces flashable images. Two bugs stood between the compiled kernel and an image;
both fixed:
1. **Empty subtarget** (fixed by coordinator, cfb900d): `SUBTARGETS:=generic` was declared but
   `generic/target.mk` didn't exist on the build host, so the subtarget resolved empty -> the image
   assembly was skipped and the name came out `openwrt-spacemit--xunlong` (double dash). Creating
   `target/linux/spacemit/generic/target.mk` (BOARDNAME:=Generic) made the subtarget real; images
   now name correctly `openwrt-spacemit-generic-xunlong_orangepi-rv2-*`.
2. **gen_spacemit_sdcard_img.sh ptgen misuse** (fixed here): my script passed explicit partition
   offsets `-p 64M@4M -t 83 -p 104M@68M` with `-l 1024` alignment, which made ptgen reject
   partition-1 start ("Invalid start ...") and emit only partial output; `set $(ptgen ...)` then got
   non-numeric tokens -> `/ 512 syntax error` and an empty `dd seek=` -> Error 1. Also ptgen's
   "part X Y" progress lines go to STDERR and were polluting the capture. Fix: let ptgen auto-place
   both partitions (drop the `@offset`s) and redirect stderr (`2>/dev/null`), matching the proven
   d1/starfive pattern. Now `set` cleanly gets `1048576 67108864 69206016 109051904`.
- **Result — `bin/targets/spacemit/generic/`:**
  - `openwrt-spacemit-generic-xunlong_orangepi-rv2-ext4-sdcard.img.gz`     (10.2 MB)
  - `openwrt-spacemit-generic-xunlong_orangepi-rv2-squashfs-sdcard.img.gz` ( 9.5 MB)
  - proper `openwrt-spacemit-generic-xunlong_orangepi-rv2.manifest`
  Both are valid gzips. Decompressed MBR layout verified: DOS/MBR label, disk id 0x5452574f (OWRT);
  **p1 = FAT32(LBA) 64M @sector 2048, boot flag set; p2 = Linux(83) 104M @sector 135168** — exactly
  the 2-partition boot+rootfs SD we designed. Boot FAT holds boot.scr + Image + dtb (from the build
  log's mcopy steps). U-Boot/OpenSBI stay in SPI-NOR (not in this image), matching the vendor flow.
- Image step rebuilt in ~7 s (kernel+pkgs cached). Disk healthy at 23 GB free.
- BUILD-ONLY: images NOT flashed/booted — board testing remains gated on the user.
- **This is the first-image milestone.** Next: a full clean `make` to regenerate sha256sums listing
  the images, and (gated) eventual on-board boot test.

## 2026-07-03 — Resolved ALL new kernel symbols in one pass (incl. the missing CLOCK driver!)
The RTC fix alone was insufficient: syncconfig stops at the FIRST unresolved symbol, so the next
build tripped on `MMP_PDMA (NEW)`. Fixed it properly this time — enumerated the COMPLETE unresolved
set by reconstructing the build's own .config (cat generic + target fragments) and running the
kernel's `listnewconfig`. That surfaced 4 symbols the fragments never recorded:
- **`CONFIG_SPACEMIT_K1_CCU=y` — CRITICAL CATCH.** `SPACEMIT_CCU` (which we had) is only the umbrella
  menu; the ACTUAL K1 clock-controller driver is the nested `SPACEMIT_K1_CCU`. Without it there is
  NO clock driver -> the board would not boot. Now enabled.
- `CONFIG_MMP_PDMA=y` — DMA engine (`spacemit,k1-pdma`), the RV2 DTS enables the &pdma node.
- `CONFIG_PWM_PXA=y` — PWM (`spacemit,k1-pwm`/`marvell,pxa910-pwm`), DTS has pwm nodes.
- `CONFIG_FRAME_WARN=2048` — default frame-size warning threshold.
All 4 added explicitly to config-6.18 (451 lines). **Definitive verification:** reconstructing the
build's .config from the generic+target fragments and running `listnewconfig` now returns ZERO new
symbols -> syncconfig will not prompt again (no more whack-a-mole). Root cause of the recurrence:
OpenWrt's `target/linux/refresh` omits symbols at their kconfig default, but the build's syncconfig
still treats never-recorded symbols as NEW; the fix is to record them explicitly.
config-6.18 synced to openclaw + repo (identical MD5). Committed. Relaunching the build.

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
