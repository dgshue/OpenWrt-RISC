<!--
Thanks for contributing! This is a hardware bring-up port — please be honest
about what you actually tested. "Builds clean" and "boots on hardware" are
tracked separately in this repo.

Reminder: do NOT upstream changes from this fork to OpenWrt / the Linux kernel.
See CONTRIBUTING.md.
-->

## What this changes

Describe the change and why. If it's a kernel patch, note whether it's a
backport of a merged mainline commit (cite the hash) or new work.

## Testing performed

- [ ] Builds clean against OpenWrt `main` (Linux 6.18)
- [ ] Image assembled (`bin/targets/spacemit/generic/`)
- [ ] Flashed and booted on real hardware
- [ ] Ran under load / soak-tested

**Board revision tested on:** <!-- Orange Pi RV2 rev, or "build-only / N/A" -->

**Image build tested:** <!-- target/profile, kernel version, git commit -->

## Serial console log

<!-- Paste the relevant serial log (115200 8N1) showing the change working
(boot to login, driver attaching, etc.), or note "build-only — not booted". -->

```
(paste serial log here, or note "build-only — not run on hardware")
```

## Checklist

- [ ] I updated `STATUS.md` with a newest-at-top entry (what changed, what was tested, what's open)
- [ ] Kernel patches under `patches-6.18/` are minimal and cite the upstream commit hash where they are backports
- [ ] Docs updated where relevant (`docs/`, README)
- [ ] Any author-specific defaults (e.g. static LAN in `99-rv2-lan`) are flagged, not silently changed
- [ ] License headers preserved; change is GPL-2.0 compatible
- [ ] No secrets, private keys, or credentials in the diff or logs
- [ ] Change is scoped to one logical thing where practical
