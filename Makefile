#
# Copyright (c) 2026 luci-app-qoscustom contributors
# This is free software, licensed under the MIT License.
#
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-qoscustom
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=luci-app-qoscustom contributors

LUCI_TITLE:=LuCI QoS (CAKE + HTB) for systems without the ifb kernel module
LUCI_DESCRIPTION:=CAKE-based traffic shaping with a Lan-bypass class, usable on OpenWrt \
	builds where the ifb module is unavailable (stock SQM cannot be installed).
LUCI_DEPENDS:=+tc-full +kmod-sched-cake +kmod-sched-htb
LUCI_PKGARCH:=all

define Package/luci-app-qoscustom/conffiles
/etc/config/qoscustom
endef

include ../../luci.mk

# call BuildPackage - OpenWrt buildroot signature
$(eval $(call BuildPackage,luci-app-qoscustom))
