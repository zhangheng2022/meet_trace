// Copyright (c) 2026 MeetTrace contributors.
// SPDX-License-Identifier: MIT

#ifndef MEETTRACE_WHISPER_H_
#define MEETTRACE_WHISPER_H_

#include <stdint.h>

#if defined(_WIN32)
#define MT_WHISPER_API __declspec(dllexport)
#elif defined(__GNUC__)
#define MT_WHISPER_API __attribute__((visibility("default")))
#else
#define MT_WHISPER_API
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct mt_whisper_context mt_whisper_context;

MT_WHISPER_API const char *mt_whisper_runtime_version(void);

MT_WHISPER_API mt_whisper_context *mt_whisper_create(
    const char *model_path,
    int32_t thread_count,
    const char *language);

MT_WHISPER_API int32_t mt_whisper_transcribe(
    mt_whisper_context *context,
    const float *samples,
    int32_t sample_count);

MT_WHISPER_API int32_t mt_whisper_segment_count(
    const mt_whisper_context *context);

MT_WHISPER_API const char *mt_whisper_segment_text(
    const mt_whisper_context *context,
    int32_t segment_index);

MT_WHISPER_API int64_t mt_whisper_segment_start_ms(
    const mt_whisper_context *context,
    int32_t segment_index);

MT_WHISPER_API int64_t mt_whisper_segment_end_ms(
    const mt_whisper_context *context,
    int32_t segment_index);

MT_WHISPER_API const char *mt_whisper_last_error(
    const mt_whisper_context *context);

MT_WHISPER_API void mt_whisper_cancel(mt_whisper_context *context);

MT_WHISPER_API void mt_whisper_destroy(mt_whisper_context *context);

#ifdef __cplusplus
}
#endif

#endif  // MEETTRACE_WHISPER_H_
