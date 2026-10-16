// Libs
// Platform-specific:
export 'stubs/dart-io.dart' // Non-web
    if (dart.library.io) 'dart:io';

export 'stubs/dart-js-interop.dart' // Web
    if (dart.library.js_interop) 'dart:js_interop';

// Crossplatform:
// Avoid Flutter, minimal Dart by design.
// import 'package:flutter/foundation.dart';
import "modules/utils.dart";
export "modules/utils.dart";

import "modules/webview.dart";
export "modules/webview.dart";

import "modules/fs.dart";
export "modules/fs.dart";

// EOF