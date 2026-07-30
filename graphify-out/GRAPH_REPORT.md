# Graph Report - codex-whisper-cpp-quality-phases-0-4  (2026-07-31)

## Corpus Check
- 485 files · ~717,757 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 9655 nodes · 17991 edges · 520 communities (350 shown, 170 thin omitted)
- Extraction: 88% EXTRACTED · 12% INFERRED · 0% AMBIGUOUS · INFERRED: 2129 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `8891dcce`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- meeting_detail_view_model.dart
- asr_preview_coordinator.dart
- meettrace_dependencies.dart
- meeting_detail_view.dart
- use_cases/evaluate_alpha_release.dart
- dart:io
- win32_window.cpp
- meeting_list_view.dart
- theme.dart
- ggml-cpu/repack.h
- asr_preview_coordinator_test.dart
- reliable_recording_service.dart
- ports/asr_engine.dart
- sqflite_repositories_test.dart
- package:flutter/widgets.dart
- final_transcription_service_test.dart
- downloadable_model_service.dart
- FlutterMacOS
- model_selection_fakes.dart
- ggml_new_tensor
- meeting_detail_view_model_test.dart
- ops.cpp
- meeting_list_previews.dart
- whisper_quality_protocol.dart
- recording_session_view.dart
- generate_summary_test.dart
- ggml_dup_tensor
- fetch_ascend_public_regression.dart
- recording_session_view_model.dart
- android_emulator_meeting_flow_test.dart
- speaker_diarization_coordinator_test.dart
- whisper_quality_metrics.dart
- sqflite_model_installation_repository.dart
- android_whisper_quality_benchmark_test.dart
- run_speaker_diarization.dart
- recording_previews.dart
- generate_synthetic_noise_corpus.dart
- reliable_recording_service_test.dart
- ggml_backend_load_best
- whisper_vad_segmenter.dart
- meeting_list_view_model.dart
- meettrace_flow.dart
- summary_generation.dart
- storage_mappers.dart
- bundled_model_preparation_service.dart
- recording_audio_waveform.dart
- revise_final_transcript.dart
- recording_session_view_test.dart
- recording_ports.dart
- transcript.dart
- meeting.dart
- start_meeting_view_model.dart
- pcm_evidence_playback_service.dart
- start_meeting.dart
- ggml_backend_buffer_t
- model_settings_view.dart
- ggml.c
- my_application.cc
- model_settings_view_model.dart
- ggml_backend_buffer_type_t
- app_swipe_action_row.dart
- x86/quants.c
- whisper_asr_engine_factory_test.dart
- repositories.dart
- meeting_detail_view_test.dart
- package:flutter_test/flutter_test.dart
- data_controls_view_model.dart
- summary.dart
- whisper_vad_context
- android_proc_asr_device_risk_monitor.dart
- whisper.cpp
- asr_preview.dart
- recording_device_readiness_probe_test.dart
- ggml-cpu.cpp
- ggml-backend-reg.cpp
- app_ledger.dart
- _string
- recording_session_view_model_test.dart
- meeting_detail_previews.dart
- pcm_evidence_playback_service_test.dart
- Exception
- vec.h
- ggml_compute_params
- meettrace_whisper.g.dart
- recording.dart
- app_file_layout.dart
- model_manifest.dart
- MeetingRepository
- whisper_vad_model
- meeting_list_view_model_test.dart
- ggml_set_op_params_f32
- ggml-cpu/repack.cpp
- models/speaker_diarization.dart
- run_final_transcription.dart
- ggml_compute_backward
- recording_bootstrap_view.dart
- final_transcription_fakes.dart
- domain_ports_test.dart
- ggml-backend.cpp
- plan_asr_preview_windows.dart
- dart:typed_data
- riscv/quants.c
- ggml-cpu/quants.c
- Codex 实施计划：whisper.cpp 质量强化与双平台交付
- pcm_audio_level_meter.dart
- State
- workflow_states.dart
- whisper_asr_engine.dart
- sqflite_summary_repository.dart
- semantic_date_time.dart
- flutter_foreground_recording_lifecycle.dart
- meettrace_whisper.cpp
- Android + iOS 自适应范围
- loongarch/quants.c
- vector
- package:flutter/services.dart
- generate_summary.dart
- fetch_ascend_public_regression_test.dart
- app_database.dart
- ggml-backend-meta.cpp
- arm/repack.cpp
- sqflite_model_preference_repository.dart
- mt_whisper_vad_context
- MeetTrace Android and iOS Alpha PRD V0.6
- app_status_notice.dart
- ggml-cpu.c
- ggml-impl.h
- processing_task.dart
- ggml-opt.cpp
- Components
- quantize_q5_0
- model_installation.dart
- ggml_is_contiguous
- ggml_compute_forward_rope_flt
- ggml-cpu-impl.h
- cpuid_x86
- whisper_vad_native_context.dart
- recording_pcm_diagnostics.dart
- ggml-alloc.c
- Q: 评估 whisper_ggml 是否适合作为会迹当前本地 ASR 模型或运行时
- vector
- whisper_build_graph_decoder
- whisper_adapter.dart
- ggml_nrows
- Q: sherpa_onnx 替换为 whisper_ggml，给我一个方案
- whisper_state
- DateTime
- app_state_panel.dart
- RecordingAudioWaveform
- Q: whisper_ggml transcribeLive 实时（流媒体）转录如何接入当前项目
- asr/whisper_small_advanced_asr_engine_test.dart
- web/manifest.json
- Q: 读取 whisper_ggml 文档并为 MeetTrace 制定替换 sherpa_onnx 的完整实施方案
- Q: 能否直接调用 ggml-org/whisper.cpp
- ggml_backend_meta_context
- APPLY_STANDARD_SETTINGS
- Q: 正式替换 sherpa-onnx 后，MeetTrace 的 whisper.cpp 双模型 ASR 架构、实时预览、最终转录、模型生命周期与录音隔离如何连接？
- cmp_argsort
- Blocked iOS and Dual-Platform Release
- _
- 增量架构优化
- cmp_top_k
- whisper_context_default_params
- gguf_tensor_info
- Stream
- ggml_tensor
- ime.cpp
- quantize_row_iq4_nl_impl
- x86/repack.cpp
- 真实录音条件预检
- gguf.cpp
- ggml_opt_build
- get_scale_min_k4
- tinyBLAS_Q0_AVX
- tinyBLAS_PPC
- whisper_native_context.dart
- kleidiai.cpp
- whisper_recognizer_profiles.dart
- UI 渐进迁移顺序
- 跨平台用户可见品牌身份
- Windows databaseFactory 未初始化
- 二次确认的永久会议删除
- 录音连续性优先
- apply_unary_op_functor
- ggml_opt_context
- whisper_decoder
- .supports_op
- nrow_block_q5_0
- whisper_vocab
- whisper_vad_segmenter_test.dart
- AppSwipeActionRow
- MeetTraceBootstrap
- AppTimeRuler
- _
- ggml_backend_registry
- models/manifest.json
- whisper_asr_engine_factory.dart
- 语义化本地日期标签
- madd
- mmq.cpp
- Strict Casts Inference and Raw Types
- MainActivity
- AppColors
- Project-local Worktree Layout
- CAS Atomic Final Snapshot Activation
- Android Alpha Device Matrix
- startup_recovery_service.dart
- ggml_backend_sched
- AGENTS.md Contributor Guide Query
- 代码实现驱动的视觉系统规范
- 120ms pressed 颜色混合变体
- connectivity_plus 的 CP936 解码失败
- 项目冗余审计
- 精确锁定 path_provider_android 2.2.23
- Android edge-to-edge 系统栏
- ggml-backend-impl.h
- size
- ime2_kernels.cpp
- whisper_context
- kernels.cpp
- spine_mem_pool_manager
- tinyBLAS_Q0_PPC
- Flutter macOS App Icon
- Flutter macOS App Icon (256×256)
- Flutter macOS App Icon
- Flutter macOS App Icon
- amx.cpp
- Flutter Web App Icon
- Flutter Maskable Web Icon (192×192)
- MeetTrace Web Shell
- Flutter Brand Mark
- Flutter Brand Mark
- Flutter Brand Mark
- sgemm.cpp
- FColorsExtensions
- FStyleExtensions
- Bounded Droppable Preview Queue
- simd-gemm.h
- ggml_kleidiai_context
- Flutter Brand Mark
- Flutter Brand Mark
- Flutter Brand Mark
- Flutter App Icon (40×40)
- Flutter Brand Mark
- Flutter Brand Mark
- Flutter App Icon (60×60 @3x)
- Flutter Brand Mark
- Flutter App Icon (83.5×83.5 @2x)
- iOS Launch Screen Placeholder
- Launch Image Placeholder
- spine_env_info
- ggml_graph_dump_dot
- Flutter Logo Mark
- Graphify Repository Workflow
- Flutter Logo Application Launcher Icon
- Flutter Logo Application Launcher Icon
- gguf_get_n_tensors
- Forui CLI 输出配置
- 损坏的 Graphify 查询记忆记录
- Flutter Logo iOS Application Icon
- Flutter Logo iOS Application Icon
- Flutter Logo iOS Application Icon
- Flutter Logo iOS Application Icon
- Flutter Logo iOS Application Icon
- Flutter Logo iOS Application Icon
- Transparent 1×1 iOS Launch-image Placeholder
- LaunchImage.imageset/README.md
- nrow_block_q3_k
- local_data_control.dart
- audio_source.dart
- model_manifest_parser.dart
- icons
- style
- style
- _typography
- meeting
- _snapshot
- summary
- descriptor
- Step 21：C++ Whisper 质量交付基线
- ops.h
- canShare
- deleteMeeting
- _diarizationMessage
- _errorMessage
- isDeleted
- _isLoading
- isProcessing
- _meeting
- _playbackState
- playEvidence
- playFullAudio
- _progress
- renameMeeting
- _resultMessage
- _selectedEvidenceSegmentId
- share
- _snapshot
- state
- stopPlayback
- _summary
- _summaryMessage
- Step 23～24：官方 VAD、预览与最终转录
- ggml-cpp.h
- LocalFactFooter
- _generateSummary
- summary
- Segment
- Step 22：Whisper 解码参数评测
- canRetranscribe
- canRetry
- installedModels
- isDiarizing
- isTranscribing
- renameSpeaker
- retranscribe
- retry
- retryDiarization
- reviseTranscript
- selectedModelId
- selectModel
- setDiarizationEnabled
- snapshot
- build
- createState
- onDeleted
- viewModel
- ggml_opt_dataset
- build
- viewModel
- build
- viewModel
- whisper_quality_metrics_test.dart
- build
- createState
- viewModel
- Q: start meeting readiness model installation whisper initialization failure
- Go NoGo Blocked Three-State Release Gate
- quantize_q4_0
- build
- editingTranscript
- onDeleted
- section
- viewModel
- build
- createState
- onOpenMeeting
- onOpenSettings
- onStartMeeting
- startingMeeting
- build
- WhisperWorker
- ggml_opt_result_t
- build
- createState
- onOpenSettings
- onStartMeeting
- startingMeeting
- ggml_new_graph_custom
- quantize_q4_1
- build
- onOpenMeeting
- build
- viewModel
- build
- viewModel
- build
- viewModel
- Linux Flutter Build Rules
- Linux Runner Build Rules
- Flutter Logo macOS Rounded-square Application Icon
- Flutter Logo macOS Rounded-square Application Icon
- Flutter Logo macOS Rounded-square Application Icon
- bool?
- String?
- Cross-Platform Accessibility and Inclusion
- app
- Flutter Logo Web Application Icon
- Flutter Logo Maskable Web Application Icon
- Windows Flutter Build Rules
- Windows Runner Build Rules
- dart:async
- size
- tinyBLAS_RVV
- whisper_model
- rvv_kernels.cpp
- simd-mappings.h
- c_library.dart
- spacemit/repack.cpp
- copyWith
- whisper_layer_decoder
- pack_qs
- hashCode
- ggml_graph_compute
- whisper_batch
- app_failure.dart
- lerp
- weight_buft_supported
- operator
- quantize_row_q8_0_ref
- _
- spine_tcm.h
- _owner
- ggml_type_name
- gguf_init_from_reader
- ggml-cpu/common.h
- quantize_row_tq2_0_ref
- nrow_block_q2_k
- MessageHandler
- make_buft_list
- ggml-backend-dl.h
- whisper_global
- ggml_backend_event_free
- ggml_backend_cpu_x86_score
- asr_model_registry.dart
- gguf_set_kv
- gguf_context
- quantize_q6_K
- .compute_forward
- _
- x86/cpu-feats.cpp
- Q: clang: warning: -Wl,-z,max-page-size=16384: linker input unused 是否影响 Android 16KB page-size 兼容性
- pool_allocation
- ggml_conv_2d_dw_params
- message
- AppDelegate
- amx/common.h
- spine_mem_pool.cpp
- ggml_backend_plan_cpu
- ggml_tensor
- asr_model.dart
- Win32Window
- quantize_row_nvfp4_ref
- _owner
- _
- unpack_A
- _owner
- nearest_int
- prepare_whisper_quality_corpus.dart
- GeneratedPluginRegistrant.swift
- make_block_q4_0x32
- gguf_writer_file
- MessageHandler
- title
- block_q8_K
- title
- q8k_blk_size
- dispose
- onEditingChanged
- tensor_traits_base
- rotate_pairs
- onEvidence
- data_control.dart
- ime_kernels.h
- block_with_zp
- flash_attn_ext_f16_one_chunk_inner_vlen1024_vf16_mrow
- value
- type_to_gguf_type<std::string>
- rvv_kernels.h
- whisper_global_cache
- ggml_quantize_chunk
- didUpdateWidget
- Step 20：whisper.cpp 正式替换
- onPress
- readiness
- meeting
- onPress
- ggml_backend_graph_copy
- ggml_backend_sched_split
- tile_config_t
- referenceTime
- make_block_q4_1x16
- ggml_backend_dev_props
- hbm.cpp
- GGML_DEPRECATED
- ggml_opt_fit
- quantize_row_q8_K_ref
- quantize_row_tq1_0_ref
- ggml-quants.c
- kleidiai_block_args
- ggml_backend_dev_caps
- ggml_backend_meta_split_state
- ggml_init_params
- ime_env.cpp
- atomic_flag_test_and_set
- WhisperWorkerFactory
- ggml_set_abort_callback
- ggml_backend_feature
- ggml_opt_optimizer_name
- Q: 分析当前项目的本地模型，是否需要更换模型或组合模型
- Q: 分析各个模型
- Q: https://github.com/moonshine-ai/moonshine
- Q: sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2025-09-09
- Q: ggml-org/whisper.cpp
- RegisterPlugins
- make_block_q8_0x32
- tinygemm_kernel_avx<float, ggml_fp16_t, float, BLOCK_M, BLOCK_N, BLOCK_K>
- meettrace_whisper_native.dart
- meettrace_whisper.record_use_mapping.g.dart
- meettrace_whisper_native/README.md
- @ffi
- File
- Map
- Set
- T

