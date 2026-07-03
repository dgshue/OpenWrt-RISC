# OpenWrt for the Orange Pi RV2 (SpacemiT K1 / Ky X1, RISC-V)

A **from-source, mainline-kernel** OpenWrt target for the **Orange Pi RV2** — the
SpacemiT **K1** ("Ky X1") SoC: 8-core RISC-V `rv64gc`, dual Gigabit Ethernet, microSD boot.

Upstream OpenWrt has **no K1 target**. This repo adds one (`target/linux/spacemit`) on top of
OpenWrt `main`'s Linux **6.18**, carrying a small set of device-tree and driver backports so the
board boots a clean, reproducible image we build ourselves — not a vendor blob.

> **Status: boots to a full OpenWrt userspace on real hardware.** Kernel 6.18.37, dual-GbE via
> `k1_emac`, microSD rootfs (F2FS overlay), `procd`, and the **LuCI** web UI all come up. See
> [STATUS.md](STATUS.md) for the running worklog.

---

## Hardware

| | |
|---|---|
| Board | Orange Pi RV2 |
| SoC | SpacemiT K1 (a.k.a. Ky "X1"), 8× RISC-V `rv64imafdcv`, `rv64gc` userland |
| RAM | 8 GB LPDDR4X |
| Ethernet | 2× GbE — SpacemiT EMAC IP (`k1_emac`), Motorcomm RGMII PHY (no HW offload) |
| Storage | microSD (root); eMMC pads; SPI-NOR holds U-Boot/OpenSBI |
| Console | Serial **UART0**, `ttyS0` @ **115200** (COM9 on the dev host) |
| Bootloader | Vendor U-Boot 2022.10ky + OpenSBI, **in SPI-NOR** — flashing the SD does not touch it |

The bootloader living in SPI-NOR is important: our SD image provides only a FAT boot partition
(`boot.scr` + `Image` + `dtb`) and the rootfs. U-Boot loads `boot.scr` from the SD and `booti`s the
kernel — mirroring the vendor flow.

---

## What works / what doesn't

**Working:** SMP boot (8 cores), clock/reset (CCU), pinctrl, GPIO, I²C, SpacemiT P1 PMIC +
regulators + RTC, **microSD** (high-speed), **dual Gigabit Ethernet**, 8250 serial console,
squashfs root + F2FS overlay, `procd`, LuCI web UI.

