# STATUS — OpenWrt on Orange Pi RV2 (newest at top)

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
