#!/bin/zsh
set -eu
project_dir="${0:A:h:h}"
build_dir="${VB_BUILD_DIR:-$project_dir/build}"
mkdir -p "$build_dir"
clang++ -std=c++20 -fobjc-arc -O2 -Wall -Wextra -Werror \
    -framework Foundation -framework CoreAudio \
    "$project_dir/Tests/audioctl.mm" -o "$build_dir/audioctl"
print "$build_dir/audioctl"
