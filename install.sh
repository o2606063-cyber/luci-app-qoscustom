#!/bin/sh
# install.sh - 一键安装 luci-app-qoscustom
# 适用于已在运行的 OpenWrt / iStoreOS 系统
set -e

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[0;33m'; NC='\033[0m'
info() { printf "${GRN}[+]${NC} %s\n" "$1"; }
warn() { printf "${YLW}[!]${NC} %s\n" "$1"; }
err()  { printf "${RED}[x]${NC} %s\n" "$1"; }

[ "$(id -u)" = "0" ] || { err "请用 root 运行"; exit 1; }

SRC=$(cd "$(dirname "$0")" && pwd)

# ---------- 架构识别 ----------
detect_arch() {
    case "$(uname -m)" in
        aarch64|arm64)       echo aarch64 ;;
        armv7l|armv7*|armv6*) echo armv7 ;;
        x86_64|amd64)        echo x86_64 ;;
        i386|i486|i586|i686)  echo x86 ;;
        *)                   echo "" ;;
    esac
}
ARCH=$(detect_arch)
info "检测到架构: $(uname -m) → ${ARCH:-未知}"

# ---------- 依赖：tc ----------
if ! command -v tc >/dev/null 2>&1; then
    if [ -n "$ARCH" ] && [ -f "$SRC/prebuilt/tc/$ARCH/tc" ]; then
        warn "系统缺少 tc 命令，安装内置的 $ARCH 版本..."
        cp "$SRC/prebuilt/tc/$ARCH/tc" /usr/bin/tc
        chmod 755 /usr/bin/tc
        if [ -d "$SRC/prebuilt/tc/$ARCH/dist" ]; then
            mkdir -p /usr/lib/tc
            cp -f "$SRC/prebuilt/tc/$ARCH/dist/"*.dist /usr/lib/tc/ 2>/dev/null || true
        fi
        if tc -V >/dev/null 2>&1; then
            info "tc 安装成功: $(tc -V 2>&1 | head -1)"
        else
            err "tc 已复制但无法运行，可能缺少动态库（试 ldd /usr/bin/tc）"
            exit 1
        fi
    else
        err "缺少 tc 命令，且没有匹配当前架构的内置二进制。"
        echo "  参见 README 的「没有 tc 怎么办」一节，或手动从 Alpine 取一个。"
        exit 1
    fi
else
    info "tc 已存在: $(tc -V 2>&1 | head -1)"
fi

# ---------- 内核模块检查 ----------
KREL=$(uname -r)
if [ -d "/lib/modules/$KREL" ]; then
    ls "/lib/modules/$KREL" | grep -q sch_cake || warn "内核里没找到 sch_cake.ko，CAKE 可能不可用。"
    ls "/lib/modules/$KREL" | grep -q sch_htb  || warn "内核里没找到 sch_htb.ko，HTB 分类可能不可用。"
else
    warn "/lib/modules/$KREL 不存在，无法确认内核模块（可能已内置）。"
fi

# ---------- 复制文件 ----------
info "复制文件..."
mkdir -p /etc/config /etc/init.d /usr/share/luci/menu.d /usr/share/rpcd/acl.d
mkdir -p /www/luci-static/resources/view/qoscustom

[ -f /etc/config/qoscustom ] || cp "$SRC/root/etc/config/qoscustom" /etc/config/qoscustom
cp "$SRC/root/etc/init.d/qos-custom" /etc/init.d/qos-custom
cp "$SRC/root/usr/share/luci/menu.d/luci-app-qoscustom.json" /usr/share/luci/menu.d/
cp "$SRC/root/usr/share/rpcd/acl.d/luci-app-qoscustom.json" /usr/share/rpcd/acl.d/
cp "$SRC/htdocs/luci-static/resources/view/qoscustom/overview.js" \
   /www/luci-static/resources/view/qoscustom/overview.js

chmod 755 /etc/init.d/qos-custom
chmod 644 /www/luci-static/resources/view/qoscustom/overview.js \
          /usr/share/luci/menu.d/luci-app-qoscustom.json \
          /usr/share/rpcd/acl.d/luci-app-qoscustom.json

# ---------- 关闭流量卸载（QoS 必须）----------
info "关闭流量卸载（flow offloading）..."
if [ -f /etc/config/firewall ]; then
    uci set firewall.@defaults[0].flow_offloading='0'    2>/dev/null || true
    uci set firewall.@defaults[0].flow_offloading_hw='0' 2>/dev/null || true
    uci commit firewall
    /etc/init.d/firewall reload >/dev/null 2>&1 || true
else
    warn "没找到 /etc/config/firewall，跳过"
fi

# ---------- 生效 ----------
info "重启 rpcd / uhttpd 并清理 LuCI 缓存..."
rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache
/etc/init.d/rpcd restart   >/dev/null 2>&1 || true
/etc/init.d/uhttpd restart >/dev/null 2>&1 || true

info "启动 QoS 服务..."
/etc/init.d/qos-custom enable
/etc/init.d/qos-custom restart
sleep 2

# ---------- 结果 ----------
WAN=$(uci get qoscustom.settings.interface 2>/dev/null || echo pppoe-wan)
LAN=$(uci get qoscustom.settings.lan_iface  2>/dev/null || echo br-lan)

echo
info "完成。当前规则："
tc qdisc show dev "$WAN" 2>/dev/null | head -1 || true
tc class show dev "$LAN" 2>/dev/null | head -2 || true

echo
info "打开 LuCI → 服务 → QoS 流量控制 进行配置。"
warn "请把 uplink_mbit / downlink_mbit 改成你实际带宽的 95%。"
