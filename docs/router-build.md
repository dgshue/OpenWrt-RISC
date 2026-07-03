# Building the "full router" image

The base target (`target/linux/spacemit`) produces a minimal OpenWrt. This adds a complete
router/firewall/VPN/DNS feature set via a package profile:
[`config/rv2-router.config`](../config/rv2-router.config).

## Build

```sh
# in your OpenWrt main checkout, with target/linux/spacemit already dropped in:
cat /path/to/OpenWrt-RISC/config/rv2-router.config >> .config
./scripts/feeds install -a          # make all feed packages selectable
make defconfig                      # resolves deps (also pulls ~170 packages total)
make -j"$(nproc)"
```

The resulting `…-squashfs-sdcard.img.gz` is ~18 MB (rootfs squashfs ~13 MB, well within the 104 MB
rootfs partition — leaving ~90 MB for the F2FS overlay).

## What's included

| Group | Packages |
|---|---|
| **VPN** | `wireguard-tools` + `kmod-wireguard` + `luci-proto-wireguard`; `openvpn-openssl` + `openvpn-easy-rsa` + `luci-proto-openvpn` |
| **DNS / adblock** | `dnsmasq-full` (swapped in for `dnsmasq`), `adblock` + `luci-app-adblock`, `https-dns-proxy` + `luci-app-https-dns-proxy`, `bind-dig` |
| **Firewall/NAT** | `firewall4`/`nftables` (base) + `kmod-nft-nat`/`kmod-nft-offload` |
| **IPv6** | `luci-proto-ipv6`, `odhcpd`, `6in4`/`6rd`/`ds-lite` |
| **QoS / DDNS / TLS** | `sqm-scripts` + `luci-app-sqm`, `ddns-scripts` + `luci-app-ddns`, `luci-app-acme` |
| **Monitoring** | `luci-app-statistics` + `collectd-mod-{cpu,interface,load,memory,network}`, `nlbwmon` |
| **System** | `irqbalance`, `luci-app-upnp`, `luci-app-ttyd`, `htop`, `tcpdump`, `ethtool`, `iperf3`, `nano`, `curl`, `ip-full` |
| **Storage / SMB** | USB storage + ext4/f2fs/exfat + `e2fsprogs`, `ksmbd-server` + `luci-app-ksmbd` |
| **Themes** | `luci-theme-material`, `luci-theme-openwrt-2020` |

`mtr` is intentionally omitted (not pulled cleanly from the feed on this arch); use busybox
`traceroute` or add it manually if wanted.

## Where the VPN config lives (gotcha)

Current OpenWrt/LuCI **removed the standalone `luci-app-openvpn` / `luci-app-wireguard` pages** —
there is **no "VPN" entry in the Services menu**. VPNs are configured as **interface protocols**:

- **WireGuard:** *Network → Interfaces → Add new interface → Protocol = "WireGuard VPN"*. Generate a
  key pair, set a listen port, add peers (pubkey + allowed IPs), assign a firewall zone, open the
  port on WAN. Full server/client, no separate app.
- **OpenVPN (client):** *Network → Interfaces → Add → Protocol = "OpenVPN"* (`luci-proto-openvpn`).
- **OpenVPN (server):** no web page — use `/etc/config/openvpn` (uci) or drop `.conf`/`.ovpn` in
  `/etc/openvpn/`, then `/etc/init.d/openvpn enable && start`. Build the CA/certs with the installed
  `openvpn-easy-rsa` (`easyrsa init-pki`, `build-ca`, `build-server-full`, …).

Sanity check from the console: `wg`, `openvpn --version`, `/etc/init.d/openvpn status`.

## Closing the "AdGuard didn't catch all DNS" gap (force-DNS / sinkhole)

Clients bypass a network DNS filter four ways: **hardcoded DNS** (`8.8.8.8`), **encrypted DNS**
(DoH:443 / DoT:853), **IPv6 DNS** (RA/DHCPv6 advertising a non-filter resolver — the most-missed
one), and **DHCP option 6** pointing elsewhere. Turn the router into a sinkhole:

1. **Encrypted upstream for the router itself:** *Services → HTTPS DNS Proxy* → Cloudflare/Quad9.
2. **Blocklists:** *Services → Adblock* → enable + select lists.
3. **Force all clients to the router:**
   - *Network → Firewall → Port Forwards* → redirect LAN dest port **53** (TCP+UDP) to *This device*
     — **do it for IPv6 too.** (Even a hardcoded `8.8.8.8` then lands on your resolver.)
   - *Network → Firewall → Traffic Rules* → **reject** LAN→WAN dest port **853** (DoT) so it falls
     back to the captured port 53.
4. **Hand out only the router as DNS** over DHCPv4 (option 6) **and** IPv6 RA/DHCPv6; disable the
   upstream/ISP RA DNS. (This is what fixes the IPv6 leak.)

Optionally block known DoH endpoints (adblock ships a DoH blocklist).

## Notes

- The image ships with **no forced DNS/VPN config** — the packages are present, configuration is left
  to the operator (LuCI or uci).
- `dnsmasq` is replaced by `dnsmasq-full`; if you re-derive the profile, keep the
  `# CONFIG_PACKAGE_dnsmasq is not set` line so the swap sticks.
