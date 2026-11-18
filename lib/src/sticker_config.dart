import 'package:flutter/foundation.dart';

import 'sticker_tier.dart';

/// Settings for [Stickers.configure]: the frame cache and the device
/// tier.
///
/// Each [Stickers.configure] call applies the whole configuration: a field
/// left out gets its default again, not the value of an earlier call (except
/// [cacheDirectory]; see there). The fetcher for network stickers is set
/// separately, through `Stickers.fetcher`, and safety limits apply only to
/// `Stickers.probe` (see `StickerLimits`).
///
/// Compares by value.
@immutable
final class StickerConfig {
  /// Creates a configuration. Each field left out takes its default.
  const StickerConfig({
    this.cacheDirectory,
    this.diskBudgetBytes = defaultDiskBudgetBytes,
    this.tier = StickerTier.auto,
    this.maxFps,
    this.maxConcurrent,
  }) : assert(diskBudgetBytes >= 0, 'diskBudgetBytes must not be negative'),
       assert(
         maxFps == null || (maxFps >= 1 && maxFps <= 240),
         'maxFps must be between 1 and 240',
       ),
       assert(
         maxConcurrent == null || maxConcurrent >= 0,
         'maxConcurrent must not be negative',
       );

  /// The default for [diskBudgetBytes]: 200 MiB.
  static const int defaultDiskBudgetBytes = 200 << 20;

  /// An absolute path for the frame cache, or null for `animated_stickers`
  /// under the app's cache directory (or, on a later
  /// [Stickers.configure] call, the directory already in use).
  ///
  /// The plugin creates it, and only ever reads, writes and deletes the
  /// `*.wsc` files it made there.
  final String? cacheDirectory;

  /// The most disk the frame cache may use, in bytes. The least recently used
  /// files are deleted to stay within it: at startup and after each write.
  /// One sticker's file may take at most a quarter of it, and never more than
  /// 64 MiB; a sticker whose frames need more plays without a cache file.
  /// Zero keeps nothing on disk.
  final int diskBudgetBytes;

  /// How much work stickers may do. With [StickerTier.auto], the default, the
  /// plugin detects it from the device's memory, cores and performance class,
  /// and lowers it while Low Power Mode (or battery saver) is on or the
  /// device runs hot. Any other value is used as given, and the device's
  /// state no longer changes it.
  final StickerTier tier;

  /// Overrides the tier's frame rate cap (1..240 frames a second), whatever
  /// the tier. Null keeps the tier's own.
  final int? maxFps;

  /// Overrides the tier's limit on stickers that play at once, whatever the
  /// tier; 0 means no limit. Null keeps the tier's own.
  final int? maxConcurrent;

  @override
  bool operator ==(Object other) =>
      other is StickerConfig &&
      other.cacheDirectory == cacheDirectory &&
      other.diskBudgetBytes == diskBudgetBytes &&
      other.tier == tier &&
      other.maxFps == maxFps &&
      other.maxConcurrent == maxConcurrent;

  @override
  int get hashCode =>
      Object.hash(cacheDirectory, diskBudgetBytes, tier, maxFps, maxConcurrent);

  @override
  String toString() =>
      'StickerConfig(cacheDirectory: $cacheDirectory, '
      'diskBudgetBytes: $diskBudgetBytes, tier: ${tier.name}, '
      'maxFps: $maxFps, maxConcurrent: $maxConcurrent)';
}

/// Throws a [RangeError] for a value [Stickers.configure] must refuse.
///
/// [StickerConfig]'s constructor asserts the same ranges, but release builds
/// drop asserts, and the platform would refuse the scheduler options without
/// a word. Takes the values rather than a [StickerConfig] so tests can pass
/// what only a release build could construct.
void checkStickerConfigValues({
  required int diskBudgetBytes,
  required int? maxFps,
  required int? maxConcurrent,
}) {
  RangeError.checkNotNegative(diskBudgetBytes, 'diskBudgetBytes');
  if (maxFps != null) {
    RangeError.checkValueInInterval(maxFps, 1, 240, 'maxFps');
  }
  if (maxConcurrent != null) {
    RangeError.checkValueInInterval(
      maxConcurrent,
      0,
      0x7fffffff,
      'maxConcurrent',
    );
  }
}
