import 'package:flutter_test/flutter_test.dart';
import 'package:animated_stickers/animated_stickers.dart';

void main() {
  const info = StickerInfo(
    format: StickerFormat.webm,
    codec: StickerCodec.vp9,
    width: 512,
    height: 512,
    frameCount: 30,
    duration: Duration(seconds: 1),
    fps: 30,
    hasAlpha: true,
    hasAudio: false,
    truncated: false,
  );

  test('StickerInfo compares by value', () {
    const same = StickerInfo(
      format: StickerFormat.webm,
      codec: StickerCodec.vp9,
      width: 512,
      height: 512,
      frameCount: 30,
      duration: Duration(seconds: 1),
      fps: 30,
      hasAlpha: true,
      hasAudio: false,
      truncated: false,
    );
    const other = StickerInfo(
      format: StickerFormat.webm,
      codec: StickerCodec.vp9,
      width: 512,
      height: 512,
      frameCount: 30,
      duration: Duration(seconds: 1),
      fps: 30,
      hasAlpha: true,
      hasAudio: false,
      truncated: true,
    );
    expect(info, same);
    expect(info.hashCode, same.hashCode);
    expect(info, isNot(other));
  });

  test('StickerLimits compares by value', () {
    const limits = StickerLimits(maxBytes: 1024, maxFrames: 10);
    expect(limits, const StickerLimits(maxBytes: 1024, maxFrames: 10));
    expect(
      limits.hashCode,
      const StickerLimits(maxBytes: 1024, maxFrames: 10).hashCode,
    );
    expect(limits, isNot(const StickerLimits(maxBytes: 1024)));
    expect(const StickerLimits(), const StickerLimits());
    expect(limits.toString(), contains('maxBytes: 1024'));
  });
}
