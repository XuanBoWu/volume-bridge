#!/bin/zsh
# Verify the app icon is declared in Info.plist, packaged unchanged, and has every macOS size.
set -eu
project_dir="${0:A:h:h}"
app_dir="${VB_BUILD_DIR:-$project_dir/build}/VolumeBridge.app"
icon_name="$(plutil -extract CFBundleIconFile raw "$project_dir/Info.plist")"
[[ "$icon_name" == "AppIcon" ]] || { print -u2 "Info.plist CFBundleIconFile must be AppIcon"; exit 1; }
source_icon="$project_dir/Resources/AppIcon.icns"
packaged="$app_dir/Contents/Resources/AppIcon.icns"
[[ -f "$packaged" ]] || { print -u2 "Missing packaged icon: $packaged"; exit 1; }
cmp -s "$packaged" "$source_icon" || { print -u2 "Packaged AppIcon.icns differs from Resources/"; exit 1; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
iconutil -c iconset "$packaged" -o "$tmp/AppIcon.iconset"
for spec in 16x16:16 16x16@2x:32 32x32:32 32x32@2x:64 128x128:128 128x128@2x:256 256x256:256 \
            256x256@2x:512 512x512:512 512x512@2x:1024; do
    file="$tmp/AppIcon.iconset/icon_${spec%%:*}.png"
    [[ -f "$file" ]] || { print -u2 "Missing icon representation icon_${spec%%:*}"; exit 1; }
    size="$(sips -g pixelWidth -g pixelHeight "$file" | awk '/pixel(Width|Height)/{print $2}' | sort -u)"
    [[ "$size" == "${spec##*:}" ]] || { print -u2 "icon_${spec%%:*} is ${size//$'\n'/x} px, expected ${spec##*:}"; exit 1; }
done
print "PASS app icon: CFBundleIconFile, packaged AppIcon.icns, 10 representations 16-1024 px"
