# 1.0.0 release review (T6.6)

- **Date:** 2026-11-18
- **Base:** `task/T6.6b-repo-rename` ([#45](https://github.com/sophie-maney/flutter-animated-stickers/pull/45)), on `main` at c337e44
- **Status:** 🛑 waiting for the owner's sign-off. The owner has decided
  D1–D10 ([below](#decisions-for-the-owner)), and `task/T6.6c-owner-decisions`
  (stacked on this branch) applies them, recorded in
  [ADR 0029](decisions/0029-owner-decisions-for-1-0.md). T6.6 isn't ticked,
  the CHANGELOG still says `(unreleased)`, and nothing is tagged or
  published.

**Bottom line.** No defect blocks 1.0 in the shipped code. One bug would
have broken the release itself: `release.yml` would have failed on the
`v1.0.0` tag at the pana step. That is fixed here, together with the four
timing tests that flake on CI's macOS runners, docs and dead code. What is
left is in three groups:

- **Decisions** ([below](#decisions-for-the-owner)): four of them change the
  public API and would be breaking after 1.0. **Decided** and applied
  ([checks](#acceptance-checks-after-the-decisions)).
- **Repository settings:** private vulnerability reporting was off, and the
  `pub-dev` environment didn't exist. **Done** by the owner.
- **Follow-ups:** 15 issues, none of them blocking.

## What was reviewed

- **Public Dart API and docs.** Everything `lib/animated_stickers.dart`
  exports: names after the rename (ADR 0028), parameters, defaults,
  nullability, class modifiers, value semantics, dartdoc against
  behaviour, and README and CHANGELOG accuracy. The README's snippets were
  compiled in an app.
- **C++ core and C ABI.** Every one of the 39 `wt_api.h` functions was
  traced to its callers in Dart, JNI, Kotlin, ObjC++ and Swift, to check
  that the documented thread affinity holds at every call site. Also
  covered: return codes and ownership docs against `src/api/*.cc`, dead
  code, and host-test and fuzz coverage.
- **Platform glue.** Kotlin, JNI, Swift, ObjC++, `Package.swift`, Gradle and
  the privacy manifest: stale comments, template leftovers, unused Pigeon
  methods, and Android/iOS parity.
- **Tooling and CI.** `tool/`, `third_party/build/` and every workflow, with
  `release.yml` checked against ADR 0024's decisions 1–6.
- **Release readiness.** Package contents (`.pubignore`), the git-dependency
  path built end to end, pana, the publish dry run, and the repository
  settings that `SECURITY.md` and ADR 0024 rely on.

Method: three read-only reviews ran in parallel (Dart API; core and
threading; glue, tooling and CI). I checked every finding against the code
myself before fixing or filing it, and corrected or dropped the ones that
didn't hold.

### Threading

Every `wt_api.h` function was traced to its callers; I checked the trace
myself for player destruction, the atlas calls and `wt_sched_set_options`.
There is no threading bug, and no call site breaks its documented
affinity. The docs had fallen behind ADR 0027 in places, and those are
fixed (see [`45a5d4c`](#fixed-inline)).

| `wt_api.h` functions | Documented | Called from | OK |
|---|---|---|---|
| `wt_api_version`, `wt_status_string`, `wt_limits_init_default` | any | Dart `Isolate.run`; JNI main and workers; `WTPlayer` | ✓ |
| `wt_source_*`, `wt_probe` | background | Dart `Isolate.run`; Android `Dispatchers.IO`; iOS global queue | ✓ |
| `wt_anim_create_cached`, `wt_anim_get_info`, `wt_anim_destroy` | background / any | Android IO, iOS background, and through `wt_player_create`/`destroy` | ✓ |
| `wt_anim_create`, `wt_anim_seek`, `wt_anim_next_frame` | background | host and integration tests only | ✓ |
| `wt_cache_*` | any (budget, file path) / background (stats, evict, clear) | Dart `Isolate.run`; Android IO; iOS utility queue | ✓ |
| `wt_sched_create`, `wt_sched_options_init_default` | any | first use, Android IO or main; iOS `dispatch_once` | ✓ |
| `wt_sched_set_options` | any but the scheduler's own | main on both platforms (a bounded wait, ADR 0027) | ✓ |
| `wt_sched_destroy`, `wt_sched_get_stats` | any but the scheduler's own / any | tests only (the glue keeps the scheduler for the process) | ✓ |
| `wt_player_create` | any | Android IO, iOS background | ✓ |
| `wt_player_destroy` | any but the scheduler's own | Android `Dispatchers.IO`, iOS global queue, after leaving any atlas on main | ✓ (the Kotlin doc said "main thread"; fixed) |
| `wt_player_set_active/set_priority/seek/redraw` | any, never blocks | main on both platforms | ✓ |
| `wt_atlas_*` | any / any but the scheduler's own | main on both platforms | ✓ (`get_page` and `shown_page` may wait for a present's slot copy; documented now) |

## Fixed inline

| Commit | What |
|---|---|
| [`72f7a28`](#flaky-timing-tests) | **De-flaked the timing tests.** They now measure their properties rather than wall-clock rates; details below. |
| `c3a356b` | **Release blocker.** `release.yml` (and `ci.yml`) set `FVM_HOME`, and fvm 4.x prints `Legacy environment variables detected: FVM_HOME` on stdout on every call. `pana --json > pana.json` would have started with that line, so the `v1.0.0` build job would have failed at the pana step. Reproduced locally with fvm 4.3.2. They now use `FVM_CACHE_PATH`, as `prebuilts.yml` has since T0.6. CI also runs `tool/aggregate_licenses.sh --check`. |
| `da662f1` | **Dart behaviour.** `Stickers.configure` throws `RangeError` and applies nothing for out-of-range `maxFps`/`maxConcurrent`/budget. Before, release builds sent them to the platform, which refused them; the error was swallowed and `debugTier` showed a tier that wasn't in force. New test. `StickerAtlasScope.debugAttaches` grew without bound in release builds and is now recorded only outside release. `Stickers.probe` no longer hashes unkeyed bytes on the UI isolate. |
| `da662f1` | **Dart docs.** `StickerLimits` reach only `probe` (security I-13; also in the CHANGELOG). What a second `configure` keeps and resets. When `debugTier` leaves `high`. That `maxPages`/`maxPageHeight` are read once. The fetcher's sharing claim. A compiling atlas example. No `PLAN.md` reference in a public doc. **Dead code:** removed `DeviceSignalsReader` and two unread `StickerLease` getters. |
| `45a5d4c` | **`wt_api.h` docs.** Defined "any thread but the scheduler's own", which six functions used without a definition. `wt_anim_next_frame` leaves `dst` alone on a decode error. `wt_anim_seek` decodes nothing itself. The sink's `error` also reports skip, seek and write failures. Atlas workers write decoded frames into the slot copy. `WT_ERR_UNIMPLEMENTED` is no longer returned, and the header's status paragraph is now a version history. Internal scheduler comments mention cancellation. Removed the unused `Atlas::scheduler()`. `AnimCancelTest` now covers GIF. Bindings regenerated (comments only). |
| `65168d2` | **Glue.** Fixed stale thread docs (`WtNative.nativeDestroy`, `StickerTexture`, `WTPlayer.h`, `surface_player.cc`, `jni_bridge.cc`). The Android `Log.i` line per sticker, surface callback and atlas page is now a debug line, off by default; a 200-sticker grid wrote hundreds of lines into apps' release logcat. Removed the template leftovers: the unused `WT_ERR_LIMIT`, Gradle's test source set and JUnit options (there are no Android unit tests), the template comments in both pubspecs, and `tool/.gitkeep`. |
| `9f749eb` | **README.** Requirements: NDK r30 with the app's `ndkVersion` (ADR 0009), and SwiftPM only on iOS. A **From a git checkout** section: the dependency, where pub keeps the copy, and `tool/fetch_prebuilts.dart` against it (verified end to end, below). The in-place rewrite warning for `StickerSource.file` (S-12). |
| `7572fa5` | **Security doc and example.** `docs/security.md` links its open follow-ups to the new issues. `example/README.md` and `corpus.dart` describe what the example really does and needs. |

Not changed on purpose:
- `Timeline::generation()`, unused but named in the timeline's rules.
- The unused-in-production C ABI entry points (`wt_cache_get_budget`, `wt_anim_create`/`seek`/`next_frame`, `wt_atlas_slot.outer_*`): removing any of them is an ABI change, and all have host tests.
- `flutter: '>=3.3.0'` in `pubspec.yaml`: the Dart constraint `^3.13.4` sets the real floor.

### Flaky timing tests

Four tests fail on CI's macOS runners, on `main` too:
- `AtlasTest.PagePresentsAtTheContentRate`
- `AtlasTest.MixedRatesShareTheFastestBeat`
- `SchedulerTest.PlaysAtTheContentRate`
- `SchedulerTest.ContentFasterThanMaxFpsSkipsFrames`

`AtlasTest.PresentsAtMostOncePerTick` failed there once as well. I pulled
the failure messages from 10 CI runs. All of them are lower bounds measured
against the wall clock, which a loaded runner can't keep. For example, 18
presents where 22 were expected, or the last frame at 84 where 102 was
expected.

| Test | Before | After |
|---|---|---|
| `PagePresentsAtTheContentRate` | presents ≥ 50 % of 30/s; frames drawn ≥ 50 % of 30/s per player | Presents counted against the frames the players drew in the same window: at most 1.25 per frame (without shared beats it is about 1.5), at least 0.5. Content pace = frames drawn **plus frames skipped** ≥ 75 % of 30/s per player. The wall-clock ceiling stays. |
| `MixedRatesShareTheFastestBeat` | presents ≥ 50 % of 30/s | The same, against the 30-fps players' frames; pace over all eight players. |
| `PresentsAtMostOncePerTick` | presents ≥ 50 % of 30/s | Presents ≥ half of the scheduler's ticks that played frames. |
| `PlaysAtTheContentRate`, `ContentFasterThanMaxFpsSkipsFrames` | last frame within ±4 (±15) frames of the content clock, in one window | **By design, a wake more than 100 ms late gives up that time** (the stall rule, ADR 0017), so one stall puts a window behind. The test now measures up to three windows on fresh players, and one must be on the clock. A scheduler that drifts is off in all of them. Every window must also never be **ahead** of the content clock, a new and tighter check, plus the existing order, overlap and count checks. |

Evidence:
- **Reproduced.** Under a plain full-CPU load (16 `yes` processes), old and
  new both passed 20/20, so load alone doesn't reproduce it. Under
  `taskpolicy -c utility` (background QoS) with all 16 cores saturated,
  the **old** tests failed twice, with CI's own messages:
  - first run: `PresentsAtMostOncePerTick`, `PagePresentsAtTheContentRate`
    and `ContentFasterThanMaxFpsSkipsFrames` failed, after 53 passes;
  - second run: `PagePresentsAtTheContentRate` (263 vs 271) and
    `MixedRatesShareTheFastestBeat` (22 vs 23) failed, after 79 passes.
- **Fixed.** Under the same conditions, the **new** tests passed
  `--repeat until-fail:20` for all five tests: twice under ASan + UBSan
  and once under TSan, 100/100 each time.
- **Still strict.** Each of these mutations of `src/sched/` makes at least
  one of the new tests fail:
  - no shared beat for atlas groups (presents rise to 1.5 per frame);
  - half frame durations (frames ahead of the clock);
  - 1.5× frame durations (off the clock in all three windows);
  - no skipping (`frames_skipped` 0, off the clock).

## Known open items

| # | Item | Outcome |
|---|---|---|
| 1 | Flaky timing tests | **Fixed** in `72f7a28` (above). |
| 2 | Archived example can't run | **Fixed** (D2, option C): a short `example/` that builds from the archive; the demo and test app moved to `example_dev/`. Before: **Decision D2**; [#60](https://github.com/sophie-maney/flutter-animated-stickers/issues/60). It is worse than "can't load its demo assets": the archived example **doesn't build**. Checked by unpacking the archive and running `flutter build bundle` in `example/`, which fails with "No file or variants found for asset: test_assets/manifest.json", plus the goldens folders. |
| 3 | `StickerLimits` reach only `probe` | **Decided** (D1, A): probe-only, recorded in ADR 0029. **Docs fixed** in `da662f1` (class doc, `probe` doc, CHANGELOG, security I-13). Whether playback should take limits is an API question: **decision D1**, [#50](https://github.com/sophie-maney/flutter-animated-stickers/issues/50). |
| 4 | `SECURITY.md` and private vulnerability reporting | **Enabled** by the owner. Before: **disabled**: `gh api …/private-vulnerability-reporting` returns `{"enabled":false}`. On the sign-off checklist. |
| 5 | Open follow-ups in `docs/security.md` | Each open one has an issue: S-08 [#46](https://github.com/sophie-maney/flutter-animated-stickers/issues/46), I-2 [#47](https://github.com/sophie-maney/flutter-animated-stickers/issues/47), I-4 [#48](https://github.com/sophie-maney/flutter-animated-stickers/issues/48), I-11 [#49](https://github.com/sophie-maney/flutter-animated-stickers/issues/49), I-13 [#50](https://github.com/sophie-maney/flutter-animated-stickers/issues/50). The rest need none: I-5, I-6, I-7, I-9 and I-12 are accepted, S-12 is mitigated and S-13 is accepted by design. |
| 6 | T3.5 unticked; lz4 1.11.1 available | **Decided** (D9 A, D10 B): sign off without T3.5; bump lz4 after 1.0 with [#59](https://github.com/sophie-maney/flutter-animated-stickers/issues/59). |

## Decisions for the owner

API changes are cheap now and breaking after 1.0, so D3–D5 are worth
settling before the tag. Every option marked "non-breaking" can also land
in 1.0.x.

**All ten are decided**, each as recommended (D2 as option C); the Outcome
column says what changed. [ADR 0029](decisions/0029-owner-decisions-for-1-0.md)
records D1, D2, D6 and D7, and the API and CI changes.

| # | Decision | Options | Recommendation | Outcome |
|---|---|---|---|---|
| D1 | `StickerLimits` for playback ([#50](https://github.com/sophie-maney/flutter-animated-stickers/issues/50)) | **A.** Probe-only, as documented now; `StickerConfig.limits` can be added later (non-breaking). **B.** Plumb limits to playback now: Pigeon `configure`, then `wt_anim_create_cached`. The cache key would then need the limits too. | **A.** No user has asked, and B widens the attack surface (security S-13). | **Decided: A.** No code change; probe-only limits are documented on `StickerLimits`, `StickerConfig`, `Stickers.probe`, the README and ADR 0029. #50 stays open for `StickerConfig.limits` if apps ask. |
| D2 | A runnable published example ([#60](https://github.com/sophie-maney/flutter-animated-stickers/issues/60)) | **A.** Ship 8 demo stickers under `example/assets/`: 6 WebMs, `anim.webp` and `anim_disposal.gif`, 127,074 bytes (+0.12 MiB on a 7.6 MiB archive). Move the "(dev)" pages, two of which import `src/gen`, out of `example/lib`. **B.** Ship as is and document "repository only" (done in `example/README.md`); pub.dev's Example tab then shows a launcher that doesn't build. **C.** A short `example/lib/main.dart` (quick start, controller, atlas grid) with 3 stickers: `vp9_alpha_512.webm` 35,223 + `anim.webp` 18,358 + `anim_disposal.gif` 756 = 54,337 bytes (+0.05 MiB). The current demo and test app moves to an unpublished folder. | **C.** pub.dev renders `example/lib/main.dart` on the Example tab, so a short runnable file there is what users read, and it ships the least. **A** is the cheaper change if the demo app should stay where it is. | **Decided: C.** `example/lib/main.dart` (a `Sticker` per format, a `StickerController`, a 300-cell atlas grid) with the three stickers in `example/assets/`; it builds from the archive alone. The demo and test app is `example_dev/` (unpublished, ids kept); the spike apps are `spikes/spike_b` and `spikes/spike_c`. Closes #60. |
| D3 | Class modifiers and value semantics | `base class StickerController`: `Sticker` reads its private `_stickers`, so `implements StickerController` (a mock, say) crashes at runtime. `final class` for `StickerInfo`, `StickerLimits`, `StickerConfig`, `CacheStats` and `StickerException`, which leaves room to add fields after 1.0. `==`/`hashCode`/`toString` for `StickerInfo`, `StickerLimits` and `StickerConfig` (non-breaking). | **Apply before 1.0.** If `StickerConfig` becomes `final`, the new configure test needs a test-only constructor instead of its subclass. | **Decided, applied.** `base class StickerController`; `final` `StickerInfo`, `StickerLimits`, `StickerConfig`, `StickerCacheStats`, `StickerException`; value equality and `toString` on the first three. The configure range test calls `checkStickerConfigValues`, the check `configure` runs, instead of subclassing. |
| D4 | Error API | **a.** Add a `StackTrace` to `StickerErrorWidgetBuilder`, like `ImageErrorWidgetBuilder` (breaking later). **b.** An enum for error kinds instead of matching `StickerException.name` strings; non-status errors all have `code` 0. **c.** Report failures without an `errorBuilder` through `FlutterError.reportError`, and route native decode errors to the widget ([#51](https://github.com/sophie-maney/flutter-animated-stickers/issues/51), non-breaking). | **a** before 1.0. **b** later as an additive getter, documenting today's names (the C status names) as stable. **c** in 1.0.x. | **Decided: a applied.** `StickerErrorWidgetBuilder` is `(BuildContext context, Object error, StackTrace? stackTrace)`: the Dart stack for fetcher, asset and other Dart errors, null for a native status. b and c stay later (#51). |
| D5 | Names and growth | Rename `CacheStats` to `StickerCacheStats`: the only exported type without the prefix, and a generic name that can clash. Mark `AssetStickerSource.assetKey` `@internal`. Say in the dartdoc that `StickerCodec`, `StickerFormat` and `StickerTier` may gain values in minor releases (exhaustive switches in apps would break). | **All three before 1.0.** Keep `FileFetchResult`/`BytesFetchResult`: they mirror `StickerFetchResult.file`/`.bytes`. | **Decided, applied.** `StickerCacheStats`; `assetKey` is `@internal`; the three enums say minor releases may add values. |
| D6 | A second `configure` call | **A.** Each call applies the whole config, so an omitted budget resets to 200 MiB (documented now). **B.** A nullable `diskBudgetBytes` where null keeps the current budget (breaking later only for code that reads the field). | **A.** It matches how the tier fields already behave. | **Decided: A.** No code change; documented on `StickerConfig`, `Stickers.configure`, the README and ADR 0029. |
| D7 | `Stickers.fetcher` (static) vs `StickerConfig.fetcher` | PLAN.md and ADR 0013 say the fetcher moves into `StickerConfig` once `configure` exists, but it never did, and no ADR records that. **A.** Keep the static setter and write that ADR. **B.** Add `StickerConfig.fetcher` (non-breaking) and keep the setter. | **A.** Folded into [#50](https://github.com/sophie-maney/flutter-animated-stickers/issues/50) with D1. | **Decided: A.** ADR 0029 records the static `Stickers.fetcher` and supersedes ADR 0013's plan; `PLAN.md` updated. |
| D8 | The publish job's supply chain ([#52](https://github.com/sophie-maney/flutter-animated-stickers/issues/52)) | Actions pinned by tag, not SHA. `curl … install.sh \| bash` for fvm, unpinned. No check that the tag is on `main`. `SHA256SUMS` sits on the same mutable release as the archives. | Do items 1–3 of #52 before setting `PUBLISH_TO_PUB_DEV`. The first publish is manual (ADR 0024), so they don't block the tag. | **Decided, items 1–3 applied** in every workflow: actions pinned by SHA (Dependabot bumps them monthly), fvm 4.3.2 via `tool/ci/install_fvm.sh` with a sha256 check, and `release.yml` refuses a tag that isn't on `main`. Items 4–5 of #52 stay open. |
| D9 | T3.5, benchmarks on real devices | **A.** Sign off 1.0 without them. Spikes B and C and T3.3 measured on emulators and the simulator, which the owner accepted, and the README makes no device-specific performance claim. **B.** Block 1.0 on a low-end Android phone and an older iPhone. | **A.** Keep T3.5 open for 1.0.x. | **Decided: A.** Sign off without T3.5; it stays open for 1.0.x. |
| D10 | lz4 1.11.0 → 1.11.1 ([#43](https://github.com/sophie-maney/flutter-animated-stickers/issues/43)) | **A.** Bump before 1.0. That means a `versions.lock` PR, the Prebuilts workflow on CI (a new `deps-<hash>`), and running this review's checks again. **B.** Bump after 1.0, together with [#59](https://github.com/sophie-maney/flutter-animated-stickers/issues/59), which needs a prebuilts rebuild anyway. | **B.** The upstream watch lists no advisory for 1.11.0, and A changes shipped binaries after everything here was tested. | **Decided: B.** Bump lz4 after 1.0 with #59. |

## Issues filed

All are labelled `follow-up`. Before filing, I checked `gh issue list`; the
only issue open was #43 (upstream watch).

| Issue | Area |
|---|---|
| [#46](https://github.com/sophie-maney/flutter-animated-stickers/issues/46) | Cache: a SHA-256 source fingerprint in a v2 `.wsc` header (S-08) |
| [#47](https://github.com/sophie-maney/flutter-animated-stickers/issues/47) | Fuzzing: instrumented third-party libraries (I-2) |
| [#48](https://github.com/sophie-maney/flutter-animated-stickers/issues/48) | Fuzzing: `fuzz_anim_cache`, with prepare/write and cancellation (I-4) |
| [#49](https://github.com/sophie-maney/flutter-animated-stickers/issues/49) | WebP: partially covered canvases show black (I-11) |
| [#50](https://github.com/sophie-maney/flutter-animated-stickers/issues/50) | `StickerLimits` for playback, and the fetcher's place (I-13; D1, D7). **Decided:** A for both (ADR 0029); stays open for `StickerConfig.limits` later. |
| [#51](https://github.com/sophie-maney/flutter-animated-stickers/issues/51) | Decode errors after creation never reach `errorBuilder`; failures are silent (D4c) |
| [#52](https://github.com/sophie-maney/flutter-animated-stickers/issues/52) | Release: the publish job's supply chain (D8). **Items 1–3 done**; 4–5 open. |
| [#53](https://github.com/sophie-maney/flutter-animated-stickers/issues/53) | CI: drop the iOS jobs' `animated_stickers/` checkout path |
| [#54](https://github.com/sophie-maney/flutter-animated-stickers/issues/54) | iOS: stop the event streams on `detachFromEngine`, as Android does |
| [#55](https://github.com/sophie-maney/flutter-animated-stickers/issues/55) | Android: declare `kotlinx.coroutines` (needs an ADR) |
| [#56](https://github.com/sophie-maney/flutter-animated-stickers/issues/56) | Tooling: tests for `vendor_prebuilts.dart`'s dry-run parser |
| [#57](https://github.com/sophie-maney/flutter-animated-stickers/issues/57) | Cache: a test for the directory scan cap |
| [#58](https://github.com/sophie-maney/flutter-animated-stickers/issues/58) | Dart: test gaps (fetcher setter, probe through the facade, atlas options, zero size, unknown codes, `fit`, a second `configure`) |
| [#59](https://github.com/sophie-maney/flutter-animated-stickers/issues/59) | The next prebuilts rebuild: rename the artifacts, drop libwebm, bump lz4 |
| [#60](https://github.com/sophie-maney/flutter-animated-stickers/issues/60) | Example: make the published example runnable (D2). **Done** (option C). |

## Acceptance checks

Everything ran locally on an Apple-silicon Mac (16 cores, macOS 27.2) on
this branch's final code. I didn't wait on CI or dispatch any workflow.
These ran before the owner's decisions, so they name the old paths
(`example/` for what is now `example_dev/`); the
[checks after the decisions](#acceptance-checks-after-the-decisions) cover
the changes.

| Check | Command | Result |
|---|---|---|
| Dart format | `fvm dart format --set-exit-if-changed .` | 67 files, 0 changed |
| C++ format | clang-format 23.1.5 `--dry-run -Werror` (the AGENTS.md command) | clean |
| Analyze | `fvm flutter analyze` (after `pub get` in `example/` and `example/spike_b`) | No issues found |
| Dart tests | `fvm flutter test` | 210 passed, 32 skipped (the FFI-backed ones, run next) |
| FFI-backed Dart tests | `tool/build_host_ffi_lib.sh`, then `ANIMATED_STICKERS_LIB=… fvm flutter test test/probe_test.dart test/sticker_cache_test.dart` | 40 passed |
| API docs | `fvm dart doc` | 0 warnings, 0 errors |
| Licenses | `tool/aggregate_licenses.sh --check` | up to date |
| Host tests, ASan + UBSan | `-DWT_HOST_TESTS=ON -DWT_SANITIZE=ON`, full `ctest` | 344/344 passed, no sanitizer report |
| Host tests, TSan (**full suite**) | `-DWT_HOST_TESTS=ON -DWT_TSAN=ON`, full `ctest` | 343 tests: 342 passed, 1 disabled by design (`SanitizerTest.NotASanitizerBuild`), no data race |
| De-flaked timing tests under load | `ctest -R '<the 5 tests>' --repeat until-fail:20` under `taskpolicy -c utility` with 16 `yes` processes | new: 100/100 under ASan (twice) and under TSan (once). Old, same conditions: 5 failures over two runs (above). Under a plain full-CPU load, both pass 20/20 |
| Fuzz smoke | `tool/fuzz.sh 120` (`/opt/homebrew/opt/llvm/bin/clang++`) | no findings. Runs: `fuzz_sniff` 37.2 M, `fuzz_probe` 11.0 M, `fuzz_webm` 585 k, `fuzz_webp` 116 k, `fuzz_gif` 137 k, `fuzz_wsc` 1.76 M |
| Example, Android | `cd example && fvm flutter build apk --debug` | built |
| Example, iOS | `cd example && fvm flutter build ios --simulator --debug` | built |
| Integration, iOS | `fvm flutter test integration_test/all_test.dart` on an iPhone 18 Pro simulator, iOS 27.2 (the latest runtime) | 26/26 passed |
| Integration, Android latest | same, on `Medium_Phone_API_37.0` (Android 17, API 37) | 26/26 passed |
| Integration, Android API 24 | same, on `SpikeB_API24` (Android 7.0, 440 dpi) | 25/26. The failure is the **checkerboard screenshot golden**, which was recorded at 420 dpi: its 16-px checker cells measure 22 px instead of 21 here, so 36.6 % of pixels differ. The stickers composite the same. Rerun at 420 dpi (`wm density 420`, then reset), **it passes**. A device-profile limit of the golden, not a plugin bug; CI runs API 34. |
| Vendor | `fvm dart run tool/vendor_prebuilts.dart vendor --skip-fetch` | complete; android 14.3 MiB, ios 11.9 MiB (40 MiB limit); 12 symlinks resolve |
| Archive | `fvm dart run tool/vendor_prebuilts.dart archive --out build/release/animated_stickers.tar.gz` | dry run with 0 warnings; 496 files, 7.6 MiB compressed, 27.5 MiB unpacked; nothing from `docs/`, `tool/`, tests, fuzz, spikes or `example/test_assets` |
| Publish dry run | `fvm flutter pub publish --dry-run` | **0 warnings** |
| pana | `fvm dart pub global run pana .` (0.23.19) | **150/160**. The only loss is the repository check (10 points): it reads `pubspec.yaml` from `main`, which still names `flutter-webm-texture` until #45 lands. All other sections are at their maximum, so expect 160/160 once this is on `main`. |
| Git dependency, end to end | an app created with `flutter create`, depending on this commit by git (pub's folder named unlike the package), then `dart <pub copy>/tool/fetch_prebuilts.dart`, analyze with every README snippet, `build ios --simulator` and `build apk` | fetched and verified `deps-3bb8ecd7ff3bfbc2`; analyze clean; iOS built, with all 39 `wt_*` symbols linked; APK built, with `libanimated_stickers.so` for 3 ABIs |
| Release workflow fix | `FVM_HOME=… fvm dart --version` vs `FVM_CACHE_PATH=…` | `FVM_HOME` prints the legacy warning on stdout; `FVM_CACHE_PATH` doesn't |

## Acceptance checks after the decisions

On `task/T6.6c-owner-decisions`'s final code, same Mac, all local.

| Check | Command | Result |
|---|---|---|
| Dart format | `fvm dart format --set-exit-if-changed .` | 69 files, 0 changed |
| C++ format | clang-format 23.1.5 `--dry-run -Werror` | clean (no C++ changes) |
| Analyze | `fvm flutter analyze`, whole repository, after `pub get` in `example/`, `example_dev/`, `spikes/spike_b`, `spikes/spike_c` | No issues found |
| Dart tests | `fvm flutter test` | 214 passed, 32 skipped (the FFI-backed ones) |
| FFI-backed Dart tests | `tool/build_host_ffi_lib.sh`, then `ANIMATED_STICKERS_LIB=… fvm flutter test test/probe_test.dart test/sticker_cache_test.dart` | 40 passed |
| API docs | `fvm dart doc` | 0 warnings, 0 errors |
| Licenses | `tool/aggregate_licenses.sh --check` | up to date |
| Host tests, ASan + UBSan | full `ctest` | 344/344 passed, no sanitizer report |
| Vendor | `vendor_prebuilts.dart vendor --skip-fetch` | complete; android 14.3 MiB, ios 11.9 MiB; every symlink resolves |
| Archive | `vendor_prebuilts.dart archive` | dry run with 0 warnings; 381 files, 7,976,544 bytes (7.6 MiB) compressed, 27.5 MiB unpacked (limits 40 MiB, pub.dev 100 MiB); `example/` 0.1 MiB; nothing from `example_dev/`, `spikes/`, `tool/`, `test/` or `docs/` |
| Published example from the archive | unpacked into a scratch `animated_stickers-1.0.0/`; in its `example/`, with the pinned SDK (`fvm spawn 3.47.9`) and nothing from the repository: `pub get`, `build apk --debug`, `build ios --simulator --debug` | both built. APK: `libanimated_stickers.so` for 3 ABIs and the 3 assets. iOS: 39 `wt_*` symbols linked. Launched on an iOS 27.2 simulator: all three formats play on the Sticker tab and the Atlas grid draws |
| Development app builds | `cd example_dev && fvm flutter build apk --debug` and `build ios --simulator --debug` | both built |
| Integration, iOS | `cd example_dev && fvm flutter test integration_test/all_test.dart` on an iPhone 18 Pro simulator, iOS 27.2 | 26/26 passed, goldens included |
| Integration, Android latest | same, on `Medium_Phone_API_37.0` (Android 17, API 37, 1080×2400, 420 dpi) | 26/26 passed, goldens included |
| Publish dry run | `fvm flutter pub publish --dry-run` (inside `archive`) | 0 warnings |
| pana | `fvm dart pub global run pana .` (0.23.19) | 150/160. The only loss is the repository check (10 points): `main`'s `pubspec.yaml` still names `flutter-webm-texture`. "Package has an example" scores 10/10 |
| Workflows | `actionlint` (all five), `shellcheck tool/ci/install_fvm.sh` | clean |
| fvm installer | `tool/ci/install_fvm.sh` on macOS arm64 (download and unpack only); then with one digit of the digest changed | installs 4.3.2; with the wrong digest it exits 1 before unpacking. The two digests match GitHub's own asset digests |
| Tag-on-main check | the step's commands against this repository | `c337e44` (on `main`) passes; this branch's head (not on `main`) fails |

## Sign-off checklist for 1.0.0

In order:

1. [x] **Decide D1–D10.** All decided ([above](#decisions-for-the-owner));
   the API changes (D3–D5), the example (D2) and items 1–3 of #52 (D8) are
   in `task/T6.6c-owner-decisions`, with `CHANGELOG.md` updated.
2. [x] **Enable private vulnerability reporting.** Done by the owner;
   `SECURITY.md` and `docs/security.md` send reporters there.
3. [x] **Merge** #45, then this PR, then the decisions PR, into `main`. Then
   confirm pana scores 160/160 on `main`: the repository check reads
   `pubspec.yaml` from the default branch. Merged; pana 0.23.19 on `main`
   (`fd037d4`) scores 160/160.
4. [x] **Release PR.** Change `## 1.0.0 (unreleased)` in `CHANGELOG.md` to
   `## 1.0.0 - <date>`: `release.yml` rejects a heading that contains
   "unreleased". In the same PR, tick T6.6 in `EXECUTION_PLAN.md`.
5. [x] **GitHub `pub-dev` environment.** Done by the owner: the owner is the
   required reviewer, and deployments are limited to `v*` tags.
   `PUBLISH_TO_PUB_DEV` stays unset.
6. [ ] **Tag** `v1.0.0` on `main` and push it. `release.yml` checks that the
   tagged commit is on `main`, vendors the prebuilts, runs the dry run and
   pana (160 needed), and uploads the archive. The publish job is skipped
   while the variable is unset.
7. [ ] **First publish by hand** (ADR 0024): unpack
   `animated_stickers.tar.gz` from the run's artifact and run
   `flutter pub publish` there with your own login. Then on pub.dev, go to
   Admin → Automated publishing → GitHub Actions and enter the repository
   `sophie-maney/flutter-animated-stickers`, the tag pattern
   `v{{version}}`, and require the environment `pub-dev`.
8. [ ] **Turn on automated publishing**: set `PUBLISH_TO_PUB_DEV=true`.
   Items 1–3 of #52 (D8), which this was waiting for, are done.
9. [ ] **Upstream watch (T6.5's post-merge check):** dispatch
   `upstream-watch.yml` by hand on `main`. Check that it updates #43 rather
   than opening a second issue, and that its report is correct. It now
   installs fvm through `tool/ci/install_fvm.sh`, so this is also that
   script's first run on CI.
10. [x] **T3.5:** sign off without real-device benchmarks (D9 A). T3.5 stays
    open for 1.0.x.
11. [x] **lz4 1.11.1:** after 1.0, with #59 (D10 B).
