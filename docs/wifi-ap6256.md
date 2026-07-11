# Onboard Wi-Fi bring-up — AP6256 (BCM43456) SDIO

The Orange Pi RV2 carries an **Ampak AP6256** module — a **Broadcom BCM43456C5**
(Wi-Fi 5, dual-band 2.4/5 GHz, plus BT5) wired to the K1's **third SDHCI**
instance over **SDIO 3.0**. Mainline 6.18 has **no device-tree node** for it, so
under stock OpenWrt the module is simply absent. This port adds three kernel
patches and the firmware/NVRAM to bring it up. **Validated on real hardware:** a
WPA2 STA join on 5 GHz at 433 Mbit/s with a DHCP lease.

## Hardware map

| | |
|---|---|
| Module | Ampak AP6256 = Broadcom **BCM43456C5** (Wi-Fi 5 + BT5) |
| Bus | SDIO 3.0 on the K1's **SDH1** (third SDHCI) @ `0xd4280800` |
| Clocks / reset | `CLK_SDH1` / `RESET_SDH1` (+ shared AXI), **IRQ 100** |
| Data/CMD pins | mmc2 group **GPIO_15..20**, MODE1, 1.8 V |
| WL_REG_ON | **GPIO 67** (active-low reset via `mmc-pwrseq-simple`) |
| Module VBAT | **EXT_3V3** buck behind **EXT_PWR_EN = GPIO 116** |
| 32 kHz LPO | PMIC **32KOUT** (the board's *only* 32.768 kHz source) |

## The three patches

### 0004 — DTS: the SDH1 node, pins, power sequencing

Adds the `sdhci1` host node (SDH1 reg/clocks/resets/IRQ 100), an `mmc2` pin group
(GPIO_15..20 MODE1), and the `&sdhci1` board node marking it `non-removable`,
`no-sd`, `no-mmc`, 4-bit, SDIO-only, with the `brcmfmac` child.

Two board-specific details were reverse-engineered from the vendor tree and
schematic:

- **All pads pulled up, including CLK**, at 1.8 V DS2. The vendor pulls the mmc2
  **clock** pad up — the opposite of the SD-slot convention — and the module is
  unreliable without it.
- **`vmmc-supply = <&pcie_vcc3v3>`.** The schematic shows **EXT_PWR_EN (GPIO 116)**
  enabling the shared **EXT_3V3** buck, which feeds **both** the module's WIFI_VCC33
  (VBAT) **and** the PCIe 3.3 V rail. Mainline already models that rail as
  `pcie_vcc3v3`; referencing it as `vmmc` makes the MMC core power the module
  (auto-muxing pad 116 via `gpio-ranges`) **before** card init. Without it the
  module has no VBAT and is **mute to every SDIO command**. `vqmmc` is `buck3_1v8`.

### 0005 — driver fix: fatal unaligned HOST_CONTROL2 access *(upstream-worthy)*

Mainline `sdhci-of-k1`'s `spacemit_sdhci_set_uhs_signaling()` does a **32-bit
read-modify-write** of `SDHCI_HOST_CONTROL2` — a **16-bit** register at offset
`0x3E`. That issues a 4-byte MMIO load at a 2-byte-aligned device address, which
**cannot be emulated on RISC-V**: it takes a load access fault in interrupt
context and the kernel panics.

```
Oops - load access fault, epc spacemit_sdhci_set_uhs_signaling+0x3c
badaddr = ioaddr + 0x3e
```

The line is guarded by `!MMC_CAP2_NO_SDIO`, and **every upstream K1 board marks
its slots `no-sdio`** — so this port's Wi-Fi slot is the *first* to ever execute
it. Panic was **100 % reproducible** at probe before the fix; clean after. The fix
uses the 16-bit `sdhci_readw`/`sdhci_writew` accessors (matching the register
width and the vendor driver).

### 0006 — PMIC RTC: enable the 32 kHz crystal and 32KOUT (the LPO)

The P1 PMIC (**SPM8821**) `RTC_CTRL` (0x1d) powers up as `0x00`. Mainline
`rtc-spacemit-p1` only toggles `RTC_EN`, so (a) the RTC never counts — `hctosys`
fails — and, critically, (b) the PMIC **32KOUT** pin stays dead. On this board
32KOUT is the **only** 32.768 kHz source and feeds the AP6256's **LPO** pin.
Without the LPO the module PMU can't raise its SDIO backplane clocks and brcmfmac
fails with **`clock enable timeout`**.

The fix programs `crystal_en | out_32k_en | rtc_en | rtc_clk_sel` at probe
(matching the vendor driver). It fixes the RTC too, as a bonus.

## Firmware & NVRAM

Shipped in the target base-files under `/lib/firmware/brcm/`:

- `brcmfmac43456-sdio.bin` + `brcmfmac43456-sdio.clm_blob` — the RPi-Distro 43456
  set, firmware **7.84.17.1**.
- Board-specific NVRAM (`.txt`), captured from the vendor Orange Pi image,
  installed under both the generic name and `brcmfmac43456-sdio.xunlong,orangepi-rv2.txt`.
- `LICENSE.brcm80211` (the Broadcom redistribution licence) accompanies them.

The kmod + supplicant are selected in `config/rv2-router.config`
(`kmod-brcmfmac`, `BRCMFMAC_SDIO`, `wpad-mbedtls`, `iw`).

## Result on hardware

```
mmc2: new high speed SDIO card at address 0001
brcmfmac: BCM4345/9 wl0: ... 7.84.17.1
phy0-sta0: associated (5 GHz, -41 dBm, 433.3 Mbit/s VHT80)
```

The STA join brings up a `wwan` interface (DHCP, `wan` firewall zone). A
uci-defaults script ships a **template STA config** with placeholder SSID/key
that retries each boot until the radio exists.

> **Note — placeholder credentials.** The shipped
> [`99-rv2-wifi-sta`](../target/linux/spacemit/base-files/etc/uci-defaults/99-rv2-wifi-sta)
> uses `ssid=YOUR-SSID` / `key=CHANGE-ME`. **Edit it** with your own network
> before building. Likewise
> [`99-rv2-lan`](../target/linux/spacemit/base-files/etc/uci-defaults/99-rv2-lan)
> hard-codes the author's static LAN address `192.168.1.250` — author-specific,
> change or delete it for your own image.

> **brcmfmac has no 4-address (WDS) mode**, so this radio can't be a transparent
> L2 bridge port; use **relayd** (or route) if you need the wireless uplink to
> serve a wired LAN.

## Wireless bridge (relayd)

The board is validated end-to-end as a **WiFi bridge**: the onboard AP6256 joins
the home AP as a STA (`wwan`), and the two wired GbE ports serve LAN clients that
get DHCP straight from the main router **through** the WiFi uplink.

**Why relayd.** brcmfmac exposes no 4-address/WDS mode, so a true L2 bridge
(`wwan` as a `br-lan` port) is impossible — the AP would only ever see the STA's
own MAC. **relayd** is the standard OpenWrt answer: a proxy-ARP "pseudo-bridge"
that relays between the wired segment and the WiFi segment at L3, so wired
clients appear on the upstream subnet and lease from the main router.

**Topology.**

```
wired client ── eth0/eth1 ── br-lan ── relayd (stabridge) ── wwan (STA) ── home AP ── main router (DHCP)
```

Both GbE ports (`eth0` + `eth1`) sit in `br-lan`; a `relay`-proto interface
(`stabridge`) bridges `lan` ↔ `wwan`, both sides sharing the board address
`192.168.1.250` so it is reachable from the wired **and** wireless sides.

**The critical routing gotcha — the LAN interface must have NO static gateway.**
With a gateway configured on `lan`, that route lands at **metric 0** via the
(usually **unplugged**) wire and **blackholes all traffic** — even though the
WiFi is fully associated. The trap: `udhcpc` on `wwan` keeps *renewing its lease
fine* (it binds to the interface directly), so the radio looks healthy while
every ping fails. **DHCP-renew-succeeds-while-ping-fails is the tell** that this
is a routing blackhole, not a radio problem. Dropping `network.lan.gateway` (so
`wwan` owns the default route) fixes it — this is why
[`99-rv2-lan`](../target/linux/spacemit/base-files/etc/uci-defaults/99-rv2-lan)
no longer sets a gateway.

**First-boot config.**
[`99-rv2-zz-bridge`](../target/linux/spacemit/base-files/etc/uci-defaults/99-rv2-zz-bridge)
applies the whole bridge on first boot: adds `eth1` to `br-lan`, creates the
`stabridge` relay interface over `lan`+`wwan`, drops the stale `wan`/`wan6`
interfaces, and moves `wwan` into the `lan` firewall zone. The board comes up
reachable at **192.168.1.250** from both the wired and the wireless side. The
packages (`relayd`, `luci-proto-relay`) are selected in
`config/rv2-router.config`.

### Bridge stability

Two fixes found during hardware soak took the bridge from bursty to loss-free:

**relayd host-table expiry 30 → 600 s.** relayd's default host expiry is 30 s.
With it, the bridge cycled **~10 s clean, then ~5–10 s unreachable** as proxy-ARP
entries aged out; recovery pings came back with **300–2600 ms RTT** — the cost of
re-resolving ARP each time an entry expired. Setting
`uci set network.stabridge.expiry='600'` in
[`99-rv2-zz-bridge`](../target/linux/spacemit/base-files/etc/uci-defaults/99-rv2-zz-bridge)
holds the proxied host entries long enough to stop the churn.

**brcmfmac ARP offload — the big one — worked around with promiscuous mode.** Even
with the expiry fix, Windows clients still marked the route dead in periodic
bursts. Root cause: the **brcmfmac firmware ARP offload absorbs ARP frames**
addressed to the hosts relayd proxies, so relayd **never sees the neighbours' ARP
revalidation probes** and can't answer them — the peers time the entry out and
declare the route dead. The **diagnostic tell is a Heisenbug**: packet loss
*vanishes the moment* `tcpdump` runs on the STA interface, because tcpdump puts
the NIC into promiscuous mode — which disables the firmware's ARP filtering. The
persistent fix sets promiscuous mode on the `wwan` device at every `ifup` via
[`99-wwan-promisc`](../target/linux/spacemit/base-files/etc/hotplug.d/iface/99-wwan-promisc),
disabling the firmware filtering and taking the bridge to **0 % loss**.

## Credit

The root causes — module **VBAT via EXT_PWR_EN / GPIO 116**, the **PMIC 32KOUT
LPO**, and the exact pad config — were first discovered during the sibling
**FreeBSD/OPNsense** port's ~50-round Wi-Fi bring-up on the same board. This Linux
port reused those hardware findings; the SDIO panic (patch 0005) is Linux-specific.
