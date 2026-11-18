import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'gen/wt_bindings.g.dart';
import 'sticker_info.dart';

/// Loads the native core and checks its ABI version.
///
/// - Android: `libanimated_stickers.so`, built by android/CMakeLists.txt.
/// - iOS: the core is linked into the app, so its symbols are in the process.
/// - Elsewhere (host tests only): the path in `ANIMATED_STICKERS_LIB`, built by
///   tool/build_host_ffi_lib.sh.
///
/// Each isolate that calls this gets its own [WtBindings]; the library itself
/// is loaded once per process.
WtBindings loadBindings() {
  final DynamicLibrary lib;
  if (Platform.isAndroid) {
    lib = DynamicLibrary.open('libanimated_stickers.so');
  } else if (Platform.isIOS) {
    lib = DynamicLibrary.process();
  } else {
    final path = Platform.environment['ANIMATED_STICKERS_LIB'];
    if (path == null) {
      throw UnsupportedError(
        'animated_stickers supports Android and iOS. For host tests set '
        'ANIMATED_STICKERS_LIB (see tool/build_host_ffi_lib.sh).',
      );
    }
    lib = DynamicLibrary.open(path);
  }
  final bindings = WtBindings(lib);
  final version = bindings.wt_api_version();
  if (version != WT_API_VERSION) {
    throw StickerException(
      0,
      'WT_API_VERSION_MISMATCH',
      'Dart bindings expect ABI $WT_API_VERSION, native library has $version',
    );
  }
  return bindings;
}

/// The name of a status code, from the core.
String statusName(WtBindings b, int status) =>
    b.wt_status_string(status).cast<Utf8>().toDartString();
