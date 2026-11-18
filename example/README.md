# animated_stickers example

A short, runnable tour of the plugin in [`lib/main.dart`](lib/main.dart):

- **Sticker**: a WebM with alpha, an animated WebP and a GIF, each in a
  plain `Sticker`.
- **Controller**: a non-looping sticker on a `StickerController`, with play,
  pause and restart, and an `errorBuilder`.
- **Atlas**: 300 stickers in a grid under a `StickerAtlasScope`.

The three stickers are in `assets/` (54 KB in all). Run it with
`flutter run` from this folder. Android needs NDK r30 (see the package
README's Requirements); iOS needs Flutter's Swift Package Manager support,
which is on by default.

The repository also has a development app with more demo pages and the
plugin's integration tests, in `example_dev/`. It isn't part of the
published package.
