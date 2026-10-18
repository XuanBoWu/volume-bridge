#!/bin/zsh
set -eu
project_dir="${0:A:h}"
build_dir="${VB_BUILD_DIR:-$project_dir/build}"
app_dir="$build_dir/VolumeBridge.app"
target_triple="${VB_ARCH:-arm64}-apple-macos14.2"
sign_identity="${VB_SIGN_IDENTITY:-VolumeBridge Local Development}"
sign_keychain="${VB_SIGN_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
clang++ -target "$target_triple" -std=c++20 -fobjc-arc -O2 -Wall -Wextra -Werror \
    -c "$project_dir/Sources/AudioController.mm" -o "$build_dir/AudioController.o"
clang++ -target "$target_triple" -std=c++20 -fobjc-arc -O2 -Wall -Wextra -Werror \
    -c "$project_dir/Sources/Logging.mm" -o "$build_dir/Logging.o"
swiftc -target "$target_triple" -swift-version 5 -O -framework AppKit -framework CoreAudio \
    -import-objc-header "$project_dir/Sources/AudioController.h" \
    "$project_dir/Sources/main.swift" "$project_dir/Sources/VolumeSliderState.swift" \
    "$project_dir/Sources/MediaKeyPolicy.swift" "$project_dir/Sources/MediaKeys.swift" \
    "$project_dir/Sources/VolumeHUD.swift" "$project_dir/Sources/ControlPopover.swift" \
    "$project_dir/Sources/VolumeFeedback.swift" "$project_dir/Sources/VolumeFeedbackPolicy.swift" \
    "$project_dir/Sources/Localization.swift" "$project_dir/Sources/Logging.swift" \
    "$build_dir/AudioController.o" "$build_dir/Logging.o" -lc++ \
    -o "$app_dir/Contents/MacOS/VolumeBridge"
cp "$project_dir/Info.plist" "$app_dir/Contents/Info.plist"
ditto "$project_dir/Resources" "$app_dir/Contents/Resources"
if security find-certificate -c "$sign_identity" "$sign_keychain" >/dev/null 2>&1 \
    && security find-key -l "$sign_identity" -s "$sign_keychain" >/dev/null 2>&1; then
    codesign --force --keychain "$sign_keychain" --sign "$sign_identity" "$app_dir"
    print "Signed with local identity: $sign_identity"
else
    codesign --force --sign - "$app_dir"
    print "Signed ad-hoc (run scripts/setup-local-signing.sh for a stable local identity)"
fi
codesign --verify --strict "$app_dir"
# A newer bundle date lets Finder and IconServices drop a cached icon after rebuilds.
touch "$app_dir"
clang++ -std=c++20 -O2 -Wall -Wextra -Werror "$project_dir/Tests/policy.cpp" -o "$build_dir/policy-tests"
"$build_dir/policy-tests"
swiftc -swift-version 5 "$project_dir/Sources/VolumeSliderState.swift" "$project_dir/Tests/Slider/main.swift" -o "$build_dir/slider-tests"
"$build_dir/slider-tests"
swiftc -swift-version 5 "$project_dir/Sources/MediaKeyPolicy.swift" "$project_dir/Tests/MediaKeys/main.swift" -o "$build_dir/media-key-tests"
"$build_dir/media-key-tests"
swiftc -target "$target_triple" -swift-version 5 -O -framework AppKit \
    -import-objc-header "$project_dir/Sources/Logging.h" \
    "$project_dir/Sources/MediaKeyPolicy.swift" "$project_dir/Sources/MediaKeys.swift" \
    "$project_dir/Sources/Logging.swift" "$project_dir/Tests/MediaKeyLifecycle/main.swift" \
    "$build_dir/Logging.o" -lc++ -o "$build_dir/media-key-lifecycle-tests"
"$build_dir/media-key-lifecycle-tests"
clang++ -target "$target_triple" -std=c++20 -fobjc-arc -O2 -Wall -Wextra -Werror \
    -framework AppKit -framework CoreAudio \
    "$project_dir/Tests/ControllerReads/main.mm" "$build_dir/AudioController.o" "$build_dir/Logging.o" \
    -o "$build_dir/controller-read-tests"
"$build_dir/controller-read-tests"
clang++ -target "$target_triple" -std=c++20 -fobjc-arc -O2 -Wall -Wextra -Werror \
    -framework AppKit -framework CoreAudio \
    "$project_dir/Tests/DeviceSelection/main.mm" "$build_dir/AudioController.o" "$build_dir/Logging.o" \
    -o "$build_dir/device-selection-tests"
"$build_dir/device-selection-tests"
clang++ -std=c++20 -O2 -Wall -Wextra -Werror "$project_dir/Tests/media_volume.cpp" -o "$build_dir/media-volume-tests"
"$build_dir/media-volume-tests"
clang++ -std=c++20 -fobjc-arc -Wall -Wextra -Werror -framework Foundation \
    "$project_dir/Sources/Logging.mm" "$project_dir/Tests/Logging/main.mm" -o "$build_dir/logging-tests"
"$build_dir/logging-tests"
swiftc -target "$target_triple" -swift-version 5 -O -framework AppKit \
    -import-objc-header "$project_dir/Sources/Logging.h" \
    "$project_dir/Sources/VolumeFeedback.swift" "$project_dir/Sources/VolumeFeedbackPolicy.swift" \
    "$project_dir/Sources/Logging.swift" "$project_dir/Tests/Feedback/main.swift" "$build_dir/Logging.o" -lc++ \
    -o "$build_dir/feedback-tests"
"$build_dir/feedback-tests"
print "$app_dir"