## God Nodes (most connected - your core abstractions)
1. `ggml_nrows()` - 99 edges
2. `ggml_compute_forward()` - 97 edges
3. `cpuid_x86` - 80 edges
4. `whisper_state` - 73 edges
5. `ggml_is_contiguous()` - 64 edges
6. `test_x86_is()` - 60 edges
7. `ggml_nbytes()` - 59 edges
8. `ggml_nelements()` - 58 edges
9. `ggml_are_same_shape()` - 53 edges
10. `____m256i()` - 51 edges

## Surprising Connections (you probably didn't know these)
- `Strict Casts Inference and Raw Types` --semantically_similar_to--> `Formatting Analysis Testing and OCR Quality Gate`  [INFERRED] [semantically similar]
  analysis_options.yaml → AGENTS.md
- `View-ViewModel-Use Case-Port-Repository-Service Architecture` --semantically_similar_to--> `On-Device Dual-Model Transcription Technical Architecture`  [INFERRED] [semantically similar]
  AGENTS.md → docs/端侧双模型转录技术方案.md
- `Continuous Time Ledger` --semantically_similar_to--> `Home Meeting Ledger Surface`  [INFERRED] [semantically similar]
  DESIGN.md → .impeccable/surfaces/ui-features-meetings-views-meeting-list-view-dart.md
- `Trustworthy Degradation` --semantically_similar_to--> `Speaker Diarization Degradation Architecture`  [INFERRED] [semantically similar]
  PRODUCT.md → docs/端侧双模型转录技术方案.md
- `APPLY_STANDARD_SETTINGS` --semantically_similar_to--> `APPLY_STANDARD_SETTINGS`  [INFERRED] [semantically similar]
  linux/CMakeLists.txt → windows/CMakeLists.txt

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **首页录音预检演进** — graphify_out_memory_query_20260728_003301_static_readiness_copy, graphify_out_memory_query_20260728_005147_real_recording_preflight, graphify_out_memory_query_20260728_025117_two_line_readiness_layout [INFERRED 0.85]
- **会议删除交互与事务** — graphify_out_memory_query_20260728_030129_confirmed_meeting_deletion, graphify_out_memory_query_20260728_030129_deletion_transaction_scope, graphify_out_memory_query_20260728_030651_reveal_only_swipe_delete, graphify_out_memory_query_20260728_030651_single_open_swipe_row [INFERRED 0.95]
- **会议列表安全删除流程** — graphify_out_memory_query_20260728_031933_app_swipe_action_row, graphify_out_memory_query_20260728_031933_meeting_list_view, graphify_out_memory_query_20260728_031933_meeting_list_view_model, graphify_out_memory_query_20260728_031933_delete_meeting_use_case [EXTRACTED 1.00]
- **PCM 波形反馈流水线** — graphify_out_memory_query_20260728_071436_reliable_recording_service, graphify_out_memory_query_20260728_071436_pcm_audio_level_meter, graphify_out_memory_query_20260728_071436_recording_session_view_model, graphify_out_memory_query_20260728_071436_recording_audio_waveform [EXTRACTED 1.00]
- **跨平台 CMake 标准编译设置** — linux_cmakelists_apply_standard_settings, windows_cmakelists_apply_standard_settings, linux_cmakelists_target_compile_features, windows_cmakelists_target_compile_features [INFERRED 0.85]

## Communities (520 total, 170 thin omitted)

### Community 0 - "meeting_detail_view_model.dart"
Cohesion: 0.02
Nodes (121): _applyInstallations, _applyProgress, canGenerate, displayLabel, displaySpeakerLabel, generate, isGenerating, _loadInstalledModels (+113 more)

### Community 1 - "asr_preview_coordinator.dart"
Cohesion: 0.03
Nodes (75): asr_preview_session.dart, ../audio/recording_ports.dart, ../../../domain/use_cases/plan_asr_preview_windows.dart, _acceptSegments, _active, add, append, _blocks (+67 more)

### Community 2 - "meettrace_dependencies.dart"
Cohesion: 0.03
Nodes (72): createDataControlsViewModel, createMeetingDetailViewModel, createMeetingListViewModel, createModelSettingsViewModel, createRecordingSessionViewModel, createStartMeetingViewModel, MeetTraceViewModelFactories, ../data/repositories/sqflite_diarization_preference_repository.dart (+64 more)

### Community 3 - "meeting_detail_view.dart"
Cohesion: 0.03
Nodes (83): SpeakerLabelGroup, _AudioCard, _confirmingDelete, _controller, detail, _DiarizationCard, duration, editing (+75 more)

### Community 4 - "use_cases/evaluate_alpha_release.dart"
Cohesion: 0.03
Nodes (78): acceptanceEvidence, _acceptanceEvidenceCount, adaptiveNavigationAccessibilityPassed, advancedEnergyWh, advancedFinalTranscriptionDurationMs, advancedRtfSamples, advancedSentenceLatencyMs, AlphaReleaseDecision (+70 more)

### Community 5 - "dart:io"
Cohesion: 0.03
Nodes (71): _PreviewInstallations, dart:io, Directory, BundledModelPreparationService, AppFileLayout, commit, DurableFileCommitException, DurableFileCommitter (+63 more)

### Community 6 - "win32_window.cpp"
Cohesion: 0.15
Nodes (16): Point, Size, wchar_t, Scale(), Create, Destroy, SetQuitOnClose, Show (+8 more)

### Community 7 - "meeting_list_view.dart"
Cohesion: 0.03
Nodes (59): _audioFactLabel, body, deletable, deleting, deletingMeetingIds, descriptor, didChangeDependencies, _disableAnimations (+51 more)

### Community 8 - "theme.dart"
Cohesion: 0.03
Nodes (57): AppColors get, AppStyle get, _body, borderRadius, borderStrong, cardRadius, contentMaxWidth, controlHeight (+49 more)

### Community 9 - "ggml-cpu/repack.h"
Cohesion: 0.04
Nodes (51): block, d, block_iq4_nlx16, d, qs, block_iq4_nlx4, d, qs (+43 more)

### Community 10 - "asr_preview_coordinator_test.dart"
Cohesion: 0.03
Nodes (71): package:meettrace/data/services/asr/asr_preview_coordinator.dart, package:meettrace/data/services/vad/voice_activity_segmenter.dart, package:meettrace/domain/models/app_failure.dart, package:meettrace/domain/models/asr_preview.dart, package:meettrace/domain/use_cases/plan_asr_preview_windows.dart, required _ScriptedVad vad,
  int, accept, acceptAudio (+63 more)

### Community 11 - "reliable_recording_service.dart"
Cohesion: 0.04
Nodes (55): audioLevelChanges, _audioLevelMeter, _audioSubscription, canFinalize, capture, _captureDone, _captureStopTimedOut, captureStopTimeout (+47 more)

### Community 12 - "ports/asr_engine.dart"
Cohesion: 0.04
Nodes (53): acceptAudio, AsrDeviceSupport, AsrEngineMetrics, AsrEnginePurpose, AsrFinalizationPhase, AsrFinalizationProgress, AsrMemoryPressure, AsrThermalState (+45 more)

### Community 13 - "sqflite_repositories_test.dart"
Cohesion: 0.03
Nodes (81): StartupRecoveryService, DomainInvariantViolation, message, toString, TranscriptSnapshotStatus, InvalidStateTransitionException, ResolveMeetingModelSelection, package:meettrace/data/repositories/sqflite_diarization_preference_repository.dart (+73 more)

### Community 14 - "package:flutter/widgets.dart"
Cohesion: 0.04
Nodes (51): AlignmentGeometry, EdgeInsetsGeometry?, FCircularProgress, Icon, appDisplayName, Application, build, home (+43 more)

### Community 15 - "final_transcription_service_test.dart"
Cohesion: 0.04
Nodes (44): required DateTime createdAt,
  int, acceptAudio, activeSnapshotId, cancel, conflictingWinner, create, delete, descriptor (+36 more)

### Community 16 - "downloadable_model_service.dart"
Cohesion: 0.02
Nodes (106): addCancelListener, _adoptExistingIfValid, alreadyInstalled, cancel, candidate, capacity, cause, code (+98 more)

### Community 17 - "FlutterMacOS"
Cohesion: 0.13
Nodes (12): Cocoa, Flutter, FlutterMacOS, FlutterSceneDelegate, SceneDelegate, RunnerTests, MainFlutterWindow, RunnerTests (+4 more)

### Community 18 - "model_selection_fakes.dart"
Cohesion: 0.04
Nodes (56): List, package:meettrace/domain/models/meeting_readiness.dart, package:meettrace/domain/use_cases/check_meeting_readiness.dart, check, freeBytes, main, microphonePermissionGranted, permissionRequests (+48 more)

### Community 19 - "ggml_new_tensor"
Cohesion: 0.04
Nodes (65): ggml_custom_op_t, ggml_tensor, ggml_argsort(), ggml_argsort_top_k(), ggml_calc_conv_output_size(), ggml_calc_conv_transpose_1d_output_size(), ggml_calc_conv_transpose_output_size(), ggml_calc_pool_output_size() (+57 more)

### Community 20 - "meeting_detail_view_model_test.dart"
Cohesion: 0.05
Nodes (44): SqfliteProcessingTaskRepository, ProcessingTaskRepository, _TaskRepository, _TaskRepository, DetailProcessingTaskRepository, capability, diarizationEnabled, dispose (+36 more)

### Community 21 - "ops.cpp"
Cohesion: 0.06
Nodes (136): ggml_op_pool, ggml_compute_forward(), ggml_compute_params, ggml_tensor, ggml_compute_forward_acc(), ggml_compute_forward_add_id(), ggml_compute_forward_add_id_f32(), ggml_compute_forward_add_rel_pos() (+128 more)

### Community 22 - "meeting_list_previews.dart"
Cohesion: 0.07
Nodes (33): @Preview, ../../../../app/application.dart, app_page_body.dart, app_state_panel.dart, check, commit, delete, getById (+25 more)

### Community 23 - "whisper_quality_protocol.dart"
Cohesion: 0.04
Nodes (55): byteLength, decodePcm16Le, decodePcm16LeWindows, deidentified, durationMs, evidenceClass, expectedKeyFacts, fromJson (+47 more)

### Community 24 - "recording_session_view.dart"
Cohesion: 0.05
Nodes (42): duration, _durationLabel, emphasized, enabled, finalizing, hours, icon, _isActive (+34 more)

### Community 25 - "generate_summary_test.dart"
Cohesion: 0.05
Nodes (41): _PreviewSummaryRepository, SqfliteSummaryRepository, Object? error,
  bool, package:meettrace/data/services/summary/summary_generation_service.dart, package:meettrace/domain/use_cases/generate_summary.dart, SummaryRepository, _SummaryService, active (+33 more)

### Community 26 - "ggml_dup_tensor"
Cohesion: 0.04
Nodes (68): ggml_custom1_op_t, ggml_custom2_op_t, ggml_custom3_op_t, ggml_acc(), ggml_acc_impl(), ggml_acc_inplace(), ggml_add_id(), ggml_add_impl() (+60 more)

### Community 27 - "fetch_ascend_public_regression.dart"
Cohesion: 0.03
Nodes (66): allowedRoot, ascendDatasetConfig, ascendDatasetId, ascendDatasetLicense, ascendDatasetRevision, AscendRow, audioDirectory, audioUri (+58 more)

### Community 28 - "recording_session_view_model.dart"
Cohesion: 0.05
Nodes (37): _audioLevels, _audioLevelSubscription, canPause, canResume, canStop, dispose, _disposed, _disposePreview (+29 more)

### Community 29 - "android_emulator_meeting_flow_test.dart"
Cohesion: 0.03
Nodes (57): AudioLevel, _PreviewRecordingService, accept, build, check, _chunkSequence, _controller, _copyAsset (+49 more)

### Community 30 - "speaker_diarization_coordinator_test.dart"
Cohesion: 0.05
Nodes (44): _PreviewTranscriptRepository, SqfliteTranscriptRepository, package:meettrace/data/services/diarization/speaker_diarization_coordinator.dart, package:meettrace/data/services/diarization/speaker_diarization_service.dart, package:meettrace/domain/models/speaker_diarization.dart, _TaskRepository, _TranscriptRepository, available (+36 more)

### Community 31 - "whisper_quality_metrics.dart"
Cohesion: 0.03
Nodes (77): asrInvocationCount, comparisons, _csvCell, decoded, detectedSpeechDurationMs, detectedSpeechSegmentCount, deviceId, durationMs (+69 more)

### Community 32 - "sqflite_model_installation_repository.dart"
Cohesion: 0.05
Nodes (47): class, ../../../../../domain/models/meeting.dart, ../../../domain/models/model_usage_lease.dart, ../../../../../domain/models/processing_task.dart, _appDatabase, _enabledKey, getEnabled, setEnabled (+39 more)

