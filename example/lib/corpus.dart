// The bundled test corpus, shared by the example pages.
import 'package:animated_stickers/animated_stickers.dart';

/// The WebM files the grid pages cycle through. The WebP and GIF files play
/// too; they stay out of this list because the Stress screenshot goldens
/// (integration_test/app_test.dart) are recorded with it.
const playableCorpus = [
  'vp9_alpha_512.webm',
  'vp8_alpha_256.webm',
  'vp9_alpha_vfr.webm',
  'vp9_odd_301x199.webm',
  'vp9_opaque_256.webm',
  'vp9_with_audio.webm',
];

/// Every corpus file for the Probe page: the ones above, a still frame, the
/// other formats, and the ones the core rejects or reports as truncated.
const allCorpus = [
  ...playableCorpus,
  'vp9_single_frame.webm',
  'vp9_2048.webm',
  'truncated.webm',
  'garbage.bin',
  'anim.webp',
  'anim_disposal.gif',
];

/// The corpus asset [name] as a sticker source. `key` is the file name, so
/// identical files share an animation.
StickerSource corpusSource(String name) =>
    StickerSource.asset('test_assets/$name');
