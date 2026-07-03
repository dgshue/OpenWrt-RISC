#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2026 dgshue
#
# Build a 2-partition MBR SD image for SpacemiT K1 (Orange Pi RV2):
#   p1 = FAT boot (boot.scr + Image + dtb),  p2 = rootfs (ext4/squashfs).
# U-Boot / OpenSBI live in SPI-NOR on the board, so nothing is written to
# the MBR gap / no SPL is embedded here.

set -ex
[ $# -eq 5 ] || {
    echo "SYNTAX: $0 <file> <bootfs image> <rootfs image> <bootfs size MB> <rootfs size MB>"
    exit 1
}

OUTPUT="$1"
BOOTFS="$2"
ROOTFS="$3"
BOOTFSSIZE="$4"
ROOTFSSIZE="$5"

# 4MB gap before p1 (matches typical K1 SD layouts; keeps clear of any
# vendor bootloader remnants even though we boot from SPI-NOR).
BOOTOFFSET_MB=4
ROOTFSPTOFFSET=$(($BOOTOFFSET_MB + $BOOTFSSIZE))

# MBR (-t): 0x0c = FAT32 LBA (boot), 0x83 = Linux (rootfs).
# -S sets a fixed disk signature so PARTUUID is deterministic.
set $(ptgen -o "$OUTPUT" -h 4 -s 63 -l 1024 \
	-t c -p ${BOOTFSSIZE}M@${BOOTOFFSET_MB}M \
	-t 83 -p ${ROOTFSSIZE}M@${ROOTFSPTOFFSET}M)

BOOTOFFSET="$(($1 / 512))"
ROOTFSOFFSET="$(($3 / 512))"

dd bs=512 if="$BOOTFS" of="$OUTPUT" seek="$BOOTOFFSET" conv=notrunc
dd bs=512 if="$ROOTFS" of="$OUTPUT" seek="$ROOTFSOFFSET" conv=notrunc