### Community 33 - "android_whisper_quality_benchmark_test.dart"
Cohesion: 0.03
Nodes (69): allSamples, _appendRecognition, asrInvocationCount, _baseModelAsset, _BenchmarkRecognition, byteLength, _completeMarker, _copyAsset (+61 more)

### Community 34 - "run_speaker_diarization.dart"
Cohesion: 0.05
Nodes (38): ../../../domain/models/audio_source.dart, ../../../../../domain/models/speaker_diarization.dart, ../../../../../domain/ports/speaker_diarization.dart, ../../../domain/use_cases/run_speaker_diarization.dart, capability, diarize, UnavailableSpeakerDiarizationService, capability (+30 more)

### Community 35 - "recording_previews.dart"
Cohesion: 0.06
Nodes (29): audioLevelChanges, canFinalize, _changes, delete, dispose, duration, _events, flush (+21 more)

### Community 36 - "generate_synthetic_noise_corpus.dart"
Cohesion: 0.04
Nodes (56): allowedRoot, audioDirectory, bytes, clickLength, corpusId, create, data, _dbToLinear (+48 more)

### Community 37 - "reliable_recording_service_test.dart"
Cohesion: 0.04
Nodes (53): delete, fromJson, hashCode, JsonRecordingCheckpointStore, layout, load, meetingId, operator (+45 more)

### Community 38 - "ggml_backend_load_best"
Cohesion: 0.23
Nodes (14): dl_handle, path, dl_error(), dl_get_sym(), dl_load_library(), backend_filename_extension(), backend_filename_prefix(), path (+6 more)

### Community 39 - "whisper_vad_segmenter.dart"
Cohesion: 0.03
Nodes (59): dart:isolate, Isolate, accept, analysisInterval, _analysisIntervalSamples, _analysisOriginSample, _analyze, _availableEndSample (+51 more)

### Community 40 - "meeting_list_view_model.dart"
Cohesion: 0.05
Nodes (38): ../../../../core/view_state.dart, ../../../../../domain/use_cases/check_meeting_readiness.dart, captureFactory, check, DeviceRecordingReadinessProbe, PcmAudioCaptureFactory, storageCapacity, RecordingDeviceReadinessProbe (+30 more)

### Community 41 - "meettrace_flow.dart"
Cohesion: 0.07
Nodes (29): ../../../../../domain/use_cases/start_meeting.dart, Future, build, createState, _dependencies, didChangeAppLifecycleState, dispose, initState (+21 more)

### Community 42 - "summary_generation.dart"
Cohesion: 0.08
Nodes (25): actionItems, available, capability, code, evidenceSegmentIds, generate, GeneratedSummaryDraft, GeneratedSummaryItem (+17 more)

### Community 43 - "storage_mappers.dart"
Cohesion: 0.07
Nodes (27): ../../../../domain/models/asr_model.dart, ../../../../domain/models/model_installation.dart, ../../../../../domain/models/workflow_states.dart, _date, fromMillisecondsSinceEpoch, meetingFromRow, meetingToRow, modelInstallationFromRow (+19 more)

### Community 44 - "bundled_model_preparation_service.dart"
Cohesion: 0.05
Nodes (40): ../../../domain/models/model_manifest.dart, alreadyReady, assetSource, BundledModelPreparationPhase, BundledModelPreparationProgress, BundledModelPreparationResult, cause, code (+32 more)

### Community 45 - "recording_audio_waveform.dart"
Cohesion: 0.07
Nodes (27): AnimationController, CustomPainter, active, baseline, build, _controller, createState, didUpdateWidget (+19 more)

### Community 46 - "revise_final_transcript.dart"
Cohesion: 0.05
Nodes (39): Meeting, TranscriptSnapshot, FinalTranscriptionProgressCallback, FinalTranscriptionResult, meeting, snapshot, transcribe, cause (+31 more)

### Community 47 - "recording_session_view_test.dart"
Cohesion: 0.03
Nodes (68): DecoratedBox, SqfliteModelInstallationRepository, SqfliteModelPreferenceRepository, ActiveModelInstallationRepository, ModelPreferenceRepository, package:meettrace/domain/ports/asr_engine.dart, package:meettrace/domain/use_cases/start_meeting.dart, package:meettrace/ui/core/asr_model_option.dart (+60 more)

### Community 48 - "recording_ports.dart"
Cohesion: 0.07
Nodes (31): dart:collection, FlutterForegroundRecordingLifecycle, PcmAudioLevelMeter, add, CallbackRecordingPreviewSink, close, _closed, DiscardingRecordingPreviewSink (+23 more)

### Community 49 - "transcript.dart"
Cohesion: 0.07
Nodes (27): double?, actualModelId, actualModelVersion, confidence, createdAt, endMs, id, isEligibleForSummary (+19 more)

### Community 50 - "meeting.dart"
Cohesion: 0.07
Nodes (27): activateFinalTranscript, activeSummaryId, activeTranscriptSnapshotId, audioDurationMs, audioPath, beginFinalTranscription, changeRecordingModel, _copyWith (+19 more)

### Community 51 - "start_meeting_view_model.dart"
Cohesion: 0.06
Nodes (34): FailureUserAction? get, action, _appFailurePresentation, _applyFailure, _applyInstallations, _availableVersions, _blockedFailure, code (+26 more)

### Community 52 - "pcm_evidence_playback_service.dart"
Cohesion: 0.07
Nodes (29): AudioPlayer, evidence_playback_service.dart, AudioplayersDeviceAudioOutput, _bitsPerSample, _bytesPerMillisecond, _bytesPerSample, _channels, _completionSubscription (+21 more)

### Community 53 - "start_meeting.dart"
Cohesion: 0.04
Nodes (59): _PreviewMeetingReadinessChecker, check_meeting_readiness.dart, _ReadyMeetingChecker, AsrModelRegistry, check, CheckMeetingReadinessUseCase, device, freeBytes (+51 more)

### Community 54 - "ggml_backend_buffer_t"
Cohesion: 0.07
Nodes (47): ggml_tallocr_alloc(), ggml_vbuffer_tensor_alloc(), ggml_backend_buffer_t, ggml_backend_buffer_type_t, ggml_backend_alloc_buffer(), ggml_backend_buffer_clear(), ggml_backend_buffer_get_alignment(), ggml_backend_buffer_get_alloc_size() (+39 more)

### Community 55 - "model_settings_view.dart"
Cohesion: 0.06
Nodes (32): ChangeNotifier, ../../../core/app_back_icon.dart, MeetingListViewModel, RecordingSessionViewModel, StartMeetingViewModel, DataControlsViewModel, ModelSettingsViewModel, _action (+24 more)

### Community 56 - "ggml.c"
Cohesion: 0.03
Nodes (93): ggml_bf16_t, ggml_fp16_t, ggml_log_callback, ggml_abort(), ggml_abs_inplace(), ggml_add1(), ggml_add1_impl(), ggml_add1_inplace() (+85 more)

### Community 57 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 58 - "model_settings_view_model.dart"
Cohesion: 0.08
Nodes (25): ../../../core/asr_model_option.dart, actions, _applyInstallations, cancelAdvanced, _defaultModelId, deleteAdvanced, dispose, _disposed (+17 more)

### Community 59 - "ggml_backend_buffer_type_t"
Cohesion: 0.14
Nodes (27): alloc_tensor_range(), ggml_backend_buffer_t, ggml_backend_buffer_type_t, free_buffers(), ggml_backend_alloc_ctx_tensors_from_buft(), ggml_backend_alloc_ctx_tensors_from_buft_impl(), ggml_backend_alloc_ctx_tensors_from_buft_size(), ggml_tallocr_new() (+19 more)

### Community 60 - "app_swipe_action_row.dart"
Cohesion: 0.08
Nodes (25): Key?, actionIcon, actionKey, actionLabel, build, child, _closeDuration, _controller (+17 more)

### Community 61 - "x86/quants.c"
Cohesion: 0.11
Nodes (47): bytes_from_bits_16(), bytes_from_bits_32(), bytes_from_nibbles_32(), __m128, __m128i, __m256, get_scale_shuffle(), get_scale_shuffle_k4() (+39 more)

### Community 62 - "whisper_asr_engine_factory_test.dart"
Cohesion: 0.03
Nodes (67): _copyAsset, data, main, _modelAsset, changes, inspect, main, _modelRoot (+59 more)

### Community 63 - "repositories.dart"
Cohesion: 0.04
Nodes (47): abstract interface class, delete, deleteAndDeactivate, deleteExpired, getActiveVersion, getById, getDefaultModelId, getEnabled (+39 more)

### Community 64 - "meeting_detail_view_test.dart"
Cohesion: 0.05
Nodes (43): SqfliteDiarizationPreferenceRepository, DiarizationPreferenceRepository, package:meettrace/ui/features/meetings/view_models/detail/meeting_detail_view_model.dart, package:meettrace/ui/features/meetings/views/detail/meeting_detail_view.dart, required String id,
  TranscriptSnapshotStatus, SpeakerDiarizationRunner? diarization,
  bool, ../../../../../support/final_transcription_fakes.dart, _DiarizationPreference (+35 more)

### Community 65 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.04
Nodes (50): main, _recordingSeconds, ModelManifestParser, package:flutter/foundation.dart, package:flutter_test/flutter_test.dart, package:meettrace/data/services/audio/device_recording_storage_capacity.dart, package:meettrace/data/services/audio/flutter_foreground_recording_lifecycle.dart, package:meettrace/data/services/audio/platform_recording_foreground_lifecycle.dart (+42 more)

### Community 66 - "data_controls_view_model.dart"
Cohesion: 0.09
Nodes (21): ../../../../domain/ports/text_share.dart, ../../../../domain/use_cases/build_meeting_share.dart, share, SharePlusTextShareService, share, TextShareService, dataControl, dispose (+13 more)

### Community 67 - "summary.dart"
Cohesion: 0.08
Nodes (23): actionItems, createdAt, endMs, evidence, id, isPendingReview, keyPoints, meetingId (+15 more)

### Community 68 - "whisper_vad_context"
Cohesion: 0.07
Nodes (30): mt_whisper_vad_segment_samples(), ggml_backend_sched_t, whisper_vad_params, samples_to_cs(), whisper_sched, sched, whisper_vad_context, backends (+22 more)

### Community 69 - "android_proc_asr_device_risk_monitor.dart"
Cohesion: 0.05
Nodes (41): android_proc_asr_device_risk_monitor.dart, asr_engine.dart, Duration, AsrRiskTextReader, AsrThermalPathLister, changes, _constrainedMemoryBytes, _deviceSupport (+33 more)

### Community 70 - "whisper.cpp"
Cohesion: 0.04
Nodes (66): mt_whisper_transcribe(), cs_to_samples(), dft(), fft(), median_filter_user_data, filter_width, sample_to_timestamp(), should_split_on_word() (+58 more)

### Community 71 - "asr_preview.dart"
Cohesion: 0.09
Nodes (22): Float32List, AsrPreviewMetrics, AsrPreviewWindow, audioDurationMs, droppedPreviewWindows, endMs, endSample, groupId (+14 more)

### Community 72 - "recording_device_readiness_probe_test.dart"
Cohesion: 0.08
Nodes (23): _DeterministicPcmAudioCapture, DeviceRecordingStorageCapacityProvider, RecordPcmAudioCapture, PcmAudioCapture, RecordingStorageCapacityProvider, package:meettrace/data/services/audio/recording_device_readiness_probe.dart, _FakeCapture, _FixedCapacity (+15 more)

### Community 73 - "ggml-cpu.cpp"
Cohesion: 0.07
Nodes (53): ggml_threadpool_t, ggml_guid_t, ggml_abort_callback, ggml_backend_buffer_t, ggml_backend_buffer_type_t, ggml_backend_dev_t, ggml_backend_graph_plan_t, ggml_backend_reg_t (+45 more)

### Community 74 - "ggml-backend-reg.cpp"
Cohesion: 0.12
Nodes (11): ggml_backend, ggml_backend_buffer, ggml_backend_buffer_type, ggml_backend_device, ggml_backend_event, ggml_backend_reg, ggml_backend_sched, ggml_cgraph (+3 more)

### Community 75 - "app_ledger.dart"
Cohesion: 0.09
Nodes (21): AppLedgerRow, AppLedgerSurface, build, children, dateLabel, emphasized, framed, icon (+13 more)

### Community 76 - "_string"
Cohesion: 0.12
Nodes (15): _string, powerpc_features, has_vsx, platform, power_version, T, gguf_get_arr_n(), gguf_kv (+7 more)

### Community 77 - "recording_session_view_model_test.dart"
Cohesion: 0.03
Nodes (60): bool get, canStart, defaultModelAvailable, defaultModelId, defaultModelName, freeBytes, issues, MeetingReadiness (+52 more)

### Community 78 - "meeting_detail_previews.dart"
Cohesion: 0.09
Nodes (21): delete, getById, listByMeeting, save, saveAndActivate, saveFinalAndActivate, _standard, transcribe (+13 more)

### Community 79 - "pcm_evidence_playback_service_test.dart"
Cohesion: 0.07
Nodes (25): int?, PcmEvidencePlaybackService, code, dispose, endMs, errorCode, EvidencePlaybackException, EvidencePlaybackService (+17 more)

### Community 80 - "Exception"
Cohesion: 0.04
Nodes (45): dart:convert, dart:math, Exception, WhisperAdapterException, BundledModelPreparationException, _PreparationFailure, ModelDownloadCanceledException, AsrEngineException (+37 more)

### Community 81 - "vec.h"
Cohesion: 0.03
Nodes (95): ggml_set_f32(), ggml_set_i32(), ggml_compute_forward_norm_f32(), ggml_compute_forward_out_prod_f32(), ggml_bf16_t, ggml_float, ggml_fp16_t, exp_ps_sve() (+87 more)

### Community 82 - "ggml_compute_params"
Cohesion: 0.19
Nodes (26): ggml_compute_forward_unary(), apply_unary_op(), ggml_compute_params, ggml_tensor, ggml_compute_forward_abs(), ggml_compute_forward_ceil(), ggml_compute_forward_cos(), ggml_compute_forward_elu() (+18 more)

