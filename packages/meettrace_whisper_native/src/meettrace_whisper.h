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
typedef struct mt_whisper_vad_context mt_whisper_vad_context;

#define MT_WHISPER_ABI_VERSION 1u

typedef enum mt_whisper_status {
  MT_WHISPER_STATUS_OK = 0,
  MT_WHISPER_STATUS_INVALID_ARGUMENT = -1,
  MT_WHISPER_STATUS_ABI_MISMATCH = -2,
  MT_WHISPER_STATUS_STRUCT_SIZE_MISMATCH = -3,
  MT_WHISPER_STATUS_UNSUPPORTED_STRATEGY = -4,
  MT_WHISPER_STATUS_CONFIG_OUT_OF_RANGE = -5,
  MT_WHISPER_STATUS_MODEL_LOAD_FAILED = -6,
  MT_WHISPER_STATUS_ALLOCATION_FAILED = -7,
  MT_WHISPER_STATUS_UNEXPECTED_ERROR = -8
} mt_whisper_status;

typedef enum mt_whisper_decoding_strategy {
  MT_WHISPER_DECODING_GREEDY = 0,
  MT_WHISPER_DECODING_BEAM_SEARCH = 1
} mt_whisper_decoding_strategy;

typedef struct mt_whisper_config_v1 {
  uint32_t struct_size;
  uint32_t abi_version;
  int32_t thread_count;
  int32_t decoding_strategy;
  int32_t best_of;
  int32_t beam_size;
  int32_t no_context;
  int32_t suppress_blank;
  float temperature;
  float temperature_inc;
  const char *language;
  const char *initial_prompt;
} mt_whisper_config_v1;

typedef struct mt_whisper_vad_config_v1 {
  uint32_t struct_size;
  uint32_t abi_version;
  int32_t thread_count;
  float threshold;
  int32_t min_speech_duration_ms;
  int32_t min_silence_duration_ms;
  float max_speech_duration_s;
  int32_t speech_pad_ms;
  float samples_overlap;
} mt_whisper_vad_config_v1;

MT_WHISPER_API const char *mt_whisper_runtime_version(void);

MT_WHISPER_API uint32_t mt_whisper_abi_version(void);

MT_WHISPER_API void mt_whisper_config_v1_init(
    mt_whisper_config_v1 *config);

MT_WHISPER_API int32_t mt_whisper_validate_config_v1(
    const mt_whisper_config_v1 *config);

MT_WHISPER_API int32_t mt_whisper_create_v1(
    const char *model_path,
    const mt_whisper_config_v1 *config,
    mt_whisper_context **out_context);

MT_WHISPER_API const char *mt_whisper_status_message(int32_t status);

// Deprecated compatibility wrapper. New callers must use mt_whisper_create_v1.
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

MT_WHISPER_API void mt_whisper_vad_config_v1_init(
    mt_whisper_vad_config_v1 *config);

MT_WHISPER_API int32_t mt_whisper_vad_validate_config_v1(
    const mt_whisper_vad_config_v1 *config);

MT_WHISPER_API int32_t mt_whisper_vad_create_v1(
    const char *model_path,
    const mt_whisper_vad_config_v1 *config,
    mt_whisper_vad_context **out_context);

MT_WHISPER_API int32_t mt_whisper_vad_segment_samples(
    mt_whisper_vad_context *context,
    const float *samples,
    int32_t sample_count);

MT_WHISPER_API int32_t mt_whisper_vad_segment_count(
    const mt_whisper_vad_context *context);

MT_WHISPER_API int64_t mt_whisper_vad_segment_start_sample(
    const mt_whisper_vad_context *context,
    int32_t segment_index);

MT_WHISPER_API int64_t mt_whisper_vad_segment_end_sample(
    const mt_whisper_vad_context *context,
    int32_t segment_index);

MT_WHISPER_API const char *mt_whisper_vad_last_error(
    const mt_whisper_vad_context *context);

MT_WHISPER_API void mt_whisper_vad_reset(
    mt_whisper_vad_context *context);

MT_WHISPER_API void mt_whisper_vad_cancel(
    mt_whisper_vad_context *context);

MT_WHISPER_API void mt_whisper_vad_destroy(
    mt_whisper_vad_context *context);

#ifdef __cplusplus
}
#endif

#endif  // MEETTRACE_WHISPER_H_
