// Copyright (c) 2026 MeetTrace contributors.
// SPDX-License-Identifier: MIT

#include "meettrace_whisper.h"

#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstring>
#include <exception>
#include <memory>
#include <new>
#include <string>
#include <utility>
#include <vector>

#include "whisper.h"

namespace {

struct Segment {
  std::string text;
  int64_t start_ms;
  int64_t end_ms;
};

bool should_abort(void *user_data) {
  const auto *cancelled = static_cast<std::atomic_bool *>(user_data);
  return cancelled->load(std::memory_order_relaxed);
}

}  // namespace

struct mt_whisper_context {
  whisper_context *runtime = nullptr;
  int32_t thread_count = 1;
  int32_t decoding_strategy = MT_WHISPER_DECODING_GREEDY;
  int32_t best_of = 5;
  int32_t beam_size = 5;
  bool no_context = true;
  bool suppress_blank = true;
  float temperature = 0.0f;
  float temperature_inc = 0.2f;
  std::string language = "auto";
  std::string initial_prompt;
  std::vector<Segment> segments;
  std::string last_error;
  std::atomic_bool cancelled = false;
};

struct VadSegment {
  int64_t start_sample;
  int64_t end_sample;
};

struct mt_whisper_vad_context {
  whisper_vad_context *runtime = nullptr;
  whisper_vad_params params = whisper_vad_default_params();
  std::vector<VadSegment> segments;
  std::string last_error;
  std::atomic_bool cancelled = false;
};

const char *mt_whisper_runtime_version(void) {
  return whisper_version();
}

uint32_t mt_whisper_abi_version(void) {
  return MT_WHISPER_ABI_VERSION;
}

void mt_whisper_config_v1_init(mt_whisper_config_v1 *config) {
  if (config == nullptr) {
    return;
  }
  std::memset(config, 0, sizeof(*config));
  config->struct_size = sizeof(*config);
  config->abi_version = MT_WHISPER_ABI_VERSION;
  config->thread_count = 2;
  config->decoding_strategy = MT_WHISPER_DECODING_GREEDY;
  config->best_of = 5;
  config->beam_size = 5;
  config->no_context = 1;
  config->suppress_blank = 1;
  config->temperature = 0.0f;
  config->temperature_inc = 0.2f;
  config->language = "auto";
  config->initial_prompt = nullptr;
}

int32_t mt_whisper_validate_config_v1(
    const mt_whisper_config_v1 *config) {
  if (config == nullptr) {
    return MT_WHISPER_STATUS_INVALID_ARGUMENT;
  }
  if (config->struct_size != sizeof(*config)) {
    return MT_WHISPER_STATUS_STRUCT_SIZE_MISMATCH;
  }
  if (config->abi_version != MT_WHISPER_ABI_VERSION) {
    return MT_WHISPER_STATUS_ABI_MISMATCH;
  }
  if (config->decoding_strategy != MT_WHISPER_DECODING_GREEDY &&
      config->decoding_strategy != MT_WHISPER_DECODING_BEAM_SEARCH) {
    return MT_WHISPER_STATUS_UNSUPPORTED_STRATEGY;
  }
  if (config->thread_count <= 0 || config->thread_count > 32 ||
      config->best_of <= 0 || config->best_of > 10 ||
      config->beam_size <= 0 || config->beam_size > 10 ||
      (config->no_context != 0 && config->no_context != 1) ||
      (config->suppress_blank != 0 && config->suppress_blank != 1) ||
      config->temperature < 0.0f || config->temperature > 1.0f ||
      config->temperature_inc < 0.0f || config->temperature_inc > 1.0f ||
      config->language == nullptr || config->language[0] == '\0') {
    return MT_WHISPER_STATUS_CONFIG_OUT_OF_RANGE;
  }
  return MT_WHISPER_STATUS_OK;
}