### Community 83 - "meettrace_whisper.g.dart"
Cohesion: 0.05
Nodes (51): external double, external int, ffi.Opaque, package:meta/meta.dart, abi_version, beam_size, best_of, decoding_strategy (+43 more)

### Community 84 - "recording.dart"
Cohesion: 0.10
Nodes (19): Duration get, audioPath, bytes, capturedThrough, duration, end, endByteOffset, level (+11 more)

### Community 85 - "app_file_layout.dart"
Cohesion: 0.03
Nodes (62): Connectivity, DatabaseFactory, device_free_space_service.dart, ../../../../domain/models/data_control.dart, ../../../../domain/ports/local_data_control.dart, downloadable_model_service.dart, _connectivity, freeSpace (+54 more)

### Community 86 - "model_manifest.dart"
Cohesion: 0.10
Nodes (19): bytes, files, installationType, license, minAppVersion, modelId, ModelLicense, ModelManifest (+11 more)

### Community 87 - "MeetingRepository"
Cohesion: 0.07
Nodes (27): _PreviewMeetingRepository, _PreviewMeetingRepository, _PreviewMeetingRepository, TranscriptRevisionException, MeetingRepository, package:meettrace/domain/use_cases/revise_final_transcript.dart, _MeetingRepository, _MeetingRepository (+19 more)

### Community 88 - "whisper_vad_model"
Cohesion: 0.07
Nodes (28): ggml_backend_buffer_t, whisper_aheads_masks, buffer, ctx, m, whisper_vad_model, buffers, ctxs (+20 more)

### Community 89 - "meeting_list_view_model_test.dart"
Cohesion: 0.02
Nodes (88): AnimatedContainer, app_file_layout.dart, _PreviewMeetingFileDeletionService, _PreviewStagedMeetingDeletion, Completer, ../../../../../domain/use_cases/delete_meeting.dart, FTappable, commit (+80 more)

### Community 90 - "ggml_set_op_params_f32"
Cohesion: 0.13
Nodes (15): ggml_arange(), ggml_fill(), ggml_fill_impl(), ggml_fill_inplace(), ggml_gated_linear_attn(), ggml_group_norm(), ggml_group_norm_impl(), ggml_group_norm_inplace() (+7 more)

### Community 91 - "ggml-cpu/repack.cpp"
Cohesion: 0.04
Nodes (56): block_q4_0x4, block_q4_0x8, block_q8_0x16, block_q8_0x4, ggml_quantize_mat_q8_K_4x8(), block_mxfp4x8, e, qs (+48 more)

### Community 92 - "models/speaker_diarization.dart"
Cohesion: 0.11
Nodes (18): available, code, endMs, errorCode, isAvailable, reasonCode, snapshot, SpeakerDiarizationCapability (+10 more)

### Community 93 - "run_final_transcription.dart"
Cohesion: 0.08
Nodes (24): _PendingTranscriptionRunner, _UnavailableTranscriptionRunner, FinalTranscriptionRunner, code, engineFactory, _errorCode, FinalTranscriptionException, FinalTranscriptionService (+16 more)

### Community 95 - "ggml_compute_backward"
Cohesion: 0.06
Nodes (45): ggml_get_n_tasks(), ggml_abs(), ggml_add_cast(), ggml_add_cast_impl(), ggml_can_repeat(), ggml_can_repeat_rows(), ggml_ceil(), ggml_compute_backward() (+37 more)

### Community 96 - "recording_bootstrap_view.dart"
Cohesion: 0.12
Nodes (17): Animation, ../../../../core/app_state_panel.dart, build, createState, didChangeDependencies, dispose, _handleRouteAnimation, _initializationScheduled (+9 more)

### Community 97 - "final_transcription_fakes.dart"
Cohesion: 0.10
Nodes (19): >, package:meettrace/data/services/asr/final_transcription_service.dart, package:meettrace/domain/models/summary.dart, main, calls, delete, DetailTranscriptionCall, getById (+11 more)

### Community 98 - "domain_ports_test.dart"
Cohesion: 0.09
Nodes (21): AsrDeviceRiskState get, AsrEngineMetrics get, acceptAudio, cancel, create, delete, descriptor, deviceRisk (+13 more)

### Community 99 - "ggml-backend.cpp"
Cohesion: 0.06
Nodes (88): ggml_backend_eval_callback, ggml_backend_dev_t, ggml_backend_event_t, ggml_backend_graph_plan_t, ggml_backend_reg_t, ggml_backend_sched_t, ggml_backend_t, ggml_guid_t (+80 more)

### Community 100 - "plan_asr_preview_windows.dart"
Cohesion: 0.12
Nodes (16): asrPreviewContextAfterMs, asrPreviewContextBeforeMs, asrPreviewMaximumWindowMs, asrPreviewSampleRate, asrPreviewWindowOverlapMs, AsrPreviewWindowPlanner, contextAfterMs, contextBeforeMs (+8 more)

### Community 101 - "dart:typed_data"
Cohesion: 0.08
Nodes (23): dart:typed_data, package:meettrace/data/services/audio/recording_pcm_diagnostics.dart, package:meettrace/data/services/vad/streaming_window_segmenter.dart, main, main, bytes, data, durationSeconds (+15 more)

### Community 102 - "riscv/quants.c"
Cohesion: 0.06
Nodes (78): NOINLINE, ggml_vec_dot_iq1_m_q8_K(), ggml_vec_dot_iq1_m_q8_K_vl1024(), ggml_vec_dot_iq1_m_q8_K_vl128(), ggml_vec_dot_iq1_m_q8_K_vl256(), ggml_vec_dot_iq1_m_q8_K_vl512(), ggml_vec_dot_iq1_s_q8_K(), ggml_vec_dot_iq1_s_q8_K_vl1024() (+70 more)

### Community 103 - "ggml-cpu/quants.c"
Cohesion: 0.04
Nodes (77): Float, ggml_vec_dot_iq1_s_q8_K(), ggml_vec_dot_iq2_s_q8_K(), ggml_vec_dot_iq2_xs_q8_K(), ggml_vec_dot_iq2_xxs_q8_K(), ggml_vec_dot_iq3_s_q8_K(), ggml_vec_dot_iq3_xxs_q8_K(), ggml_vec_dot_iq4_nl_q8_0() (+69 more)

### Community 104 - "Codex 实施计划：whisper.cpp 质量强化与双平台交付"
Cohesion: 0.05
Nodes (40): 1. 交付目标, 2. 明确不做, 3.1 隔离工作区, 3.2 每个任务的固定循环, 3.3 每个阶段的统一验证, 3.4 停止条件, 3.5 首个交付点的验证边界, 3. Codex 执行协议 (+32 more)

### Community 105 - "pcm_audio_level_meter.dart"
Cohesion: 0.06
Nodes (30): AudioRecorder, flutter_foreground_recording_lifecycle.dart, add, _changes, defaultRecordingAudioLevelFloorDbfs, defaultRecordingAudioLevelFrame, dispose, _disposed (+22 more)

### Community 106 - "State"
Cohesion: 0.12
Nodes (25): _ResultActionsCard, _ResultActionsCardState, _SpeakerLabelEditor, _SpeakerLabelEditorState, _TranscriptCard, _TranscriptCardState, MeetingListContent, _MeetingListContentState (+17 more)

### Community 107 - "workflow_states.dart"
Cohesion: 0.16
Nodes (15): Enum, canTransitionTo, from, machine, MeetingState, MeetingStateTransition, ModelInstallationState, ModelInstallationStateTransition (+7 more)

### Community 108 - "whisper_asr_engine.dart"
Cohesion: 0.03
Nodes (78): acceptAudio, _adapter, AsrEngineLifecycleHook, _beforeOperation, cancel, _cancelled, _config, data (+70 more)

### Community 109 - "sqflite_summary_repository.dart"
Cohesion: 0.06
Nodes (34): ../../domain/models/domain_exception.dart, ../../../../../domain/models/summary.dart, ../../../../../domain/models/transcript.dart, actionItems, _appDatabase, delete, executor, getById (+26 more)

### Community 110 - "semantic_date_time.dart"
Cohesion: 0.12
Nodes (16): clockTimeLabel, compact, date, dateLabel, _dateOnly, difference, isRelative, localReference (+8 more)

### Community 111 - "flutter_foreground_recording_lifecycle.dart"
Cohesion: 0.12
Nodes (15): @pragma, meetTraceRecordingForegroundCallback, onDestroy, onRepeatEvent, onStart, _RecordingKeepAliveTaskHandler, _recordingServiceId, _requireSuccess (+7 more)

### Community 112 - "meettrace_whisper.cpp"
Cohesion: 0.08
Nodes (34): ffi.Struct, mt_whisper_config_v1, mt_whisper_vad_config_v1, mt_whisper_cancel(), mt_whisper_config_v1_init(), mt_whisper_context, beam_size, best_of (+26 more)

### Community 113 - "Android + iOS 自适应范围"
Cohesion: 0.67
Nodes (3): Android + iOS 自适应范围, Android 与 iOS 全面调整查询, 平台敏感服务集合

### Community 114 - "loongarch/quants.c"
Cohesion: 0.11
Nodes (72): bytes_from_bits_32(), bytes_from_nibbles_32(), __m128, __m128i, __m256, get_scale_shuffle(), get_scale_shuffle_k4(), get_scale_shuffle_q3k() (+64 more)

### Community 115 - "vector"
Cohesion: 0.07
Nodes (51): pair, vector, decode_utf8(), get_signal_energy(), log_mel_spectrogram(), log_mel_spectrogram_worker_thread(), map_processed_to_original_time(), tokenize() (+43 more)

### Community 116 - "package:flutter/services.dart"
Cohesion: 0.08
Nodes (21): AssetBundle, bundled_model_preparation_service.dart, CachingAssetBundle, ModelAssetSource, bundle, FlutterModelAssetSource, load, appSystemUiOverlayStyle (+13 more)

### Community 117 - "generate_summary.dart"
Cohesion: 0.06
Nodes (30): ../../../domain/ports/summary_generation.dart, capability, generate, UnavailableSummaryGenerationService, SummaryGenerationService, _buildEvidence, _buildItems, _buildRequest (+22 more)

### Community 118 - "fetch_ascend_public_regression_test.dart"
Cohesion: 0.12
Nodes (15): required double duration,
  String, bytes, channels, data, fourCc, host, includeJunkChunk, junkSize (+7 more)

### Community 119 - "app_database.dart"
Cohesion: 0.14
Nodes (13): Database?, close, _createSchema, _createVersion1Schema, _createVersion2Schema, _createVersion3Schema, _createVersion4Schema, _database (+5 more)

### Community 120 - "ggml-backend-meta.cpp"
Cohesion: 0.08
Nodes (61): ggml_backend_meta_get_split_state_t, ggml_backend_buffer_get_usage(), ggml_backend_buft_get_device(), ggml_backend_tensor_get_2d(), ggml_backend_tensor_set_2d(), ggml_backend_buffer_t, ggml_backend_dev_t, ggml_backend_t (+53 more)

### Community 121 - "arm/repack.cpp"
Cohesion: 0.05
Nodes (68): quantize_row_q8_0(), quantize_row_q8_1(), int16x8_t, decode_q_Kx8_6bit_scales(), ggml_gemm_iq4_nl_4x4_q8_0(), ggml_gemm_mxfp4_4x4_q8_0(), ggml_gemm_q4_0_4x4_q8_0(), ggml_gemm_q4_0_4x8_q8_0() (+60 more)

### Community 122 - "sqflite_model_preference_repository.dart"
Cohesion: 0.12
Nodes (14): ../../../../domain/models/asr_model_registry.dart, _appDatabase, _defaultModelKey, getDefaultModelId, _legacyModelMigrations, registry, setDefaultModelId, _writeDefaultModelId (+6 more)

### Community 123 - "mt_whisper_vad_context"
Cohesion: 0.11
Nodes (19): atomic_bool, vector, whisper_vad_params, mt_whisper_vad_cancel(), mt_whisper_vad_context, cancelled, last_error, params (+11 more)

### Community 124 - "MeetTrace Android and iOS Alpha PRD V0.6"
Cohesion: 0.05
Nodes (49): Forui-First UI Policy, View-ViewModel-Use Case-Port-Repository-Service Architecture, Official sherpa_onnx Package-Only Boundary, Repository Product Boundaries, MeetTrace Repository Guide, Adaptive Native Mobile and Tablet Layout, Continuous Time Ledger, Grayscale Semantic Encoding (+41 more)

### Community 125 - "app_status_notice.dart"
Cohesion: 0.08
Nodes (22): Color, compact,
  medium,, IconData, AppResponsiveBuilder, AppResponsiveWidgetBuilder, AppWindowSizeClass, build, builder (+14 more)

### Community 126 - "ggml-cpu.c"
Cohesion: 0.05
Nodes (65): atomic_thread_fence(), cpu_set_t, ggml_bf16_t, ggml_fp16_t, ggml_backend_cpu_get_features(), ggml_compute_forward_mul_mat_id_one_chunk(), ggml_cpu_bf16_to_fp32(), ggml_cpu_fp16_to_fp32() (+57 more)

### Community 127 - "ggml-impl.h"
Cohesion: 0.04
Nodes (74): ggml_bitset_t, GGML_NORETURN, initializer_list, ggml_cpu_try_fuse_ops(), ggml_build_backward_expand(), ggml_can_fuse_subgraph_ext(), ggml_fp32_to_bf16_row_ref(), ggml_graph_cpy() (+66 more)

### Community 128 - "processing_task.dart"
Cohesion: 0.15
Nodes (12): createdAt, id, kind, lastErrorCode, leaseExpiresAt, meetingId, modelId, ProcessingTask (+4 more)

### Community 129 - "ggml-opt.cpp"
Cohesion: 0.17
Nodes (20): ggml_opt_context_t, ggml_opt_epoch_callback, ggml_opt_context_optimizer_type(), ggml_opt_dataset_get_batch(), ggml_opt_dataset_shuffle(), ggml_opt_epoch(), ggml_opt_epoch_callback_progress_bar(), ggml_opt_free() (+12 more)

