#!/bin/bash
# diy-part1.sh
#opkg update
#opkg install kmod-batman-adv

sed -i '$a src-git batman https://github.com/open-mesh-mirror/batman-adv' feeds.conf.default