int32_t mt_whisper_create_v1(
    const char *model_path,
    const mt_whisper_config_v1 *config,
    mt_whisper_context **out_context) {
  if (out_context == nullptr) {
    return MT_WHISPER_STATUS_INVALID_ARGUMENT;
  }
  *out_context = nullptr;
  if (model_path == nullptr || model_path[0] == '\0') {
    return MT_WHISPER_STATUS_INVALID_ARGUMENT;
  }
  const int32_t validation = mt_whisper_validate_config_v1(config);
  if (validation != MT_WHISPER_STATUS_OK) {
    return validation;
  }

  try {
    std::unique_ptr<mt_whisper_context> context(
        new (std::nothrow) mt_whisper_context());
    if (!context) {
      return MT_WHISPER_STATUS_ALLOCATION_FAILED;
    }

    context->thread_count = config->thread_count;
    context->decoding_strategy = config->decoding_strategy;
    context->best_of = config->best_of;
    context->beam_size = config->beam_size;
    context->no_context = config->no_context != 0;
    context->suppress_blank = config->suppress_blank != 0;
    context->temperature = config->temperature;
    context->temperature_inc = config->temperature_inc;
    context->language = config->language;
    if (config->initial_prompt != nullptr) {
      context->initial_prompt = config->initial_prompt;
    }

    whisper_context_params params = whisper_context_default_params();
    params.use_gpu = false;
    params.flash_attn = false;
    context->runtime = whisper_init_from_file_with_params(model_path, params);
    if (context->runtime == nullptr) {
      return MT_WHISPER_STATUS_MODEL_LOAD_FAILED;
    }
    *out_context = context.release();
    return MT_WHISPER_STATUS_OK;
  } catch (const std::bad_alloc &) {
    return MT_WHISPER_STATUS_ALLOCATION_FAILED;
  } catch (...) {
    return MT_WHISPER_STATUS_UNEXPECTED_ERROR;
  }
}

const char *mt_whisper_status_message(int32_t status) {
  switch (status) {
    case MT_WHISPER_STATUS_OK:
      return "ok";
    case MT_WHISPER_STATUS_INVALID_ARGUMENT:
      return "native.invalid_argument";
    case MT_WHISPER_STATUS_ABI_MISMATCH:
      return "native.abi_version_mismatch";
    case MT_WHISPER_STATUS_STRUCT_SIZE_MISMATCH:
      return "native.config_struct_size_mismatch";
    case MT_WHISPER_STATUS_UNSUPPORTED_STRATEGY:
      return "native.unsupported_decoding_strategy";
    case MT_WHISPER_STATUS_CONFIG_OUT_OF_RANGE:
      return "native.config_out_of_range";
    case MT_WHISPER_STATUS_MODEL_LOAD_FAILED:
      return "native.context_create_failed";
    case MT_WHISPER_STATUS_ALLOCATION_FAILED:
      return "native.allocation_failed";
    case MT_WHISPER_STATUS_UNEXPECTED_ERROR:
      return "native.unexpected_error";
    default:
      return "native.unknown_status";
  }
}

mt_whisper_context *mt_whisper_create(
    const char *model_path,
    int32_t thread_count,
    const char *language) {
  mt_whisper_config_v1 config;
  mt_whisper_config_v1_init(&config);
  config.thread_count = thread_count;
  if (language != nullptr && language[0] != '\0') {
    config.language = language;
  }
  mt_whisper_context *context = nullptr;
  return mt_whisper_create_v1(model_path, &config, &context) ==
                 MT_WHISPER_STATUS_OK
             ? context
             : nullptr;
}