### Community 130 - "Components"
Cohesion: 0.07
Nodes (27): Bottom Action Bar, Buttons, Cards / Containers, Colors, Components, Design System: 会迹 · MeetTrace, Do:, Do's and Don'ts (+19 more)

### Community 131 - "quantize_q5_0"
Cohesion: 0.47
Nodes (6): quantize_row_q5_0(), block_q5_0, dequantize_row_q5_0(), quantize_q5_0(), quantize_row_q5_0_impl(), quantize_row_q5_0_ref()

### Community 132 - "model_installation.dart"
Cohesion: 0.15
Nodes (12): domain_exception.dart, bytes, installationType, installedPath, lastErrorCode, modelId, ModelInstallation, state (+4 more)

### Community 133 - "ggml_is_contiguous"
Cohesion: 0.07
Nodes (72): from_float(), atomic_fetch_add_explicit(), ggml_barrier(), ggml_compute_forward_mul_mat(), ggml_compute_forward_mul_mat_id(), ggml_compute_forward_mul_mat_one_chunk(), ggml_get_type_traits_cpu(), ggml_graph_plan() (+64 more)

### Community 134 - "ggml_compute_forward_rope_flt"
Cohesion: 0.50
Nodes (5): ggml_compute_forward_rope_flt(), ggml_mrope_cache_init(), ggml_rope_cache_init(), rope_yarn(), rope_yarn_ramp()

### Community 135 - "ggml-cpu-impl.h"
Cohesion: 0.09
Nodes (61): ggml_int16x8x2_t, ggml_int8x16x2_t, ggml_int8x16x4_t, ggml_uint8x16x2_t, ggml_uint8x16x4_t, int32x4_t, int8x8_t, ggml_decode_q4scales_and_mins_for_mmla() (+53 more)

### Community 136 - "cpuid_x86"
Cohesion: 0.06
Nodes (14): cpuid_x86, brand, f_1_ecx, f_1_edx, f_7_1_eax, f_7_ebx, f_7_ecx, f_7_edx (+6 more)

### Community 137 - "whisper_vad_native_context.dart"
Cohesion: 0.08
Nodes (23): Char, dart:ffi, mt_whisper_vad_context>, package:ffi/ffi.dart, cancel, cancelAddress, dispose, endSample (+15 more)

### Community 138 - "recording_pcm_diagnostics.dart"
Cohesion: 0.09
Nodes (22): double get, addChunk, chunkCount, clippedSampleCount, clippingRatio, dcOffsetNormalized, duration, _nextByteOffset (+14 more)

### Community 139 - "ggml-alloc.c"
Cohesion: 0.11
Nodes (47): add_allocated_tensor(), aligned_offset(), ggml_gallocr_t, get_node_buffer_id(), ggml_buffer_address_less(), ggml_dyn_tallocr_alloc(), ggml_dyn_tallocr_free(), ggml_dyn_tallocr_free_bytes() (+39 more)

### Community 140 - "Q: 评估 whisper_ggml 是否适合作为会迹当前本地 ASR 模型或运行时"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: 评估 whisper_ggml 是否适合作为会迹当前本地 ASR 模型或运行时, Source Nodes

### Community 141 - "vector"
Cohesion: 0.21
Nodes (9): _In_, _In_opt_, vector, wWinMain(), vector, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 142 - "whisper_build_graph_decoder"
Cohesion: 0.09
Nodes (57): ggml_context, ggml_acc_or_set(), ggml_add(), ggml_add1_or_set(), ggml_add_or_set(), ggml_build_forward_expand(), ggml_cast(), ggml_cont() (+49 more)

### Community 143 - "whisper_adapter.dart"
Cohesion: 0.03
Nodes (68): beamSize, bestOf, cancel, _cancelled, _commands, _config, context, create (+60 more)

### Community 144 - "ggml_nrows"
Cohesion: 0.07
Nodes (67): get_thread_range(), pair, ggml_compute_forward_add1(), ggml_compute_forward_add1_bf16_bf16(), ggml_compute_forward_add1_bf16_f32(), ggml_compute_forward_add1_f16_f16(), ggml_compute_forward_add1_f16_f32(), ggml_compute_forward_add1_f32() (+59 more)

### Community 145 - "Q: sherpa_onnx 替换为 whisper_ggml，给我一个方案"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: sherpa_onnx 替换为 whisper_ggml，给我一个方案, Source Nodes

### Community 146 - "whisper_state"
Cohesion: 0.04
Nodes (53): vad_time_mapping, original_time, processed_time, whisper_state, aheads_cross_QKs, aheads_cross_QKs_data, aheads_masks, backends (+45 more)

### Community 147 - "DateTime"
Cohesion: 0.18
Nodes (10): DateTime, acquiredAt, expiresAt, isActiveAt, leaseId, modelId, ModelUsageLease, ownerId (+2 more)

### Community 148 - "app_state_panel.dart"
Cohesion: 0.13
Nodes (14): app_status_notice.dart, actionLabel, AppStatePanel, _AppStatePanelKind, build, empty, error, icon (+6 more)

### Community 149 - "RecordingAudioWaveform"
Cohesion: 0.18
Nodes (11): PCM16 RMS 实时波形, RecordingPcmChunk, ReliableRecordingService, 有界可丢弃派生音频链, PcmAudioLevelMeter, RecordingAudioWaveform, RecordingSessionViewModel, ReliableRecordingService (+3 more)

### Community 150 - "Q: whisper_ggml transcribeLive 实时（流媒体）转录如何接入当前项目"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: whisper_ggml transcribeLive 实时（流媒体）转录如何接入当前项目, Source Nodes

### Community 151 - "asr/whisper_small_advanced_asr_engine_test.dart"
Cohesion: 0.03
Nodes (59): _FakeWorkerFactory, AsrDeviceRiskState, active, activeVersions, add, bytes, cancel, _changes (+51 more)

### Community 152 - "web/manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 153 - "Q: 读取 whisper_ggml 文档并为 MeetTrace 制定替换 sherpa_onnx 的完整实施方案"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: 读取 whisper_ggml 文档并为 MeetTrace 制定替换 sherpa_onnx 的完整实施方案, Source Nodes

### Community 154 - "Q: 能否直接调用 ggml-org/whisper.cpp"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: 能否直接调用 ggml-org/whisper.cpp, Source Nodes

### Community 155 - "ggml_backend_meta_context"
Cohesion: 0.06
Nodes (36): backend_config, ggml_backend_buffer_ptr, ggml_backend_comm_allreduce_tensor_t, ggml_backend_meta_split_state, ggml_context_ptr, ggml_cgraph, ggml_tensor, map (+28 more)

### Community 156 - "APPLY_STANDARD_SETTINGS"
Cohesion: 0.20
Nodes (10): APPLY_STANDARD_SETTINGS, Relocatable Linux Flutter Bundle, target_compile_definitions, target_compile_features, target_compile_options, APPLY_STANDARD_SETTINGS, target_compile_definitions, target_compile_features (+2 more)

### Community 157 - "Q: 正式替换 sherpa-onnx 后，MeetTrace 的 whisper.cpp 双模型 ASR 架构、实时预览、最终转录、模型生命周期与录音隔离如何连接？"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: 正式替换 sherpa-onnx 后，MeetTrace 的 whisper.cpp 双模型 ASR 架构、实时预览、最终转录、模型生命周期与录音隔离如何连接？, Source Nodes

### Community 159 - "Blocked iOS and Dual-Platform Release"
Cohesion: 0.50
Nodes (4): Independent Android and iOS Acceptance, Blocked iOS and Dual-Platform Release, iPhone and iPad Validation Requirements, Current Android and iOS Implementation Status

### Community 160 - "_"
Cohesion: 0.07
Nodes (29): _PreviewAsrEngine, _, acceptAudio, cancel, _core, descriptor, deviceRisk, deviceRisks (+21 more)

### Community 161 - "增量架构优化"
Cohesion: 0.22
Nodes (9): Domain Port 边界, FinalTranscriptionService, GenerateSummaryUseCase, 增量架构优化, MeetingDetailViewModel, MeetTraceDependencies, RecordingSessionViewModel, Repository Contracts (+1 more)

### Community 163 - "whisper_context_default_params"
Cohesion: 0.20
Nodes (15): whisper_context_default_params(), whisper_context_default_params_by_ref(), whisper_free(), whisper_init(), whisper_init_from_buffer(), whisper_init_from_buffer_no_state(), whisper_init_from_buffer_with_params(), whisper_init_from_buffer_with_params_no_state() (+7 more)

### Community 164 - "gguf_tensor_info"
Cohesion: 0.67
Nodes (3): gguf_tensor_info, offset, t

### Community 165 - "Stream"
Cohesion: 0.14
Nodes (13): AsrPreviewMetrics get, _PreviewSession, AsrPreviewCoordinator, AsrPreviewState, AsrPreviewSession, dispose, events, flush (+5 more)

### Community 166 - "ggml_tensor"
Cohesion: 0.14
Nodes (14): ggml_tensor, buffer, data, extra, flags, name, nb, ne (+6 more)

### Community 167 - "ime.cpp"
Cohesion: 0.08
Nodes (31): bind_ai_thread(), cpu::extra_buffer_type, cpu_set_t, cpu::tensor_traits, ggml_backend_buffer_t, ggml_backend_buffer_type_t, ggml_backend_dev_t, ggml_compute_params (+23 more)

### Community 168 - "quantize_row_iq4_nl_impl"
Cohesion: 0.12
Nodes (18): quantize_row_iq4_nl(), quantize_row_iq4_xs(), best_index_int8(), block_iq4_nl, block_iq4_xs, ggml_fp16_t, dequantize_row_iq4_nl(), dequantize_row_iq4_xs() (+10 more)

### Community 169 - "x86/repack.cpp"
Cohesion: 0.06
Nodes (41): ggml_gemm_q4_0_8x8_q8_0(), ggml_gemv_q4_0_8x8_q8_0(), ggml_gemm_q4_0_8x8_q8_0(), ggml_gemv_q4_0_8x8_q8_0(), ggml_quantize_mat_q8_0_4x8(), __avx512_f32cx8x2_load(), __avx512_repeat_f32cx16_load(), __avx_f32cx8_load() (+33 more)

### Community 170 - "真实录音条件预检"
Cohesion: 0.25
Nodes (8): 未绑定技术预检的静态就绪文案, 首页固定准备就绪文案解释, MeetingReadinessChecker, 首页真实录音条件预检解释, 真实录音条件预检, 窄屏与大字体换行稳定性, 首页预检条重新排版, 预检条双层 Column 布局

### Community 171 - "gguf.cpp"
Cohesion: 0.06
Nodes (42): gguf_find_key(), gguf_get_arr_str(), gguf_get_arr_type(), gguf_get_key(), gguf_get_kv_type(), gguf_get_n_kv(), gguf_get_val_bool(), gguf_get_val_data() (+34 more)

### Community 172 - "ggml_opt_build"
Cohesion: 0.12
Nodes (23): ggml_new_f32(), ggml_new_i32(), ggml_argmax(), ggml_col2im_1d(), ggml_count_equal(), ggml_cross_entropy_loss(), ggml_get_no_alloc(), ggml_get_rows_back() (+15 more)

### Community 173 - "get_scale_min_k4"
Cohesion: 0.23
Nodes (13): quantize_row_q4_K(), quantize_row_q5_K(), block_q4_K, block_q5_K, dequantize_row_q4_K(), dequantize_row_q5_K(), get_scale_min_k4(), quantize_q4_K() (+5 more)

### Community 174 - "tinyBLAS_Q0_AVX"
Cohesion: 0.08
Nodes (31): block_iq4_nl, block_q4_0, block_q5_0, block_q8_0, int8x16_t, __m128i, NOINLINE, gemm() (+23 more)

### Community 175 - "tinyBLAS_PPC"
Cohesion: 0.10
Nodes (13): acc_t, kernel(), tinyBLAS_PPC, A, B, C, ith, k (+5 more)

### Community 176 - "whisper_native_context.dart"
Cohesion: 0.08
Nodes (24): mt_whisper_context>, abiVersion, cancel, cancelAddress, code, dispose, endMs, _handle (+16 more)

### Community 177 - "kleidiai.cpp"
Cohesion: 0.08
Nodes (45): GGML_KLEIDIAI_MAX_KERNEL_SLOTS, align_up(), ceil_div_size(), array, cpu::extra_buffer_type, cpu::tensor_traits, ggml_backend_buffer_t, ggml_backend_buffer_type_t (+37 more)

### Community 178 - "whisper_recognizer_profiles.dart"
Cohesion: 0.12
Nodes (16): WhisperDecodingStrategy, beamSize, bestOf, createConfig, decodingStrategy, id, initialPrompt, noContext (+8 more)

### Community 179 - "UI 渐进迁移顺序"
Cohesion: 0.33
Nodes (6): MeetingDetail 展示职责拆分, 全量 UI 重构方案查询, UI 渐进迁移顺序, S00-S16 与 T01-T03 设计画板范围, Google Stitch 设计文档查询, DESIGN.md 作为 Google Stitch 单一设计源

### Community 180 - "跨平台用户可见品牌身份"
Cohesion: 0.33
Nodes (6): 保留内部技术身份与本地数据, 跨平台用户可见品牌身份, 会迹 · MeetTrace 可见品牌重命名, MeetTrace 全项目身份迁移, MeetTrace 技术与产品统一身份, 新应用身份与旧沙箱数据不迁移

### Community 181 - "Windows databaseFactory 未初始化"
Cohesion: 0.33
Nodes (6): 启动异常映射为通用本地能力错误, Windows 启动异常诊断, Windows databaseFactory 未初始化, PlatformDatabaseFactory, Windows 可移植运行时回退, Windows 启动异常修复

### Community 182 - "二次确认的永久会议删除"
Cohesion: 0.33
Nodes (6): 二次确认的永久会议删除, 会议删除事务数据范围, 会议列表删除功能方案, 仅揭示操作的左滑删除, 一次仅展开一条会议行, 会议列表左滑删除方案

