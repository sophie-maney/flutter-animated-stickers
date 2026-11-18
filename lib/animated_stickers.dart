import 'package:flutter/foundation.dart';

import 'src/probe.dart';
import 'src/sticker_cache.dart';
import 'src/sticker_config.dart';
import 'src/sticker_tier.dart';
import 'src/sticker_info.dart';
import 'src/sticker_runtime.dart';
import 'src/sticker_source.dart';

export 'src/sticker.dart'
    show Sticker, StickerController, StickerErrorWidgetBuilder;
export 'src/sticker_atlas_scope.dart' show StickerAtlasScope;
export 'src/sticker_cache.dart' show CacheStats;
export 'src/sticker_config.dart' show StickerConfig;
export 'src/sticker_info.dart'
    show
        StickerCodec,
        StickerException,
        StickerFormat,
        StickerInfo,
        StickerLimits;
export 'src/sticker_source.dart'
    show
        AssetStickerSource,
        BytesFetchResult,
        BytesStickerSource,
        FileFetchResult,
        FileStickerSource,
        NetworkStickerSource,
        StickerFetchResult,
        StickerFetcher,
        StickerSource;
export 'src/sticker_tier.dart' show StickerTier;

/// Entry points of the plugin that don't need a widget.
abstract final class Stickers {
  /// Handles [StickerSource.network]. Set it once at startup; without one,
  /// network stickers fail with a [StateError] that reaches `errorBuilder`.
  static StickerFetcher? get fetcher =>
      StickerRuntime.instance.resolver.fetcher;
  static set fetcher(StickerFetcher? value) {
    final resolver = StickerRuntime.instance.resolver;
    resolver.fetcher = value;
    resolver.clear();
  }

  /// Applies [config]: where the frame cache lives and how big it may grow,
  /// and which tier stickers run at.
  ///
  /// Call it once at startup, before the first sticker is shown; stickers
  /// created earlier keep caching where they began. The cache is evicted down
  /// to [StickerConfig.diskBudgetBytes] right away. Without it the cache
  /// lives in `animated_stickers` under the app's cache directory with a 200
  /// MiB budget, and the tier is detected ([StickerTier.auto]).
  ///
  /// It can be called again, say to change the tier: running stickers follow
  /// at once. Each call applies the whole [config], so a field left out gets
  /// its default again (a budget of 200 MiB, [StickerTier.auto]), except a
  /// null [StickerConfig.cacheDirectory], which keeps the directory in use.
  ///
  /// Throws a [RangeError], and applies nothing, for a negative
  /// [StickerConfig.diskBudgetBytes], a [StickerConfig.maxFps] outside 1..240
  /// or a negative [StickerConfig.maxConcurrent]. A relative
  /// [StickerConfig.cacheDirectory] fails with a `PlatformException`.
  static Future<void> configure(StickerConfig config) async {
    // StickerConfig asserts these, but release builds drop asserts, and the
    // platform would refuse the scheduler options without a word.
    RangeError.checkNotNegative(config.diskBudgetBytes, 'diskBudgetBytes');
    final maxFps = config.maxFps;
    if (maxFps != null) {
      RangeError.checkValueInInterval(maxFps, 1, 240, 'maxFps');
    }
    final maxConcurrent = config.maxConcurrent;
    if (maxConcurrent != null) {
      RangeError.checkValueInInterval(
        maxConcurrent,
        0,
        0x7fffffff,
        'maxConcurrent',
      );
    }
    final runtime = StickerRuntime.instance;
    await Future.wait([
      runtime.cache.configure(config),
      runtime.tiers.configure(config),
    ]);
  }

  /// The tier stickers run at now: never [StickerTier.auto]. With
  /// [StickerTier.auto] it follows Low Power Mode and thermal state. It reads
  /// [StickerTier.high] until the device has been read, which starts with the
  /// first sticker or [configure].
  ///
  /// Meant for debug overlays and tests.
  static ValueListenable<StickerTier> get debugTier =>
      StickerRuntime.instance.tiers.tier;

  /// How many animations the frame cache holds and how much disk they use.
  ///
  /// Runs on a background isolate, so it is safe to call from the UI isolate.
  static Future<CacheStats> cacheStats() =>
      StickerRuntime.instance.cache.stats();

  /// Deletes every cached frame file. Stickers that are playing carry on, and
  /// write their cache again the next time they play through.
  static Future<void> clearCache() => StickerRuntime.instance.cache.clear();

  /// Reads [source]'s metadata (codec, size, frames, duration, alpha, audio)
  /// without decoding pixels. Assets and network sources are loaded first,
  /// like a [Sticker] loads them (and the result is kept for one that shows
  /// the same source).
  ///
  /// The native work runs on a background isolate, so it is safe to call from
  /// the UI isolate. Input is checked against [limits] (the native defaults
  /// when null; playback always uses the defaults). Throws a
  /// [StickerException] for a sticker the core rejects, such as `WT_ERR_LIMIT`
  /// for one that is too large, and a [RangeError] for [limits] the core
  /// can't hold. Bytes a [StickerFetcher] returns are refused over 2 MiB,
  /// whatever [limits] say.
  static Future<StickerInfo> probe(
    StickerSource source, {
    StickerLimits? limits,
  }) async {
    // Bytes need no loading, and probing doesn't need their content hash,
    // which the resolver would compute on this isolate.
    final resolved = source is BytesStickerSource
        ? source
        : (await StickerRuntime.instance.resolver.resolve(source)).source;
    return probeSticker(resolved, limits: limits);
  }

  /// How many [Sticker]s want to animate right now: playing, on screen,
  /// under an enabled `TickerMode`, with the app in the foreground.
  ///
  /// Meant for debug overlays and tests.
  static ValueListenable<int> get debugActiveCount =>
      StickerRuntime.instance.registry.activeLeases;
}
