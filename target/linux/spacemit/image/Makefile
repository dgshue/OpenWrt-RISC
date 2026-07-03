# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2026 dgshue <dgshue@gmail.com>
#
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

FAT32_BLOCK_SIZE=1024
FAT32_BLOCKS=$(shell echo $$(($(CONFIG_SPACEMIT_SD_BOOT_PARTSIZE)*1024*1024/$(FAT32_BLOCK_SIZE))))

define Build/boot-scr
	rm -f $@-boot.scr
	mkimage -A riscv -O linux -T script -C none -a 0 -e 0 \
		-n "OpenWrt K1 boot" -d boot.scr.txt $@-boot.scr
endef

define Build/spacemit-sdcard
	rm -f $@.boot
	mkfs.fat $@.boot -C $(FAT32_BLOCKS)
	mcopy -i $@.boot $@-boot.scr ::boot.scr
	mcopy -i $@.boot $(DTS_DIR)/$(DEVICE_DTS).dtb ::dtb
	mcopy -i $@.boot $(IMAGE_KERNEL) ::Image
	./gen_spacemit_sdcard_img.sh \
		$@ \
		$@.boot \
		$(IMAGE_ROOTFS) \
		$(CONFIG_SPACEMIT_SD_BOOT_PARTSIZE) \
		$(CONFIG_TARGET_ROOTFS_PARTSIZE)
endef

define Device/Default
  PROFILES := Default
  KERNEL_NAME := Image
  KERNEL := kernel-bin
  IMAGES := sdcard.img.gz
  IMAGE/sdcard.img.gz := boot-scr | spacemit-sdcard | append-metadata | gzip
endef

define Device/xunlong_orangepi-rv2
  DEVICE_VENDOR := Orange Pi
  DEVICE_MODEL := RV2
  DEVICE_DTS := spacemit/k1-orangepi-rv2
  # K1 SoC drivers (EMAC, sdhci-of-k1, CCU clk, pinctrl, P1 PMIC) are built
  # into the kernel via target config-6.18; no kmod-* packages needed here.
  SUPPORTED_DEVICES += xunlong,orangepi-rv2
endef
TARGET_DEVICES += xunlong_orangepi-rv2

$(eval $(call BuildImage))