### Community 183 - "录音连续性优先"
Cohesion: 0.33
Nodes (6): 录音连续性优先, RecordingPreviewDispatcher, RecordingSessionViewModel, 有界停止与后台清理, RecordPcmAudioCapture, ReliableRecordingService

### Community 184 - "apply_unary_op_functor"
Cohesion: 0.26
Nodes (12): Op, op, dst_t, src0_t, vec_binary_op_contiguous(), vec_binary_op_non_contiguous(), apply_unary_op_functor(), dst_t (+4 more)

### Community 185 - "ggml_opt_context"
Cohesion: 0.05
Nodes (37): ggml_cgraph, mt19937, ggml_opt_context, allocated_graph, allocated_graph_copy, backend_sched, buf_cpu, buf_static (+29 more)

### Community 186 - "whisper_decoder"
Cohesion: 0.06
Nodes (37): A, B, id, whisper_decoder, completed, failed, grammar, has_ts (+29 more)

### Community 187 - ".supports_op"
Cohesion: 0.25
Nodes (7): cpu::extra_buffer_type, ggml_backend_buffer_type_t, ggml_backend_dev_t, extra_buffer_type, ggml_backend_cpu_repack_buffer_type(), ggml_backend_cpu_repack_buffer_type_get_alignment(), ggml_backend_cpu_repack_buffer_type_get_name()

### Community 188 - "nrow_block_q5_0"
Cohesion: 0.40
Nodes (5): nrow_block_q5_0, qh, qs, scales16, make_block_q5_0x32()

### Community 189 - "whisper_vocab"
Cohesion: 0.13
Nodes (14): map, whisper_vocab, id_to_token, n_vocab, token_beg, token_eot, token_nosp, token_not (+6 more)

### Community 190 - "whisper_vad_segmenter_test.dart"
Cohesion: 0.12
Nodes (17): _IsolateWhisperVadWorker, OfficialWhisperVadWorkerFactory, WhisperVadWorker, WhisperVadWorkerFactory, package:meettrace/data/services/vad/whisper_vad_segmenter.dart, package:meettrace_whisper_native/meettrace_whisper_native.dart, _CountingVadWorkerFactory, create (+9 more)

### Community 191 - "AppSwipeActionRow"
Cohesion: 0.40
Nodes (5): AppSwipeActionRow, DeleteMeetingUseCase, MeetingListView, MeetingListViewModel, 安全左滑删除交互

### Community 192 - "MeetTraceBootstrap"
Cohesion: 0.50
Nodes (5): 本地启动边界, MeetTraceBootstrap, MeetTraceDependencies, MeetTraceStartupErrorView, MeetTraceStartupView

### Community 193 - "AppTimeRuler"
Cohesion: 0.40
Nodes (5): AppTimeRuler, RecordingSessionView, RecordingSessionViewModel, 唯一真实录音时长, _TimeRulerLabels

### Community 194 - "_"
Cohesion: 0.09
Nodes (23): _, acceptAudio, cancel, context, _core, create, descriptor, deviceRisk (+15 more)

### Community 195 - "ggml_backend_registry"
Cohesion: 0.14
Nodes (19): dl_handle_ptr, ggml_backend_reg_name(), ggml_backend_reg_t, vector, ggml_backend_reg_by_name(), ggml_backend_reg_count(), ggml_backend_reg_entry, handle (+11 more)

### Community 196 - "models/manifest.json"
Cohesion: 0.50
Nodes (3): minAppVersion, models, schemaVersion

### Community 197 - "whisper_asr_engine_factory.dart"
Cohesion: 0.07
Nodes (27): ../../../../../domain/models/app_failure.dart, context, create, _createAdvanced, _createStandard, _failure, _finalVadFactory, installations (+19 more)

### Community 198 - "语义化本地日期标签"
Cohesion: 0.50
Nodes (4): AppLedgerRow, 可注入参考时间, Meeting List View, 语义化本地日期标签

### Community 199 - "madd"
Cohesion: 0.14
Nodes (30): float16x8_t, __m256bh, __m512bh, add(), float32x4_t, ggml_bf16_t, __m128, __m256 (+22 more)

### Community 200 - "mmq.cpp"
Cohesion: 0.06
Nodes (25): ALWAYS_INLINE, Func, integral_constant<bool,
    std::is_same<T, block_q4_0>::value ||
    std::is_same<T, block_q4_1>::value>, integral_constant<bool,
    std::is_same<T, block_q4_K>::value ||
    std::is_same<T, block_q5_K>::value ||
    std::is_same<T, block_q6_K>::value ||
    std::is_same<T, block_iq4_xs>::value>, integral_constant<bool,
    std::is_same<T, block_q8_0>::value>, acc_C, do_compensate, do_unpack (+17 more)

### Community 201 - "Strict Casts Inference and Raw Types"
Cohesion: 0.67
Nodes (3): Formatting Analysis Testing and OCR Quality Gate, Flutter Recommended Lints, Strict Casts Inference and Raw Types

### Community 203 - "AppColors"
Cohesion: 1.33
Nodes (3): AppColors, AppStyle, ThemeExtension

### Community 204 - "Project-local Worktree Layout"
Cohesion: 0.67
Nodes (3): Alpha Step Branch Policy, Worktree Safety Rules, Project-local Worktree Layout

### Community 205 - "CAS Atomic Final Snapshot Activation"
Cohesion: 0.67
Nodes (3): CAS Atomic Final Snapshot Activation, Durable File Commit Before Database Reference, Minimal Final-Text Summary Boundary

### Community 206 - "Android Alpha Device Matrix"
Cohesion: 0.67
Nodes (3): Minimum and Low-end Device Acceptance Gap, Android Alpha Device Matrix, Android Alpha Platform Baseline

### Community 207 - "startup_recovery_service.dart"
Cohesion: 0.10
Nodes (19): app_database.dart, ../audio/recording_checkpoint_store.dart, ../../../../../domain/models/recording.dart, durable_file_committer.dart, _activateCompletedSnapshots, activatedSnapshots, _alignRecoverablePcm, database (+11 more)

### Community 208 - "ggml_backend_sched"
Cohesion: 0.06
Nodes (36): ggml_backend_sched_eval_callback, ggml_gallocr_t, ggml_backend_sched, backends, bufts, callback_eval_user_data, context_buffer, context_buffer_size (+28 more)

### Community 209 - "AGENTS.md Contributor Guide Query"
Cohesion: 1.00
Nodes (3): AGENTS.md Contributor Guide Query, Forui 优先 AGENTS.md 重设计查询, AGENTS.md 中文化查询

### Community 210 - "代码实现驱动的视觉系统规范"
Cohesion: 0.67
Nodes (3): Application 注入 Forui 明暗主题, Impeccable DESIGN.md 文档查询, 代码实现驱动的视觉系统规范

### Community 211 - "120ms pressed 颜色混合变体"
Cohesion: 0.67
Nodes (3): 120ms pressed 颜色混合变体, 开始会议按下状态修复, 保持全宽边缘稳定的按下状态

### Community 212 - "connectivity_plus 的 CP936 解码失败"
Cohesion: 0.67
Nodes (3): connectivity_plus 的 CP936 解码失败, 公共 MSVC /utf-8 编译修复, Windows C4819 构建异常

### Community 213 - "项目冗余审计"
Cohesion: 0.67
Nodes (3): 非目标平台脚手架, 无引用组件与过时配置, 项目冗余审计

### Community 214 - "精确锁定 path_provider_android 2.2.23"
Cohesion: 0.67
Nodes (3): Mi 10 Android 11 回归门槛, path_provider_android 直接依赖原因, 精确锁定 path_provider_android 2.2.23

### Community 215 - "Android edge-to-edge 系统栏"
Cohesion: 0.67
Nodes (3): Android edge-to-edge 系统栏, Android 沉浸式标题栏修复, 透明状态栏主题策略

### Community 216 - "ggml-backend-impl.h"
Cohesion: 0.06
Nodes (22): aarch64_features, has_dotprod, has_fp16_va, has_i8mm, has_sme, has_sve, has_sve2, riscv64_features (+14 more)

### Community 217 - "size"
Cohesion: 0.17
Nodes (15): vector, gguf_buffer_reader, data, size, gguf_get_arr_data(), gguf_get_meta_data(), gguf_get_meta_size(), gguf_write_out() (+7 more)

### Community 218 - "ime2_kernels.cpp"
Cohesion: 0.10
Nodes (33): gemm_kernel_i8i2k(), gemm_kernel_i8i2k_m1(), gemm_kernel_i8i2k_m4(), gemm_kernel_i8i4(), gemm_kernel_i8i4_hp(), gemm_kernel_i8i4_hp_m1(), gemm_kernel_i8i4_hp_m4(), gemm_kernel_i8i4_m1() (+25 more)

### Community 219 - "whisper_context"
Cohesion: 0.10
Nodes (23): ggml_backend_tensor_get(), abort_callback, ggml_graph_get_tensor(), ggml_graph_node(), ggml_abort_callback, whisper_context, itype, model (+15 more)

### Community 220 - "kernels.cpp"
Cohesion: 0.07
Nodes (8): cpu_feature, ggml_kleidiai_kernels, ggml_tensor, ggml_kleidiai_select_kernels(), ggml_kleidiai_select_kernels_q4_0(), ggml_kleidiai_select_kernels_q8_0(), kai_rhs_pack_qs4cxs1s0_param, kai_rhs_pack_qsi8cx_params

### Community 221 - "spine_mem_pool_manager"
Cohesion: 0.11
Nodes (16): align_up(), vector, pool_chunk, base, fd, free_blocks, size, spine_mem_pool_hugetlb_1g (+8 more)

### Community 222 - "tinyBLAS_Q0_PPC"
Cohesion: 0.10
Nodes (17): ArrayType, compute(), ggml_fp16_t, vector, pack_q8_block(), tinyBLAS_Q0_PPC, A, B (+9 more)

### Community 223 - "Flutter macOS App Icon"
Cohesion: 0.67
Nodes (3): Flutter Brand Mark, Flutter macOS App Icon, Rounded-Square App Icon Container

### Community 224 - "Flutter macOS App Icon (256×256)"
Cohesion: 0.67
Nodes (3): Flutter Logo Mark, Flutter macOS App Icon (256×256), Rounded-Square Icon Tile

### Community 225 - "Flutter macOS App Icon"
Cohesion: 0.67
Nodes (3): Flutter Brand Mark, Flutter macOS App Icon, Rounded-Square App Icon Container

### Community 226 - "Flutter macOS App Icon"
Cohesion: 0.67
Nodes (3): Flutter Brand Mark, Flutter macOS App Icon, Rounded-Square App Icon Container

### Community 227 - "amx.cpp"
Cohesion: 0.10
Nodes (26): cpu::extra_buffer_type, cpu::tensor_traits, ggml_backend_buffer_t, ggml_backend_buffer_type_t, ggml_backend_dev_t, ggml_tensor, extra_buffer_type, get_tensor_traits() (+18 more)

### Community 228 - "Flutter Web App Icon"
Cohesion: 0.67
Nodes (3): Flutter Brand Mark, Flutter Web App Icon, Progressive Web App Icon Asset

### Community 229 - "Flutter Maskable Web Icon (192×192)"
Cohesion: 0.67
Nodes (3): Flutter Logo Mark, Flutter Maskable Web Icon (192×192), Maskable Icon Safe-Area Composition

### Community 230 - "MeetTrace Web Shell"
Cohesion: 0.67
Nodes (3): Flutter Web Bootstrap, 本地优先会议录音与端侧转录应用, MeetTrace Web Shell

### Community 234 - "sgemm.cpp"
Cohesion: 0.12
Nodes (12): BLOC_POS(), array, size, gemm_Mx8(), gemm_small(), llamafile_sgemm(), mma_instr, mma_instr<ggml_bf16_t> (+4 more)

### Community 239 - "ggml_kleidiai_context"
Cohesion: 0.22
Nodes (9): cpu_feature, cpu_feature_to_string(), ggml_kleidiai_context, chunk_multiplier, features, kernels_q4, kernels_q8, sme_thread_cap (+1 more)

### Community 251 - "spine_env_info"
Cohesion: 0.08
Nodes (29): vector, spine_mem_pool_backend, spine_core_info, arch_id, core_id, get_spine_core_info, spine_env_info, aicpu_id_offset (+21 more)

### Community 252 - "ggml_graph_dump_dot"
Cohesion: 0.23
Nodes (12): FILE, wchar_t, ggml_fopen(), ggml_graph_dump_dot(), ggml_graph_dump_dot_leaf_edge(), ggml_graph_dump_dot_node_edge(), ggml_graph_find(), ggml_graph_get_grad() (+4 more)

### Community 260 - "gguf_get_n_tensors"
Cohesion: 0.29
Nodes (8): gguf_add_tensor(), gguf_find_tensor(), gguf_get_n_tensors(), gguf_get_tensor_name(), gguf_get_tensor_offset(), gguf_get_tensor_size(), gguf_get_tensor_type(), gguf_set_tensor_data()

### Community 272 - "nrow_block_q3_k"
Cohesion: 0.40
Nodes (5): nrow_block_q3_k, hmask, qs, scales, scales16

### Community 273 - "local_data_control.dart"
Cohesion: 0.33
Nodes (5): LocalDataControlService, buildDiagnostics, LocalDataControlPort, measure, ../models/data_control.dart

### Community 274 - "audio_source.dart"
Cohesion: 0.33
Nodes (5): AudioSource, channelCount, durationMs, path, sampleRate

### Community 276 - "model_manifest_parser.dart"
Cohesion: 0.10
Nodes (20): 0, _compareVersions, currentAppVersion, leftParts, normalized, parse, _parseEntry, _parseFile (+12 more)

