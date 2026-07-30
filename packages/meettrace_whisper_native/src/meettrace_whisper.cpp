// Copyright (c) 2026 MeetTrace contributors.
// SPDX-License-Identifier: MIT

#include "meettrace_whisper.h"

#include <atomic>
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
  std::string language = "auto";
  std::vector<Segment> segments;
  std::string last_error;
  std::atomic_bool cancelled = false;
};

const char *mt_whisper_runtime_version(void) {
  return whisper_version();
}

mt_whisper_context *mt_whisper_create(
    const char *model_path,
    int32_t thread_count,
    const char *language) {
  if (model_path == nullptr || model_path[0] == '\0' || thread_count <= 0) {
    return nullptr;
  }

  try {
    std::unique_ptr<mt_whisper_context> context(
        new (std::nothrow) mt_whisper_context());
    if (!context) {
      return nullptr;
    }

    context->thread_count = thread_count;
    if (language != nullptr && language[0] != '\0') {
      context->language = language;
    }

    whisper_context_params params = whisper_context_default_params();
    params.use_gpu = false;
    params.flash_attn = false;
    context->runtime = whisper_init_from_file_with_params(model_path, params);
    if (context->runtime == nullptr) {
      return nullptr;
    }
    return context.release();
  } catch (...) {
    return nullptr;
  }
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
    whisper_full_params params =
        whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.n_threads = context->thread_count;
    params.language = context->language.c_str();
    params.translate = false;
    params.no_context = true;
    params.single_segment = false;
    params.no_timestamps = false;
    params.print_realtime = false;
    params.print_progress = false;
    params.print_timestamps = false;
    params.print_special = false;
    params.suppress_blank = true;
    params.abort_callback = should_abort;
    params.abort_callback_user_data = &context->cancelled;

    const int result =
        whisper_full(context->runtime, params, samples, sample_count);
    if (result != 0) {
      context->last_error =
          context->cancelled.load(std::memory_order_relaxed)
              ? "cancelled"
              : "whisper_full_failed";
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