**Not yet / caveats:**
- **microSD runs in high-speed (3.3 V) mode only**, not UHS — see [patch 0003](#patches) and the
  [MMC fix writeup](docs/openwrt-sd-mmc-fix.md). UHS needs two more driver commits backported.
- USB / PCIe device-tree nodes are present (from the board backport) but not exercised/validated here.
- No Wi-Fi (board has none on-SoC).
- `reboot` behaviour on this board is quirky (OpenSBI SRST is a no-op on the vendor firmware) — a
  power cycle is the reliable reset.

---

## Build from source

OpenWrt **must not be built as root.** Use a normal user on a Debian/Ubuntu-like host.

```sh
# 1. Build deps (Debian/Ubuntu)
sudo apt install build-essential clang flex bison g++ gawk gettext git \
  libncurses-dev libssl-dev python3 rsync unzip zlib1g-dev file wget swig time

# 2. OpenWrt main (pins Linux 6.18)
git clone https://git.openwrt.org/openwrt/openwrt.git
cd openwrt

# 3. Drop in this target
git clone https://github.com/dgshue/OpenWrt-RISC.git /tmp/rv2
cp -a /tmp/rv2/target/linux/spacemit target/linux/

# 4. Feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 5. Select the target + build
make defconfig          # auto-selects spacemit / generic / xunlong_orangepi-rv2
make -j"$(nproc)"
```

Output lands in `bin/targets/spacemit/generic/`:

- `openwrt-spacemit-generic-xunlong_orangepi-rv2-squashfs-sdcard.img.gz` (recommended)
- `openwrt-spacemit-generic-xunlong_orangepi-rv2-ext4-sdcard.img.gz`

### Adding the LuCI web UI (optional)

```sh
./scripts/feeds install luci
echo 'CONFIG_PACKAGE_luci=y'                     >> .config
echo 'CONFIG_PACKAGE_luci-theme-material=y'      >> .config   # optional themes
echo 'CONFIG_PACKAGE_luci-theme-openwrt-2020=y'  >> .config
make defconfig && make -j"$(nproc)"
```

---

## Flash & first boot

1. Decompress and write the `.img.gz` to a **quality** microSD (balenaEtcher reads the gz directly
   and verifies). SD-card quality matters on this board — cheap/worn cards fail to init.
2. Insert the card, connect serial (`115200 8N1`), power on. Watch for
   `Starting kernel …` → `Please press Enter to activate this console.`
3. Networking default (see caveat below): LAN comes up and the board is reachable; open
   `http://<board-ip>/` for LuCI. No root password is set initially (set one in
   *System → Administration* or via `passwd` on the console before enabling SSH).

> ⚠️ **Local LAN default:** [`base-files/etc/uci-defaults/99-rv2-lan`](target/linux/spacemit/base-files/etc/uci-defaults/99-rv2-lan)
> sets a **static `192.168.1.35`**, points gateway/DNS at `192.168.1.1`, and **disables the LAN
> DHCP server** (so the board is a well-behaved host on an existing network rather than a router at
> `.1`). This is tailored to the author's LAN — **edit or delete that file** to restore OpenWrt's
> standard `192.168.1.1` + DHCP behaviour before building your own image.

---

## The target & patches

```
target/linux/spacemit/
├── Makefile                     # BOARD=spacemit, ARCH=riscv64, KERNEL_PATCHVER=6.18
├── config-6.18                  # K1 driver stack built-in (CCU clk, EMAC, sdhci, pinctrl, PMIC…)
├── generic/target.mk            # the 'generic' subtarget
├── image/                       # SD image recipe (MBR: FAT boot p1 + rootfs p2, boot.scr)
├── base-files/                  # 02_network (eth0=LAN/eth1=WAN), inittab, uci-defaults
└── patches-6.18/
    ├── 0001-…-backport-k1-board-enablement…      # board DTS (see below)
    ├── 0002-mmc-sdhci-of-k1-enable-pad-clock…    # the SD boot fix (see below)
    └── 0003-…-sd-high-speed-only                 # constrain SD to high-speed
```

### Patches

- **0001 — board device-tree backport.** OpenWrt's 6.18 ships only a minimal K1 DTS (RV2 = UART+LED).
  This replaces the K1 DTS trio (`k1.dtsi`, `k1-pinctrl.dtsi`, `k1-orangepi-rv2.dts`) with the
  mainline-**master** versions, wiring dual-GbE EMAC, microSD, USB, PCIe and the PMIC. The
  clock/reset dt-bindings header is byte-identical between 6.18 and master, and all three K1 boards
  compile clean against the 6.18 headers.

- **0002 — `sdhci-of-k1` pad-clock enable** *(backport of upstream `f87b273e4b6d`, 2026-05-11).*
  **This is the fix that makes the microSD work under Linux.** The 6.18 driver never enables the SD
  **pad clock**, so the card receives no clock and card-init times out *silently* (`mmc1: Failed to
  initialize …` with no CRC/-110/voltage error). U-Boot reads the same card fine, which makes it a
  confusing failure. Full debugging story: **[docs/openwrt-sd-mmc-fix.md](docs/openwrt-sd-mmc-fix.md).**

- **0003 — microSD high-speed only.** We backport 0002 but not the K1 UHS voltage-switch/tuning
  commits (`00a97fc57c09`, `e9cb83c10071`), so requesting UHS risks a failed 1.8 V switch during
  init. This drops `sd-uhs-*` and adds `no-1-8-v` for reliable 3.3 V high-speed operation. Remove it
  once those two commits are backported.

---

## Contributing

PRs to **this repo** are welcome — additional hardware bring-up (USB, PCIe, UHS SD), config
cleanups, docs, and testing on real boards. Useful conventions:

- Keep the target buildable against OpenWrt `main` and match OpenWrt's style for target files.
- Kernel patches under `patches-6.18/` should be minimal and, where possible, **backports of merged
  mainline commits** (cite the upstream hash in the patch header, as 0002 does).
- Test on hardware over the serial console (`115200`); include the relevant boot-log lines in your PR.
- Upstreaming changes to OpenWrt or the Linux kernel is coordinated by the maintainer — open an issue
  first.

Related sibling project (separate repo): a FreeBSD/OPNsense port of the same board, which is where
much of the K1 hardware reverse-engineering (register maps, clock tree, board quirks) originated.

---

## Credits & license

Maintainer: **Daniel Shue** (`dgshue`). Upstream K1 enablement is the work of the SpacemiT / Ky
engineers and the mainline RISC-V community (device tree by Yangyu Chen & Hendrik Hamerlinck; the
`sdhci-of-k1` clock fix by Iker Pedrosa / Yixun Lan).

Target files and patches are licensed **GPL-2.0**, matching OpenWrt and the Linux kernel they derive
from. Backported patches retain their upstream authorship and license.
