# Architecture decision records

Each file records one decision: its context, the decision itself, and its
consequences. [`../architecture.md`](../architecture.md) describes the
current design and links to these files.

## Writing a new ADR

Write one for any change to the design in `architecture.md`: a library
choice, the API shape, a file format, a limit, or the scope. Name it
`NNNN-title.md` with the next number, and follow the shape of the existing
files: a title line `# NNNN: Title`, **Status** and **Date** bullets, then
`## Context`, `## Decision` and `## Consequences`. Update `architecture.md`
in the same PR.

When a later ADR changes an earlier one, add a note to the earlier ADR's
**Status** line rather than rewriting its text. ADRs 0011, 0013, 0016, 0017
and 0020 show the pattern.

## Reading older ADRs

The ADRs were written while the package was built from a plan, and they
refer to things that have since left `main`:

- **`PLAN.md`** was the design plan. [`../architecture.md`](../architecture.md)
  replaces it.
- **`EXECUTION_PLAN.md`** was the task list. Task IDs such as `T2.2` or
  `T6.1` refer to its tasks, and so do the same IDs in code comments.
- **The spike code** lived in `spikes/` (earlier `example/spike_*`). The
  reports are still in [`../spikes/`](../spikes/).
- **`docs/release-1.0-review.md`** was the 1.0 release review. ADR 0029
  records its decisions, and its follow-ups are issues labelled `follow-up`.

All of these are kept at the
[`archive/plan-and-spikes`](https://github.com/sophie-maney/flutter-animated-stickers/tree/archive/plan-and-spikes)
tag. Read the old names as described in ADRs 0028 and 0029:

- `webm_texture`, `WebmSticker` and `WebmStickers` are now
  `animated_stickers`, `Sticker` and `Stickers`.
- `example/integration_test` is now `example_dev/integration_test`.

## Index

| ADR | Decision |
|---|---|
| [0001](0001-sampled-reference-frames.md) | Sampled, gzipped reference frames |
| [0002](0002-pinning-and-prebuilt-contents.md) | Source pinning and prebuilt contents |
| [0003](0003-release-tag-covers-build-recipe.md) | Release tag covers the build recipe |
| [0004](0004-own-webm-demuxer.md) | Our own minimal WebM demuxer instead of libwebm |
| [0005](0005-no-ui-image-fallback.md) | No Dart `ui.Image` fallback; platform textures everywhere |
| [0006](0006-atlas-for-grids.md) | Atlas mode is the default for grids |
| [0007](0007-test-only-pins.md) | Test-only dependencies are pinned in `third_party/test-deps.lock` |
| [0008](0008-c-abi-shape.md) | Shape of the C ABI (`src/api/wt_api.h`) |
| [0009](0009-ffi-loading-and-native-wiring.md) | How the core reaches Dart, and how each platform builds it |
| [0010](0010-pigeon-api-shape.md) | Shape of the Pigeon API |
| [0011](0011-android-texture-glue.md) | Android texture glue lives in libwebm_texture.so |
| [0012](0012-sticker-widget-visibility-and-playback.md) | `WebmSticker` visibility and playback control |
| [0013](0013-sources-and-fetcher.md) | Sticker sources, content keys and the fetcher |
| [0014](0014-loop-and-seek.md) | Loop control and seeking |
| [0015](0015-frame-cache-file-and-abi.md) | Frame cache file and its C ABI |
| [0016](0016-cache-budget-and-eviction.md) | Cache budget, eviction and glue wiring |
| [0017](0017-scheduler.md) | One scheduler per process, ranked by visible area |
| [0018](0018-device-tiers.md) | Device tiers are decided in Dart from platform signals |
| [0019](0019-slot-allocator.md) | Atlas slot allocator: shelves per bucket, slots never move |
| [0020](0020-atlas-compositor.md) | Atlas compositor: slot frames in RAM, one present per page per tick, a texture per page size |
| [0021](0021-atlas-scope-and-content-rate.md) | `StickerAtlasScope`, page beats and one latch per page per frame |
| [0022](0022-animated-webp.md) | Animated WebP through a canvas-decoder seam |
| [0023](0023-gif.md) | GIF through the canvas-decoder seam |
| [0024](0024-publish-pipeline.md) | Publish pipeline |
| [0025](0025-security-review-hardening.md) | Hardening from the 1.0 security review |
| [0026](0026-cache-file-cap.md) | A cache file may take at most a quarter of the budget |
| [0027](0027-cancellable-frames.md) | Decode before taking the sink, and cancel frames that are waited for |
| [0028](0028-package-rename.md) | Package rename to `animated_stickers` |
| [0029](0029-owner-decisions-for-1-0.md) | The owner's decisions for 1.0 |
| [0030](0030-material-ui-package.md) | `material_ui` for the example apps and tests |
