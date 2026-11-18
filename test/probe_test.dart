// Probes the whole corpus through the real FFI path against a host build of
// the core. Needs the shared library, so it skips itself without it:
//
//   tool/build_host_deps.sh && tool/build_host_ffi_lib.sh
//   ANIMATED_STICKERS_LIB=build/ffi/src/libanimated_stickers.dylib fvm flutter test test/probe_test.dart
//
// The same expectations run on devices in example/integration_test/.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:animated_stickers/animated_stickers.dart';

import '../example/integration_test/corpus_expectations.dart';

void main() {
  final lib = Platform.environment['ANIMATED_STICKERS_LIB'];
  final skip = lib == null || !File(lib).existsSync()
      ? 'set ANIMATED_STICKERS_LIB (tool/build_host_ffi_lib.sh)'
      : null;

  final manifest = jsonDecode(
    File('test_assets/manifest.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final entries = (manifest['files'] as List).cast<Map<String, dynamic>>();

  group('probe', () {
    for (final entry in entries) {
      final name = entry['name'] as String;
      test('$name from a file', skip: skip, () {
        return expectProbeMatchesManifest(
          entry,
          () => Stickers.probe(StickerSource.file('test_assets/$name')),
        );
      });
      test('$name from bytes', skip: skip, () {
        final bytes = File('test_assets/$name').readAsBytesSync();
        return expectProbeMatchesManifest(
          entry,
          () => Stickers.probe(StickerSource.bytes(bytes)),
        );
      });
    }

    test('missing file is WT_ERR_IO', skip: skip, () {
      expect(
        Stickers.probe(const StickerSource.file('test_assets/nope.webm')),
        throwsA(
          isA<StickerException>().having((e) => e.name, 'name', 'WT_ERR_IO'),
        ),
      );
    });

    test('empty bytes are rejected, not a crash', skip: skip, () {
      expect(
        Stickers.probe(StickerSource.bytes(Uint8List(0))),
        throwsA(isA<StickerException>()),
      );
    });

    // FFI would store -1 into a uint32_t as 2^32 - 1: no limit at all. Checked
    // before the native library is touched, so this runs without it.
    test('limits that wt_limits can\'t hold are refused', () {
      for (final limits in [
        const StickerLimits(maxDimension: -1),
        const StickerLimits(maxDimension: 0),
        const StickerLimits(maxDimension: 1 << 32),
        const StickerLimits(maxFrames: -600),
        const StickerLimits(maxBytes: -1),
        const StickerLimits(maxDuration: Duration(milliseconds: -1)),
        const StickerLimits(maxDuration: Duration(days: 50)),
      ]) {
        expect(
          Stickers.probe(
            const StickerSource.file('test_assets/vp9_alpha_512.webm'),
            limits: limits,
          ),
          throwsA(isA<RangeError>()),
        );
      }
    });

    test('limits tighten the defaults', skip: skip, () {
      expect(
        Stickers.probe(
          const StickerSource.file('test_assets/vp9_alpha_512.webm'),
          limits: const StickerLimits(maxDimension: 256),
        ),
        throwsA(
          isA<StickerException>().having((e) => e.name, 'name', 'WT_ERR_LIMIT'),
        ),
      );
      expect(
        Stickers.probe(
          const StickerSource.file('test_assets/vp9_alpha_512.webm'),
          limits: const StickerLimits(maxFrames: 10),
        ),
        throwsA(
          isA<StickerException>().having((e) => e.name, 'name', 'WT_ERR_LIMIT'),
        ),
      );
    });
  });
}
