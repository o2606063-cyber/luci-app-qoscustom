#!/bin/sh
# build-ipk.sh - 重新生成 luci-app-qoscustom_<版本>_all.ipk
# 不需要 OpenWrt SDK，只要有 tar 就能跑（Linux / macOS / WSL / Git Bash）
set -e

VER="${1:-1.0.0}"
REL="${2:-1}"
OUT="luci-app-qoscustom_${VER}-${REL}_all.ipk"
SRC=$(cd "$(dirname "$0")" && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "[+] 准备目录"
mkdir -p "$TMP/data" "$TMP/ctrl"
cp -r "$SRC/root/." "$TMP/data/"
mkdir -p "$TMP/data/www/luci-static/resources/view/qoscustom"
cp "$SRC/htdocs/luci-static/resources/view/qoscustom/overview.js" \
   "$TMP/data/www/luci-static/resources/view/qoscustom/"

# control
cat > "$TMP/ctrl/control" <<EOF
Package: luci-app-qoscustom
Version: ${VER}-${REL}
Depends: libc, tc-full, kmod-sched-cake, kmod-sched-htb
Source: https://github.com/o2606063-cyber/luci-app-qoscustom
SourceName: luci-app-qoscustom
License: MIT
Section: luci
Architecture: all
Installed-Size: $(du -sk "$TMP/data" | awk '{print $1}')
Description: LuCI QoS (CAKE + HTB) for OpenWrt builds without the ifb kernel module.
 CAKE-based traffic shaping with a LAN-bypass class. Usable on systems where
 stock SQM cannot be installed because kmod-ifb is unavailable.
EOF

echo "/etc/config/qoscustom" > "$TMP/ctrl/conffiles"

cat > "$TMP/ctrl/postinst" <<'EOF'
#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] && exit 0
/etc/init.d/qos-custom enable
rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache
/etc/init.d/rpcd restart >/dev/null 2>&1
/etc/init.d/uhttpd restart >/dev/null 2>&1
/etc/init.d/qos-custom restart >/dev/null 2>&1
exit 0
EOF
chmod 755 "$TMP/ctrl/postinst"

echo "2.0" > "$TMP/debian-binary"

echo "[+] 打包"
( cd "$TMP/ctrl" && tar -czf "$TMP/control.tar.gz" ./control ./conffiles ./postinst )
( cd "$TMP/data" && tar -czf "$TMP/data.tar.gz" . )
( cd "$TMP"      && tar -czf "$SRC/$OUT" ./debian-binary ./control.tar.gz ./data.tar.gz )

echo "[+] 完成: $OUT ($(wc -c < "$SRC/$OUT") 字节)"
echo
echo "结构校验:"
tar -tzf "$SRC/$OUT"
