#!/usr/bin/env bash
# Builds the core as a shared library for the host, so Dart tests can load it:
#
#   tool/build_host_deps.sh          # once, and after versions.lock changes
#   tool/build_host_ffi_lib.sh
#   ANIMATED_STICKERS_LIB=build/ffi/src/libanimated_stickers.dylib fvm flutter test
#
# (.so on Linux.) Dart tests that need the library skip themselves when
# ANIMATED_STICKERS_LIB is unset.
set -euo pipefail
cd "$(dirname "$0")/.."
cmake -S . -B build/ffi -DWT_BUILD_SHARED=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build/ffi --target animated_stickers -j
ls build/ffi/src/libanimated_stickers.*
