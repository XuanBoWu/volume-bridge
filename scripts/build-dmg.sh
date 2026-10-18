#!/bin/zsh
# Build and check the app, then package a read-only drag-to-Applications disk image.
set -eu
project_dir="${0:A:h:h}"
build_dir="${VB_BUILD_DIR:-$project_dir/build}"
build_dir="${build_dir:A}"
export VB_BUILD_DIR="$build_dir"
arch="${VB_ARCH:-arm64}"

zsh "$project_dir/scripts/check.sh"
app_dir="$build_dir/VolumeBridge.app"
version="$(plutil -extract CFBundleShortVersionString raw "$app_dir/Contents/Info.plist")"
[[ "$version" == [0-9]* && "$version" != *[^0-9.]* ]] || { print -u2 "Invalid app version: $version"; exit 1; }
[[ "$arch" == arm64 || "$arch" == x86_64 ]] || { print -u2 "Unsupported architecture: $arch"; exit 1; }
dmg="$build_dir/VolumeBridge-$version-$arch.dmg"
package_work="$(mktemp -d "$build_dir/dmg.XXXXXX")"
mounted=0
cleanup() {
    if (( mounted )); then
        if ! hdiutil detach "$package_work/mount" >/dev/null; then
            print -u2 "Could not detach verification volume: $package_work/mount"
            return 1
        fi
    fi
    rm -rf "$package_work"
}
trap cleanup EXIT
mkdir -p "$package_work/stage" "$package_work/mount"
ditto "$app_dir" "$package_work/stage/VolumeBridge.app"
ln -s /Applications "$package_work/stage/Applications"
codesign --verify --strict "$package_work/stage/VolumeBridge.app"
hdiutil create -ov -format UDZO -fs HFS+ -volname "VolumeBridge $version" \
    -srcfolder "$package_work/stage" "$dmg"
hdiutil verify "$dmg"
hdiutil attach -readonly -nobrowse -noautoopen -mountpoint "$package_work/mount" "$dmg" >/dev/null
mounted=1
codesign --verify --strict "$package_work/mount/VolumeBridge.app"
[[ "$(readlink "$package_work/mount/Applications")" == /Applications ]] || { print -u2 "Invalid Applications link"; exit 1; }
diff -qr "$app_dir" "$package_work/mount/VolumeBridge.app"
[[ "$(plutil -extract CFBundleIdentifier raw "$package_work/mount/VolumeBridge.app/Contents/Info.plist")" == local.alexwu.DisplayVolume ]] || { print -u2 "Unexpected bundle identifier"; exit 1; }
hdiutil detach "$package_work/mount" >/dev/null
mounted=0
print "PASS DMG: image checksum, mounted app signature, bundle contents, Applications link"
shasum -a 256 "$dmg"
print "$dmg"
