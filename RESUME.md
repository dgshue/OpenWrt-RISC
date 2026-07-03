# RESUME — after a host reboot

Both builds are **resumable from on-disk cache**. The board is idle on its validated kernel.
The in-memory orchestration (background agents, monitors, cron backstops) does NOT survive a
reboot / Claude restart — re-establish it, then resume the two builds below.

## PLANNED (do this on return): migrate the OpenWrt build WSL → `openclaw` Ubuntu VM
Decision (2026-07-03): move the OpenWrt buildroot off WSL to the user's **`openclaw`** Ubuntu VM
(dedicated, native Linux, ideally always-on & independent of this Windows host so it survives host reboots).
Need from user on return: **openclaw IP/hostname + SSH access** (add a key), and confirm it's host-independent.
Migration steps:
1. SSH access to openclaw (install a key — reuse buildvm_ed25519.pub pattern or a new key). Probe cores/RAM/disk (need ~50 GB free).
2. Install OpenWrt build deps (build-essential clang flex bison g++ gawk gettext git libncurses-dev libssl-dev python3 rsync unzip zlib1g-dev file wget swig time). **Build as a NON-root user** (WSL hit OpenWrt's tar root-refusal — openclaw's normal user is fine).
3. Get the work over: the target lives in this repo (`target/linux/spacemit`, `config-6.18`, `patches-6.18/`, `image/`, committed at c1fb479). Cleanest transfer = **push this repo to a GitHub remote** (dgshue/OpenWrt-RISC, private) then clone on openclaw + drop our target into an OpenWrt `main` checkout. (Alt: rsync the files.) A remote also gives this local-only repo an off-machine backup.
4. `./scripts/feeds update -a && ./scripts/feeds install -a`, `make defconfig` (should select spacemit/generic/orangepi-rv2), `make -j<N> V=s`.
5. Retire the WSL build (or keep as fallback). Vendor ref image: re-extract from `~/Downloads/openwrt-ky-...-sysupgrade.img.gz` on openclaw if node-mining is still needed (analysis is already done).

## 1. OpenWrt build (WSL) — the active project
- Tree: `/home/builder/openwrt` in WSL Ubuntu. **Must run as the `builder` user (uid 1001), NOT root.**
- Target committed here (F:\GitHub\OpenWrt-RISC): `target/linux/spacemit` on kernel 6.18.37 (SHAs 449f8ac scaffold, c1fb479 env-fix). `docs/gate1-kernel-research.md` has the kernel rationale.
- **Resume the build:**
  `wsl -u root -e bash -c "sudo -u builder -H bash -c 'cd /home/builder/openwrt && make -j24 V=s' >> /home/builder/buildlogs/build-resume.log 2>&1 &"`
  (OpenWrt is stamp-based — it continues from where it stopped; only an interrupted package re-builds.)
- Milestones pending: kernel patch/config applies (exercises our DTS patch), then FIRST image in `bin/targets/spacemit/generic/`.
- Vendor reference image mounted-source at `/root/owrt/disk.img` (read-only).

## 2. OPNsense ports build (Hyper-V VM) — background track
- 15.1 build VM: `ssh -i /c/FreeBSD-VM/ssh/buildvm_ed25519 root@192.168.1.132`. Build at `/root/opnsense`.
- **Ensure the VM is started after host reboot** (Hyper-V Manager / Start-VM) — it may not auto-start.
- ~162/244 pkgs cached; resume the detached `make ... ports` (harness skips cached pkgs), then `make core` → `make rv2` for the EFI/GPT SD image. Base+kernel sets staged at `C:\FreeBSD-VM\sets\`.
- Fixes all pushed to dgshue forks (tools/core/ports riscv64). Image builder EFI-arch bug fixed (tools 9576fe6).

## 3. Board — DO NOT TOUCH without approval
- Orange Pi RV2 at 192.168.1.131 (smte0) / .161 (smte1). On the validated superpages+C+D test kernel;
  default `/boot/kernel` is the known-good #33. Serial console = COM9 @115200. All new work is BUILD-ONLY.

## Constraints (unchanged)
Author dgshue / dgshue@gmail.com, no Co-Authored-By. Forks/local only, no upstream submission.
Do not modify `../OPNsense-RISC` (read-only hardware reference).
