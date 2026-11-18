## 1.0.0 - 2026-11-18

First release.

* `Sticker` widget: plays VP9/VP8 WebM with alpha, animated WebP and GIF
  through platform `Texture`s on Android (API 24+) and iOS (15+). Decoding
  runs in a shared C++ core on native worker threads.
* Sources: `StickerSource.asset`, `.file`, `.bytes` and `.network`, the last
  through an app-provided `StickerFetcher` (`Stickers.fetcher`).
* Playback: `autoplay`, `loop`, `StickerController` (`play`, `pause`,
  `seekToFrame`), `placeholder` and `errorBuilder`, which gets the error and
  its stack trace like Flutter's `ImageErrorWidgetBuilder` (null for a
  status the native core reported). Stickers advance only
  while on screen, under an enabled `TickerMode` and in the foreground, and
  widgets showing the same content at the same size share one animation.
* `StickerAtlasScope`: draws many stickers through a few shared atlas
  textures, presented at the content's frame rate.
* Device tiers (`StickerTier`: `auto`, `high`, `mid`, `low`) that follow the
  device class, Low Power Mode and thermal state, with `StickerConfig.maxFps`
  and `maxConcurrent` overrides.
* On-disk frame cache with an LRU budget (`StickerConfig.diskBudgetBytes`,
  200 MiB by default, `cacheDirectory`), `Stickers.cacheStats()`
  (`StickerCacheStats`) and `clearCache()`. Each `Stickers.configure` call
  applies the whole `StickerConfig`.
* `Stickers.probe` reads a sticker's metadata (`StickerInfo`) without
  decoding pixels.
* Hard limits on untrusted input (2 MiB, 1024 px, 10 s, 600 frames);
  violations surface as `StickerException`. `Stickers.probe` can check a
  file against other `StickerLimits`; playback always uses the defaults.
* `StickerController` is a `base` class. `StickerInfo`, `StickerLimits`,
  `StickerConfig`, `StickerCacheStats` and `StickerException` are `final`,
  so fields can be added in minor releases; the first four compare by
  value. `StickerCodec`, `StickerFormat` and `StickerTier` may gain values in
  minor releases, so give a `switch` over them a default case.
* A short runnable example (`example/lib/main.dart`) with three small
  stickers.
