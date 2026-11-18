# animated_stickers_dev

The development app of the `animated_stickers` plugin: demo pages, and the
integration tests and screenshot goldens in `integration_test/` (see the
Integration tests row in `AGENTS.md`). It isn't published; the package's
short example is in `../example`. Run it with `fvm flutter run` from this
directory of a clone of the repository: the stickers come from the test
corpus through the `test_assets/` symlink.

| Page | What it shows |
|---|---|
| Chat | Stickers mixed with text bubbles, in a list where off-screen stickers pause |
| Checkerboard | Alpha correctness over a checker pattern; toggles dark checks and play/pause |
| Stress | 200 stickers in a grid, in a `StickerAtlasScope` or standalone (the layers button), with the active count; the "own" switch gives each cell its own animation |
| Probe | `Stickers.probe` metadata for every corpus file, including the rejected ones |
| Textures (dev) | The raw platform texture glue (T2.2, T2.3) |
| Atlas (dev) | 64 stickers through atlas page textures (T4.2) |
| Visibility (dev) | A 200-row list with the active counter (T2.5) |
