#!/bin/zsh
set -eu
project_dir="${0:A:h}"
build_dir="${VB_BUILD_DIR:-$project_dir/build}"
app_dir="$build_dir/VolumeBridge.app"
target_triple="${VB_ARCH:-arm64}-apple-macos14.2"
mkdir -p "$app_dir/Contents/MacOS"
clang++ -target "$target_triple" -std=c++20 -fobjc-arc -O2 -Wall -Wextra -Werror \
    -c "$project_dir/Sources/AudioController.mm" -o "$build_dir/AudioController.o"
swiftc -target "$target_triple" -swift-version 5 -O -framework AppKit -framework CoreAudio \
    -import-objc-header "$project_dir/Sources/AudioController.h" \
    "$project_dir/Sources/main.swift" "$project_dir/Sources/VolumeSliderState.swift" \
    "$project_dir/Sources/MediaKeyPolicy.swift" "$project_dir/Sources/MediaKeys.swift" \
    "$project_dir/Sources/VolumeHUD.swift" "$build_dir/AudioController.o" -lc++ \
    -o "$app_dir/Contents/MacOS/VolumeBridge"
cp "$project_dir/Info.plist" "$app_dir/Contents/Info.plist"
codesign --force --sign - "$app_dir"
codesign --verify --strict "$app_dir"
clang++ -std=c++20 -O2 -Wall -Wextra -Werror "$project_dir/Tests/policy.cpp" -o "$build_dir/policy-tests"
"$build_dir/policy-tests"
swiftc -swift-version 5 "$project_dir/Sources/VolumeSliderState.swift" "$project_dir/Tests/Slider/main.swift" -o "$build_dir/slider-tests"
"$build_dir/slider-tests"
swiftc -swift-version 5 "$project_dir/Sources/MediaKeyPolicy.swift" "$project_dir/Tests/MediaKeys/main.swift" -o "$build_dir/media-key-tests"
"$build_dir/media-key-tests"
clang++ -std=c++20 -O2 -Wall -Wextra -Werror "$project_dir/Tests/media_volume.cpp" -o "$build_dir/media-volume-tests"
"$build_dir/media-volume-tests"
print "$app_dir"
