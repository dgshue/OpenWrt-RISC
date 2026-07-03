# RESUME — after a host reboot

Both builds are **resumable from on-disk cache**. The board is idle on its validated kernel.
The in-memory orchestration (background agents, monitors, cron backstops) does NOT survive a
reboot / Claude restart — re-establish it, then resume the two builds below.

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
