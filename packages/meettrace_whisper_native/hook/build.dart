// Copyright (c) 2026 MeetTrace contributors.
// SPDX-License-Identifier: MIT

import 'package:hooks/hooks.dart';
import 'package:meettrace_whisper_native/src/c_library.dart';

Future<void> main(List<String> arguments) async {
  await build(arguments, buildWhisperLibrary);
}