int32_t mt_whisper_transcribe(
    mt_whisper_context *context,
    const float *samples,
    int32_t sample_count) {
  if (context == nullptr || context->runtime == nullptr || samples == nullptr ||
      sample_count <= 0) {
    return -1;
  }

  context->segments.clear();
  context->last_error.clear();

  try {
    const whisper_sampling_strategy strategy =
        context->decoding_strategy == MT_WHISPER_DECODING_BEAM_SEARCH
            ? WHISPER_SAMPLING_BEAM_SEARCH
            : WHISPER_SAMPLING_GREEDY;
    whisper_full_params params = whisper_full_default_params(strategy);
    params.n_threads = context->thread_count;
    params.language = context->language.c_str();
    params.translate = false;
    params.no_context = context->no_context;
    params.single_segment = false;
    params.no_timestamps = false;
    params.print_realtime = false;
    params.print_progress = false;
    params.print_timestamps = false;
    params.print_special = false;
    params.suppress_blank = context->suppress_blank;
    params.temperature = context->temperature;
    params.temperature_inc = context->temperature_inc;
    params.greedy.best_of = context->best_of;
    params.beam_search.beam_size = context->beam_size;
    // Keep the whisper.cpp quality baseline. A non-zero audio_ctx shortens the
    // encoder context and is reserved for a separately validated optimization.
    params.audio_ctx = 0;
    params.initial_prompt = context->initial_prompt.empty()
                                ? nullptr
                                : context->initial_prompt.c_str();
    params.abort_callback = should_abort;
    params.abort_callback_user_data = &context->cancelled;

    const int result =
        whisper_full(context->runtime, params, samples, sample_count);
    if (result != 0) {
      context->last_error =
          context->cancelled.load(std::memory_order_relaxed)
              ? "cancelled"
              : "whisper_full_failed:" + std::to_string(result);
      return result;
    }

    const int segment_count = whisper_full_n_segments(context->runtime);
    context->segments.reserve(static_cast<size_t>(segment_count));
    for (int index = 0; index < segment_count; ++index) {
      const char *text = whisper_full_get_segment_text(context->runtime, index);
      context->segments.push_back(Segment{
          text == nullptr ? "" : text,
          whisper_full_get_segment_t0(context->runtime, index) * 10,
          whisper_full_get_segment_t1(context->runtime, index) * 10,
      });
    }
    return 0;
  } catch (const std::exception &error) {
    context->last_error = error.what();
    return -2;
  } catch (...) {
    context->last_error = "unknown_native_error";
    return -3;
  }
}

int32_t mt_whisper_segment_count(const mt_whisper_context *context) {
  return context == nullptr ? 0
                            : static_cast<int32_t>(context->segments.size());
}

const char *mt_whisper_segment_text(
    const mt_whisper_context *context,
    int32_t segment_index) {
  if (context == nullptr || segment_index < 0 ||
      static_cast<size_t>(segment_index) >= context->segments.size()) {
    return "";
  }
  return context->segments[static_cast<size_t>(segment_index)].text.c_str();
}

int64_t mt_whisper_segment_start_ms(
    const mt_whisper_context *context,
    int32_t segment_index) {
  if (context == nullptr || segment_index < 0 ||
      static_cast<size_t>(segment_index) >= context->segments.size()) {
    return 0;
  }
  return context->segments[static_cast<size_t>(segment_index)].start_ms;
}

int64_t mt_whisper_segment_end_ms(
    const mt_whisper_context *context,
    int32_t segment_index) {
  if (context == nullptr || segment_index < 0 ||
      static_cast<size_t>(segment_index) >= context->segments.size()) {
    return 0;
  }
  return context->segments[static_cast<size_t>(segment_index)].end_ms;
}

const char *mt_whisper_last_error(const mt_whisper_context *context) {
  return context == nullptr ? "invalid_context" : context->last_error.c_str();
}

void mt_whisper_cancel(mt_whisper_context *context) {
  if (context != nullptr) {
    context->cancelled.store(true, std::memory_order_relaxed);
  }
}

void mt_whisper_destroy(mt_whisper_context *context) {
  if (context == nullptr) {
    return;
  }
  if (context->runtime != nullptr) {
    whisper_free(context->runtime);
    context->runtime = nullptr;
  }
  delete context;
}

