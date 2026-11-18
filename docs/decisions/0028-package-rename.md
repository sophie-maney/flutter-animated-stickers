# 0028: Package rename to `animated_stickers`

- **Status:** Accepted (T6.6a, a pre-step of T6.6)
- **Date:** 2026-11-18

## Context

`webm_texture` was a working title (the "name TBC" in `AGENTS.md`, the open
question in `PLAN.md`, the follow-up in [ADR 0024](0024-publish-pipeline.md)).
The package is renamed before its first pub.dev release, while nothing
depends on the old names. The plugin plays WebM, WebP and GIF stickers, so a
name that says "WebM" and "texture" sells it short.

## Decision

The owner chose these names.

| What | Old | New |
|---|---|---|
| pub package | `webm_texture` | `animated_stickers` |
| Library entry point | `lib/webm_texture.dart` | `lib/animated_stickers.dart` |
| Widget, facade, controller | `WebmSticker`, `WebmStickers`, `WebmStickerController` | `Sticker`, `Stickers`, `StickerController` |
| Android namespace, Kotlin package, Gradle group | `com.example.webm_texture` | `town.leggy.animated_stickers` |
| iOS SwiftPM folder, package, target, product | `ios/webm_texture`, `webm_texture`, `webm-texture` | `ios/animated_stickers`, `animated_stickers`, `animated-stickers` |
| Plugin class | `WebmTexturePlugin` | `AnimatedStickersPlugin` |
| Pigeon APIs | `WebmTextureHostApi`, `WebmTextureEvents` | `StickersHostApi`, `StickersEvents` (channel names `dev.flutter.pigeon.animated_stickers.*`) |
| Native shared library | `libwebm_texture.so`, host `libwebm_texture.dylib` | `libanimated_stickers.so`, `libanimated_stickers.dylib` (CMake target `animated_stickers`, JNI symbols `Java_town_leggy_animated_1stickers_*`) |
| Host-test env var | `WEBM_TEXTURE_LIB` | `ANIMATED_STICKERS_LIB` |
| Frame cache directory under the app's cache dir | `webm_texture` | `animated_stickers` |
| Log tag | `WebmTexture` | `AnimatedStickers` |
| Release archive | `webm_texture.tar.gz` | `animated_stickers.tar.gz` |
| Example app | `webm_texture_example`, `com.example…` | `animated_stickers_example`, application id and bundle id `town.leggy.animated_stickers.example` |

**Namespace.** Flutter plugins are not published to Maven (Gradle builds the
plugin from the app's source tree), so the namespace need not be a domain
the plugin's users own; `town.leggy` is the owner's. The example app's id
uses it too.

**Kept on purpose.**

- `third_party/build/**`, `third_party/versions.lock` and
  `third_party/LICENSES.md`. The `deps-<hash>` release tag hashes them, so
  editing them would force a rebuild of the prebuilts for a name nobody
  sees. The prebuilt artifacts therefore keep their names:
  `WebmTextureDeps.xcframework`, `libwebm_texture_deps.a`,
  `webm_texture_deps-{android,ios}.tar.gz`. The renamed iOS package's
  `binaryTarget` and `Frameworks/` symlink point at the same xcframework.
  Rename them with the next change to `third_party/build/`.
- The C ABI (`wt_*`, `src/api/wt_api.h`) and the internal SwiftPM targets
  `wt_core` and `wt_ios`.
- The GitHub repository name, at first. The owner renamed it afterwards to
  `sophie-maney/flutter-animated-stickers` (GitHub redirects the old URLs);
  `pubspec.yaml`, `fetch_prebuilts.dart` (`defaultRepo`), `release.yml` (the
  publish job's `github.repository` guard, which doesn't follow redirects) and
  ADR 0024's setup steps name the new one.
- ADRs 0001–0027 and the spike reports are history and keep the old names;
  read `WebmSticker` as `Sticker` and so on. `EXECUTION_PLAN.md` carries a
  note to the same effect. The spike apps (`example/spike_b`, `spike_c`,
  ids `dev.webmtexture.*`) are standalone throwaways and are untouched.

**Removed.** The plugin-template leftovers: the `WebmTexture` class, its
platform interface and method channel (`lib/webm_texture_platform_interface.dart`,
`lib/webm_texture_method_channel.dart`), `getPlatformVersion` on Android and
iOS together with the `webm_texture` `MethodChannel`, the template's Kotlin,
Swift and Dart tests, and the `plugin_platform_interface` dependency.

**Example's Xcode project.** `example/ios/Runner.xcodeproj` had a
`PBXFileReference` (`wrapper`, `../../ios/webm_texture`). Xcode treats it as a
local package override named after the folder, so any checkout whose root
folder wasn't named exactly like the package (a clone into
`flutter-webm-texture/`, a pub-cache folder `animated_stickers-1.0.0`, a
worktree) failed with "unable to override package … because its identity …
doesn't match override's identity". The reference and its group entry are
removed rather than retargeted: Flutter's generated plugin package already
links the plugin.

## Consequences

- Apps depending on a pre-release build must change imports and class names;
  nothing was published, so this is a one-off.
- The frame cache directory changes name: files under the old one are
  orphaned on devices that ran a development build, and a development build
  can delete them by hand.
- `PLAN.md` is updated in the same change; the "Still open" name question is
  closed.