### Community 285 - "Step 21：C++ Whisper 质量交付基线"
Cohesion: 0.14
Nodes (13): 10. OCR 代码审查, 1. 产品与架构边界, 2. 工具链, 3. 可复现基线, 4. 已确认缺口, 5.1 公开回归轨道, 5.2 确定性非语音烟测轨道, 5. 评测输入契约 (+5 more)

### Community 308 - "Step 23～24：官方 VAD、预览与最终转录"
Cohesion: 0.29
Nodes (6): 1. 固定资产与原生边界, 2. 会中预览, 3. 最终转录, 4. 自动化与模拟器证据, 5. Hard Gate 3～4, Step 23～24：官方 VAD、预览与最终转录

### Community 309 - "ggml-cpp.h"
Cohesion: 0.10
Nodes (11): gguf_context, ggml_backend_buffer_deleter, ggml_backend_deleter, ggml_backend_sched_deleter, ggml_context_deleter, ggml_gallocr_deleter, gguf_context_deleter, ggml_backend_buffer_t (+3 more)

### Community 310 - "LocalFactFooter"
Cohesion: 0.67
Nodes (3): 合并本地音频事实说明, 本地事实音频底栏替代方案, LocalFactFooter

### Community 313 - "Segment"
Cohesion: 0.33
Nodes (6): Metrics, Segment, end_ms, start_ms, text, _PreviewSession

### Community 314 - "Step 22：Whisper 解码参数评测"
Cohesion: 0.33
Nodes (5): 1. 已实现能力, 2. 候选 Profile, 3. 可复现评测, 4. Hard Gate 2, Step 22：Whisper 解码参数评测

### Community 333 - "ggml_opt_dataset"
Cohesion: 0.13
Nodes (17): ggml_opt_dataset_t, ggml_backend_buffer_t, get_opt_pars, ggml_opt_dataset, buf, ctx, data, ggml_opt_dataset_free() (+9 more)

### Community 339 - "whisper_quality_metrics_test.dart"
Cohesion: 0.29
Nodes (6): _asVadObservation, _input, main, samples, ../../../tool/benchmarks/whisper_quality_metrics.dart, WhisperQualityMetricsException

### Community 343 - "Q: start meeting readiness model installation whisper initialization failure"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: start meeting readiness model installation whisper initialization failure, Source Nodes

### Community 345 - "quantize_q4_0"
Cohesion: 0.47
Nodes (6): quantize_row_q4_0(), block_q4_0, dequantize_row_q4_0(), quantize_q4_0(), quantize_row_q4_0_impl(), quantize_row_q4_0_ref()

### Community 359 - "WhisperWorker"
Cohesion: 0.50
Nodes (4): _IsolateWhisperWorker, WhisperWorker, _FakeWorker, _FakeWorker

### Community 360 - "ggml_opt_result_t"
Cohesion: 0.20
Nodes (12): ggml_opt_result_t, vector, ggml_opt_result, ggml_opt_result_free(), ggml_opt_result_init(), loss, loss_per_datapoint, ncorrect (+4 more)

### Community 366 - "ggml_new_graph_custom"
Cohesion: 0.22
Nodes (13): ggml_build_forward_impl(), ggml_build_forward_select(), ggml_graph_clear(), ggml_graph_nbytes(), ggml_hash_set_new(), ggml_hash_set_reset(), ggml_hash_size(), ggml_new_buffer() (+5 more)

### Community 367 - "quantize_q4_1"
Cohesion: 0.47
Nodes (6): quantize_row_q4_1(), block_q4_1, dequantize_row_q4_1(), quantize_q4_1(), quantize_row_q4_1_impl(), quantize_row_q4_1_ref()

### Community 391 - "dart:async"
Cohesion: 0.06
Nodes (32): dart:async, ../../../../../domain/models/asr_preview.dart, int get, _FailingVoiceActivitySegmenter, accept, _availableEndSample, dispose, _disposed (+24 more)

### Community 392 - "size"
Cohesion: 0.09
Nodes (54): function, ggml_backend_t, ggml_backend_alloc_ctx_tensors(), ggml_backend_free(), ggml_backend_sched_alloc_graph(), ggml_backend_tensor_set(), ggml_cpu_init(), ggml_free() (+46 more)

### Community 393 - "tinyBLAS_RVV"
Cohesion: 0.07
Nodes (35): ggml_compute_params, TA, TB, TC, tinyBLAS, A, B, C (+27 more)

### Community 394 - "whisper_model"
Cohesion: 0.05
Nodes (38): e_model, whisper_layer_encoder, attn_k_w, attn_ln_0_b, attn_ln_0_w, attn_ln_1_b, attn_ln_1_w, attn_q_b (+30 more)

### Community 395 - "rvv_kernels.cpp"
Cohesion: 0.16
Nodes (26): _Float16, vfloat32m2_t, forward_flash_attn_ext_f16_tiled_vlen1024_vf16(), memcpy1d(), memcpy2d(), reduce_sum_f32m2_vlen1024(), rvv_add_inplace_f32(), rvv_add_max_inplace_f32() (+18 more)

### Community 396 - "simd-mappings.h"
Cohesion: 0.16
Nodes (24): __avx_f32cx8_load(), __avx_f32cx8_store(), ggml_lookup_fp16_to_fp32(), float32x4_t, ggml_fp16_t, __m128, __m256, __lasx_f32cx8_load() (+16 more)

### Community 397 - "c_library.dart"
Cohesion: 0.08
Nodes (23): package:code_assets/code_assets.dart, package:hooks/hooks.dart, package:meettrace_whisper_native/src/c_library.dart, package:native_toolchain_c/native_toolchain_c.dart, arguments, build, buildWhisperLibrary, main (+15 more)

### Community 398 - "spacemit/repack.cpp"
Cohesion: 0.22
Nodes (23): ggml_tensor, get_scale_min_k4(), make_block_q5_1x32(), repack(), repack_q2_k_to_q2_k_32_bl(), repack_q3_k_to_q3_k_32_bl(), repack_q4_0_to_q4_0_16_bl(), repack_q4_0_to_q4_0_256_32_bl_ref() (+15 more)

### Community 400 - "whisper_layer_decoder"
Cohesion: 0.08
Nodes (25): whisper_layer_decoder, attn_k_w, attn_ln_0_b, attn_ln_0_w, attn_ln_1_b, attn_ln_1_w, attn_q_b, attn_q_w (+17 more)

### Community 401 - "pack_qs"
Cohesion: 0.12
Nodes (22): acc_C<block_q8_0, block_q4_0, is_acc>, acc_C<block_q8_0, block_q8_0, is_acc>, bytes_from_nibbles_128(), bytes_from_nibbles_32(), bytes_from_nibbles_64(), convert_B_packed_format(), block_iq4_xs, block_q4_0 (+14 more)

### Community 403 - "ggml_graph_compute"
Cohesion: 0.12
Nodes (29): atomic_int, LONG, memory_order, atomic_fetch_add(), atomic_load(), atomic_load_explicit(), atomic_store(), atomic_store_explicit() (+21 more)

### Community 404 - "whisper_batch"
Cohesion: 0.11
Nodes (23): set, whisper_batch, logits, n_seq_id, n_tokens, pos, seq_id, token (+15 more)

### Community 405 - "app_failure.dart"
Cohesion: 0.17
Nodes (11): AppFailure, code, diagnosticContext, FailureRecoverability, FailureStage, FailureUserAction, modelId, modelVersion (+3 more)

### Community 407 - "weight_buft_supported"
Cohesion: 0.06
Nodes (42): buft_list_t, ggml_op, ggml_n_dims(), byteswap(), byteswap_tensor(), byteswap_tensor_data(), ggml_backend_buffer_type_t, ggml_backend_dev_t (+34 more)

### Community 409 - "quantize_row_q8_0_ref"
Cohesion: 0.25
Nodes (8): quantize_row_q8_0(), quantize_row_q8_0(), quantize_row_q8_0(), quantize_row_q8_0(), quantize_row_q8_0(), quantize_row_q8_0_generic(), quantize_q8_0(), quantize_row_q8_0_ref()

### Community 411 - "spine_tcm.h"
Cohesion: 0.26
Nodes (19): spine_mem_pool_tcm_init(), spine_tcm_block_info(), spine_tcm_default_handle(), spine_tcm_handle_bind(), spine_tcm_handle_reset(), spine_tcm_is_available(), spine_tcm_mem_force_release(), spine_tcm_mem_free() (+11 more)

### Community 413 - "ggml_type_name"
Cohesion: 0.33
Nodes (6): ggml_compute_forward_xielu(), op_xielu(), unary_op(), unary_op_functor(), unary_op_params(), ggml_type_name()

### Community 414 - "gguf_init_from_reader"
Cohesion: 0.15
Nodes (14): gguf_reader_callback_t, ggml_set_no_alloc(), gguf_free(), gguf_init_from_buffer(), gguf_init_from_callback(), gguf_init_from_reader(), gguf_read_emplace_helper(), gguf_reader (+6 more)

### Community 415 - "ggml-cpu/common.h"
Cohesion: 0.12
Nodes (14): bf16_to_f32(), f16_to_f32(), f32_to_bf16(), f32_to_f16(), ggml_fa_tile_config, KV, Q, ggml_bf16_t (+6 more)

### Community 416 - "quantize_row_tq2_0_ref"
Cohesion: 0.40
Nodes (5): block_tq2_0, quantize_row_tq2_0(), dequantize_row_tq2_0(), quantize_row_tq2_0_ref(), quantize_tq2_0()

### Community 417 - "nrow_block_q2_k"
Cohesion: 0.40
Nodes (5): nrow_block_q2_k, qs, scales, scales16, zeros16

### Community 418 - "MessageHandler"
Cohesion: 0.33
Nodes (6): HWND, LPARAM, LRESULT, UINT, WPARAM, MessageHandler

### Community 419 - "make_buft_list"
Cohesion: 0.25
Nodes (18): ggml_backend_dev_init(), ggml_backend_dev_name(), ggml_backend_dev_type(), ggml_backend_dev_t, ggml_backend_t, ggml_backend_dev_by_name(), ggml_backend_dev_by_type(), ggml_backend_dev_count() (+10 more)

### Community 421 - "whisper_global"
Cohesion: 0.25
Nodes (8): ggml_log_level, ggml_log_callback, whisper_global, log_callback, log_callback_user_data, whisper_log_callback_default(), whisper_log_internal(), whisper_log_set()

### Community 422 - "ggml_backend_event_free"
Cohesion: 0.50
Nodes (3): ggml_backend_event_deleter, ggml_backend_event_t, ggml_backend_event_free()

### Community 424 - "asr_model_registry.dart"
Cohesion: 0.15
Nodes (12): asr_model.dart, AsrModelDescriptor get, alpha, _byId, defaultModel, defaultModelId, findById, models (+4 more)

### Community 425 - "gguf_set_kv"
Cohesion: 0.31
Nodes (17): gguf_check_reserved_keys(), gguf_remove_key(), gguf_set_arr_data(), gguf_set_arr_str(), gguf_set_kv(), gguf_set_val_bool(), gguf_set_val_f32(), gguf_set_val_f64() (+9 more)

### Community 426 - "gguf_context"
Cohesion: 0.25
Nodes (8): gguf_context, alignment, data, info, kv, offset, size, version

### Community 427 - "quantize_q6_K"
Cohesion: 0.40
Nodes (6): quantize_row_q6_K(), block_q6_K, dequantize_row_q6_K(), quantize_q6_K(), quantize_row_q6_K_impl(), quantize_row_q6_K_ref()

### Community 428 - ".compute_forward"
Cohesion: 0.23
Nodes (9): apply_binary_op(), binary_op(), ggml_compute_params, ggml_tensor, ggml_compute_forward_add_non_quantized(), ggml_compute_forward_div(), ggml_compute_forward_mul(), ggml_compute_forward_sub() (+1 more)

### Community 430 - "x86/cpu-feats.cpp"
Cohesion: 0.50
Nodes (3): bitset, cpuid(), cpuidex()

### Community 431 - "Q: clang: warning: -Wl,-z,max-page-size=16384: linker input unused 是否影响 Android 16KB page-size 兼容性"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: clang: warning: -Wl,-z,max-page-size=16384: linker input unused 是否影响 Android 16KB page-size 兼容性, Source Nodes

### Community 432 - "pool_allocation"
Cohesion: 0.17
Nodes (10): iterator, align_up_uintptr(), free_block, offset, size, pool_allocation, base, chunk_base (+2 more)

### Community 433 - "ggml_conv_2d_dw_params"
Cohesion: 0.13
Nodes (15): ggml_conv_2d_dw_params, batch, channels, dilation_x, dilation_y, dst_h, dst_w, knl_h (+7 more)

### Community 435 - "AppDelegate"
Cohesion: 0.16
Nodes (10): Any, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, AppDelegate, Bool, AppDelegate, Bool (+2 more)

### Community 436 - "amx/common.h"
Cohesion: 0.21
Nodes (12): func_t, balance211(), div_up(), ggml_compute_params, T, parallel_for(), parallel_for_ggml(), ggml_compute_params (+4 more)

### Community 437 - "spine_mem_pool.cpp"
Cohesion: 0.12
Nodes (13): hugetlb_1g_region, dma_addr, flags, reserved, size, is_power_of_two(), spine_mem_pool_alloc(), spine_mem_pool_free() (+5 more)

### Community 438 - "ggml_backend_plan_cpu"
Cohesion: 0.67
Nodes (3): ggml_backend_plan_cpu, cgraph, cplan

### Community 439 - "ggml_tensor"
Cohesion: 0.28
Nodes (13): ggml_compute_params, ggml_tensor, forward_cont_with_permute(), forward_cpy_with_permute(), forward_flash_attn_ext_f16_one_chunk_vlen1024_vf16(), forward_get_rows(), forward_norm_f32(), forward_repeat_dim1() (+5 more)

### Community 440 - "asr_model.dart"
Cohesion: 0.17
Nodes (11): AsrInstallationType, AsrModelDescriptor, AsrModelTier, capabilities, displayName, installationType, modelId, requiredBytes (+3 more)

