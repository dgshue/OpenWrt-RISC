# GATE 1 — Kernel-version research (SpacemiT K1 / Orange Pi RV2 on OpenWrt)

Date: 2026-07-03. Method: offline where possible; mainline verification via the actual
`torvalds/linux` git tree (raw.githubusercontent.com per-tag file probes + GitHub contents API),
plus the OpenWrt `main` buildroot at `/root/openwrt`, plus the vendor image at `/root/owrt/disk.img`.
No board contact.

## TL;DR

- **OpenWrt `main` now pins Linux `6.18.37` (LTS-line 6.18)** — NOT 6.12 as the initial brief
  assumed. All three existing RISC-V targets (`d1`, `sifiveu`, `starfive`) already run
  `KERNEL_PATCHVER:=6.18`. So the kernel we want and the kernel OpenWrt carries are the SAME major.
- **6.18 is the minimum mainline kernel with the K1 EMAC ethernet driver merged** (the gate).
  Verified: `drivers/net/ethernet/spacemit/k1_emac.c` is **404 at v6.17, 200 at v6.18**.
- **BUT** the *Orange Pi RV2 board device tree* only reaches full router-critical enablement in
  **mainline master (6.19-rc, heading to 6.19)**. The 6.18 board DTS is minimal (UART + LED only);
  6.19-rc1 adds the dual EMAC wiring; **master** adds SD (sdhci0), USB (dwc3 + PHYs), and PCIe.
- **Net recommendation: build the OpenWrt target on the in-tree 6.18 (zero kernel-version lift),
  and carry the board-enablement DTS ourselves** (mainline-derived, dual-GbE + SD + USB), rather
  than waiting for 6.19 or bumping OpenWrt's kernel. The drivers we need are all in 6.18; only the
  *board wiring* needs to come from us / from master, which is exactly the DTS we were going to own
  anyway. This keeps us on OpenWrt's supported kernel with no generic-patch/plumbing risk.

## 1. Minimum mainline kernel per router-critical block (verified against torvalds/linux tags)

| Block (router-critical) | Driver path | Landed in |
|---|---|---|
| **Ethernet MAC (THE GATE)** | `drivers/net/ethernet/spacemit/k1_emac.c` (`SPACEMIT_K1_EMAC`, compatible `spacemit,k1-emac`) | **6.18** (404@6.17, 200@6.18) |
| **MMC / microSD (root)** | `drivers/mmc/host/sdhci-of-k1.c` (`MMC_SDHCI_OF_K1`) | **6.17** (200@6.17) |
| **Clocks (CCU: PLL+mux+div+gate)** | `drivers/clk/spacemit/ccu-k1.c` (`SPACEMIT_CCU`) — full tree incl. `ccu_pll.c` | **6.16** (404@6.15, 200@6.16) |
| **Reset controller** | `drivers/reset/reset-spacemit.c` (`RESET_SPACEMIT`, default y on ARCH_SPACEMIT) | present @6.18 |
| **Pin control** | `drivers/pinctrl/spacemit/pinctrl-k1.c` (`spacemit,k1-pinctrl`) | **6.15** |
| **UART console** | 8250-class `serial@d4017000` (uart0), `console=ttyS0,115200` | pre-6.15 (works since first K1 DT) |
| **SoC Kconfig** | `arch/riscv/Kconfig.socs` → `ARCH_SPACEMIT` (selects PINCTRL) | present @6.18 |
| SoC `k1.dtsi` | `arch/riscv/boot/dts/spacemit/k1.dtsi` | since 6.15 (grows each release) |

Every router-critical driver is in **6.18**. `k1_emac` is the newest of them and is the binding
constraint → **6.18 is the minimum viable mainline kernel.** (EMAC merge trail: Vivian Wang's
"Add Ethernet MAC support for SpacemiT K1" series reached v12 on netdev/net-next mid-Sept 2025
and was picked up by the netdev patchwork-bot → rode the 6.18 merge window. Confirmed by the tag
probe above.)

USB and PCIe are secondary for a router (dual-GbE + SD is the must-have set). Their driver/PHY
support is present in-tree; board-DTS enablement matures in master (see §3).

## 2. OpenWrt kernel-version feasibility — trivial (no lift)

- `include/kernel-version.mk` + `target/linux/generic/kernel-6.18` pin **`LINUX_VERSION-6.18 = .37`**
  (`6.18.37`, hash on file). `target/linux/generic/config-6.18` and `patches-6.18/` exist.
- The three shipping RISC-V targets already use `KERNEL_PATCHVER:=6.18` → the generic riscv64
  kernel plumbing (config, generic patches, arch bits) is proven on this exact kernel.
