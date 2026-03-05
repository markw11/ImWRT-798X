#!/bin/bash

function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../
  cd .. && rm -rf $repodir
}

set -x

# kenrel Vermagic
sed -ie 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk
grep HASH target/linux/generic/kernel-6.12 | awk -F'HASH-' '{print $2}' | awk '{print $1}' | md5sum | awk '{print $1}' > .vermagic

git clone -b packages --depth 1 --single-branch https://github.com/shiyu1314/openwrt-feeds package/xd
git clone -b porxy --depth 1 --single-branch https://github.com/shiyu1314/openwrt-feeds package/porxy

rm -rf feeds/luci/applications/{luci-app-dockerman,luci-app-samba4,luci-app-aria2,luci-app-diskman}
rm -rf feeds/packages/net/{samba4,v2ray-geodata,mosdns,sing-box,aria2,ariang,adguardhome}

# drop attendedsysupgrade （保留，但只针对通用位置，不针对 nginx 集合）
sed -i '/luci-app-attendedsysupgrade/d' feeds/luci/collections/luci/Makefile

# fstools
rm -rf package/system/fstools
git clone https://github.com/sbwml/package_system_fstools -b openwrt-25.12 package/system/fstools

# util-linux
rm -rf package/utils/util-linux
git clone https://github.com/sbwml/package_utils_util-linux -b openwrt-25.12 package/utils/util-linux

# nghttp3
rm -rf feeds/packages/libs/nghttp3
git clone https://github.com/sbwml/package_libs_nghttp3 package/libs/nghttp3

# ngtcp2
rm -rf feeds/packages/libs/ngtcp2
git clone https://github.com/sbwml/package_libs_ngtcp2 package/libs/ngtcp2

# curl - fix passwall `time_pretransfer` check
rm -rf feeds/packages/net/curl
git clone https://github.com/sbwml/feeds_packages_net_curl feeds/packages/net/curl

# golang 26.x
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang

./scripts/feeds update -a
./scripts/feeds install -a

# 强制禁用 nginx 相关包（防止意外被选上）
cat >> .config << 'EOF'
CONFIG_PACKAGE_nginx=n
CONFIG_PACKAGE_nginx-ssl=n
CONFIG_PACKAGE_nginx-mod-luci=n
CONFIG_PACKAGE_luci-nginx=n
CONFIG_PACKAGE_luci-app-nginx=n
CONFIG_PACKAGE_uwsgi=n
CONFIG_PACKAGE_uwsgi-luci-support=n
EOF

# 确保 uhttpd 被启用（通常默认就是，但显式写一下更保险）
echo "CONFIG_PACKAGE_uhttpd=y" >> .config
echo "CONFIG_PACKAGE_uhttpd-mod-ubus=y" >> .config
echo "CONFIG_PACKAGE_uhttpd-mod-tls=y" >> .config   # 如果你想要 https 支持

sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

sudo rm -rf package/base-files/files/etc/banner

sed -i "s/%D %V %C/%D %V $(TZ=UTC-8 date +%Y.%m.%d)/" package/base-files/files/etc/openwrt_release
sed -i "s/%R/by $OP_author/" package/base-files/files/etc/openwrt_release

date=$(date +"%Y-%m-%d")
echo " " >> package/base-files/files/etc/banner
echo " _______ ________ __" >> package/base-files/files/etc/banner
echo " | |.-----.-----.-----.| | | |.----.| |_" >> package/base-files/files/etc/banner
echo " | - || _ | -__| || | | || _|| _|" >> package/base-files/files/etc/banner
echo " |_______|| __|_____|__|__||________||__| |____|" >> package/base-files/files/etc/banner
echo " |__|" >> package/base-files/files/etc/banner
echo " -----------------------------------------------------" >> package/base-files/files/etc/banner
echo " %D ${date} by $OP_author " >> package/base-files/files/etc/banner
echo " -----------------------------------------------------" >> package/base-files/files/etc/banner
