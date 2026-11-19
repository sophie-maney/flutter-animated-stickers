# 0030: `material_ui` for the example apps and tests

- **Status:** Accepted
- **Date:** 2026-11-19

## Context

Flutter 3.50 deprecates `package:flutter/material.dart` (deprecated after
v3.47.0-0.0.pre). Material moved out of the framework into the `material_ui`
package on pub.dev, published by the Flutter team. `fvm flutter analyze`
reports every old import as `deprecated_member_use`, and CI fails on infos.

The plugin's `lib/` never imported Material; only the example apps, the
spikes and one widget test did.

## Decision

Import `package:material_ui/material_ui.dart` instead of
`package:flutter/material.dart` everywhere, and depend on
`material_ui: ^1.11.1`:

| Package | Kind |
|---|---|
| `animated_stickers` (root) | `dev_dependencies` (for `test/sticker_atlas_scope_test.dart`) |
| `example`, `example_dev`, `spikes/spike_b`, `spikes/spike_c` | `dependencies` |

## Consequences

- The published package gains no runtime dependency: `material_ui` is a dev
  dependency of the plugin, so apps using `animated_stickers` don't pull it in.
- `material_ui` needs Flutter 3.47 or newer. That binds only the example apps
  and the tests, not the plugin's own SDK floor (`sdk: ^3.13.4`).
