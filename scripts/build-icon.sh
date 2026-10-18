#!/bin/zsh
# Regenerate the app icon from design/icon/icon.py:
#   design/icon/*.svg -> headless Chrome (1024 px) -> linear-light box downscale -> AppIcon.iconset
#   -> Resources/AppIcon.icns, plus design/icon/preview.png for review.
# Needs Google Chrome and ImageMagick (`magick`). Normal builds only copy the committed .icns.
set -eu
project_dir="${0:A:h:h}"
work="${VB_BUILD_DIR:-$project_dir/build}/icon"
design="$project_dir/design/icon"
chrome="${VB_CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
[[ -x "$chrome" ]] || { print -u2 "Google Chrome not found; set VB_CHROME to its executable"; exit 1; }
command -v magick >/dev/null || { print -u2 "ImageMagick 'magick' not found (brew install imagemagick)"; exit 1; }

profile="$(mktemp -d)"
trap 'rm -rf "$profile"' EXIT
# Headless Chrome writes the screenshot but may never exit; a mock keychain avoids a
# Keychain prompt, and the process is stopped as soon as the PNG exists.
shot() {
    rm -f "$4"
    "$chrome" --headless=new --disable-gpu --hide-scrollbars --no-first-run --no-default-browser-check \
        --disable-extensions --use-mock-keychain --password-store=basic --disable-background-networking \
        --disable-component-update --disable-sync --user-data-dir="$profile" \
        --default-background-color=00000000 --force-device-scale-factor="$3" --window-size="$2" \
        --screenshot="$4" "file://$1" >/dev/null 2>&1 &
    local pid=$! waited=0
    while kill -0 $pid 2>/dev/null && (( waited < 300 )); do
        if [[ -s "$4" ]]; then sleep 0.5; break; fi
        sleep 0.1
        (( waited += 1 ))
    done
    kill $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true
    [[ -s "$4" ]] || { print -u2 "render failed: $1"; return 1; }
}
# Integer-factor box filter in linear light: each output pixel is the exact average of its block.
shrink() { magick "$1" -colorspace RGB -filter Box -resize "$2x$2" -colorspace sRGB "$3"; }

rm -rf "$work"
mkdir -p "$work/png" "$work/AppIcon.iconset"
python3 "$design/icon.py" "$design"
for name in AppIcon AppIcon-64 AppIcon-32 AppIcon-16; do
    shot "$design/$name.svg" 1024,1024 1 "$work/png/$name-render.png"
done
cp "$work/png/AppIcon-render.png" "$work/png/icon-1024.png"
for size in 512 256 128; do shrink "$work/png/AppIcon-render.png" $size "$work/png/icon-$size.png"; done
for size in 64 32 16; do shrink "$work/png/AppIcon-$size-render.png" $size "$work/png/icon-$size.png"; done

set_dir="$work/AppIcon.iconset"
for spec in 16x16:16 16x16@2x:32 32x32:32 32x32@2x:64 128x128:128 128x128@2x:256 256x256:256 \
            256x256@2x:512 512x512:512 512x512@2x:1024; do
    cp "$work/png/icon-${spec##*:}.png" "$set_dir/icon_${spec%%:*}.png"
done
iconutil -c icns "$set_dir" -o "$project_dir/Resources/AppIcon.icns"

cat > "$work/preview.html" <<'HTML'
<!doctype html><html><head><meta charset="utf-8"><style>
body{margin:0;background:#F2F2F5;font-family:-apple-system,"PingFang SC",sans-serif;color:#1d1d1f;padding:24px 28px}
.card{background:#fff;border-radius:18px;padding:16px 20px;margin-bottom:16px;box-shadow:0 1px 3px rgba(0,0,0,.06)}
h2{font-size:17px;font-weight:600;margin:0 0 4px}p{font-size:12px;color:#6e6e73;margin:0 0 12px}
.hero{display:flex;gap:24px;align-items:center}.hero img{width:200px;height:200px}
.zoom{display:flex;gap:18px}.zoom div{display:flex;flex-direction:column;align-items:center;gap:6px;font-size:12px;color:#6e6e73}
.zoom img{width:128px;height:128px;image-rendering:pixelated}
.trays{display:flex;gap:14px}.tray{display:flex;align-items:center;gap:20px;padding:12px 18px;border-radius:12px;flex:1}
.light{background:#E8E8ED}.dark{background:#1C1C1E}
.tray div{display:flex;flex-direction:column;align-items:center;gap:4px;font-size:11px;color:#8e8e93}
</style></head><body>
<div class="card hero"><img src="png/icon-1024.png"><div><h2>音桥 / VolumeBridge 应用图标</h2>
<p>金门大桥侧视图，晴空蓝配国际橙。由 scripts/build-icon.sh 根据 design/icon/icon.py 生成。</p></div></div>
<div class="card"><h2>小尺寸专用版本（像素放大）</h2><p>16 / 32 / 64 px 各自简化并对齐像素，不是主图直接缩小。</p>
<div class="zoom"><div><img src="png/icon-16.png">16 px</div><div><img src="png/icon-32.png">32 px</div><div><img src="png/icon-64.png">64 px</div><div><img src="png/icon-128.png">128 px（主图）</div></div></div>
<div class="card"><h2>Retina 实际大小</h2><p>16pt 用 32px、32pt 用 64px、64pt 用 128px、128pt 用 256px。</p><div class="trays">
<div class="tray light"><div><img src="png/icon-32.png" width="16">16pt</div><div><img src="png/icon-64.png" width="32">32pt</div><div><img src="png/icon-128.png" width="64">64pt</div><div><img src="png/icon-256.png" width="128">128pt</div></div>
<div class="tray dark"><div><img src="png/icon-32.png" width="16">16pt</div><div><img src="png/icon-64.png" width="32">32pt</div><div><img src="png/icon-128.png" width="64">64pt</div><div><img src="png/icon-256.png" width="128">128pt</div></div>
</div></div></body></html>
HTML
shot "$work/preview.html" 860,800 2 "$design/preview.png"
print "$project_dir/Resources/AppIcon.icns"
