#!/bin/sh
# uninstall.sh - 卸载 luci-app-qoscustom
set -e

RED='\033[0;31m'; GRN='\033[0;32m'; NC='\033[0m'
info() { printf "${GRN}[+]${NC} %s\n" "$1"; }
err()  { printf "${RED}[x]${NC} %s\n" "$1"; }

[ "$(id -u)" = "0" ] || { err "请用 root 运行"; exit 1; }

info "停止并禁用服务..."
/etc/init.d/qos-custom disable 2>/dev/null || true
/etc/init.d/qos-custom stop    2>/dev/null || true

info "删除文件..."
rm -f /etc/init.d/qos-custom
rm -f /usr/share/luci/menu.d/luci-app-qoscustom.json
rm -f /usr/share/rpcd/acl.d/luci-app-qoscustom.json
rm -f /www/luci-static/resources/view/qoscustom/overview.js
rmdir /www/luci-static/resources/view/qoscustom 2>/dev/null || true

info "保留 /etc/config/qoscustom（如需彻底删除请手动 rm）"

info "清理缓存并重启 LuCI 后端..."
rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache
/etc/init.d/rpcd restart   >/dev/null 2>&1 || true
/etc/init.d/uhttpd restart >/dev/null 2>&1 || true

echo
info "已卸载。如需恢复流量卸载："
echo "  uci set firewall.@defaults[0].flow_offloading='1'"
echo "  uci set firewall.@defaults[0].flow_offloading_hw='1'"
echo "  uci commit firewall && /etc/init.d/firewall reload"