### Community 441 - "Win32Window"
Cohesion: 0.13
Nodes (19): RECT, unique_ptr, DartProject, FlutterWindow, flutter_controller_, FlutterWindow::FlutterWindow(), OnCreate, OnDestroy (+11 more)

### Community 442 - "quantize_row_nvfp4_ref"
Cohesion: 0.15
Nodes (14): block_nvfp4, ggml_vec_dot_nvfp4_q8_0_generic(), quantize_row_mxfp4(), quantize_row_nvfp4(), ggml_fp32_to_ue4m3(), ggml_ue4m3_to_fp32(), best_index_mxfp4(), block_mxfp4 (+6 more)

### Community 445 - "unpack_A"
Cohesion: 0.18
Nodes (8): acc_C<block_q8_1, block_q4_1, is_acc>, block_q8_1, TA, TC, tinygemm_kernel_amx(), tinygemm_kernel_avx, tinygemm_kernel_vnni<block_q8_K, block_iq4_xs, float, BLOCK_M, BLOCK_N, BLOCK_K>, unpack_A()

### Community 447 - "nearest_int"
Cohesion: 0.13
Nodes (22): block_q3_K, quantize_row_q2_K(), quantize_row_q3_K(), block_q2_K, dequantize_row_q2_K(), dequantize_row_q3_K(), iq2_find_best_neighbour(), make_q3_quants() (+14 more)

### Community 448 - "prepare_whisper_quality_corpus.dart"
Cohesion: 0.17
Nodes (11): corpus, index, main, manifest, output, outputFile, repositoryRoot, requiredEvidenceClass (+3 more)

### Community 449 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.17
Nodes (10): audioplayers_darwin, connectivity_plus, FlutterPluginRegistry, FlutterViewController, Foundation, RegisterGeneratedPlugins(), record_macos, share_plus (+2 more)

### Community 450 - "make_block_q4_0x32"
Cohesion: 0.20
Nodes (10): block_q4_0x32, block_q4_0x32x256, blocks, block_q4_1x32x256, blocks, zps, block_q4_0, block_q4_0x16 (+2 more)

### Community 451 - "gguf_writer_file"
Cohesion: 0.22
Nodes (9): FILE, gguf_file_reader, file, offset, gguf_init_from_file_ptr(), gguf_write_to_file(), gguf_write_to_file_ptr(), gguf_writer_file (+1 more)

### Community 452 - "MessageHandler"
Cohesion: 0.36
Nodes (10): HWND, LPARAM, LRESULT, UINT, WPARAM, EnableFullDpiSupportIfAvailable(), GetHandle, GetThisFromHandle (+2 more)

### Community 454 - "block_q8_K"
Cohesion: 0.22
Nodes (5): acc_C<block_q8_K, block_iq4_xs, is_acc>, acc_C<block_q8_K, block_q4_K, is_acc>, acc_C<block_q8_K, block_q5_K, is_acc>, acc_C<block_q8_K, block_q6_K, is_acc>, block_q8_K

### Community 456 - "q8k_blk_size"
Cohesion: 0.25
Nodes (9): gemm_kernel_i8i2k_mrow_ref(), gemm_kernel_i8i3k(), gemm_kernel_i8i3k_m1(), gemm_kernel_i8i3k_m4(), gemm_kernel_i8i3k_mrow_ref(), q8k_blk_size(), quantize_a_4row_i8k(), quantize_a_nrow_i8k_ref() (+1 more)

### Community 459 - "tensor_traits_base"
Cohesion: 0.67
Nodes (3): cpu::tensor_traits, tensor_traits_base, repack

### Community 462 - "data_control.dart"
Cohesion: 0.20
Nodes (9): databaseBytes, DiagnosticReport, fields, freeBytes, LocalStorageUsage, meetingBytes, modelBytes, toJsonText (+1 more)

### Community 463 - "ime_kernels.h"
Cohesion: 0.15
Nodes (13): nrow_block_mxfp4, e, qh, qs, nrow_block_q5_1, qh, qs, scales16 (+5 more)

### Community 464 - "block_with_zp"
Cohesion: 0.25
Nodes (8): block, d, qs, block_with_zp, d, qs, zp, ggml_half

### Community 465 - "flash_attn_ext_f16_one_chunk_inner_vlen1024_vf16_mrow"
Cohesion: 0.32
Nodes (8): align_up(), ggml_fp16_t, vfloat32m4_t, flash_attn_ext_f16_one_chunk_inner_vlen1024_vf16_m1(), flash_attn_ext_f16_one_chunk_inner_vlen1024_vf16_mrow(), flash_attn_ext_supported_d_vlen1024_vf16(), flash_attn_ext_supported_shape_vlen1024_vf16(), reduce_sum_f32m4_vlen1024()

### Community 468 - "rvv_kernels.h"
Cohesion: 0.33
Nodes (6): gemm_kernel_i8i4_hp_mrow_ref(), div_round_up(), q8_hp_blk_size(), quantize_a_4row_i8_hp(), quantize_a_nrow_i8_hp_ref(), quantize_a_row_i8_hp()

### Community 469 - "whisper_global_cache"
Cohesion: 0.38
Nodes (4): whisper_global_cache, cos_vals, hann_window, sin_vals

### Community 470 - "ggml_quantize_chunk"
Cohesion: 0.13
Nodes (17): block_iq2_s, block_q1_0, block_q5_1, quantize_row_q1_0(), quantize_row_q5_1(), ggml_quantize_chunk(), ggml_quantize_requires_imatrix(), dequantize_row_iq2_s() (+9 more)

### Community 472 - "Step 20：whisper.cpp 正式替换"
Cohesion: 0.33
Nodes (5): Step 20：whisper.cpp 正式替换, 变更, 已验证, 未完成, 真机复验入口

### Community 477 - "ggml_backend_graph_copy"
Cohesion: 0.33
Nodes (6): ggml_backend_graph_copy, buffer, ctx_allocated, ctx_unallocated, graph, ggml_backend_buffer_t

### Community 478 - "ggml_backend_sched_split"
Cohesion: 0.33
Nodes (6): ggml_backend_sched_split, backend_id, i_end, i_start, inputs, n_inputs

### Community 479 - "tile_config_t"
Cohesion: 0.33
Nodes (6): tile_config_t, colsb, palette_id, reserved_0, rows, start_row

### Community 485 - "make_block_q4_1x16"
Cohesion: 0.40
Nodes (5): block_q4_1x16, block_q4_1x32, block_q4_1, make_block_q4_1x16(), make_block_q4_1x32()

### Community 486 - "ggml_backend_dev_props"
Cohesion: 0.25
Nodes (8): ggml_backend_dev_props, caps, description, device_id, memory_free, memory_total, name, type

### Community 487 - "hbm.cpp"
Cohesion: 0.31
Nodes (7): ggml_backend_cpu_buffer_type_get_alignment(), ggml_backend_buffer_t, ggml_backend_buffer_type_t, ggml_backend_cpu_hbm_buffer_free_buffer(), ggml_backend_cpu_hbm_buffer_type(), ggml_backend_cpu_hbm_buffer_type_alloc_buffer(), ggml_backend_cpu_hbm_buffer_type_get_name()

### Community 490 - "ggml_opt_fit"
Cohesion: 0.33
Nodes (7): ggml_opt_get_optimizer_params, ggml_backend_sched_t, ggml_tensor, map, ggml_opt_default_params(), ggml_opt_fit(), map_tensor()

### Community 491 - "quantize_row_q8_K_ref"
Cohesion: 0.25
Nodes (8): quantize_row_q8_K(), quantize_row_q8_K(), quantize_row_q8_K(), quantize_row_q8_K(), quantize_row_q8_K_generic(), block_q8_K, dequantize_row_q8_K(), quantize_row_q8_K_ref()

### Community 493 - "quantize_row_tq1_0_ref"
Cohesion: 0.40
Nodes (5): block_tq1_0, quantize_row_tq1_0(), dequantize_row_tq1_0(), quantize_row_tq1_0_ref(), quantize_tq1_0()

### Community 494 - "ggml-quants.c"
Cohesion: 0.08
Nodes (34): block_iq1_m, block_iq1_s, block_iq2_xs, block_iq2_xxs, block_iq3_s, block_iq3_xxs, ggml_quantize_free(), block_q8_0 (+26 more)

### Community 495 - "kleidiai_block_args"
Cohesion: 0.33
Nodes (6): ggml_type, kleidiai_block_args, lhs_bl, pack_bl, rhs_bl, kleidiai_get_block_args()

### Community 499 - "ggml_backend_dev_caps"
Cohesion: 0.40
Nodes (5): ggml_backend_dev_caps, async, buffer_from_host_ptr, events, host_buffer

### Community 500 - "ggml_backend_meta_split_state"
Cohesion: 0.40
Nodes (5): ggml_backend_meta_split_state, axis, n_segments, ne, nr

### Community 501 - "ggml_init_params"
Cohesion: 0.40
Nodes (4): ggml_init_params, mem_buffer, mem_size, no_alloc

### Community 502 - "ime_env.cpp"
Cohesion: 0.19
Nodes (12): spine_mem_pool_backend, hex_string_to_u16(), parse_mem_backend(), spine_env_info::spine_env_info(), spine_mem_pool_backend_to_string(), spine_mem_pool_shared_mem_free(), spine_mem_pool_tcm_info, available (+4 more)

### Community 503 - "atomic_flag_test_and_set"
Cohesion: 0.50
Nodes (4): atomic_flag, atomic_flag_clear(), atomic_flag_test_and_set(), atomic_bool

### Community 505 - "WhisperWorkerFactory"
Cohesion: 0.50
Nodes (4): OfficialWhisperWorkerFactory, WhisperWorkerFactory, _FakeWorkerFactory, _FakeWorkerFactory

### Community 506 - "ggml_set_abort_callback"
Cohesion: 0.67
Nodes (3): ggml_abort_callback_t, GGML_API, ggml_set_abort_callback()

### Community 507 - "ggml_backend_feature"
Cohesion: 0.67
Nodes (3): ggml_backend_feature, name, value

### Community 518 - "Q: 分析当前项目的本地模型，是否需要更换模型或组合模型"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: 分析当前项目的本地模型，是否需要更换模型或组合模型, Source Nodes

### Community 519 - "Q: 分析各个模型"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: 分析各个模型, Source Nodes

### Community 520 - "Q: https://github.com/moonshine-ai/moonshine"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: https://github.com/moonshine-ai/moonshine, Source Nodes

### Community 521 - "Q: sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2025-09-09"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2025-09-09, Source Nodes

### Community 522 - "Q: ggml-org/whisper.cpp"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: ggml-org/whisper.cpp, Source Nodes

### Community 531 - "make_block_q8_0x32"
Cohesion: 0.67
Nodes (3): block_q8_0x32, block_q8_0, make_block_q8_0x32()

## Knowledge Gaps
- **4629 isolated node(s):** `schemaVersion`, `minAppVersion`, `models`, `_MeetingFlowFixture`, `_modelAsset` (+4624 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **170 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Work-memory lessons

**Preferred sources** — corroborated by past sessions; start here.
- `AsrModelRegistry` (9× useful, score=8.768365603) _(code changed — re-verify)_
- `AsrPreviewCoordinator` (7× useful, score=6.833449021) _(code changed — re-verify)_
- `meeting_list_view.dart` (7× useful, score=6.615026485) _(code changed — re-verify)_
- `theme.dart` (5× useful, score=4.664654037) _(code changed — re-verify)_
- `Application` (5× useful, score=4.663849221)
- `AsrEngine` (4× useful, score=3.904767704) _(code changed — re-verify)_
- `Meeting` (4× useful, score=3.746704252)
- `supportedLanguages` (3× useful, score=2.926484443)
- `meeting_detail_view.dart` (3× useful, score=2.799642011) _(code changed — re-verify)_
- `AppDatabase` (3× useful, score=2.794292349)

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `_string` connect `_string` to `use_cases/evaluate_alpha_release.dart`, `cpuid_x86`, `size`, `whisper_model`, `vector`, `whisper_state`, `ggml_backend_meta_context`, `gguf_init_from_reader`, `ggml_backend_load_best`, `gguf_set_kv`, `gguf.cpp`, `x86/cpu-feats.cpp`, `Segment`, `whisper_decoder`, `ggml_backend_buffer_type_t`, `whisper_vad_context`, `whisper.cpp`, `ggml-cpu.cpp`, `ggml-backend-reg.cpp`, `whisper_vad_model`, `size`, `whisper_context`, `meettrace_whisper.cpp`, `vector`, `ime_env.cpp`, `ggml-backend-meta.cpp`, `mt_whisper_vad_context`?**
  _High betweenness centrality (0.188) - this node is a cross-community bridge._
- **Why does `cpuid_x86` connect `cpuid_x86` to `_string`, `x86/cpu-feats.cpp`, `ggml_backend_cpu_x86_score`?**
  _High betweenness centrality (0.023) - this node is a cross-community bridge._
- **Why does `ggml_type_size()` connect `ggml_is_contiguous` to `quantize_row_iq4_nl_impl`, `size`, `rvv_kernels.cpp`, `ggml_opt_build`, `whisper_build_graph_decoder`, `ggml_nrows`, `ggml_new_tensor`, `ops.cpp`, `ggml.c`, `gguf_init_from_reader`?**
  _High betweenness centrality (0.016) - this node is a cross-community bridge._
- **Are the 98 inferred relationships involving `ggml_nrows()` (e.g. with `get_thread_range()` and `ggml_get_n_tasks()`) actually correct?**
  _`ggml_nrows()` has 98 INFERRED edges - model-reasoned connections that need verification._
- **Are the 93 inferred relationships involving `ggml_compute_forward()` (e.g. with `ggml_compute_forward_div()` and `ggml_compute_forward_mul()`) actually correct?**
  _`ggml_compute_forward()` has 93 INFERRED edges - model-reasoned connections that need verification._
- **What connects `schemaVersion`, `minAppVersion`, `models` to the rest of the system?**
  _4629 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `meeting_detail_view_model.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.01679328268692523 - nodes in this community are weakly interconnected._
