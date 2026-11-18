import 'package:flutter/foundation.dart';

/// Container format of a sticker.
///
/// Minor releases may add values (a new container), so a `switch` over it in
/// an app needs a default case.
enum StickerFormat {
  /// Not recognised.
  unknown,

  /// WebM (Matroska) container.
  webm,

  /// Animated WebP.
  webp,

  /// GIF.
  gif,
}

/// Codec of the frames inside a sticker.
///
/// Minor releases may add values (a new codec), so a `switch` over it in an
/// app needs a default case.
enum StickerCodec {
  /// Not recognised.
  unknown,

  /// VP8 video.
  vp8,

  /// VP9 video.
  vp9,

  /// WebP frames (lossy or lossless).
  webp,

  /// GIF (LZW) frames.
  gif,
}

/// What `Stickers.probe` learns about a sticker without decoding pixels.
///
/// Compares by value.
@immutable
final class StickerInfo {
  /// Creates a [StickerInfo].
  const StickerInfo({
    required this.format,
    required this.codec,
    required this.width,
    required this.height,
    required this.frameCount,
    required this.duration,
    required this.fps,
    required this.hasAlpha,
    required this.hasAudio,
    required this.truncated,
  });

  /// Container format.
  final StickerFormat format;

  /// Codec of the video frames.
  final StickerCodec codec;

  /// Source width, in pixels.
  final int width;

  /// Source height, in pixels.
  final int height;

  /// Number of complete frames.
  final int frameCount;

  /// Sum of every frame's duration.
  final Duration duration;

  /// Average frames per second, or 0 when [duration] is zero. Frames may have
  /// different durations.
  final double fps;

  /// Whether the sticker has an alpha channel.
  final bool hasAlpha;

  /// Whether the container also holds audio. It is ignored, never played.
  final bool hasAudio;

  /// The input ended inside a frame. [frameCount] and [duration] cover only
  /// the complete frames before it, which play normally.
  final bool truncated;

  @override
  bool operator ==(Object other) =>
      other is StickerInfo &&
      other.format == format &&
      other.codec == codec &&
      other.width == width &&
      other.height == height &&
      other.frameCount == frameCount &&
      other.duration == duration &&
      other.fps == fps &&
      other.hasAlpha == hasAlpha &&
      other.hasAudio == hasAudio &&
      other.truncated == truncated;

  @override
  int get hashCode => Object.hash(
    format,
    codec,
    width,
    height,
    frameCount,
    duration,
    fps,
    hasAlpha,
    hasAudio,
    truncated,
  );

  @override
  String toString() =>
      'StickerInfo($format/$codec ${width}x$height, $frameCount frames, '
      '${duration.inMilliseconds} ms, ${fps.toStringAsFixed(2)} fps, '
      'alpha: $hasAlpha, audio: $hasAudio, truncated: $truncated)';
}

/// Safety limits applied to untrusted sticker input. A null field keeps the
/// native default (`wt_limits_init_default`): 1024 px, 10 s, 2 MiB, 600 frames.
/// A field must be at least 1 (and [maxDimension], [maxFrames] and
/// [maxDuration] in milliseconds at most 2^32 - 1), or using the limits
/// throws a [RangeError].
///
/// Only [Stickers.probe] takes limits, to check a file against tighter (or
/// looser) bounds before showing it. Playback in a [Sticker] always uses the
/// defaults, so a file over them fails with `WT_ERR_LIMIT` even if it passed a
/// probe with looser limits. Loosening them also gives up the memory bounds
/// they keep (see `docs/security.md` in the repository).
///
/// Compares by value.
@immutable
final class StickerLimits {
  /// Creates limits; any null field keeps its default.
  const StickerLimits({
    this.maxDimension,
    this.maxDuration,
    this.maxBytes,
    this.maxFrames,
  });

  /// Largest accepted width or height, in pixels.
  final int? maxDimension;

  /// Longest accepted total duration.
  final Duration? maxDuration;

  /// Largest accepted input, in bytes.
  final int? maxBytes;

  /// Most frames in one animation.
  final int? maxFrames;

  @override
  bool operator ==(Object other) =>
      other is StickerLimits &&
      other.maxDimension == maxDimension &&
      other.maxDuration == maxDuration &&
      other.maxBytes == maxBytes &&
      other.maxFrames == maxFrames;

  @override
  int get hashCode =>
      Object.hash(maxDimension, maxDuration, maxBytes, maxFrames);

  @override
  String toString() =>
      'StickerLimits(maxDimension: $maxDimension, maxDuration: $maxDuration, '
      'maxBytes: $maxBytes, maxFrames: $maxFrames)';
}

/// Thrown when the native core rejects a sticker or can't be loaded.
final class StickerException implements Exception {
  /// Creates an exception for native status [code] named [name].
  const StickerException(this.code, this.name, [this.message]);

  /// The `wt_status` value (negative), or 0 when the failure isn't a status.
  final int code;

  /// The status name, such as `WT_ERR_LIMIT`.
  final String name;

  /// Extra detail, if any.
  final String? message;

  @override
  String toString() =>
      'StickerException($name${message == null ? '' : ': $message'})';
}
