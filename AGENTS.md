# AGENTS.md

Instructions for any coding agent working in this repository. Human contributors will find the same commands and rules useful.

## What this is
`animated_stickers` is a Flutter plugin for **Android and iOS only**, published on pub.dev. It plays animated stickers inline, the way Telegram does: VP9/VP8 WebM with alpha, animated WebP and GIF. A shared C++ core decodes in software, caches frames, and renders them into Flutter `Texture`s.

- **How it works and why**: [`docs/architecture.md`](docs/architecture.md). The decisions behind it are the ADRs in [`docs/decisions/`](docs/decisions/README.md).
- **Security**: the threat model and review findings are in [`docs/security.md`](docs/security.md).
- **What to do next**: open GitHub issues, especially those labelled `follow-up`.
- **History**: the package was built from a plan whose task IDs (`T2.2`, `T6.1`, …) still appear in code comments and ADRs. The plan, the task list and the spike code are kept at the `archive/plan-and-spikes` tag (see [`docs/decisions/README.md`](docs/decisions/README.md#reading-older-adrs)).

## Ground rules
1. **Always run Flutter/Dart through `fvm`** (`fvm flutter …`, `fvm dart …`). The SDK version is pinned in `.fvmrc`. Change it only in a PR that is about upgrading Flutter.
2. **One change per branch and PR.** Name the branch `<kind>/<slug>` (`fix/…`, `feat/…`, `chore/…`, `docs/…`) and link the issue it addresses.
3. **A change is done only when its checks pass.** Run format, analyze and the tests that cover what you touched (see Commands), and paste a summary of the output into the PR description.
4. **Some decisions belong to the owner.** These include changes to the public API, the scope, the `StickerLimits` defaults, and choices between designs with real trade-offs. Write up the options and ask; don't decide them yourself.
5. **Decisions go in writing.** Any change to the design in `docs/architecture.md` (library choice, API shape, file format, limits) gets a short ADR in `docs/decisions/NNNN-title.md` (see [its README](docs/decisions/README.md)). Update `docs/architecture.md` in the same PR.
6. **Stay in scope.** Don't add desktop/web platforms, encoding, audio, Lottie/TGS, or new dependencies without an ADR.
7. **User-visible changes go in `CHANGELOG.md`** under the next version. Follow semver: breaking public API changes need a major version.

## Repository map
```
lib/                 Dart public API (lib/animated_stickers.dart) + lib/src/ internals
pigeons/             Pigeon definitions → generated code in lib/src/gen, android/, ios/
src/                 C++17 core (demux/ decode/ convert/ cache/ sched/ atlas/ api/)
  api/wt_api.h       The ONLY C ABI surface (FFI + platform glue include this)
third_party/         versions.lock, test-deps.lock, build scripts; prebuilt/ is gitignored
android/             Kotlin plugin + JNI + CMake
ios/animated_stickers/    Package.swift (SwiftPM only), Swift + ObjC++ shim
native_test/         GoogleTest host tests
fuzz/                libFuzzer targets + seed corpus
test/                Dart unit/widget tests
test_assets/         Generated corpus (tool/gen_corpus.sh) + reference frames
example/             Published example: a short main.dart + 3 stickers in assets/
example_dev/         Development app (unpublished): demo pages, integration_test/, goldens
tool/                fetch_prebuilts.dart, build_host_deps.sh, gen_corpus.sh, bench scripts
docs/                decisions/ (ADRs), spikes/ (spike reports), cache-format.md, security.md
```

## Commands
| Purpose | Command |
|---|---|
| Deps | `fvm flutter pub get` |
| Format | `fvm dart format --set-exit-if-changed .` · `clang-format --dry-run -Werror $(git ls-files 'src/*.cc' 'src/*.h' 'native_test/*.cc' 'native_test/*.c' 'native_test/*.h' 'fuzz/*.cc' 'android/src/main/cpp/*.cc' 'android/src/main/cpp/*.h')` (clang-format 23.1.5, as in CI) |
| Analyze | `fvm flutter analyze` |
| Dart tests | `fvm flutter test` |
| Build iOS prebuilts | `third_party/build/build-ios.sh` (macOS + Xcode, `brew install cmake nasm`) → `third_party/prebuilt/ios/WebmTextureDeps.xcframework` |
| Build Android prebuilts | `third_party/build/build-android.sh [--with-x86]` (NDK r30 for the plugin, [ADR 0009](docs/decisions/0009-ffi-loading-and-native-wiring.md); the script itself accepts r28+, `cmake`, `nasm`) → `third_party/prebuilt/android/{include,<abi>/libwebm_texture_deps.a}` |
| Vendor + archive | `fvm dart run tool/vendor_prebuilts.dart vendor` (fetch, verify, size-check the prebuilts) · `fvm dart run tool/vendor_prebuilts.dart archive --out build/release/animated_stickers.tar.gz` (dry run, then the archive pub would upload) · `fvm dart pub global activate pana 0.23.19 && fvm dart pub global run pana .`. Release flow and one-time pub.dev setup: [ADR 0024](docs/decisions/0024-publish-pipeline.md) |
| Third-party licenses | `third_party/build/collect-licenses.sh` → `third_party/LICENSES.md` (commit it) |
| Fetch native libs | `fvm dart run tool/fetch_prebuilts.dart` |
| Host deps | `tool/build_host_deps.sh` (`cmake`, `nasm` on x86_64) → `build/deps/host-core/prefix`; rerun after `versions.lock` or `test-deps.lock` changes |
| Native host tests | `cmake -S . -B build/host -DWT_HOST_TESTS=ON -DWT_SANITIZE=ON && cmake --build build/host -j && ctest --test-dir build/host --output-on-failure` |
| Scheduler race check | `cmake -S . -B build/tsan -DWT_HOST_TESTS=ON -DWT_TSAN=ON && cmake --build build/tsan -j && ctest --test-dir build/tsan -R 'Sched\|Timeline\|SkipFrame\|SanitizerTest\|Atlas' --output-on-failure` (ThreadSanitizer; can't share a build with `WT_SANITIZE`. Includes the 500-animation scheduler stress test, the atlas churn test and the cancellation stress test) |
| Fuzz (60 s smoke) | `cmake -S . -B build/fuzz -DWT_FUZZ=ON -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ && cmake --build build/fuzz -j && tool/fuzz.sh 60` (runs `fuzz_sniff`, `fuzz_probe`, `fuzz_webm`, `fuzz_webp`, `fuzz_gif` and `fuzz_wsc` in parallel; findings go to `build/fuzz/artifacts/<target>/`. LLVM clang; Apple clang has no libFuzzer, so on macOS use `brew install llvm` and `/opt/homebrew/opt/llvm/bin/clang++`) |
| Regenerate bindings | `fvm dart run pigeon --input pigeons/messages.dart` · `fvm dart run ffigen --config ffigen.yaml` (needs libclang: `brew install llvm`) |
| Dart tests against the core | `tool/build_host_ffi_lib.sh` → `ANIMATED_STICKERS_LIB=build/ffi/src/libanimated_stickers.dylib fvm flutter test test/probe_test.dart test/sticker_cache_test.dart` (`.so` on Linux; the test skips without it) |
| Regenerate corpus | `tool/gen_corpus.sh` (needs `ffmpeg` with libvpx + libopus, `img2webp`, `gif2webp`, `gifsicle`, `jq`) · validate: `tool/gen_corpus.sh --check` |
| Android build | `cd example && fvm flutter build apk --debug` (the published example) · `cd example_dev && fvm flutter build apk --debug` (the development app) |
| iOS build | `cd example && fvm flutter build ios --simulator --debug` · the same in `example_dev` |
| Integration tests | `cd example_dev && fvm flutter test integration_test/all_test.dart -d <device>` (one app launch for every file below, which is what CI runs; pass a single file instead while developing. `probe_test.dart` probes the corpus over FFI; `cache_test.dart` checks the frame cache files, budget eviction and `clearCache()` through the glue; `texture_test.dart` drives the texture glue; `tier_test.dart` checks the device signals and scheduler options; `visibility_test.dart` checks that only on-screen stickers in a 200-item list report active; `atlas_test.dart` plays 64 animations through one atlas page texture, switches them to their own textures and back, and compares a slot with the decoded frame at 1:1; `atlas_demo_test.dart` drives the development app's Atlas page (add `--dart-define=DUMP_SCREENSHOT=true` to print a screenshot, see the file header); `app_test.dart` holds the per-platform checkerboard and Stress-atlas screenshot goldens (the atlas also against the same grid standalone) and the playback/pause tests: re-record goldens with `--dart-define=UPDATE_GOLDENS=true … \| fvm dart run ../tool/extract_goldens.dart`, see the file header). Not in `all_test.dart`: `sched_perf_test.dart` measures raster p90 with 60+ visible standalone stickers and the app's CPU playing and paused, printing a `SCHED_PERF {json}` line; `atlas_perf_test.dart` checks that 60 visible stickers in a `StickerAtlasScope` present and render at the content rate (30 fps) and iOS raster p90 ≤ 3 ms, printing an `ATLAS_PERF {json}` line. On Android run both with `--no-dds` |

## Conventions
- **Dart**: `flutter_lints` plus the rules in `analysis_options.yaml`. Public API is documented with dartdoc. The public API is what `lib/animated_stickers.dart` exports. Don't export anything more from `lib/src/` without an ADR.
- **C++17**: Google style via `.clang-format`. Build with `-fno-exceptions -fno-rtti` and use no exceptions across the C ABI; return `wt_status` codes.
  - Every allocation is bounded by `StickerLimits`, and every buffer write is bounds-checked.
  - Use RAII inside the core. `wt_api.h` stays plain C with explicit `*_create`/`*_destroy` pairs.
- **Kotlin/Swift**: keep platform glue thin (texture plumbing, lifecycle, device-tier signals). All media logic lives in `src/`.
- **Threads**: never decode on the platform main thread or the Flutter UI/raster threads. Document the thread affinity of every `wt_api.h` function in its header comment.
- **Pixel formats**: frames are **premultiplied**. Android writes RGBA_8888 and iOS writes BGRA (in libyuv naming, `ABGR` and `ARGB` respectively).
- **Generated code** gets committed and must not be edited by hand. Regenerate it with the commands above.
- **Commits**: imperative subject ≤ 72 chars. Reference the issue in the body when there is one (e.g. `Fixes #51`).

## Security
Sticker files come from other users, so treat every input as hostile.
- Never weaken `StickerLimits` defaults or libvpx's `--size-limit` without an ADR.
- Any new parser or decoder path needs a fuzz target in the same PR.
- Host tests run under ASan/UBSan. A sanitizer finding blocks merge.

## Native libraries
- Versions and sha256s live only in `third_party/versions.lock` (shipped libraries) and `third_party/test-deps.lock` (test-only tools, never linked into the plugin; [ADR 0007](docs/decisions/0007-test-only-pins.md)). Bump shipped libraries via a PR that reruns the prebuilt workflow.
- The release tag `deps-<hash>` covers the `versions.lock` rows and every file in `third_party/build/`, so changing either gets a fresh release. `force` on the Prebuilts workflow replaces an existing one.
- Never commit binaries. `third_party/prebuilt/` is gitignored and filled by `tool/fetch_prebuilts.dart`.
- Android `.so` files must be 16 KB page aligned. Check with `llvm-readelf -l <so> | grep LOAD`, where alignment must be `0x4000`.

## Devices
- Prefer the Android emulator (API 24 and the latest) and the latest iOS Simulator. No iOS 15 simulator runtime is available, so skip iOS 15.
- Work that needs a **real device** (performance budgets, benchmarks such as #69) must say which device was used. If you have no device, stop and ask; don't substitute an emulator silently.
