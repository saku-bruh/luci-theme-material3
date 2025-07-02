#
# Copyright (C) 2008-2014 The LuCI Team <luci@lists.subsignal.org>
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=Material 3 Theme
LUCI_DEPENDS:=+luci-base
PKG_VERSION:=1.1.0
PKG_RELEASE:=20250701

PKG_LICENSE:=Apache-2.0

define Package/luci-theme-material3/postrm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	uci -q delete luci.themes.Material3
	uci -q delete luci.themes.Material3Blue
	uci -q delete luci.themes.Material3Green
	uci -q delete luci.themes.Material3Red
	uci -q delete luci.themes.Material3Amoled
	uci set luci.main.mediaurlbase='/luci-static/bootstrap'
	# uci -q delete luci.themes.Material3Dark
	# uci -q delete luci.themes.Material3Light
	uci commit luci

	# Make sure Google Sans cache doesn't prevent a complete removal
	rm -rf /www/luci-static/material3
}
endef

define Package/luci-theme-material3/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0"

	INPUT="/tmp/google-sans.css"
	TMP="/tmp/google-sans.local.css"
	OUTPUT="/www/luci-static/material3/google-sans.css"
	FONT_DIR="/www/luci-static/material3/fonts"

	# Ensure target directory exists
	mkdir -p "$FONT_DIR"

	# Download Google Fonts CSS
	wget -q -O "$INPUT" -U "$UA" "https://fonts.googleapis.com/css?family=Google+Sans"

	# Generate local CSS
	lang=""
	in_block=0

	rm -f "$TMP"
	while IFS= read -r line; do
		case "$line" in
		"/* "*)
			lang=$(echo "$line" | sed -n 's|/\*\s*\(.*\)\s*\*/|\1|p' | sed 's/^ *//;s/ *$//')
			in_block=1
			echo "$line" >> "$TMP"
			;;
		*"@font-face {"*)
			echo "$line" >> "$TMP"
			;;
		*"src: url("*)
			if [ "$in_block" -eq 1 ] && [ -n "$lang" ]; then
				file=$(echo "$line" | sed -n 's|.*url(.*\/\([^/]*\.woff2\)).*|\1|p')
				echo "  src: url('fonts/$lang.woff2') format('woff2');" >> "$TMP"

				# Download font
				if [ ! -f "$FONT_DIR/$lang.woff2" ]; then
					url=$(echo "$line" | sed -n 's|.*url(\(https[^)]*\.woff2\)).*|\1|p')
					wget -q -O "$FONT_DIR/$lang.woff2" "$url"
					if [ $? -ne 0 ]; then
						rm -rf "$FONT_DIR"
						break
					fi
				fi
			else
				echo "$line" >> "$TMP"
			fi
			;;
		"}")
			in_block=0
			echo "$line" >> "$TMP"
			echo "" >> "$TMP"
			;;
		*)
			echo "$line" >> "$TMP"
			;;
		esac
	done < "$INPUT"
	rm -f "$INPUT"

	if [ -d "$FONT_DIR" ]; then
		mv "$TMP" "$OUTPUT"
	else
		rm -f "$TMP"
	fi
}
endef

LUCI_MINIFY_CSS:=0

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature