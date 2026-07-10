---
name: Bug report
about: Report a problem building, flashing, or booting this OpenWrt target on the Orange Pi RV2
title: "[bug] "
labels: bug
assignees: ''
---

<!--
This is a hardware bring-up port. Please be specific about WHAT you tested and
on WHAT hardware. A serial console log is almost always required to diagnose
boot / SD / driver issues. Redact any secrets before pasting logs.
-->

## Summary

A clear, one-line description of the problem.

## Environment

- **Board revision:** <!-- Orange Pi RV2 rev? any add-in hardware -->
- **What was tested:** <!-- build-only / flashed + booted on real hardware / ran under load -->
- **Image build id:** <!-- target/profile, kernel version, git commit you built from -->
- **SD card model:** <!-- SD quality matters a lot on this board; note the exact card -->
- **Build host OS:** <!-- Debian/Ubuntu version; note if you (wrongly) built as root -->

## What happened

Describe the actual behaviour.

## What you expected

Describe the expected behaviour.

## Steps to reproduce

1.
2.
3.

## Serial console log

<!--
Paste the RELEVANT serial console lines (115200 8N1), not a paraphrase.
Include from "Starting kernel …" through the failure (or the login prompt).
For SD/root problems, the mmc/root-device lines are essential.
-->

```
(paste serial log here)
```

## Anything else

Last known-good build (for regressions), related STATUS.md entry, links, etc.
