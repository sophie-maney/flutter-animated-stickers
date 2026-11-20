# 0029: The owner's decisions for 1.0

- **Status:** Accepted (T6.6)
- **Date:** 2026-11-18

## Context

The 1.0 release review ([`docs/release-1.0-review.md`](https://github.com/sophie-maney/flutter-animated-stickers/blob/archive/plan-and-spikes/docs/release-1.0-review.md))
put ten decisions to the owner. Three of them settle where the code had
drifted from `PLAN.md` and [ADR 0013](0013-sources-and-fetcher.md) without a
record, and one changes the repository's layout. This ADR records those,
with the API changes made before the tag.

- `PLAN.md`'s draft API showed `StickerConfig(limits: …, fetcher: …)`.
  Neither field exists: `StickerLimits` only reach `Stickers.probe`, and the
  fetcher is the static `Stickers.fetcher`.
- ADR 0013 said the fetcher would move into `StickerConfig.fetcher` once
  `configure` existed (T3.x). `configure` arrived in T3.2 and the fetcher
  stayed where it was.
- The published `example/` was the demo and test app. Its assets were the
  test corpus (through a symlink) and the integration-test goldens, which
  `.pubignore` leaves out, so the archived example didn't build
  ([#60](https://github.com/sophie-maney/flutter-animated-stickers/issues/60)).

## Decision

**D1: limits stay probe-only.** Playback always uses the core's default
`StickerLimits` (2 MiB, 1024 px, 10 s, 600 frames); `Stickers.probe` takes
other limits to check a file before showing it. Plumbing limits to playback
would mean a Pigeon change, limits in `wt_anim_create_cached`, and limits in
the frame cache key (or a file cached under loose limits replays under
strict ones), and it widens what a hostile file can reach (security S-13).
No app has asked. `StickerConfig.limits` can be added later without
breaking anything ([#50](https://github.com/sophie-maney/flutter-animated-stickers/issues/50)).

**D6: each `configure` call applies the whole config.** A field left out
gets its default again (a 200 MiB budget, `StickerTier.auto`), as the tier
fields always did. The one exception stays: a null `cacheDirectory` keeps
the directory in use, because animations already playing write there.

**D7: the fetcher stays a static setter.** `Stickers.fetcher` is the only
way to register a `StickerFetcher`. Setting it clears the resolver's cached
results, which a `configure` call that resets every field would do on
every call, and a fetcher is set once at startup while `configure` may be
called again to change the tier. A `StickerConfig.fetcher` can still be
added later without breaking anything. This supersedes ADR 0013's
"Registration" line.

**D2: a short published example and an unpublished development app.**

| Folder | What | Published | Android id / iOS bundle id |
|---|---|---|---|
| `example/` | `lib/main.dart` only: a plain `Sticker` per format, a `StickerController` with play, pause and restart, and a 300-cell `StickerAtlasScope` grid. Three stickers copied from the corpus into `assets/`: `vp9_alpha_512.webm`, `anim.webp`, `anim_disposal.gif` (54,337 bytes) | yes | `town.leggy.animatedstickers.sample` |
| `example_dev/` | The former `example/`, unchanged apart from paths: the demo pages, `integration_test/`, the goldens, the `test_assets` symlink to the corpus | no (`.pubignore`) | `town.leggy.animated_stickers.example`, kept |
| `spikes/spike_b`, `spikes/spike_c` | The Spike B and C apps, formerly `example/spike_*`, beside the host spike `spikes/alpha` | no | unchanged |

- pub.dev shows `example/lib/main.dart` on the package's Example tab, so
  that file is what users read, and the published example now builds and
  runs from the archive alone.
- `example_dev/` sits beside `example/` at the same depth, so its relative
  paths (`path: ../`, `test_assets -> ../test_assets`, Gradle's
  `source = "../.."`) are unchanged and the goldens render as before. Its
  Dart package is renamed `animated_stickers_dev`, so two packages in the
  repository don't share a name.
- The sample's ids avoid underscores, which iOS bundle ids don't allow.
- CI builds the published example in the APK and iOS jobs; the integration
  jobs build and test the development app.
- ADRs 0001–0028 and the spike reports keep the old paths
  (`example/integration_test`, `example/spike_b`); read them as
  `example_dev/integration_test` and `spikes/spike_b`.

**API changes before the tag (D3–D5).** `StickerController` is a `base`
class (`Sticker` relies on its private state, so a class that implements it
would fail at runtime). `StickerInfo`, `StickerLimits`, `StickerConfig`,
`StickerCacheStats` and `StickerException` are `final`, so fields can be
added after 1.0, and the first three compare by value. `CacheStats` is
renamed `StickerCacheStats`. `StickerErrorWidgetBuilder` takes a
`StackTrace?`, like Flutter's `ImageErrorWidgetBuilder`: the trace of a Dart
error (a failing fetcher, a missing asset), and null for a status the core
reported. `AssetStickerSource.assetKey` is `@internal`. `StickerCodec`,
`StickerFormat` and `StickerTier` may gain values in minor releases.

**Release job supply chain (D8; items 1–3 of
[#52](https://github.com/sophie-maney/flutter-animated-stickers/issues/52)).**
Every workflow pins its actions by commit SHA, with the release in a
comment, and Dependabot proposes bumps monthly. fvm is installed by
`tool/ci/install_fvm.sh`: a pinned release (4.3.2) from GitHub, checked
against its sha256 before it is unpacked, instead of `curl … | bash` from
`fvm.app`. `release.yml` refuses to build, and so to publish, a tag whose
commit isn't on `main`. Items 4 (the checksum trust anchor) and 5 (ADR
0024's wording) stay open.

## Consequences

- `PLAN.md`'s API sketch and repository layout match the code.
- A sticker over the default limits fails in a `Sticker` even when a probe
  with looser limits accepted it; the docs of `StickerLimits` and
  `Stickers.probe` say so.
- Apps that need a different fetcher per configuration set
  `Stickers.fetcher` again, which drops cached resolutions.
- The published example shows less than the development app. The demo pages
  stay in the repository, where `example_dev/README.md` lists them.
- Bumping fvm in CI means changing the version and both digests in
  `tool/ci/install_fvm.sh`.
