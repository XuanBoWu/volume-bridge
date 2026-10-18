#!/bin/zsh
set -eu
project_dir="${0:A:h:h}"
build_dir="${VB_BUILD_DIR:-$project_dir/build}"
app_dir="$build_dir/LocalizationTests.app"
target_triple="${VB_ARCH:-arm64}-apple-macos14.2"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
swiftc -target "$target_triple" -swift-version 5 -framework Foundation -framework AppKit -framework CoreAudio \
    -import-objc-header "$project_dir/Sources/AudioController.h" \
    "$project_dir/Sources/Localization.swift" "$project_dir/Tests/Localization/main.swift" \
    "$build_dir/AudioController.o" "$build_dir/Logging.o" -lc++ -o "$app_dir/Contents/MacOS/LocalizationTests"
cp "$project_dir/Info.plist" "$app_dir/Contents/Info.plist"
plutil -replace CFBundleExecutable -string LocalizationTests "$app_dir/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string local.alexwu.VolumeBridge.LocalizationTests "$app_dir/Contents/Info.plist"
ditto "$project_dir/Resources" "$app_dir/Contents/Resources"
python3 "$project_dir/scripts/check-localizations.py" "$build_dir/VolumeBridge.app/Contents/Resources"
"$app_dir/Contents/MacOS/LocalizationTests" -AppleLanguages '(en)' -AppleLocale en_US --expect-language en --expect-percent '50%'
"$app_dir/Contents/MacOS/LocalizationTests" -AppleLanguages '(zh-Hans)' -AppleLocale zh_CN --expect-language zh-Hans --expect-percent '50%'
"$app_dir/Contents/MacOS/LocalizationTests" -AppleLanguages '(fr)' -AppleLocale fr_FR --expect-language en --expect-percent '50 %'