- **Effort to "carry the kernel": ~zero.** We do NOT need a newer kernel, a git-clone kernel, a
  KERNEL_TESTING bump, or backports of the K1 drivers — they are already in 6.18. This removes the
  single biggest risk the brief flagged (kernel too far ahead of OpenWrt's plumbing). It does not
  apply here: OpenWrt caught up to 6.18 and 6.18 is exactly where the EMAC landed.

## 3. Upstream Orange Pi RV2 device tree — exists, but board enablement is staged

`arch/riscv/boot/dts/spacemit/k1-orangepi-rv2.dts` exists upstream
(authors: Yangyu Chen `cyy@cyyself.name`, Hendrik Hamerlinck `hendrik.hamerlinck@hammernet.be`;
compatible `"xunlong,orangepi-rv2", "spacemit,k1"`). Enablement by tag:

| Tag | RV2 board DTS state |
|---|---|
| **v6.18** | Minimal: UART0 + sys-LED only (40 lines). No eth/SD/USB/PCIe. |
| **v6.19-rc1/rc2** | Adds **dual EMAC** (`&eth0`,`&eth1`, rgmii-id, per-port MDIO + PHY) (92 lines). SD/USB still absent; SoC `k1.dtsi` does not yet carry `sdhci0`/`usb_dwc3` labels. |
| **master (→6.19)** | Full: **eth0/eth1 + sdhci0 (SD root) + usb_dwc3 + usbphy2 + PCIe1/PCIe2** (386 lines). `k1.dtsi` grows to 1345 lines and defines the `eth0/eth1/sdhci0/usb_dwc3/pcie1/pcie2` SoC nodes the board DTS references. |

Interpretation: the **drivers** are all in 6.18; the **board wiring** for the two NICs + SD + USB
is the piece that matured in 6.19/master. Since our target owns the RV2 device profile's DTS
anyway, we take the mainline master `k1.dtsi` + `k1-orangepi-rv2.dts` (and `k1-pinctrl.dtsi`),
compile them against the 6.18 kernel headers. They are mainline-authored (upstream-shaped) and
cross-check cleanly against our own OPNsense-RISC mainline-derived DTB (same node@addr map:
`ethernet@cac80000/cac81000`, `mmc@d4280000`, `usb@c0a00000`, PLIC@e0000000, etc.).

Risk to validate at build time: the master DTS may reference a binding/property newer than the
6.18 driver accepts (e.g. an SD/USB property). Mitigation: start from the **6.19-rc dual-eth DTS**
(matches 6.18 EMAC driver exactly) as the guaranteed-good baseline, then layer SD/USB from master
and confirm each node's compatible/props exist in the 6.18 driver before enabling.

## 4. Vendor references (reference-only, do NOT ship)

- **Orange Pi vendor OpenWrt:** `github.com/orangepi-xunlong/openwrt`, branch **`openwrt-24.10`**,
  target triplet **`ky` / `riscv64` / `x1_orangepi-rv2`**, on the **6.6.73 BSP** kernel. This is the
  fork we are explicitly NOT copying — mine it for the image/partition recipe and package set only.
- **Vendor image boot flow** (from `/root/owrt/disk.img`, mounted ro): MBR, p1 = boot (FAT/ext),
  p2 = ext4 rootfs. Boot partition holds `kernel.img` (28 MB Image), `ky.dtb` (110 KB), `boot.scr`.
  The `boot.scr` U-Boot flow (this is the recipe our image must reproduce):
  ```
  part uuid ${devtype} ${devnum}:2 uuid
  setenv bootargs "earlycon=sbi earlyprintk console=ttyS0,115200 loglevel=8 \
      clk_ignore_unused workqueue.default_affinity_scope=system \
      root=PARTUUID=${uuid} rw rootwait";
  load ${devtype} ${devnum}:1 ${fdt_addr_r} ky.dtb
  load ${devtype} ${devnum}:1 ${kernel_addr_r} kernel.img
  booti ${kernel_addr_r} - ${fdt_addr_r}
  ```
  Takeaways for our image recipe: FIT/`booti` with a raw `Image` (`kernel.img`) + separate DTB,
  console `ttyS0,115200`, `root=PARTUUID=` on p2, `rootwait`. U-Boot/OpenSBI live in SPI-NOR
  (SD does not touch the bootloader), so a 2-partition SD image (boot + rootfs) is sufficient.

## Proposed target structure (for main's approval before building)

```
target/linux/spacemit/                 # BOARD:=spacemit, ARCH:=riscv64, KERNEL_PATCHVER:=6.18
  Makefile                             # FEATURES: squashfs ext4 fpu ramdisk; DEFAULT_PACKAGES + kmods
  config-6.18                          # CONFIG_ARCH_SPACEMIT, SPACEMIT_CCU, RESET_SPACEMIT,
                                       #   PINCTRL_SPACEMIT_K1, MMC_SDHCI_OF_K1, SPACEMIT_K1_EMAC,
                                       #   NET_VENDOR_SPACEMIT, 8250 console, USB/dwc3 (phase 2)
  base-files/                          # board.d network defaults: 2 EMAC -> WAN(eth1)/LAN(eth0)
  image/
    Makefile                           # orangepi-rv2 profile: 2-part (boot+rootfs), boot.scr,
                                       #   ext4/squashfs, PARTUUID root, booti flow above
  dts/ (or patches to kernel dts)      # k1.dtsi + k1-pinctrl.dtsi + k1-orangepi-rv2.dts
                                       #   (mainline master, dual-GbE + SD + USB), pinned to build
```

Single subtarget (`generic`) to start. Device profile `orangepi-rv2`. Upstream-shaped so the whole
`target/linux/spacemit` could be a future OpenWrt contribution (submission gated on user).