void mt_whisper_vad_config_v1_init(mt_whisper_vad_config_v1 *config) {
  if (config == nullptr) {
    return;
  }
  const whisper_vad_params defaults = whisper_vad_default_params();
  std::memset(config, 0, sizeof(*config));
  config->struct_size = sizeof(*config);
  config->abi_version = MT_WHISPER_ABI_VERSION;
  config->thread_count = 2;
  config->threshold = defaults.threshold;
  config->min_speech_duration_ms = defaults.min_speech_duration_ms;
  config->min_silence_duration_ms = defaults.min_silence_duration_ms;
  config->max_speech_duration_s = defaults.max_speech_duration_s;
  config->speech_pad_ms = defaults.speech_pad_ms;
  config->samples_overlap = defaults.samples_overlap;
}

int32_t mt_whisper_vad_validate_config_v1(
    const mt_whisper_vad_config_v1 *config) {
  if (config == nullptr) {
    return MT_WHISPER_STATUS_INVALID_ARGUMENT;
  }
  if (config->struct_size != sizeof(*config)) {
    return MT_WHISPER_STATUS_STRUCT_SIZE_MISMATCH;
  }
  if (config->abi_version != MT_WHISPER_ABI_VERSION) {
    return MT_WHISPER_STATUS_ABI_MISMATCH;
  }
  if (config->thread_count <= 0 || config->thread_count > 32 ||
      config->threshold <= 0.0f || config->threshold >= 1.0f ||
      config->min_speech_duration_ms < 0 ||
      config->min_speech_duration_ms > 10000 ||
      config->min_silence_duration_ms < 0 ||
      config->min_silence_duration_ms > 10000 ||
      config->max_speech_duration_s <= 0.0f ||
      config->max_speech_duration_s > 3600.0f ||
      config->speech_pad_ms < 0 || config->speech_pad_ms > 5000 ||
      config->samples_overlap < 0.0f ||
      config->samples_overlap > 10.0f) {
    return MT_WHISPER_STATUS_CONFIG_OUT_OF_RANGE;
  }
  return MT_WHISPER_STATUS_OK;
}

int32_t mt_whisper_vad_create_v1(
    const char *model_path,
    const mt_whisper_vad_config_v1 *config,
    mt_whisper_vad_context **out_context) {
  if (out_context == nullptr) {
    return MT_WHISPER_STATUS_INVALID_ARGUMENT;
  }
  *out_context = nullptr;
  if (model_path == nullptr || model_path[0] == '\0') {
    return MT_WHISPER_STATUS_INVALID_ARGUMENT;
  }
  const int32_t validation = mt_whisper_vad_validate_config_v1(config);
  if (validation != MT_WHISPER_STATUS_OK) {
    return validation;
  }

  try {
    std::unique_ptr<mt_whisper_vad_context> context(
        new (std::nothrow) mt_whisper_vad_context());
    if (!context) {
      return MT_WHISPER_STATUS_ALLOCATION_FAILED;
    }
    whisper_vad_context_params runtime_params =
        whisper_vad_default_context_params();
    runtime_params.n_threads = config->thread_count;
    runtime_params.use_gpu = false;
    context->runtime =
        whisper_vad_init_from_file_with_params(model_path, runtime_params);
    if (context->runtime == nullptr) {
      return MT_WHISPER_STATUS_MODEL_LOAD_FAILED;
    }
    context->params.threshold = config->threshold;
    context->params.min_speech_duration_ms =
        config->min_speech_duration_ms;
    context->params.min_silence_duration_ms =
        config->min_silence_duration_ms;
    context->params.max_speech_duration_s =
        config->max_speech_duration_s;
    context->params.speech_pad_ms = config->speech_pad_ms;
    context->params.samples_overlap = config->samples_overlap;
    *out_context = context.release();
    return MT_WHISPER_STATUS_OK;
  } catch (const std::bad_alloc &) {
    return MT_WHISPER_STATUS_ALLOCATION_FAILED;
  } catch (...) {
    return MT_WHISPER_STATUS_UNEXPECTED_ERROR;
  }
}

