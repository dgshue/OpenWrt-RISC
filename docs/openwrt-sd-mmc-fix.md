# microSD won't boot under Linux — the `sdhci-of-k1` pad-clock fix

This documents the single hardest bring-up problem on the Orange Pi RV2 OpenWrt port: the kernel
booted fine but **could not mount the rootfs**, because mainline 6.18's `sdhci-of-k1` driver never
enables the SD pad clock. It's written up because the failure signature is misleading and cost
several debugging cycles.

## Symptom

The image built and U-Boot loaded the kernel from the SD's FAT partition without trouble
(`19757056 bytes read … 15 MiB/s`), the kernel booted, then hung forever at:

```
[    1.033] mmc1: SDHCI controller on d4280000.mmc [d4280000.mmc] using ADMA
[    1.052] Waiting for root device PARTUUID=5452574f-02...
```

No block device, no error. The controller registered but the card never enumerated.

## Why it was confusing

1. **U-Boot reads the exact same card at 15 MiB/s.** So the card, the slot, and the wiring are all
   fine — it's purely a Linux-driver problem. (U-Boot uses its own MMC driver.)
2. **A removable SD that fails init prints *nothing*.** The Linux MMC core only logs
   `Failed to initialize …` for **non-removable** cards. With the stock (removable) DT node, a failed
   `mmc_attach_sd` returns silently — so the first boots looked like "card not detected" when the card
   *was* being tried and failing.

Forcing the issue with a DT tweak made the failure visible:

```
# add to the &sdhci0 node to force the core to attempt init and print the result
non-removable;
```
```
[    1.193] mmc1: Failed to initialize a non-removable card
```

Still no sub-error (no `-110`, no CRC, no voltage-switch message) — the card simply never responds.
A total non-response ~150 ms after controller registration points at **no clock or no power**, not
signalling. The regulators (`vmmc=buck4`, `vqmmc=aldo1`) both cover 3.3 V and are always-on/boot-on,
so power was fine. That leaves **clock**.

## Root cause

Reading `drivers/mmc/host/sdhci-of-k1.c` (6.18): the driver uses
`SDHCI_QUIRK_CAP_CLOCK_BASE_BROKEN`, so its base clock comes entirely from `clk_get_rate(clk_io)`,
and — critically — its `spacemit_sdhci_reset()` **never turns on the SD pad clock generator**. The
SD pads therefore get no clock, and `CMD0`/`ACMD41` time out silently.

This was fixed upstream on **2026-05-11** in commit **`f87b273e4b6d`**
("mmc: sdhci-of-k1: enable essential clock infrastructure for SD operation"), which lands *after*
OpenWrt's 6.18 base. It adds three register writes to the reset path:

```c
#define SPACEMIT_SDHC_OP_EXT_REG        0x108
#define  SDHC_OVRRD_CLK_OEN             BIT(11)
#define  SDHC_FORCE_CLK_ON              BIT(12)
#define SPACEMIT_SDHC_LEGACY_CTRL_REG   0x10C
#define  SDHC_GEN_PAD_CLK_ON            BIT(6)

/* in spacemit_sdhci_reset(), after the MMC card-mode setup: */
spacemit_sdhci_setbits(host, SDHC_GEN_PAD_CLK_ON, SPACEMIT_SDHC_LEGACY_CTRL_REG);
if (host->mmc->caps2 & MMC_CAP2_NO_MMC)
        spacemit_sdhci_setbits(host, SDHC_OVRRD_CLK_OEN | SDHC_FORCE_CLK_ON,
                               SPACEMIT_SDHC_OP_EXT_REG);
```

We carry this as [`patches-6.18/0002-mmc-sdhci-of-k1-enable-pad-clock-for-SD.patch`](../target/linux/spacemit/patches-6.18/0002-mmc-sdhci-of-k1-enable-pad-clock-for-SD.patch).

## Result

With 0002 applied, the stock removable DT node works — the card enumerates immediately:

```
[    1.092] mmc1: new high speed SDXC card at address aaaa
[    1.096] mmcblk1: mmc1:aaaa SD128 119 GiB
[    1.101]  mmcblk1: p1 p2
[    1.114] VFS: Mounted root (squashfs filesystem) readonly on device 179:2.
[    1.125] Run /sbin/init as init process
```

`non-removable` was only a diagnostic — it is **not** needed with the driver fix and should not be
shipped.

## Follow-up: UHS

`f87b273e4b6d` gets the card to **high-speed (3.3 V)**. Full **UHS** (SDR50/104, 1.8 V) additionally
needs:

- `00a97fc57c09` — regulator + pinctrl voltage switching (3.3 V ↔ 1.8 V)
- `e9cb83c10071` — SDR tuning

Until those are backported, [`patch 0003`](../target/linux/spacemit/patches-6.18/0003-riscv-dts-k1-orangepi-rv2-sd-high-speed-only.patch)
drops the `sd-uhs-*` modes and adds `no-1-8-v` on the board's `&sdhci0` node so the card stays in the
proven high-speed path (a requested-but-unsupported UHS switch can otherwise wedge card init).

## Debugging tips for this board

- Watch the whole boot on serial from the first byte — the interesting failure is in the U-Boot →
  kernel handoff and the first ~2 s of kernel time.
- The DTB is a **standalone file** on the FAT boot partition, so you can iterate on device-tree
  changes by replacing just `dtb` (and the kernel by replacing just `Image`) instead of reflashing.
- `CONFIG_MMC_DEBUG=y` makes the core trace commands, but here it was unnecessary once the driver
  source made the missing pad-clock enable obvious.
