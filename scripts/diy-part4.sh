#!/bin/bash

# --- 1. 内核 Vermagic 伪装 (确保能安装官方仓库的插件) ---
sed -ie 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk
grep HASH target/linux/generic/kernel-6.12 | awk -F'HASH-' '{print $2}' | awk '{print $1}' | md5sum | awk '{print $1}' > .vermagic

# --- 2. 添加第三方轻量化插件 ---
# 仅保留 shiyu1314 的基础包，剔除占用大的 proxy 仓库
git clone -b packages --depth 1 --single-branch https://github.com/shiyu1314/openwrt-feeds package/xd

# --- 3. 彻底清理冗余/大型包 (节省空间关键) ---
# 删除占用巨大的服务及其依赖
rm -rf feeds/luci/applications/{luci-app-dockerman,luci-app-samba4,luci-app-aria2,luci-app-diskman}
rm -rf feeds/packages/net/{samba4,v2ray-geodata,mosdns,sing-box,aria2,ariang,adguardhome}

# --- 4. 系统响应优化 ---
# 延长 RPC 超时时间，防止 Web 界面在大数据量下卡死
sed -i 's/option timeout 30/option timeout 60/g' package/system/rpcd/files/rpcd.config
sed -i 's#20) \* 1000#60) \* 1000#g' feeds/luci/modules/luci-base/htdocs/luci-static/resources/rpc.js

# 移除没必要的 luci-compat 空行（美化界面）
sed -i '/<br \/>/d' feeds/luci/modules/luci-compat/luasrc/view/cbi/full_valuefooter.htm

# --- 5. 应用核心系统补丁 (LuCI 增强) ---
pushd feeds/luci
    # 仅应用最实用的轻量化补丁
    patch -p1 < 0002-luci-mod-status-displays-actual-process-memory-usage.patch
    patch -p1 < 0003-luci-mod-status-storage-index-applicable-only-to-val.patch
    patch -p1 < 0005-luci-mod-system-add-refresh-interval-setting.patch
popd

# 应用防火墙自定义规则支持
patch -p1 --no-backup-if-mismatch < 100-openwrt-firewall4-add-custom-nft-command-support.patch

# --- 6. 自动更新与安装 Feeds ---
./scripts/feeds update -a
./scripts/feeds install -a

# --- 7. 终端与登录设置 ---
# 设置 ttyd 免密登录 root (方便调试)
if [ -f feeds/packages/utils/ttyd/files/ttyd.config ]; then
    sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config
fi

# --- 8. 自定义 Banner 与 版本信息 ---
# 移除原有的 banner
rm -rf package/base-files/files/etc/banner

# 写入极简风格 Banner
date=$(date +"%Y-%m-%d")
cat << 'EOF' > package/base-files/files/etc/banner
  _______                     ________        __
 |       |.-----.-----.-----.|  |  |  |.----.|  |_
 |   -   ||  _  |  -__|  _  ||  |  |  ||  _||   _|
 |_______||   __|_____|__|__||________||__|  |____|
          |__| W I R E L E S S   F R E E D O M
 -----------------------------------------------------
 %D ${date} by Minimal-Build
 -----------------------------------------------------
EOF

# 修改版本发布信息
sed -i "s/%D %V %C/%D %V $(date +%Y.%m.%d)/" package/base-files/files/etc/openwrt_release
