# STATUS — OpenWrt on Orange Pi RV2 (newest at top)

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
