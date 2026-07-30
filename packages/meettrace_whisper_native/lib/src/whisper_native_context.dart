// Copyright (c) 2026 MeetTrace contributors.
// SPDX-License-Identifier: MIT

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'third_party/meettrace_whisper.g.dart' as native;

final class WhisperNativeException implements Exception {
  const WhisperNativeException(this.code);

  final String code;

  @override
  String toString() => 'WhisperNativeException($code)';
}

final class WhisperNativeSegment {
  const WhisperNativeSegment({
    required this.text,
    required this.startMs,
    required this.endMs,
  });

  final String text;
  final int startMs;
  final int endMs;
}

final class WhisperNativeResult {
  WhisperNativeResult(List<WhisperNativeSegment> segments)
    : segments = List.unmodifiable(segments);

  final List<WhisperNativeSegment> segments;

  String get text => segments
      .map((segment) => segment.text.trim())
      .where((text) => text.isNotEmpty)
      .join(' ')
      .trim();
}

final class WhisperNativeContext {
  WhisperNativeContext._(this._handle);

  factory WhisperNativeContext.open({
    required String modelPath,
    int threadCount = 2,
    String language = 'auto',
  }) {
    if (modelPath.trim().isEmpty) {
      throw ArgumentError.value(modelPath, 'modelPath', '不能为空');
    }
    if (threadCount <= 0) {
      throw ArgumentError.value(threadCount, 'threadCount', '必须大于 0');
    }
    if (language.trim().isEmpty) {
      throw ArgumentError.value(language, 'language', '不能为空');
    }

    return using((arena) {
      final path = modelPath.toNativeUtf8(allocator: arena).cast<Char>();
      final languagePointer = language
          .toNativeUtf8(allocator: arena)
          .cast<Char>();
      final handle = native.mt_whisper_create(
        path,
        threadCount,
        languagePointer,
      );
      if (handle == nullptr) {
        throw const WhisperNativeException('native.context_create_failed');
      }
      return WhisperNativeContext._(handle);
    });
  }

  Pointer<native.mt_whisper_context> _handle;

  bool get isDisposed => _handle == nullptr;

  int get address {
    _throwIfDisposed();
    return _handle.address;
  }

  static String get runtimeVersion =>
      native.mt_whisper_runtime_version().cast<Utf8>().toDartString();

  WhisperNativeResult transcribe(Float32List samples) {
    _throwIfDisposed();
    if (samples.isEmpty) {
      throw ArgumentError.value(samples, 'samples', '不能为空');
    }

    return using((arena) {
      final nativeSamples = arena<Float>(samples.length);
      nativeSamples.asTypedList(samples.length).setAll(0, samples);
      final status = native.mt_whisper_transcribe(
        _handle,
        nativeSamples,
        samples.length,
      );
      if (status != 0) {
        final message = native
            .mt_whisper_last_error(_handle)
            .cast<Utf8>()
            .toDartString();
        throw WhisperNativeException(
          message.isEmpty ? 'native.transcribe_failed.$status' : message,
        );
      }

      final count = native.mt_whisper_segment_count(_handle);
      final segments = <WhisperNativeSegment>[];
      for (var index = 0; index < count; index++) {
        segments.add(
          WhisperNativeSegment(
            text: native
                .mt_whisper_segment_text(_handle, index)
                .cast<Utf8>()
                .toDartString(),
            startMs: native.mt_whisper_segment_start_ms(_handle, index),
            endMs: native.mt_whisper_segment_end_ms(_handle, index),
          ),
        );
      }
      return WhisperNativeResult(segments);
    });
  }

  void cancel() {
    if (!isDisposed) {
      native.mt_whisper_cancel(_handle);
    }
  }

  static void cancelAddress(int address) {
    if (address <= 0) {
      return;
    }
    native.mt_whisper_cancel(
      Pointer<native.mt_whisper_context>.fromAddress(address),
    );
  }

  void dispose() {
    if (isDisposed) {
      return;
    }
    native.mt_whisper_destroy(_handle);
    _handle = nullptr;
  }

  void _throwIfDisposed() {
    if (isDisposed) {
      throw StateError('Whisper native context 已释放');
    }
  }
}
