# Architecture

How `animated_stickers` works and why it is built this way. The decisions
behind each part are in the [ADRs](decisions/README.md). The threat model is
in [`security.md`](security.md), and the frame cache file format is in
[`cache-format.md`](cache-format.md).

> This file replaces `PLAN.md`, the design plan the package was built from.
> That plan, the task list `EXECUTION_PLAN.md` (whose task IDs, such as
> `T2.2`, still appear in code comments and ADRs) and the spike code are
> kept at the
> [`archive/plan-and-spikes`](https://github.com/sophie-maney/flutter-animated-stickers/tree/archive/plan-and-spikes)
> tag.

A Flutter plugin (Android + iOS) that plays animated stickers inline the way
Telegram does: transparent, looping, and cheap enough for a grid of 60. It
decodes in software through a shared C++ core, caches the frames once, and
renders them into Flutter `Texture`s.

## Decisions

| Topic | Decision |
|---|---|
| Flutter | `fvm`, pinned in `.fvmrc` (3.50.0). The example apps and tests import Material from the `material_ui` package, not `package:flutter/material.dart` ([ADR 0030](decisions/0030-material-ui-package.md)) |
| Scope | **Playback only.** No encoding. `probe()` exposes metadata, and safety limits reject hostile files. No desktop or web, no audio, no Lottie/TGS |
| Formats | VP9 WebM (with alpha), VP8 WebM (with alpha), animated WebP, GIF |
| Density | Inline chat stickers (1–10 on screen) **and** picker grids (30–60+ on screen) |
| Min OS | Android API 24, iOS 15 |
| Sources | `file`, `bytes` and `asset` are built in. `network` goes through a pluggable `StickerFetcher`, registered with the static `Stickers.fetcher` ([ADR 0029](decisions/0029-owner-decisions-for-1-0.md)). Content is keyed by the SHA-1 of the bytes, a caller `key`, or a file path ([ADR 0013](decisions/0013-sources-and-fetcher.md)) |
| Native libs | Built by CI per ABI with pinned versions, then vendored into the published package with sha256 checks |
| Low-end devices | Automatic device tiers, which the app can override |
| Name | Package `animated_stickers`; widget `Sticker`, facade `Stickers`, controller `StickerController`; Android and iOS id `town.leggy.animated_stickers` ([ADR 0028](decisions/0028-package-rename.md)) |
| Distribution | Public on pub.dev, so the API, docs, licenses and binary hosting meet that bar |

## Why libvpx (and not FFmpeg)

| | **libvpx + libyuv** + our own WebM demuxer (chosen) | Minimal FFmpeg |
|---|---|---|
| VP9/VP8 **alpha** | Decode the color stream and the alpha stream (Matroska `BlockAdditions`, `BlockAddID=1`) with two `vpx_codec_ctx_t`, then merge them. Full control. | FFmpeg's built-in `vp9` decoder **drops alpha**. Alpha works only through `libvpx-vp9`, so libvpx is needed anyway. |
| Size per ABI | ~0.8–1.2 MB (decoders only, `--disable-vp9-highbitdepth`) | 2–4 MB, even stripped down |
| License | All BSD/MIT. No relinking obligations. | LGPL: needs dynamic linking or relinkable objects; awkward on iOS |
| Build | `configure` with a per-target triple, NEON intrinsics | Larger `configure` matrix, plus libvpx anyway |
| Other formats | Add libwebp (anim) + giflib (BSD/MIT, small) | One library for everything, but much heavier |

Platform decoders are ruled out. Android's `MediaCodec` VP9 hardware paths
discard the alpha side-stream and vary by vendor. iOS has no public WebM/VP9
decode path. The plugin decodes in software everywhere, as Telegram does.
Telegram's own clients are worth reading for reference: Android
`AnimatedFileDrawable`/`BitmapsCache`, iOS
`AnimationCache`/`MultiAnimationRenderer`.

**Third-party set:** libvpx (VP8/VP9 decoders), libyuv (scaling,
YUV→RGBA, and premultiplying via `I420AlphaToARGB/ABGR(..., attenuate=1)`),
libwebp (`WebPAnimDecoder`), giflib and lz4. WebM demuxing is our own minimal
EBML reader in `src/demux/` ([ADR 0004](decisions/0004-own-webm-demuxer.md)),
not libwebm. libwebm stays in `versions.lock` until the next prebuilts
rebuild drops it
([#59](https://github.com/sophie-maney/flutter-animated-stickers/issues/59)).

### Native library builds

`third_party/build/` builds static libraries for arm64-v8a, armeabi-v7a and
x86_64 (x86 behind a flag), plus an iOS xcframework (device arm64, simulator
arm64 + x86_64). Versions and sha256s are pinned in `third_party/versions.lock`
([ADR 0002](decisions/0002-pinning-and-prebuilt-contents.md)). Test-only tools
are pinned in `third_party/test-deps.lock`
([ADR 0007](decisions/0007-test-only-pins.md)). CI publishes them as a
`deps-<hash>` GitHub release, and the hash covers the build scripts too
([ADR 0003](decisions/0003-release-tag-covers-build-recipe.md)).

- **Android:** NDK r30 for the plugin build
  ([ADR 0009](decisions/0009-ffi-loading-and-native-wiring.md)), with
  `-Wl,-z,max-page-size=16384`, because Play requires 16 KB page alignment.
- **libvpx flags:** `--disable-vp8-encoder --disable-vp9-encoder
  --enable-vp8-decoder --enable-vp9-decoder --disable-vp9-highbitdepth
  --size-limit=1024x1024 --enable-pic`, plus `--enable-runtime-cpu-detect` on
  x86. libvpx has no `--disable-encoders` switch (ADR 0002).

## Overview

```
Dart (lib/)                                   Native core (src/, C++17, shared Android+iOS)
─────────────────────────────────────         ─────────────────────────────────────────────
Sticker widget ──► StickerRegistry        Source sniff ─► Demuxer (WebM | AnimWebP | GIF)
   (TickerMode + viewport visibility)            │                 │
StickerAtlasScope (grid mode)                    │           Decoder (vpx color + vpx alpha | webp | gif)
Stickers.configure / probe                       │                 │
        │  Pigeon (lifecycle, textures)          │       libyuv: scale to target bucket → YUVA420
        │  dart:ffi (probe, cache admin)         │                 │
        ▼                                        ▼                 ▼
Platform glue                                 FrameCache (disk: LZ4 YUVA420 frames, LRU budget)
  Android: Kotlin + JNI                          │
    SurfaceProducer → ANativeWindow              ▼
  iOS: Swift + ObjC++ shim                    Scheduler: 1 clock thread + N workers (N = tier)
    FlutterTexture → CVPixelBuffer(IOSurface)    └─► YUVA→premultiplied RGBA/BGRA straight into
                                                     the platform buffer (ANativeWindow_lock / CVPixelBuffer)
```

## Core concepts

### Animations and size buckets

- **Animation** = (content hash, size bucket). Exactly one
  decoder/cache/texture exists per Animation, refcounted by every widget that
  shows it. Identical stickers share a single `textureId`, and several
  `Texture` widgets can show the same id.
- **Size buckets:** the target size is rounded up to a bucket in physical
  pixels (for example 64/96/128/192/256/384/512). Decoding happens at display
  size, never at 512 when the widget is 80 px.
- **Pixel pipeline:** scale to the bucket → YUVA420 → premultiplied RGBA.
  Scaling happens before premultiplying, on straight alpha. Frames are
  premultiplied: Android writes RGBA_8888 and iOS writes BGRA (libyuv's
  `ABGR` and `ARGB`).

### Two render modes

One widget, two modes:

1. **Standalone** (the default): one platform texture per Animation.
2. **Atlas** (`StickerAtlasScope`, **the mode for grids**, per
   [ADR 0006](decisions/0006-atlas-for-grids.md)): one texture per atlas page.
   - Pages are up to 2048 px wide and only as tall as the rows they need,
     rounded up to 16 px.
   - A full 2048² page costs 32 MB on iOS and 80–112 MB on Android once the
     buffer queue is counted.
   - Slots are 16-px aligned, with a transparent gutter of at least 2 px
     against bilinear bleed.
   - Native code blits each visible Animation into its slot, and each widget
     draws the atlas `Texture` clipped and translated to its slot.

   This avoids 60 platform textures and 60 buffer queues, and matches Telegram
   iOS's multi-animation renderer.

### Scheduler

- **One clock** lives in the core and runs at most at the tier's fps cap (60
  by default; the display rate isn't read), and only while something is due.
- **Each tick** queues the frames that are due to a small worker pool.
- **Late frames are dropped, not queued.** Each Animation has at most one
  frame in flight. A late frame is decoded but never shown, so playback keeps
  the content's timing.
- **Over `maxConcurrent`**, the stickers with the largest on-screen area play
  first, then the most recently started. Dart reports the areas with
  `setPriority`.
- **Buffers** come from the glue through a `wt_sink`
  ([ADR 0017](decisions/0017-scheduler.md)). A worker decodes each frame
  before it takes the sink's buffer, so the buffer (and on Android, the window
  lock) is held only for the YUV→RGBA write.
- **Cancellation:** removing a player, moving it into or out of an atlas, or
  shrinking the pool cancels a frame in flight between frames of its catch-up
  instead of waiting for it ([ADR 0027](decisions/0027-cancellable-frames.md)).

### Frame cache

- **What the file holds:** the first playback decodes and writes
  `<hash>_<w>x<h>_v1.wsc` in the background. The file has a header, per-frame
  durations, an offset table, and **LZ4-compressed YUVA420** frames (2.5 B/px
  before compression, against 4 B/px for RGBA). The format is in
  [`cache-format.md`](cache-format.md).
- **Naming and staleness:** the caller names the file through
  `wt_anim_create_cached`. The header fingerprints the source, so a stale file
  is deleted rather than shown
  ([ADR 0015](decisions/0015-frame-cache-file-and-abi.md)).
- **Later playback:** later loops and later sessions read only from the cache,
  at the cost of an LZ4 decompress and a NEON YUV→RGBA pass per frame.
- **Budget:** the disk budget defaults to 200 MB, with LRU eviction
  ([ADR 0016](decisions/0016-cache-budget-and-eviction.md)).
- **Per-file cap:** one file may take at most a quarter of the budget, and
  never more than 64 MiB. A write past that is abandoned, evicts nothing, and
  isn't tried again in the process; the sticker then decodes on every loop
  ([ADR 0026](decisions/0026-cache-file-cap.md)).
- **RAM:** only 2 frame buffers per active Animation, plus atlas memory.

### Pausing

A widget animates only when `TickerMode` is enabled **and** the widget
intersects the viewport. Off-screen widgets inside `cacheExtent` keep their
first frame ready. Everything pauses when the app is `hidden`, `paused` or
`detached`. `inactive` keeps playing, because the app is still on screen.

### Tiers

Tiers are detected automatically from RAM, CPU cores, Android
`isLowRamDevice` and media performance class, iOS `physicalMemory`, Low Power
Mode, and thermal state (which can change at runtime).

| Tier | Frame rate | Concurrent animations |
|---|---|---|
| high | source fps | unlimited |
| mid | ≤ 30 fps | ≤ 30 |
| low | ≤ 15 fps | ≤ 8; the rest show a static first frame |

Apps override this with `StickerConfig(tier:, maxFps:, maxConcurrent:)`. The
rules (thresholds, how Low Power Mode and thermal state lower the tier, worker
counts) are in [ADR 0018](decisions/0018-device-tiers.md).
`Stickers.debugTier` shows the tier in force.

### Safety

Input from other users is untrusted.

- libvpx is built with `--size-limit=1024x1024`, which only the VP9 decoder
  enforces. Every VP8/VP9 keyframe must also have the track's size, which is
  checked before libvpx sees it
  ([ADR 0025](decisions/0025-security-review-hardening.md)).
- The core enforces limits: maximum dimensions, frame count, duration, file
  size, and total decode budget. The defaults are 2 MiB, 1024 px, 10 s and
  600 frames, and a decode pass may touch at most 160 Mi pixels (600 frames
  at 512 × 512, plus margin). Playback always uses the defaults;
  `Stickers.probe` takes other `StickerLimits` to check a file before showing
  it ([ADR 0029](decisions/0029-owner-decisions-for-1-0.md)).
- Malformed input becomes an error state in the widget, never a crash.
- Demux and decode entry points are fuzzed.
- The threat model, the review findings and how to report a vulnerability are
  in [`security.md`](security.md).

## Components

### Native core (`src/`)

- **Pipeline:** format sniffing; WebM demux (tracks, `AlphaMode`,
  `DefaultDuration`/timestamps, per-frame durations); VP8/VP9 color + alpha
  decode; libyuv scaling to a bucket and YUVA conversion; `probe()`.
- **C ABI:** `src/api/wt_api.h` is the only C ABI
  (`wt_source_create_memory/file`, `wt_probe`, `wt_anim_create/destroy`,
  `wt_anim_seek`, `wt_anim_next_frame(dst, dst_size, stride, format)`,
  `wt_sched_*`, `wt_player_*`, `wt_atlas_*`, …), with `ffigen` bindings. Its
  shape is in [ADR 0008](decisions/0008-c-abi-shape.md).
- **Tests:** GoogleTest host tests run on macOS and Linux CI under
  ASan/UBSan, with a TSan build for the scheduler. They cover golden checksums
  per frame against reference decodes
  ([ADR 0001](decisions/0001-sampled-reference-frames.md)), limit enforcement,
  and corrupt-file handling. libFuzzer targets cover each demuxer and the full
  pipeline; they run briefly on every PR and longer nightly.

### Platform textures and the widget

- **Pigeon API** ([ADR 0010](decisions/0010-pigeon-api-shape.md)):
  `createAnimation(sourceKey, source, bucketW, bucketH) → {animId, textureId}`,
  `setActive`, `dispose`, `deviceSignals`, plus a `streamErrors` event channel.
- **Android:** a `SurfaceProducer` per Animation, with `resetInBackground`,
  passed to native code as an `ANativeWindow` (`RGBA_8888`). The glue handles
  `onSurfaceAvailable`/`onSurfaceCleanup`, because the surface is destroyed in
  the background and has to be recreated. Under Skia, the `manual` lifecycle
  loses the image in the background, so the glue redraws in
  `onSurfaceAvailable` ([ADR 0005](decisions/0005-no-ui-image-fallback.md)).
  The JNI glue is compiled into `libanimated_stickers.so` together with the
  core ([ADR 0011](decisions/0011-android-texture-glue.md)).
- **iOS:** a `FlutterTexture` with a `CVPixelBufferPool` (BGRA, IOSurface,
  Metal-compatible); native code writes into the locked buffer. SwiftPM only,
  no podspec ([ADR 0009](decisions/0009-ffi-loading-and-native-wiring.md)).
- **Dart:**
  - `Sticker` and `StickerRegistry`, which dedupes animations by hash and
    bucket with a refcount.
  - Visibility comes from a custom render object (viewport intersection plus
    `TickerMode`) and is checked after each frame. App lifecycle handling and
    placeholder/error states sit alongside.
  - Controlled stickers, and those with `autoplay: false` or `loop: false`,
    get a private animation
    ([ADR 0012](decisions/0012-sticker-widget-visibility-and-playback.md)).
  - A non-looping sticker holds its last frame, and
    `StickerController.seekToFrame` shows any frame, paused or playing
    ([ADR 0014](decisions/0014-loop-and-seek.md)).

### Cache, scheduler and tiers

- **Cache:** the `.wsc` writer streams frames during the first playback and
  writes to a temp file, then fsyncs and renames. The reader mmaps the file and
  checks bounds. The budget is enforced after each write and at startup, as
  LRU on mtime. The platform glue caches under `<cache dir>/animated_stickers`
  ([ADR 0015](decisions/0015-frame-cache-file-and-abi.md),
  [ADR 0016](decisions/0016-cache-budget-and-eviction.md)).
- **Scheduler:** one per process, in `src/sched/`, behind
  `wt_sched_*`/`wt_player_*` and a `wt_sink` per animation. The visible area
  reaches it through the Pigeon call `setPriority`
  ([ADR 0017](decisions/0017-scheduler.md)). The clock pauses entirely when
  nothing is active.
- **Tiers:** the platforms report `deviceSignals` and push changes on
  `streamDeviceSignals`. Dart picks the tier and sends it through
  `setSchedulerOptions` ([ADR 0018](decisions/0018-device-tiers.md)).

### Atlas mode

- **`StickerAtlasScope`** has a slot allocator (shelf packing per bucket), a
  native compositor that writes into one platform buffer, and clipped
  `Texture` children. It is the documented way to show grids
  ([ADR 0006](decisions/0006-atlas-for-grids.md)).
- **Slots:** the allocator's shelf, reuse and handle rules are in
  [ADR 0019](decisions/0019-slot-allocator.md). Slots never move, and a page
  shrinks only from the bottom. Slots are reclaimed when items scroll out, and
  the atlas grows (a taller page) or splits (a new page) when it is full.
- **Compositor** (`wt_atlas_*`, [ADR 0020](decisions/0020-atlas-compositor.md)):
  - Workers decode into a RAM frame per slot. Once per scheduler tick, each
    page with new frames locks one buffer, rewrites every live slot and its
    gutter, and presents.
  - A page that changes size gets a new texture, because a `Texture`
    stretches its buffer to its box. The old texture is retired until Dart
    releases it.
  - Pigeon calls: `createAtlas`, `attachToAtlas`/`detachFromAtlas` (batched),
    `releaseTextures`, `atlasStats`, `disposeAtlas`.
- **Scope** ([ADR 0021](decisions/0021-atlas-scope-and-content-rate.md)):
  - The scope owns one native atlas. A `Sticker` below it holds an animation
    (and a slot) only while some of it is on screen, keyed by scope in the
    registry.
  - The sticker shows its placeholder until the platform says the slot's
    first frame reached the page texture (`atlasShownTextures`,
    `wt_atlas_shown_page`).
  - Attaches are batched once per frame. Retired textures are released two
    frames after nothing draws them.
- **Content rate:** pages present at the content rate.
  - A page's players show their frames on a shared beat (the page's shortest
    member frame, and at least one clock period), so players started at
    different times don't make a page present on every tick.
  - Slots draw the page texture frozen, and the scope latches each page's
    newest image once per frame, because Android's external texture asks for
    a new image on every un-frozen paint.

### Animated WebP and GIF

- **WebP** ([ADR 0022](decisions/0022-animated-webp.md)): `WebPAnimDecoder`
  produces an RGBA canvas, which is converted into the same YUVA cache path
  as WebM.
  - The `CanvasDecoder` seam is shared with GIF. `RgbaToYuva` uses full-range
    BT.601.
  - Frame durations of ≤ 10 ms play as 100 ms, and a still WebP is one frame.
  - The 1:1 colour bar is WebP-specific (40 dB; measured 40.83), because the
    4:2:0 round trip loses chroma detail that WebM sources never had.
- **GIF** ([ADR 0023](decisions/0023-gif.md)): giflib plus our own frame
  compositing, behind the same `CanvasDecoder` seam.
  - The reader is giflib's sequential low-level one, never `DGifSlurp`.
  - Compositing handles disposal none/background/previous on a transparent
    canvas, the transparency index, local palettes and de-interlacing. Rects
    are clipped to the screen.
  - Delays under 20 ms play as 100 ms, as browsers do.
  - Rect areas count against `max_total_pixels`, and each rect is at most
    `max_dimension`² ([ADR 0025](decisions/0025-security-review-hardening.md)).
  - The 1:1 colour meets the shared bar (50.01 dB measured). At buckets whose
    chroma can't resolve pixel-aligned saturated edges, the colour bar is
    GIF-specific (14 dB; measured 15.26).

### Testing and release

- **Integration tests** live in `example_dev/integration_test/`:
  - golden screenshots of transparent stickers over a checkerboard, and of the
    Stress page in atlas mode, per platform;
  - texture glue, cache, tier, visibility and atlas checks;
  - performance budgets on the iOS simulator (`sched_perf_test.dart`,
    `atlas_perf_test.dart`).

  Real-device numbers are still missing
  ([#69](https://github.com/sophie-maney/flutter-animated-stickers/issues/69)).
- **Examples:** `example/` is the short published example; `example_dev/` is
  the unpublished development app
  ([ADR 0029](decisions/0029-owner-decisions-for-1-0.md)).
- **Release** ([ADR 0024](decisions/0024-publish-pipeline.md)): tag → CI
  builds the prebuilts → `tool/vendor_prebuilts.dart` fetches them, checks
  their sha256 and vendors them into the archive, checking size limits → pana
  → `flutter pub publish --dry-run` → publish via pub.dev OIDC behind an
  approval gate. A scheduled job (`upstream-watch.yml`) watches upstream
  libvpx/libwebp/giflib/libyuv/lz4 releases and OSV advisories, and opens or
  updates an `upstream-watch` issue.

## Spikes

Three spikes settled the risky parts before the core was built. Their reports
are in [`spikes/`](spikes/).

- **A: alpha decode.** `webm_parser` and a minimal EBML reader both delivered
  the alpha `BlockAdditional`, and alpha decoded bit-exact. We chose our own
  reader for size and for robustness against hostile input
  ([report](spikes/A-alpha.md), [ADR 0004](decisions/0004-own-webm-demuxer.md)).
- **B: texture transparency.** Every reachable renderer/producer pairing
  composites premultiplied alpha correctly (±1/255). This was checked on
  emulators and the simulator, which the owner accepted. The `ui.Image`
  fallback was dropped. Skia with the `manual` lifecycle loses the image in
  the background, hence `resetInBackground` and the redraw in
  `onSurfaceAvailable` ([report](spikes/B-texture-alpha.md),
  [ADR 0005](decisions/0005-no-ui-image-fallback.md)).
- **C: density.** The atlas was cheaper on every device and backend. With 60
  stickers, iOS raster p90 was 2.0 ms for the atlas against 5.9 ms for
  textures, and Android API 37 was 1.2 ms against 18.5 ms; textures mode
  couldn't sustain 30 fps updates there. The atlas's cost is memory per page,
  so pages are sized to their content. Again measured on emulators and the
  simulator ([report](spikes/C-density.md),
  [ADR 0006](decisions/0006-atlas-for-grids.md)).

## API at a glance

The dartdoc and the [README](../README.md) are the reference; this is the shape.

```dart
// Each call applies the whole config; limits and the fetcher aren't part of it (ADR 0029).
await Stickers.configure(const StickerConfig(
  cacheDirectory: ..., diskBudgetBytes: 200 << 20,
  tier: StickerTier.auto, maxFps: null, maxConcurrent: null,
));
Stickers.fetcher = myFetcher;  // implements StickerFetcher for StickerSource.network (static, ADR 0029)

Sticker(
  source: StickerSource.file(path) | .bytes(data, key:) | .asset(name) | .network(url),
  width: 120, height: 120, fit: BoxFit.contain,
  autoplay: true, loop: true, controller: ctrl,          // play/pause/seekToFrame (ADR 0014)
  placeholder: ..., errorBuilder: (ctx, err, stackTrace) => ...,
);

StickerAtlasScope(child: GridView.builder(...));         // grid mode
final info = await Stickers.probe(source, limits: StickerLimits(maxBytes: 1 << 20)); // codec, w, h, fps, frames, duration, hasAlpha, hasAudio; limits are probe-only (ADR 0029)
await Stickers.clearCache();
final stats = await Stickers.cacheStats();          // StickerCacheStats: fileCount, totalBytes
Stickers.debugActiveCount;                           // ValueListenable<int>: widgets animating now
```

## Repository layout

```
.fvmrc                     # the pinned Flutter version
pubspec.yaml               # package: animated_stickers (ADR 0028)
lib/                       # public API, registry, visibility, Pigeon + ffigen bindings
pigeons/                   # Pigeon definitions
src/                       # C++ core + CMakeLists.txt (shared by Android CMake and iOS)
  demux/ decode/ convert/ cache/ sched/ atlas/ api/ (C ABI for FFI + glue)
third_party/
  versions.lock            # pinned tags (or commits) + sha256 of every shipped upstream (ADR 0002)
  test-deps.lock           # the same format, for test-only tools such as GoogleTest; never shipped (ADR 0007)
  build/                   # build-android.sh, build-ios.sh (xcframework), license collector
  prebuilt/                # gitignored; filled by tool/fetch_prebuilts.dart from GitHub Releases
android/                   # Kotlin plugin, JNI bridge, CMake → libanimated_stickers.so (core + prebuilt .a; Dart opens it)
ios/animated_stickers/     # Package.swift (SwiftPM only); Sources/animated_stickers = Swift, Sources/wt_ios = ObjC++ shim, Sources/wt_core = symlinks to src/ (ADR 0009)
example/                   # the published example: a short main.dart and 3 small stickers (ADR 0029)
example_dev/               # unpublished development app: demo pages, integration_test/, goldens
test/                      # Dart unit and widget tests
test_assets/               # generated test corpus (tool/gen_corpus.sh) + reference frames
native_test/               # GoogleTest host tests, golden frame checksums
fuzz/                      # libFuzzer targets + seed corpus
tool/                      # fetch/vendor prebuilts, host deps and FFI lib builds, corpus generator, fuzz runner, upstream watch
docs/                      # this file, ADRs (decisions/), spike reports (spikes/), cache-format.md, security.md
.github/workflows/         # CI, prebuilts, nightly fuzzing, release, upstream watch
```

## Key risks

| Risk | Mitigation |
|---|---|
| Android `Texture` alpha/premultiply differs between backends | Spike B found no difference ([ADR 0005](decisions/0005-no-ui-image-fallback.md)). The remaining risk is the surface lifecycle, which the Android glue handles |
| Too many platform textures in grids | Grids use atlas mode ([ADR 0006](decisions/0006-atlas-for-grids.md)) |
| Atlas graphics memory (16 MB per 2048² buffer × queue depth) | Content-sized pages, freed with the scope; memory is reported per page |
| Hostile or malformed user uploads (libvpx has had in-the-wild CVEs) | Size limits, our own limit checks, a demuxer that allocates nothing sized by input (ADR 0004), fuzzing, fast upstream bumps |
| Binary size per ABI | Decoders only; no highbitdepth; `-Oz` + LTO for our core; `vendor_prebuilts.dart` checks the archive size before release |
| CocoaPods is legacy in Flutter | SwiftPM only; no podspec ([ADR 0009](decisions/0009-ffi-loading-and-native-wiring.md)) |
| Cache disk usage | Size buckets, YUVA+LZ4, an LRU budget, `clearCache()` |

## Open questions

Follow-ups are GitHub issues labelled
[`follow-up`](https://github.com/sophie-maney/flutter-animated-stickers/issues?q=is%3Aopen+label%3Afollow-up).
The two longer-term ones:

- Real-device benchmarks
  ([#69](https://github.com/sophie-maney/flutter-animated-stickers/issues/69)).
- Dart build hooks (`code_assets`) as a delivery path for the native library
  ([#70](https://github.com/sophie-maney/flutter-animated-stickers/issues/70)).
