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

head=4
sect=63

# Let ptgen place both partitions (aligned to 1 MiB). MBR types: 0x0c = FAT32
# LBA (boot), 0x83 = Linux (rootfs). ptgen prints, per partition, the byte
# offset then the byte size on stdout; its "part X Y" progress lines go to
# stderr, so drop stderr before feeding "set".
set $(ptgen -o "$OUTPUT" -h "$head" -s "$sect" -l 1024 \
	-t c -p ${BOOTFSSIZE}M \
	-t 83 -p ${ROOTFSSIZE}M 2>/dev/null)

BOOTOFFSET="$(($1 / 512))"
ROOTFSOFFSET="$(($3 / 512))"

dd bs=512 if="$BOOTFS" of="$OUTPUT" seek="$BOOTOFFSET" conv=notrunc
dd bs=512 if="$ROOTFS" of="$OUTPUT" seek="$ROOTFSOFFSET" conv=notrunc