int32_t mt_whisper_vad_segment_samples(
    mt_whisper_vad_context *context,
    const float *samples,
    int32_t sample_count) {
  if (context == nullptr || context->runtime == nullptr ||
      samples == nullptr || sample_count <= 0) {
    return MT_WHISPER_STATUS_INVALID_ARGUMENT;
  }
  context->segments.clear();
  context->last_error.clear();
  if (context->cancelled.load(std::memory_order_relaxed)) {
    context->last_error = "cancelled";
    return MT_WHISPER_STATUS_UNEXPECTED_ERROR;
  }
  try {
    std::unique_ptr<whisper_vad_segments,
                    decltype(&whisper_vad_free_segments)>
        native_segments(
            whisper_vad_segments_from_samples(
                context->runtime, context->params, samples, sample_count),
            &whisper_vad_free_segments);
    if (!native_segments) {
      context->last_error = "native.vad_segmentation_failed";
      return MT_WHISPER_STATUS_UNEXPECTED_ERROR;
    }
    const int count =
        whisper_vad_segments_n_segments(native_segments.get());
    context->segments.reserve(static_cast<size_t>(count));
    for (int index = 0; index < count; ++index) {
      const int64_t start_sample = std::max<int64_t>(
          0, std::llround(
                 whisper_vad_segments_get_segment_t0(
                     native_segments.get(), index) *
                 16000.0));
      const int64_t end_sample = std::min<int64_t>(
          sample_count,
          std::llround(
              whisper_vad_segments_get_segment_t1(
                  native_segments.get(), index) *
              16000.0));
      if (end_sample > start_sample) {
        context->segments.push_back({start_sample, end_sample});
      }
    }
    return MT_WHISPER_STATUS_OK;
  } catch (const std::bad_alloc &) {
    context->last_error = "native.allocation_failed";
    return MT_WHISPER_STATUS_ALLOCATION_FAILED;
  } catch (const std::exception &error) {
    context->last_error = error.what();
    return MT_WHISPER_STATUS_UNEXPECTED_ERROR;
  } catch (...) {
    context->last_error = "native.unexpected_error";
    return MT_WHISPER_STATUS_UNEXPECTED_ERROR;
  }
}

int32_t mt_whisper_vad_segment_count(
    const mt_whisper_vad_context *context) {
  return context == nullptr
             ? 0
             : static_cast<int32_t>(context->segments.size());
}

int64_t mt_whisper_vad_segment_start_sample(
    const mt_whisper_vad_context *context,
    int32_t segment_index) {
  if (context == nullptr || segment_index < 0 ||
      static_cast<size_t>(segment_index) >= context->segments.size()) {
    return 0;
  }
  return context->segments[static_cast<size_t>(segment_index)].start_sample;
}

int64_t mt_whisper_vad_segment_end_sample(
    const mt_whisper_vad_context *context,
    int32_t segment_index) {
  if (context == nullptr || segment_index < 0 ||
      static_cast<size_t>(segment_index) >= context->segments.size()) {
    return 0;
  }
  return context->segments[static_cast<size_t>(segment_index)].end_sample;
}

const char *mt_whisper_vad_last_error(
    const mt_whisper_vad_context *context) {
  return context == nullptr
             ? "native.invalid_vad_context"
             : context->last_error.c_str();
}

void mt_whisper_vad_reset(mt_whisper_vad_context *context) {
  if (context == nullptr || context->runtime == nullptr) {
    return;
  }
  context->segments.clear();
  context->last_error.clear();
  context->cancelled.store(false, std::memory_order_relaxed);
  whisper_vad_reset_state(context->runtime);
}

void mt_whisper_vad_cancel(mt_whisper_vad_context *context) {
  if (context != nullptr) {
    context->cancelled.store(true, std::memory_order_relaxed);
  }
}

void mt_whisper_vad_destroy(mt_whisper_vad_context *context) {
  if (context == nullptr) {
    return;
  }
  if (context->runtime != nullptr) {
    whisper_vad_free(context->runtime);
    context->runtime = nullptr;
  }
  delete context;
}
