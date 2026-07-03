# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2026 dgshue <dgshue@gmail.com>
#
include $(TOPDIR)/rules.mk

ARCH:=riscv64
BOARD:=spacemit
BOARDNAME:=SpacemiT RISC-V SoCs (K1)
FEATURES:=ext4 squashfs fpu
KERNELNAME:=Image dtbs
SUBTARGETS:=generic

KERNEL_PATCHVER:=6.18

include $(INCLUDE_DIR)/target.mk

DEFAULT_PACKAGES += e2fsprogs mkf2fs f2fsck partx-utils

define Target/Description
	Build firmware images for SpacemiT K1 (Ky X1) RISC-V boards,
	e.g. the Orange Pi RV2. Mainline-kernel target (Linux 6.18) with
	upstream K1 drivers (EMAC, sdhci-of-k1, CCU clocks, pinctrl, P1 PMIC).
endef

$(eval $(call BuildTarget))
