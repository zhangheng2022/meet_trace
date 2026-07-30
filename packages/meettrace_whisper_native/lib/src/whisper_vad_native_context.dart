// Copyright (c) 2026 MeetTrace contributors.
// SPDX-License-Identifier: MIT

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'third_party/meettrace_whisper.g.dart' as native;
import 'whisper_native_context.dart';

final class WhisperVadNativeSegment {
  const WhisperVadNativeSegment({
    required this.startSample,
    required this.endSample,
  });

  final int startSample;
  final int endSample;
}

final class WhisperVadNativeContext {
  WhisperVadNativeContext._(this._handle);

  factory WhisperVadNativeContext.open({
    required String modelPath,
    int threadCount = 2,
    double threshold = 0.5,
    int minSpeechDurationMs = 250,
    int minSilenceDurationMs = 100,
    double maxSpeechDurationSeconds = 15,
    int speechPadMs = 30,
    double samplesOverlapSeconds = 0.1,
  }) {
    if (modelPath.trim().isEmpty) {
      throw ArgumentError.value(modelPath, 'modelPath', '不能为空');
    }
    if (threadCount <= 0 || threadCount > 32) {
      throw ArgumentError.value(threadCount, 'threadCount', '必须在 1 到 32 之间');
    }

    final runtimeAbiVersion = native.mt_whisper_abi_version();
    if (runtimeAbiVersion != whisperNativeAbiVersion) {
      throw WhisperNativeException(
        'native.abi_version_mismatch.'
        '$whisperNativeAbiVersion.$runtimeAbiVersion',
      );
    }

    return using((arena) {
      final config = arena<native.mt_whisper_vad_config_v1>();
      native.mt_whisper_vad_config_v1_init(config);
      config.ref
        ..thread_count = threadCount
        ..threshold = threshold
        ..min_speech_duration_ms = minSpeechDurationMs
        ..min_silence_duration_ms = minSilenceDurationMs
        ..max_speech_duration_s = maxSpeechDurationSeconds
        ..speech_pad_ms = speechPadMs
        ..samples_overlap = samplesOverlapSeconds;
      final status = native.mt_whisper_vad_validate_config_v1(config);
      if (status != 0) {
        throw WhisperNativeException(_statusMessage(status));
      }

      final path = modelPath.toNativeUtf8(allocator: arena).cast<Char>();
      final output = arena<Pointer<native.mt_whisper_vad_context>>();
      output.value = nullptr;
      final createStatus = native.mt_whisper_vad_create_v1(
        path,
        config,
        output,
      );
      if (createStatus != 0 || output.value == nullptr) {
        throw WhisperNativeException(_statusMessage(createStatus));
      }
      return WhisperVadNativeContext._(output.value);
    });
  }

  Pointer<native.mt_whisper_vad_context> _handle;

  bool get isDisposed => _handle == nullptr;

  int get address {
    _throwIfDisposed();
    return _handle.address;
  }

  List<WhisperVadNativeSegment> segment(Float32List samples) {
    _throwIfDisposed();
    if (samples.isEmpty) {
      return const [];
    }
    return using((arena) {
      final nativeSamples = arena<Float>(samples.length);
      nativeSamples.asTypedList(samples.length).setAll(0, samples);
      final status = native.mt_whisper_vad_segment_samples(
        _handle,
        nativeSamples,
        samples.length,
      );
      if (status != 0) {
        final detail = native
            .mt_whisper_vad_last_error(_handle)
            .cast<Utf8>()
            .toDartString();
        throw WhisperNativeException(
          detail.isEmpty ? _statusMessage(status) : detail,
        );
      }
      return List.unmodifiable([
        for (
          var index = 0;
          index < native.mt_whisper_vad_segment_count(_handle);
          index++
        )
          WhisperVadNativeSegment(
            startSample: native.mt_whisper_vad_segment_start_sample(
              _handle,
              index,
            ),
            endSample: native.mt_whisper_vad_segment_end_sample(_handle, index),
          ),
      ]);
    });
  }

  void reset() {
    _throwIfDisposed();
    native.mt_whisper_vad_reset(_handle);
  }

  void cancel() {
    if (!isDisposed) {
      native.mt_whisper_vad_cancel(_handle);
    }
  }

  static void cancelAddress(int address) {
    if (address > 0) {
      native.mt_whisper_vad_cancel(
        Pointer<native.mt_whisper_vad_context>.fromAddress(address),
      );
    }
  }

  void dispose() {
    if (isDisposed) {
      return;
    }
    native.mt_whisper_vad_destroy(_handle);
    _handle = nullptr;
  }

  void _throwIfDisposed() {
    if (isDisposed) {
      throw StateError('Whisper VAD native context 已释放');
    }
  }
}

String _statusMessage(int status) {
  final message = native
      .mt_whisper_status_message(status)
      .cast<Utf8>()
      .toDartString();
  return message.isEmpty ? 'native.vad_failed.$status' : message;
}
