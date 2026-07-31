# Graph Report - codex-whisper-cpp-quality-phases-0-4  (2026-07-31)

## Corpus Check
- 495 files · ~727,317 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 9873 nodes · 18239 edges · 521 communities (350 shown, 171 thin omitted)
- Extraction: 88% EXTRACTED · 12% INFERRED · 0% AMBIGUOUS · INFERRED: 2129 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `7cc4d646`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- meeting_detail_view_model.dart
- asr_preview_coordinator.dart
- meettrace_dependencies.dart
- meeting_detail_view.dart
- use_cases/evaluate_alpha_release.dart
- bundled_model_preparation_service_test.dart
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
- whisper_build_graph_decoder
- meeting_detail_view_model_test.dart
- ops.cpp
- meeting_list_previews.dart
- whisper_quality_protocol.dart
- recording_session_view.dart
- generate_summary_test.dart
- rebuild_android_emulator_smoke_evidence.dart
- fetch_ascend_public_regression.dart
- recording_session_view_model.dart
- android_emulator_meeting_flow_test.dart
- speaker_diarization_coordinator_test.dart
- whisper_quality_metrics.dart
- sqflite_model_installation_repository.dart
- android_whisper_quality_benchmark_test.dart
- run_speaker_diarization.dart
- ggml_dup_tensor
- generate_synthetic_noise_corpus.dart
- reliable_recording_service_test.dart
- downloadable_model_service_test.dart
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
- ggml-backend.cpp
- model_settings_view.dart
- ggml.c
- my_application.cc
- model_settings_view_model.dart
- ggml_compute_backward
- app_swipe_action_row.dart
- x86/quants.c
- whisper_asr_engine_factory_test.dart
- recording_previews.dart
- meeting_detail_view_test.dart
- benchmarks/evaluate_alpha_release.dart
- data_controls_view_model.dart
- summary.dart
- ggml_new_tensor
- bool get
- whisper.cpp
- asr_preview.dart
- dart:typed_data
- ggml-cpu.cpp
- ggml-backend-reg.cpp
- phase_0_4_quality_input_builder.dart
- size
- recording_device_readiness_probe_test.dart
- android_proc_asr_device_risk_monitor.dart
- whisper_decoder
- whisper_quality_protocol_test.dart
- vec.h
- unary-ops.cpp
- meettrace_whisper.g.dart
- recording.dart
- ggml_set_op_params_i32
- model_manifest.dart
- MeetingRepository
- whisper_vad_model
- List
- repositories.dart
- ggml-cpu/repack.cpp
- models/speaker_diarization.dart
- run_final_transcription.dart
- vector
- return
- recording_bootstrap_view.dart
- final_transcription_fakes.dart
- domain_ports_test.dart
- dart:convert
- plan_asr_preview_windows.dart
- build_spike_sample.dart
- riscv/quants.c
- ggml-cpu/quants.c
- Codex 实施计划：whisper.cpp 质量强化与双平台交付
- Stream
- whisper_model
- workflow_states.dart
- whisper_asr_engine.dart
- sqflite_summary_repository.dart
- semantic_date_time.dart
- flutter_foreground_recording_lifecycle.dart
- meettrace_whisper.cpp
- Android + iOS 自适应范围
- loongarch/quants.c
- _
- package:flutter/services.dart
- generate_summary.dart
- fetch_ascend_public_regression_test.dart
- package:flutter_test/flutter_test.dart
- ggml-backend-meta.cpp
- arm/repack.cpp
- meeting_detail_previews.dart
- ../../../../theme/theme.dart
- MeetTrace Android and iOS Alpha PRD V0.6
- app_ledger.dart
- ggml-cpu.c
- ggml-impl.h
- processing_task.dart
- ggml-opt.cpp
- Components
- recording_session_view_model_test.dart
- model_installation.dart
- ggml_is_contiguous
- package:meettrace/domain/models/workflow_states.dart
- ggml-cpu-impl.h
- cpuid_x86
- whisper_vad_native_context.dart
- recording_pcm_diagnostics.dart
- ggml-alloc.c
- Q: 评估 whisper_ggml 是否适合作为会迹当前本地 ASR 模型或运行时
- vector
- size
- whisper_adapter.dart
- get_thread_range
- Q: sherpa_onnx 替换为 whisper_ggml，给我一个方案
- whisper_state
- DateTime
- whisper_full_with_state
- RecordingAudioWaveform
- Q: whisper_ggml transcribeLive 实时（流媒体）转录如何接入当前项目
- asr/whisper_small_advanced_asr_engine_test.dart
- web/manifest.json
- Q: 读取 whisper_ggml 文档并为 MeetTrace 制定替换 sherpa_onnx 的完整实施方案
- Q: 能否直接调用 ggml-org/whisper.cpp
- ggml_backend_meta_context
- APPLY_STANDARD_SETTINGS
- Q: 正式替换 sherpa-onnx 后，MeetTrace 的 whisper.cpp 双模型 ASR 架构、实时预览、最终转录、模型生命周期与录音隔离如何连接？
- asr/whisper_base_standard_asr_engine_test.dart
- Blocked iOS and Dual-Platform Release
- _
- 增量架构优化
- whisper_decode_internal
- app_file_layout.dart
- ggml_v_silu
- gemv
- local_data_control_service.dart
- ime.cpp
- s390/quants.c
- x86/repack.cpp
- 真实录音条件预检
- gguf.cpp
- q8_blk_size
- nearest_int
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
- platform_download_preflight_providers.dart
- ggml_opt_context
- _string
- .supports_op
- iq2_data_index
- ggml_new_graph_custom
- whisper_vad_segmenter_test.dart
- AppSwipeActionRow
- MeetTraceBootstrap
- AppTimeRuler
- quantize_row_q8_K_ref
- model_settings_view_test.dart
- models/manifest.json
- build_phase_0_4_quality_input.dart
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
- data
- ime2_kernels.cpp
- ggml_backend_cpu_context
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
- ggml_are_same_shape
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
- app_status_notice.dart
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
- app_state_panel.dart
- quantize_q5_0
- platform_asr_device_risk_monitor.dart
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
- ggml_opt_result_t
- LocalFactFooter
- _generateSummary
- summary
- ggml_cgraph
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
- dart:io
- build
- viewModel
- nrow_block_q2_k
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
- nrow_block_q5_1
- build
- createState
- onOpenSettings
- onStartMeeting
- startingMeeting
- ggml_opt_dataset
- ffigen.dart
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
- ggml_bf16_t
- tinyBLAS
- whisper_layer_decoder
- rvv_kernels.cpp
- simd-mappings.h
- c_library.dart
- spacemit/repack.cpp
- copyWith
- .compute_forward_qx
- pack_qs
- hashCode
- ggml_graph_compute
- whisper_context
- ggml_unravel_index
- lerp
- weight_buft_supported
- operator
- quantize_row_q8_1_ref
- _
- spine_tcm.h
- _owner
- get_scale_min_k4
- gguf_reader
- ggml-cpu/common.h
- ggml_quantize_chunk
- app_failure.dart
- MessageHandler
- ggml_backend_dev_t
- MeetingDetailViewModel
- ffi.Opaque
- gguf_get_n_tensors
- ggml_backend_cpu_x86_score
- asr_model_registry.dart
- gguf_set_kv
- atomic_load_explicit
- ggml_cpu_fp16_to_fp32
- ggml_compute_forward
- _
- x86/cpu-feats.cpp
- Q: clang: warning: -Wl,-z,max-page-size=16384: linker input unused 是否影响 Android 16KB page-size 兼容性
- spine_mem_pool.cpp
- ggml_conv_2d_dw_params
- message
- AppDelegate
- amx/common.h
- pool_allocation
- kleidiai_collect_kernel_chain
- ggml_tensor
- data_control.dart
- Win32Window
- quantize_row_nvfp4_ref
- _owner
- _
- unpack_A
- _owner
- ggml_opt_fit
- prepare_whisper_quality_corpus.dart
- GeneratedPluginRegistrant.swift
- make_block_q4_0x32
- FILE
- MessageHandler
- title
- block_q8_K
- title
- q8k_blk_size
- dispose
- onEditingChanged
- ../../../../../domain/ports/asr_engine.dart
- ../../../../../domain/ports/evidence_playback.dart
- onEvidence
- .supports_op
- ime_kernels.h
- block_with_zp
- flash_attn_ext_f16_one_chunk_inner_vlen1024_vf16_mrow
- value
- gguf_context
- rvv_kernels.h
- whisper_global_cache
- gguf_tensor_info
- didUpdateWidget
- Step 20：whisper.cpp 正式替换
- onPress
- readiness
- meeting
- onPress
- type_to_gguf_type<int64_t>
- quantize_row_iq3_xxs_impl
- tile_config_t
- quantize_q5_1
- referenceTime
- local_data_control.dart
- ggml_kleidiai_select_kernels
- repack_q4_k_to_q4_1_16_bl
- ggml_backend_dev_props
- hbm.cpp
- kleidiai_block_args
- type_to_gguf_type<int8_t>
- nrow_block_q5_0
- quantize_row_iq2_s_impl
- type_to_gguf_type<uint64_t>
- ggml-quants.c
- type_to_gguf_type<uint8_t>
- ggml_scale_impl
- type_to_gguf_type<uint16_t>
- type_to_gguf_type<uint32_t>
- ime_env.cpp
- atomic_flag_test_and_set
- WhisperWorkerFactory
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

## Communities (521 total, 171 thin omitted)

### Community 0 - "meeting_detail_view_model.dart"
Cohesion: 0.02
Nodes (115): _applyInstallations, _applyProgress, canGenerate, displayLabel, displaySpeakerLabel, generate, isGenerating, _loadInstalledModels (+107 more)

### Community 1 - "asr_preview_coordinator.dart"
Cohesion: 0.03
Nodes (75): asr_preview_session.dart, ../audio/recording_ports.dart, ../../../domain/use_cases/plan_asr_preview_windows.dart, _acceptSegments, _active, add, append, _blocks (+67 more)

### Community 2 - "meettrace_dependencies.dart"
Cohesion: 0.03
Nodes (70): createDataControlsViewModel, createMeetingDetailViewModel, createMeetingListViewModel, createModelSettingsViewModel, createRecordingSessionViewModel, createStartMeetingViewModel, MeetTraceViewModelFactories, ../data/repositories/sqflite_diarization_preference_repository.dart (+62 more)

### Community 3 - "meeting_detail_view.dart"
Cohesion: 0.04
Nodes (56): SpeakerLabelGroup, _confirmingDelete, _controller, detail, duration, editing, _evidenceKeys, group (+48 more)

### Community 4 - "use_cases/evaluate_alpha_release.dart"
Cohesion: 0.02
Nodes (121): acceptanceEvidence, _acceptanceEvidenceCount, adaptiveNavigationAccessibilityPassed, advancedEnergyWh, advancedFinalTranscriptionDurationMs, advancedRtfSamples, advancedSentenceLatencyMs, advancedVadKeyFactRecallRatio (+113 more)

### Community 5 - "bundled_model_preparation_service_test.dart"
Cohesion: 0.05
Nodes (40): Directory, BundledModelPreparationService, AppFileLayout, commit, DurableFileCommitException, DurableFileCommitter, message, toString (+32 more)

### Community 6 - "win32_window.cpp"
Cohesion: 0.15
Nodes (16): Point, Size, wchar_t, Scale(), Create, Destroy, SetQuitOnClose, Show (+8 more)

### Community 7 - "meeting_list_view.dart"
Cohesion: 0.03
Nodes (66): _audioFactLabel, body, deletable, deleting, deletingMeetingIds, descriptor, didChangeDependencies, _disableAnimations (+58 more)

### Community 8 - "theme.dart"
Cohesion: 0.03
Nodes (57): AppColors get, AppStyle get, _body, borderRadius, borderStrong, cardRadius, contentMaxWidth, controlHeight (+49 more)

### Community 9 - "ggml-cpu/repack.h"
Cohesion: 0.05
Nodes (45): block, d, block_iq4_nlx16, d, qs, block_mxfp4x4, e, qs (+37 more)

### Community 10 - "asr_preview_coordinator_test.dart"
Cohesion: 0.05
Nodes (37): package:meettrace/data/services/asr/asr_preview_coordinator.dart, package:meettrace/domain/models/asr_preview.dart, package:meettrace/domain/use_cases/plan_asr_preview_windows.dart, required _ScriptedVad vad,
  int, accept, acceptAudio, acceptCalls, cancel (+29 more)

### Community 11 - "reliable_recording_service.dart"
Cohesion: 0.04
Nodes (55): audioLevelChanges, _audioLevelMeter, _audioSubscription, canFinalize, capture, _captureDone, _captureStopTimedOut, captureStopTimeout (+47 more)

### Community 12 - "ports/asr_engine.dart"
Cohesion: 0.03
Nodes (59): _SupportedRiskMonitor, PortableAsrDeviceRiskMonitor, acceptAudio, AsrDeviceRiskMonitor, AsrDeviceRiskState, AsrDeviceSupport, AsrEngineMetrics, AsrEnginePurpose (+51 more)

### Community 13 - "sqflite_repositories_test.dart"
Cohesion: 0.04
Nodes (55): SqfliteMeetingRepository, DomainInvariantViolation, message, toString, TranscriptSnapshotStatus, ResolveMeetingModelSelection, package:meettrace/data/repositories/sqflite_diarization_preference_repository.dart, package:meettrace/data/repositories/sqflite_meeting_repository.dart (+47 more)

### Community 14 - "package:flutter/widgets.dart"
Cohesion: 0.05
Nodes (42): FCircularProgress, Icon, appDisplayName, Application, build, home, enableAppEdgeToEdge, main (+34 more)

### Community 15 - "final_transcription_service_test.dart"
Cohesion: 0.04
Nodes (49): AudioSource, channelCount, durationMs, path, sampleRate, required DateTime createdAt,
  int, acceptAudio, activeSnapshotId (+41 more)

### Community 16 - "downloadable_model_service.dart"
Cohesion: 0.04
Nodes (51): addCancelListener, _adoptExistingIfValid, alreadyInstalled, cancel, candidate, capacity, cause, code (+43 more)

### Community 17 - "FlutterMacOS"
Cohesion: 0.13
Nodes (12): Cocoa, Flutter, FlutterMacOS, FlutterSceneDelegate, SceneDelegate, RunnerTests, MainFlutterWindow, RunnerTests (+4 more)

### Community 18 - "model_selection_fakes.dart"
Cohesion: 0.03
Nodes (58): DeviceRecordingReadinessProbe, RecordingDeviceReadinessProbe, package:meettrace/domain/models/meeting_readiness.dart, package:meettrace/domain/use_cases/check_meeting_readiness.dart, check, _DeviceProbe, freeBytes, main (+50 more)

### Community 19 - "whisper_build_graph_decoder"
Cohesion: 0.10
Nodes (50): ggml_context, ggml_acc_or_set(), ggml_add(), ggml_add1_or_set(), ggml_add_or_set(), ggml_build_forward_expand(), ggml_can_mul_mat(), ggml_cast() (+42 more)

### Community 20 - "meeting_detail_view_model_test.dart"
Cohesion: 0.05
Nodes (44): SqfliteProcessingTaskRepository, ProcessingTaskRepository, _TaskRepository, _TaskRepository, DetailProcessingTaskRepository, capability, diarizationEnabled, dispose (+36 more)

### Community 21 - "ops.cpp"
Cohesion: 0.05
Nodes (144): ggml_op_pool, cmp_argsort, data, cmp_top_k, data, ggml_compute_params, ggml_tensor, T (+136 more)

### Community 22 - "meeting_list_previews.dart"
Cohesion: 0.06
Nodes (35): @Preview, ../../../../app/application.dart, app_page_body.dart, app_state_panel.dart, app_status_notice.dart, check, commit, delete (+27 more)

### Community 23 - "whisper_quality_protocol.dart"
Cohesion: 0.02
Nodes (93): boundaryEndCount, boundaryStartCount, byteLength, corpusId, countTag, decodePcm16Le, decodePcm16LeWindows, deidentified (+85 more)

### Community 24 - "recording_session_view.dart"
Cohesion: 0.03
Nodes (83): _AudioCard, _DiarizationCard, _FactLine, _FailureCard, _MeetingFactRail, _ProcessingCard, _ProcessingStage, _ProcessingView (+75 more)

### Community 25 - "generate_summary_test.dart"
Cohesion: 0.05
Nodes (41): _PreviewSummaryRepository, SqfliteSummaryRepository, Object? error,
  bool, package:meettrace/data/services/summary/summary_generation_service.dart, package:meettrace/domain/use_cases/generate_summary.dart, SummaryRepository, _SummaryService, active (+33 more)

### Community 26 - "rebuild_android_emulator_smoke_evidence.dart"
Cohesion: 0.05
Nodes (40): abi, apiLevel, asrLifecycle, _asrLifecycleMarker, canonicalResolved, canonicalRoot, capturedAtUtc, expectedCommandFragments (+32 more)

### Community 27 - "fetch_ascend_public_regression.dart"
Cohesion: 0.03
Nodes (66): allowedRoot, ascendDatasetConfig, ascendDatasetId, ascendDatasetLicense, ascendDatasetRevision, AscendRow, audioDirectory, audioUri (+58 more)

### Community 28 - "recording_session_view_model.dart"
Cohesion: 0.05
Nodes (43): AudioLevel, _PreviewRecordingService, ReliableRecordingService, RecordingSessionService, _audioLevels, _audioLevelSubscription, canPause, canResume (+35 more)

### Community 29 - "android_emulator_meeting_flow_test.dart"
Cohesion: 0.04
Nodes (51): accept, build, check, _chunkSequence, _controller, _copyAsset, create, createState (+43 more)

### Community 30 - "speaker_diarization_coordinator_test.dart"
Cohesion: 0.05
Nodes (44): _PreviewTranscriptRepository, SqfliteTranscriptRepository, package:meettrace/data/services/diarization/speaker_diarization_coordinator.dart, package:meettrace/data/services/diarization/speaker_diarization_service.dart, package:meettrace/domain/models/speaker_diarization.dart, _TaskRepository, _TranscriptRepository, available (+36 more)

### Community 31 - "whisper_quality_metrics.dart"
Cohesion: 0.02
Nodes (81): asrInvocationCount, comparisons, _csvCell, decoded, detectedSpeechDurationMs, detectedSpeechSegmentCount, deviceId, durationMs (+73 more)

### Community 32 - "sqflite_model_installation_repository.dart"
Cohesion: 0.05
Nodes (47): class, ../../../../domain/models/asr_model_registry.dart, ../../../domain/models/model_usage_lease.dart, ../../../../../domain/models/processing_task.dart, ../../../../../domain/models/workflow_states.dart, ../../../domain/ports/summary_generation.dart, _appDatabase, _enabledKey (+39 more)

### Community 33 - "android_whisper_quality_benchmark_test.dart"
Cohesion: 0.05
Nodes (43): allSamples, _appendRecognition, asrInvocationCount, _baseModelAsset, _BenchmarkRecognition, _completeMarker, _copyAsset, data (+35 more)

### Community 34 - "run_speaker_diarization.dart"
Cohesion: 0.05
Nodes (38): ../../../domain/models/audio_source.dart, ../../../../../domain/models/speaker_diarization.dart, ../../../../../domain/ports/speaker_diarization.dart, ../../../domain/use_cases/run_speaker_diarization.dart, capability, diarize, UnavailableSpeakerDiarizationService, capability (+30 more)

### Community 35 - "ggml_dup_tensor"
Cohesion: 0.04
Nodes (65): ggml_custom1_op_t, ggml_custom2_op_t, ggml_custom3_op_t, ggml_acc(), ggml_acc_impl(), ggml_acc_inplace(), ggml_add_id(), ggml_add_impl() (+57 more)

### Community 36 - "generate_synthetic_noise_corpus.dart"
Cohesion: 0.04
Nodes (56): allowedRoot, audioDirectory, bytes, clickLength, corpusId, create, data, _dbToLinear (+48 more)

### Community 37 - "reliable_recording_service_test.dart"
Cohesion: 0.04
Nodes (53): delete, fromJson, hashCode, JsonRecordingCheckpointStore, layout, load, meetingId, operator (+45 more)

### Community 38 - "downloadable_model_service_test.dart"
Cohesion: 0.04
Nodes (46): DownloadableModelException, DownloadableModelProgress, DownloadableModelService, DownloadNetworkKind, ModelDownloadCancellationToken, package:meettrace/data/services/models/downloadable_model_service.dart, package:meettrace/data/services/models/http_model_file_downloader.dart, active (+38 more)

### Community 39 - "whisper_vad_segmenter.dart"
Cohesion: 0.03
Nodes (59): dart:isolate, Isolate, accept, analysisInterval, _analysisIntervalSamples, _analysisOriginSample, _analyze, _availableEndSample (+51 more)

### Community 40 - "meeting_list_view_model.dart"
Cohesion: 0.07
Nodes (29): ../../../../core/view_state.dart, canDeleteMeeting, checking, _checkReadiness, defaultModelName, _deleteErrorMessage, deleteMeeting, _deletingMeetingIds (+21 more)

### Community 41 - "meettrace_flow.dart"
Cohesion: 0.07
Nodes (28): ../../../../../domain/use_cases/start_meeting.dart, build, createState, _dependencies, didChangeAppLifecycleState, dispose, initState, _loading (+20 more)

### Community 42 - "summary_generation.dart"
Cohesion: 0.08
Nodes (25): actionItems, available, capability, code, evidenceSegmentIds, generate, GeneratedSummaryDraft, GeneratedSummaryItem (+17 more)

### Community 43 - "storage_mappers.dart"
Cohesion: 0.07
Nodes (27): ../../../../domain/models/asr_model.dart, ../../../../domain/models/model_installation.dart, _date, fromMillisecondsSinceEpoch, meetingFromRow, meetingToRow, modelInstallationFromRow, modelInstallationToRow (+19 more)

### Community 44 - "bundled_model_preparation_service.dart"
Cohesion: 0.04
Nodes (52): ../../../domain/models/model_manifest.dart, Exception, WhisperAdapterException, alreadyReady, assetSource, BundledModelPreparationException, BundledModelPreparationPhase, BundledModelPreparationProgress (+44 more)

### Community 45 - "recording_audio_waveform.dart"
Cohesion: 0.07
Nodes (29): AnimationController, CustomPainter, active, baseline, build, _controller, createState, didUpdateWidget (+21 more)

### Community 46 - "revise_final_transcript.dart"
Cohesion: 0.04
Nodes (45): ../../../../../domain/use_cases/check_meeting_readiness.dart, captureFactory, check, PcmAudioCaptureFactory, storageCapacity, Meeting, TranscriptSnapshot, FinalTranscriptionProgressCallback (+37 more)

### Community 47 - "recording_session_view_test.dart"
Cohesion: 0.05
Nodes (38): DecoratedBox, RecordingState, RecordingStateTransition, package:meettrace/ui/features/meetings/views/recording/recording_session_view.dart, _PreviewSession, _RecordingService, audioLevelChanges, _audioLevels (+30 more)

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
Cohesion: 0.06
Nodes (32): AudioPlayer, evidence_playback_service.dart, AudioplayersDeviceAudioOutput, _bitsPerSample, _bytesPerMillisecond, _bytesPerSample, _channels, _completionSubscription (+24 more)

### Community 53 - "start_meeting.dart"
Cohesion: 0.04
Nodes (48): _PreviewMeetingReadinessChecker, check_meeting_readiness.dart, _ReadyMeetingChecker, AsrModelRegistry, check, CheckMeetingReadinessUseCase, device, freeBytes (+40 more)

### Community 54 - "ggml-backend.cpp"
Cohesion: 0.04
Nodes (134): ggml_backend_eval_callback, ggml_backend_deleter, ggml_backend_event_deleter, ggml_backend_event_t, ggml_backend_t, ggml_backend_buffer_t, ggml_backend_buffer_type_t, ggml_backend_event_t (+126 more)

### Community 55 - "model_settings_view.dart"
Cohesion: 0.06
Nodes (33): ChangeNotifier, ../../../core/app_back_icon.dart, ../../../core/asr_model_option.dart, MeetingListViewModel, RecordingSessionViewModel, StartMeetingViewModel, DataControlsViewModel, ModelSettingsViewModel (+25 more)

### Community 56 - "ggml.c"
Cohesion: 0.03
Nodes (88): ggml_fp16_t, ggml_log_callback, ggml_abort(), ggml_abs_inplace(), ggml_ceil_inplace(), ggml_elu_inplace(), ggml_exp_inplace(), ggml_expm1_inplace() (+80 more)

### Community 57 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 58 - "model_settings_view_model.dart"
Cohesion: 0.07
Nodes (28): Future, SqfliteModelPreferenceRepository, ModelPreferenceRepository, actions, _applyInstallations, cancelAdvanced, _defaultModelId, deleteAdvanced (+20 more)

### Community 59 - "ggml_compute_backward"
Cohesion: 0.06
Nodes (47): ggml_get_n_tasks(), ggml_abs(), ggml_add_cast(), ggml_add_cast_impl(), ggml_can_repeat(), ggml_can_repeat_rows(), ggml_ceil(), ggml_compute_backward() (+39 more)

### Community 60 - "app_swipe_action_row.dart"
Cohesion: 0.07
Nodes (27): Key?, actionIcon, actionKey, actionLabel, AppSwipeActionRow, _AppSwipeActionRowState, build, child (+19 more)

### Community 61 - "x86/quants.c"
Cohesion: 0.11
Nodes (47): bytes_from_bits_16(), bytes_from_bits_32(), bytes_from_nibbles_32(), __m128, __m128i, __m256, get_scale_shuffle(), get_scale_shuffle_k4() (+39 more)

### Community 62 - "whisper_asr_engine_factory_test.dart"
Cohesion: 0.04
Nodes (54): changes, inspect, main, _modelRoot, _prepareDelaySeconds, SqfliteModelUsageLeaseRepository, ModelUsageLeaseRepository, _MemoryInstallations (+46 more)

### Community 63 - "recording_previews.dart"
Cohesion: 0.05
Nodes (39): audioLevelChanges, canFinalize, _changes, delete, dispose, duration, _events, flush (+31 more)

### Community 64 - "meeting_detail_view_test.dart"
Cohesion: 0.05
Nodes (39): package:meettrace/ui/features/meetings/view_models/detail/meeting_detail_view_model.dart, package:meettrace/ui/features/meetings/views/detail/meeting_detail_view.dart, required String id,
  TranscriptSnapshotStatus, SpeakerDiarizationRunner? diarization,
  bool, ../../../../../support/final_transcription_fakes.dart, available, capability, diarizationEnabled (+31 more)

### Community 65 - "benchmarks/evaluate_alpha_release.dart"
Cohesion: 0.08
Nodes (24): actualSha256, allowed, androidEvidence, canonicalEvidencePath, canonicalRoot, decoded, _deepEquals, EvaluateAlphaReleaseCliOptions (+16 more)

### Community 66 - "data_controls_view_model.dart"
Cohesion: 0.09
Nodes (21): ../../../../domain/ports/text_share.dart, ../../../../domain/use_cases/build_meeting_share.dart, share, SharePlusTextShareService, share, TextShareService, dataControl, dispose (+13 more)

### Community 67 - "summary.dart"
Cohesion: 0.08
Nodes (23): actionItems, createdAt, endMs, evidence, id, isPendingReview, keyPoints, meetingId (+15 more)

### Community 68 - "ggml_new_tensor"
Cohesion: 0.07
Nodes (43): ggml_custom_op_t, ggml_tensor, ggml_calc_conv_output_size(), ggml_calc_conv_transpose_1d_output_size(), ggml_calc_pool_output_size(), ggml_can_out_prod(), ggml_clamp(), ggml_col2im_1d() (+35 more)

### Community 69 - "bool get"
Cohesion: 0.09
Nodes (21): bool get, Duration, _bytesPerPcm16Sample, bytesWritten, channelCount, elapsed, isComplete, _minimumCompleteRatio (+13 more)

### Community 70 - "whisper.cpp"
Cohesion: 0.03
Nodes (65): ggml_log_level, mt_whisper_destroy(), mt_whisper_transcribe(), ggml_n_dims(), aheads_masks_free(), aheads_masks_nbytes(), ggml_log_callback, mt19937 (+57 more)

### Community 71 - "asr_preview.dart"
Cohesion: 0.08
Nodes (24): Float32List, AsrPreviewMetrics, AsrPreviewState, AsrPreviewWindow, audioDurationMs, droppedPreviewWindows, endMs, endSample (+16 more)

### Community 72 - "dart:typed_data"
Cohesion: 0.08
Nodes (20): AudioRecorder, dart:typed_data, dispose, hasPermission, meettracePcmRecordConfig, pause, _recorder, resume (+12 more)

### Community 73 - "ggml-cpu.cpp"
Cohesion: 0.08
Nodes (46): ggml_guid_t, ggml_abort_callback, ggml_backend_buffer_t, ggml_backend_buffer_type_t, ggml_backend_dev_t, ggml_backend_graph_plan_t, ggml_backend_reg_t, ggml_backend_t (+38 more)

### Community 74 - "ggml-backend-reg.cpp"
Cohesion: 0.04
Nodes (58): dl_handle, gguf_context, HMODULE, ggml_backend, ggml_backend_buffer, ggml_backend_buffer_type, ggml_backend_dev_caps, async (+50 more)

### Community 75 - "phase_0_4_quality_input_builder.dart"
Cohesion: 0.05
Nodes (38): build, created, expectedCoverage, _integer, _integerOrNull, _jsonDeepEquals, left, _listEquals (+30 more)

### Community 76 - "size"
Cohesion: 0.13
Nodes (18): T, vector, gguf_buffer_reader, size, gguf_get_arr_n(), gguf_get_meta_data(), gguf_get_meta_size(), gguf_kv (+10 more)

### Community 77 - "recording_device_readiness_probe_test.dart"
Cohesion: 0.08
Nodes (23): _DeterministicPcmAudioCapture, DeviceRecordingStorageCapacityProvider, RecordPcmAudioCapture, PcmAudioCapture, RecordingStorageCapacityProvider, package:meettrace/data/services/audio/recording_device_readiness_probe.dart, _FakeCapture, _FixedCapacity (+15 more)

### Community 78 - "android_proc_asr_device_risk_monitor.dart"
Cohesion: 0.10
Nodes (20): AsrRiskTextReader, AsrThermalPathLister, changes, _constrainedMemoryBytes, _deviceSupport, inspect, _listThermalPaths, _memoryCriticalBytes (+12 more)

### Community 79 - "whisper_decoder"
Cohesion: 0.07
Nodes (30): A, B, id, whisper_decoder, completed, failed, grammar, has_ts (+22 more)

### Community 80 - "whisper_quality_protocol_test.dart"
Cohesion: 0.10
Nodes (19): required Directory audioRoot,
  bool, bytes, corruptFirstHash, create, deidentified, _deviceModelJson, _deviceRunJson, environment (+11 more)

### Community 81 - "vec.h"
Cohesion: 0.04
Nodes (79): ggml_set_f32(), ggml_set_i32(), ggml_compute_forward_flash_attn_ext_f16_one_chunk(), ggml_compute_forward_out_prod(), ggml_compute_forward_out_prod_f32(), ggml_compute_forward_out_prod_q_f32(), ggml_compute_forward_repeat_back(), ggml_compute_forward_repeat_back_f32() (+71 more)

### Community 82 - "unary-ops.cpp"
Cohesion: 0.05
Nodes (58): Op, ggml_tensor, buffer, data, extra, flags, name, nb (+50 more)

### Community 83 - "meettrace_whisper.g.dart"
Cohesion: 0.05
Nodes (48): external double, external int, package:meta/meta.dart, abi_version, beam_size, best_of, decoding_strategy, initial_prompt (+40 more)

### Community 84 - "recording.dart"
Cohesion: 0.11
Nodes (18): audioPath, bytes, capturedThrough, duration, end, endByteOffset, level, meetingId (+10 more)

### Community 85 - "ggml_set_op_params_i32"
Cohesion: 0.06
Nodes (34): ggml_arange(), ggml_argsort(), ggml_argsort_top_k(), ggml_calc_conv_transpose_output_size(), ggml_concat(), ggml_conv_transpose_2d_p0(), ggml_fill(), ggml_fill_impl() (+26 more)

### Community 86 - "model_manifest.dart"
Cohesion: 0.10
Nodes (19): bytes, files, installationType, license, minAppVersion, modelId, ModelLicense, ModelManifest (+11 more)

### Community 87 - "MeetingRepository"
Cohesion: 0.06
Nodes (36): _PreviewMeetingRepository, TranscriptRevisionException, MeetingRepository, package:meettrace/data/repositories/repository_contracts.dart, package:meettrace/data/services/storage/local_data_control_service.dart, package:meettrace/domain/use_cases/revise_final_transcript.dart, _MeetingRepository, _MeetingRepository (+28 more)

### Community 88 - "whisper_vad_model"
Cohesion: 0.04
Nodes (46): ggml_backend_buffer_t, ggml_backend_sched_t, whisper_aheads_masks, buffer, ctx, m, whisper_sched, sched (+38 more)

### Community 89 - "List"
Cohesion: 0.03
Nodes (86): AnimatedContainer, _PreviewMeetingFileDeletionService, _PreviewStagedMeetingDeletion, Completer, FTappable, _DirectoryStagedMeetingDeletion, MeetingDirectoryDeletionService, _NoopStagedMeetingDeletion (+78 more)

### Community 90 - "repositories.dart"
Cohesion: 0.04
Nodes (51): abstract interface class, SqfliteDiarizationPreferenceRepository, delete, deleteAndDeactivate, deleteExpired, DiarizationPreferenceRepository, getActiveVersion, getById (+43 more)

### Community 91 - "ggml-cpu/repack.cpp"
Cohesion: 0.04
Nodes (64): block_q4_0x4, block_q4_0x8, block_q8_0x16, block_q8_0x4, ggml_quantize_mat_q8_K_4x8(), block_iq4_nlx4, d, qs (+56 more)

### Community 92 - "models/speaker_diarization.dart"
Cohesion: 0.11
Nodes (18): available, code, endMs, errorCode, isAvailable, reasonCode, snapshot, SpeakerDiarizationCapability (+10 more)

### Community 93 - "run_final_transcription.dart"
Cohesion: 0.05
Nodes (35): WhisperAsrEngineFactory, AsrEngineFactory, commit, DeleteMeetingUseCase, execute, files, MeetingFileDeletionService, meetings (+27 more)

### Community 94 - "vector"
Cohesion: 0.09
Nodes (42): pair, vector, decode_utf8(), log_mel_spectrogram_worker_thread(), map_processed_to_original_time(), tokenize(), whisper_compute_logprobs(), whisper_compute_probs() (+34 more)

### Community 95 - "return"
Cohesion: 0.11
Nodes (17): createPlatformDatabaseFactory, _createWindowsFactory, databaseFactory, databaseFactoryFfi, _windowsDatabaseFactory, return, build, created (+9 more)

### Community 96 - "recording_bootstrap_view.dart"
Cohesion: 0.12
Nodes (17): Animation, ../../../../core/app_state_panel.dart, build, createState, didChangeDependencies, dispose, _handleRouteAnimation, _initializationScheduled (+9 more)

### Community 97 - "final_transcription_fakes.dart"
Cohesion: 0.08
Nodes (24): >, _PendingTranscriptionRunner, _UnavailableTranscriptionRunner, FinalTranscriptionRunner, FinalTranscriptionService, package:meettrace/data/services/asr/final_transcription_service.dart, package:meettrace/domain/models/summary.dart, main (+16 more)

### Community 98 - "domain_ports_test.dart"
Cohesion: 0.09
Nodes (22): AsrDeviceRiskState get, AsrEngineMetrics get, acceptAudio, cancel, create, delete, descriptor, deviceRisk (+14 more)

### Community 99 - "dart:convert"
Cohesion: 0.07
Nodes (29): dart:convert, dart:math, package:crypto/crypto.dart, package:meettrace/domain/use_cases/evaluate_alpha_release.dart, phase_0_4_release_input_builder.dart, main, _passingInput, main (+21 more)

### Community 100 - "plan_asr_preview_windows.dart"
Cohesion: 0.07
Nodes (28): AsrPreviewMetrics get, _PreviewSession, AsrPreviewCoordinator, AsrPreviewSession, dispose, events, flush, metrics (+20 more)

### Community 101 - "build_spike_sample.dart"
Cohesion: 0.11
Nodes (18): bytes, data, durationSeconds, header, main, offset, output, outputPath (+10 more)

### Community 102 - "riscv/quants.c"
Cohesion: 0.06
Nodes (80): ggml_vec_dot_iq4_nl_q8_0(), NOINLINE, ggml_vec_dot_iq1_m_q8_K(), ggml_vec_dot_iq1_m_q8_K_vl1024(), ggml_vec_dot_iq1_m_q8_K_vl128(), ggml_vec_dot_iq1_m_q8_K_vl256(), ggml_vec_dot_iq1_m_q8_K_vl512(), ggml_vec_dot_iq1_s_q8_K() (+72 more)

### Community 103 - "ggml-cpu/quants.c"
Cohesion: 0.04
Nodes (62): Float, ggml_vec_dot_iq1_s_q8_K(), ggml_vec_dot_iq2_s_q8_K(), ggml_vec_dot_iq2_xs_q8_K(), ggml_vec_dot_iq2_xxs_q8_K(), ggml_vec_dot_iq3_s_q8_K(), ggml_vec_dot_iq3_xxs_q8_K(), ggml_vec_dot_iq4_xs_q8_K() (+54 more)

### Community 104 - "Codex 实施计划：whisper.cpp 质量强化与双平台交付"
Cohesion: 0.05
Nodes (40): 1. 交付目标, 2. 明确不做, 3.1 隔离工作区, 3.2 每个任务的固定循环, 3.3 每个阶段的统一验证, 3.4 停止条件, 3.5 首个交付点的验证边界, 3. Codex 执行协议 (+32 more)

### Community 105 - "Stream"
Cohesion: 0.05
Nodes (38): ../../../../../domain/models/recording.dart, int?, add, _changes, defaultRecordingAudioLevelFloorDbfs, defaultRecordingAudioLevelFrame, dispose, _disposed (+30 more)

### Community 106 - "whisper_model"
Cohesion: 0.05
Nodes (38): e_model, whisper_layer_encoder, attn_k_w, attn_ln_0_b, attn_ln_0_w, attn_ln_1_b, attn_ln_1_w, attn_q_b (+30 more)

### Community 107 - "workflow_states.dart"
Cohesion: 0.18
Nodes (13): Enum, canTransitionTo, from, machine, MeetingState, MeetingStateTransition, ModelInstallationState, ModelInstallationStateTransition (+5 more)

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
Cohesion: 0.09
Nodes (21): @pragma, flutter_foreground_recording_lifecycle.dart, meetTraceRecordingForegroundCallback, onDestroy, onRepeatEvent, onStart, _RecordingKeepAliveTaskHandler, _recordingServiceId (+13 more)

### Community 112 - "meettrace_whisper.cpp"
Cohesion: 0.04
Nodes (64): ffi.Struct, mt_whisper_config_v1, mt_whisper_vad_config_v1, atomic_bool, vector, whisper_vad_params, mt_whisper_cancel(), mt_whisper_config_v1_init() (+56 more)

### Community 113 - "Android + iOS 自适应范围"
Cohesion: 0.67
Nodes (3): Android + iOS 自适应范围, Android 与 iOS 全面调整查询, 平台敏感服务集合

### Community 114 - "loongarch/quants.c"
Cohesion: 0.11
Nodes (72): bytes_from_bits_32(), bytes_from_nibbles_32(), __m128, __m128i, __m256, get_scale_shuffle(), get_scale_shuffle_k4(), get_scale_shuffle_q3k() (+64 more)

### Community 115 - "_"
Cohesion: 0.05
Nodes (42): ../../../../../domain/models/app_failure.dart, context, create, _createAdvanced, _createStandard, _failure, _finalVadFactory, installations (+34 more)

### Community 116 - "package:flutter/services.dart"
Cohesion: 0.08
Nodes (21): AssetBundle, bundled_model_preparation_service.dart, CachingAssetBundle, ModelAssetSource, bundle, FlutterModelAssetSource, load, appSystemUiOverlayStyle (+13 more)

### Community 117 - "generate_summary.dart"
Cohesion: 0.07
Nodes (26): UnavailableSummaryGenerationService, SummaryGenerationService, _buildEvidence, _buildItems, _buildRequest, _buildSummary, capability, code (+18 more)

### Community 118 - "fetch_ascend_public_regression_test.dart"
Cohesion: 0.12
Nodes (15): required double duration,
  String, bytes, channels, data, fourCc, host, includeJunkChunk, junkSize (+7 more)

### Community 119 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.04
Nodes (41): main, _recordingSeconds, AndroidProcAsrDeviceRiskMonitor, package:flutter/foundation.dart, package:flutter_test/flutter_test.dart, package:meettrace/data/services/asr/android_proc_asr_device_risk_monitor.dart, package:meettrace/data/services/asr/asr_engine.dart, package:meettrace/data/services/asr/platform_asr_device_risk_monitor.dart (+33 more)

### Community 120 - "ggml-backend-meta.cpp"
Cohesion: 0.07
Nodes (75): ggml_backend_meta_get_split_state_t, ggml_backend_dev_get_props(), ggml_backend_dev_memory(), ggml_backend_tensor_set_2d(), ggml_backend_buffer_t, ggml_backend_buffer_type_t, ggml_backend_dev_t, ggml_backend_t (+67 more)

### Community 121 - "arm/repack.cpp"
Cohesion: 0.06
Nodes (55): quantize_row_q8_0(), quantize_row_q8_1(), int16x8_t, decode_q_Kx8_6bit_scales(), ggml_gemm_iq4_nl_4x4_q8_0(), ggml_gemm_mxfp4_4x4_q8_0(), ggml_gemm_q4_0_4x4_q8_0(), ggml_gemm_q4_0_4x8_q8_0() (+47 more)

### Community 122 - "meeting_detail_previews.dart"
Cohesion: 0.07
Nodes (24): delete, getById, listByMeeting, _PreviewMeetingRepository, save, saveAndActivate, saveFinalAndActivate, _standard (+16 more)

### Community 123 - "../../../../theme/theme.dart"
Cohesion: 0.10
Nodes (18): AlignmentGeometry, compact,
  medium,, EdgeInsetsGeometry?, alignment, AppPageBody, AppPageWidth, build, child (+10 more)

### Community 124 - "MeetTrace Android and iOS Alpha PRD V0.6"
Cohesion: 0.05
Nodes (49): Forui-First UI Policy, View-ViewModel-Use Case-Port-Repository-Service Architecture, Official sherpa_onnx Package-Only Boundary, Repository Product Boundaries, MeetTrace Repository Guide, Adaptive Native Mobile and Tablet Layout, Continuous Time Ledger, Grayscale Semantic Encoding (+41 more)

### Community 125 - "app_ledger.dart"
Cohesion: 0.09
Nodes (21): AppLedgerRow, AppLedgerSurface, build, children, dateLabel, emphasized, framed, icon (+13 more)

### Community 126 - "ggml-cpu.c"
Cohesion: 0.07
Nodes (47): cpu_set_t, ggml_bf16_t, ggml_backend_cpu_get_features(), ggml_compute_forward_mul_mat_id_one_chunk(), ggml_cpu_bf16_to_fp32(), ggml_cpu_fp32_to_bf16(), ggml_cpu_get_rvv_vlen(), ggml_cpu_get_sve_cnt() (+39 more)

### Community 127 - "ggml-impl.h"
Cohesion: 0.05
Nodes (61): ggml_bitset_t, GGML_NORETURN, initializer_list, graph_copy_dup_tensor(), ggml_cpu_try_fuse_ops(), ggml_build_backward_expand(), ggml_can_fuse_subgraph_ext(), ggml_graph_cpy() (+53 more)

### Community 128 - "processing_task.dart"
Cohesion: 0.14
Nodes (13): createdAt, id, kind, lastErrorCode, leaseExpiresAt, meetingId, modelId, ProcessingTask (+5 more)

### Community 129 - "ggml-opt.cpp"
Cohesion: 0.15
Nodes (22): ggml_opt_context_t, ggml_opt_epoch_callback, GGML_API, ggml_opt_context_optimizer_type(), ggml_opt_dataset_get_batch(), ggml_opt_dataset_shuffle(), ggml_opt_epoch(), ggml_opt_epoch_callback_progress_bar() (+14 more)

### Community 130 - "Components"
Cohesion: 0.07
Nodes (27): Bottom Action Bar, Buttons, Cards / Containers, Colors, Components, Design System: 会迹 · MeetTrace, Do:, Do's and Don'ts (+19 more)

### Community 131 - "recording_session_view_model_test.dart"
Cohesion: 0.04
Nodes (50): Duration get, audioLevelChanges, canFinalize, cause, code, duration, message, pause (+42 more)

### Community 132 - "model_installation.dart"
Cohesion: 0.15
Nodes (12): domain_exception.dart, AsrInstallationType, bytes, installationType, installedPath, lastErrorCode, modelId, ModelInstallation (+4 more)

### Community 133 - "ggml_is_contiguous"
Cohesion: 0.05
Nodes (79): memory_order, from_float(), atomic_fetch_add_explicit(), atomic_store_explicit(), atomic_thread_fence(), ggml_backend_cpu_device_supports_op(), ggml_barrier(), ggml_compute_forward_mul_mat() (+71 more)

### Community 134 - "package:meettrace/domain/models/workflow_states.dart"
Cohesion: 0.05
Nodes (36): InvalidStateTransitionException, package:meettrace/domain/models/meeting.dart, package:meettrace/domain/models/transcript.dart, package:meettrace/domain/models/workflow_states.dart, package:meettrace/domain/ports/asr_engine.dart, package:meettrace/domain/use_cases/build_meeting_share.dart, package:meettrace/domain/use_cases/start_meeting.dart, package:meettrace/ui/features/meetings/view_models/start/start_meeting_view_model.dart (+28 more)

### Community 135 - "ggml-cpu-impl.h"
Cohesion: 0.09
Nodes (56): ggml_int16x8x2_t, ggml_int8x16x2_t, ggml_int8x16x4_t, ggml_uint8x16x2_t, ggml_uint8x16x4_t, int32x4_t, int8x8_t, ggml_decode_q4scales_and_mins_for_mmla() (+48 more)

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
Cohesion: 0.09
Nodes (60): add_allocated_tensor(), aligned_offset(), alloc_tensor_range(), ggml_backend_buffer_t, ggml_backend_buffer_type_t, ggml_gallocr_t, free_buffers(), get_node_buffer_id() (+52 more)

### Community 140 - "Q: 评估 whisper_ggml 是否适合作为会迹当前本地 ASR 模型或运行时"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: 评估 whisper_ggml 是否适合作为会迹当前本地 ASR 模型或运行时, Source Nodes

### Community 141 - "vector"
Cohesion: 0.21
Nodes (9): _In_, _In_opt_, vector, wWinMain(), vector, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 142 - "size"
Cohesion: 0.07
Nodes (72): function, ggml_backend_t, ggml_backend_alloc_ctx_tensors(), ggml_backend_alloc_ctx_tensors_from_buft(), ggml_backend_graph_copy(), ggml_backend_sched_alloc_graph(), ggml_backend_tensor_set(), ggml_argmax() (+64 more)

### Community 143 - "whisper_adapter.dart"
Cohesion: 0.03
Nodes (68): beamSize, bestOf, cancel, _cancelled, _commands, _config, context, create (+60 more)

### Community 144 - "get_thread_range"
Cohesion: 0.16
Nodes (14): get_thread_range(), pair, ggml_compute_forward_arange(), ggml_compute_forward_arange_f32(), ggml_compute_forward_cumsum(), ggml_compute_forward_cumsum_f32(), ggml_compute_forward_fill(), ggml_compute_forward_fill_f16() (+6 more)

### Community 145 - "Q: sherpa_onnx 替换为 whisper_ggml，给我一个方案"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: sherpa_onnx 替换为 whisper_ggml，给我一个方案, Source Nodes

### Community 146 - "whisper_state"
Cohesion: 0.03
Nodes (61): log_mel_spectrogram(), vad_time_mapping, original_time, processed_time, whisper_mel, data, n_len, n_len_org (+53 more)

### Community 147 - "DateTime"
Cohesion: 0.18
Nodes (10): DateTime, acquiredAt, expiresAt, isActiveAt, leaseId, modelId, ModelUsageLease, ownerId (+2 more)

### Community 148 - "whisper_full_with_state"
Cohesion: 0.09
Nodes (39): get_signal_energy(), sample_to_timestamp(), should_split_on_word(), timestamp_to_sample(), utf8_len(), voice_length(), whisper_batch_prep_legacy(), whisper_decode() (+31 more)

### Community 149 - "RecordingAudioWaveform"
Cohesion: 0.18
Nodes (11): PCM16 RMS 实时波形, RecordingPcmChunk, ReliableRecordingService, 有界可丢弃派生音频链, PcmAudioLevelMeter, RecordingAudioWaveform, RecordingSessionViewModel, ReliableRecordingService (+3 more)

### Community 150 - "Q: whisper_ggml transcribeLive 实时（流媒体）转录如何接入当前项目"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: whisper_ggml transcribeLive 实时（流媒体）转录如何接入当前项目, Source Nodes

### Community 151 - "asr/whisper_small_advanced_asr_engine_test.dart"
Cohesion: 0.03
Nodes (57): _FakeWorkerFactory, active, activeVersions, add, bytes, cancel, _changes, clock (+49 more)

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
Cohesion: 0.05
Nodes (43): backend_config, ggml_backend_buffer_ptr, ggml_backend_comm_allreduce_tensor_t, ggml_backend_meta_split_state, ggml_context_ptr, ggml_init_params, mem_buffer, mem_size (+35 more)

### Community 156 - "APPLY_STANDARD_SETTINGS"
Cohesion: 0.20
Nodes (10): APPLY_STANDARD_SETTINGS, Relocatable Linux Flutter Bundle, target_compile_definitions, target_compile_features, target_compile_options, APPLY_STANDARD_SETTINGS, target_compile_definitions, target_compile_features (+2 more)

### Community 157 - "Q: 正式替换 sherpa-onnx 后，MeetTrace 的 whisper.cpp 双模型 ASR 架构、实时预览、最终转录、模型生命周期与录音隔离如何连接？"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: 正式替换 sherpa-onnx 后，MeetTrace 的 whisper.cpp 双模型 ASR 架构、实时预览、最终转录、模型生命周期与录音隔离如何连接？, Source Nodes

### Community 158 - "asr/whisper_base_standard_asr_engine_test.dart"
Cohesion: 0.06
Nodes (34): package:meettrace/data/services/vad/voice_activity_segmenter.dart, package:meettrace/domain/models/app_failure.dart, accept, acceptedSamples, bytes, cancel, cancelCalls, configs (+26 more)

### Community 159 - "Blocked iOS and Dual-Platform Release"
Cohesion: 0.50
Nodes (4): Independent Android and iOS Acceptance, Blocked iOS and Dual-Platform Release, iPhone and iPad Validation Requirements, Current Android and iOS Implementation Status

### Community 160 - "_"
Cohesion: 0.07
Nodes (32): _PreviewAsrEngine, WhisperBaseStandardAsrEngine, _, acceptAudio, cancel, context, _core, create (+24 more)

### Community 161 - "增量架构优化"
Cohesion: 0.22
Nodes (9): Domain Port 边界, FinalTranscriptionService, GenerateSummaryUseCase, 增量架构优化, MeetingDetailViewModel, MeetTraceDependencies, RecordingSessionViewModel, Repository Contracts (+1 more)

### Community 162 - "whisper_decode_internal"
Cohesion: 0.08
Nodes (29): ggml_graph_node(), ggml_abort_callback, set, whisper_batch, logits, n_seq_id, n_tokens, pos (+21 more)

### Community 163 - "app_file_layout.dart"
Cohesion: 0.07
Nodes (28): createBaseDirectories, databaseDirectory, databasePath, forApplication, meetingAudioCheckpointNextPath, meetingAudioCheckpointPath, meetingAudioCheckpointPreviousPath, meetingAudioDirectory (+20 more)

### Community 164 - "ggml_v_silu"
Cohesion: 0.14
Nodes (23): ggml_compute_forward_ssm_scan(), ggml_compute_forward_ssm_scan_f32(), ggml_bf16_t, ggml_float, exp_ps_sve(), ggml_silu_f32(), ggml_v_expf(), ggml_v_expf_m2() (+15 more)

### Community 165 - "gemv"
Cohesion: 0.09
Nodes (26): ggml_gemv_iq4_nl_4x4_q8_0(), ggml_gemv_mxfp4_4x4_q8_0(), ggml_gemv_q4_0_4x4_q8_0(), ggml_gemv_q4_0_4x8_q8_0(), ggml_gemv_q6_K_8x4_q8_K(), ggml_gemv_q6_K_8x8_q8_K(), ggml_gemv_q8_0_4x4_q8_0(), ggml_gemv_q8_0_4x8_q8_0() (+18 more)

### Community 166 - "local_data_control_service.dart"
Cohesion: 0.09
Nodes (22): _PreviewInstallations, device_free_space_service.dart, ../../../../domain/models/data_control.dart, ../../../../domain/ports/local_data_control.dart, SqfliteModelInstallationRepository, buildDiagnostics, freeSpace, installations (+14 more)

### Community 167 - "ime.cpp"
Cohesion: 0.08
Nodes (31): bind_ai_thread(), cpu::extra_buffer_type, cpu_set_t, cpu::tensor_traits, ggml_backend_buffer_t, ggml_backend_buffer_type_t, ggml_backend_dev_t, ggml_compute_params (+23 more)

### Community 168 - "s390/quants.c"
Cohesion: 0.16
Nodes (23): quantize_row_q8_0(), quantize_row_q8_0(), ggml_vec_dot_iq4_nl_q8_0(), ggml_vec_dot_iq4_xs_q8_K(), ggml_vec_dot_mxfp4_q8_0(), ggml_vec_dot_q3_K_q8_K(), ggml_vec_dot_q4_0_q8_0(), ggml_vec_dot_q4_1_q8_1() (+15 more)

### Community 169 - "x86/repack.cpp"
Cohesion: 0.08
Nodes (33): ggml_gemm_q4_0_8x8_q8_0(), ggml_gemv_q4_0_8x8_q8_0(), ggml_gemm_q4_0_8x8_q8_0(), ggml_gemv_q4_0_8x8_q8_0(), ggml_quantize_mat_q8_0_4x8(), __avx512_f32cx8x2_load(), __avx512_repeat_f32cx16_load(), __avx_f32cx8_load() (+25 more)

### Community 170 - "真实录音条件预检"
Cohesion: 0.25
Nodes (8): 未绑定技术预检的静态就绪文案, 首页固定准备就绪文案解释, MeetingReadinessChecker, 首页真实录音条件预检解释, 真实录音条件预检, 窄屏与大字体换行稳定性, 首页预检条重新排版, 预检条双层 Column 布局

### Community 171 - "gguf.cpp"
Cohesion: 0.08
Nodes (33): gguf_find_key(), gguf_get_arr_str(), gguf_get_arr_type(), gguf_get_key(), gguf_get_kv_type(), gguf_get_n_kv(), gguf_get_val_bool(), gguf_get_val_data() (+25 more)

### Community 172 - "q8_blk_size"
Cohesion: 0.24
Nodes (11): gemm_kernel_i8i4_mrow_ref(), gemm_kernel_i8i5_mrow_ref(), gemm_kernel_i8i8_mrow_ref(), gemm_kernel_i8mxfp4_mrow_ref(), moe_gemm_kernel_i8i4_mrow_ref(), moe_gemm_kernel_i8i5_mrow_ref(), q8_blk_size(), quantize_a_4row_i8() (+3 more)

### Community 173 - "nearest_int"
Cohesion: 0.14
Nodes (21): block_q3_K, block_q2_K, block_q6_K, dequantize_row_q2_K(), dequantize_row_q3_K(), dequantize_row_q6_K(), make_q3_quants(), make_qkx1_quants() (+13 more)

### Community 174 - "tinyBLAS_Q0_AVX"
Cohesion: 0.09
Nodes (31): block_iq4_nl, block_q4_0, block_q5_0, block_q8_0, int8x16_t, __m128i, NOINLINE, gemm() (+23 more)

### Community 175 - "tinyBLAS_PPC"
Cohesion: 0.09
Nodes (14): vector, kernel(), llamafile_sgemm(), tinyBLAS_PPC, A, B, C, ith (+6 more)

### Community 176 - "whisper_native_context.dart"
Cohesion: 0.08
Nodes (24): mt_whisper_context>, abiVersion, cancel, cancelAddress, code, dispose, endMs, _handle (+16 more)

### Community 177 - "kleidiai.cpp"
Cohesion: 0.23
Nodes (11): ggml_backend_buffer_t, ggml_backend_buffer_type_t, gcd_size(), get_tensor_traits(), ggml_backend_cpu_kleidiai_buffer_init_tensor(), ggml_backend_cpu_kleidiai_buffer_set_tensor(), ggml_backend_cpu_kleidiai_buffer_type_alloc_buffer(), ggml_backend_cpu_kleidiai_buffer_type_get_alignment() (+3 more)

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

### Community 184 - "platform_download_preflight_providers.dart"
Cohesion: 0.11
Nodes (17): Connectivity, downloadable_model_service.dart, freeSpace, getFreeBytes, DownloadNetworkStatusProvider, ModelStorageCapacityProvider, _connectivity, ConnectivityDownloadNetworkStatusProvider (+9 more)

### Community 185 - "ggml_opt_context"
Cohesion: 0.05
Nodes (37): ggml_cgraph, mt19937, ggml_opt_context, allocated_graph, allocated_graph_copy, backend_sched, buf_cpu, buf_static (+29 more)

### Community 186 - "_string"
Cohesion: 0.14
Nodes (13): _string, powerpc_features, has_vsx, platform, power_version, to_timestamp(), whisper_segment, no_speech_prob (+5 more)

### Community 187 - ".supports_op"
Cohesion: 0.25
Nodes (7): cpu::extra_buffer_type, ggml_backend_buffer_type_t, ggml_backend_dev_t, extra_buffer_type, ggml_backend_cpu_repack_buffer_type(), ggml_backend_cpu_repack_buffer_type_get_alignment(), ggml_backend_cpu_repack_buffer_type_get_name()

### Community 188 - "iq2_data_index"
Cohesion: 0.16
Nodes (16): ggml_quantize_free(), ggml_quantize_init(), iq1_find_best_neighbour2(), iq2_data_index(), iq2_grid_size(), iq2xs_free_impl(), iq2xs_init_impl(), iq3_data_index() (+8 more)

### Community 189 - "ggml_new_graph_custom"
Cohesion: 0.20
Nodes (14): ggml_build_forward_impl(), ggml_build_forward_select(), ggml_graph_clear(), ggml_graph_dup(), ggml_graph_nbytes(), ggml_hash_set_new(), ggml_hash_set_reset(), ggml_hash_size() (+6 more)

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

### Community 194 - "quantize_row_q8_K_ref"
Cohesion: 0.25
Nodes (8): quantize_row_q8_K(), quantize_row_q8_K(), quantize_row_q8_K(), quantize_row_q8_K(), quantize_row_q8_K_generic(), block_q8_K, dequantize_row_q8_K(), quantize_row_q8_K_ref()

### Community 195 - "model_settings_view_test.dart"
Cohesion: 0.15
Nodes (13): package:meettrace/ui/core/asr_model_option.dart, package:meettrace/ui/features/settings/view_models/model_settings_view_model.dart, package:meettrace/ui/features/settings/views/model_settings_view.dart, ../../../../support/model_selection_fakes.dart, installations, main, preferences, cases (+5 more)

### Community 196 - "models/manifest.json"
Cohesion: 0.50
Nodes (3): minAppVersion, models, schemaVersion

### Community 197 - "build_phase_0_4_quality_input.dart"
Cohesion: 0.14
Nodes (13): phase_0_4_quality_input_builder.dart, allowed, main, _Options, output, _parseArguments, qualityEvidenceOutput, qualityEvidenceRef (+5 more)

### Community 198 - "语义化本地日期标签"
Cohesion: 0.50
Nodes (4): AppLedgerRow, 可注入参考时间, Meeting List View, 语义化本地日期标签

### Community 199 - "madd"
Cohesion: 0.10
Nodes (39): float16x8_t, __m256bh, __m512bh, add(), float32x4_t, ggml_bf16_t, __m128, __m256 (+31 more)

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
Cohesion: 0.06
Nodes (30): app_database.dart, app_file_layout.dart, ../audio/recording_checkpoint_store.dart, ../../../../../domain/use_cases/delete_meeting.dart, durable_file_committer.dart, commit, layout, meetingsRoot (+22 more)

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

### Community 217 - "data"
Cohesion: 0.21
Nodes (10): data, gguf_get_arr_data(), gguf_write_out(), gguf_writer_base, write, write_tensor_data, written_bytes, gguf_writer_file (+2 more)

### Community 218 - "ime2_kernels.cpp"
Cohesion: 0.13
Nodes (22): gemm_kernel_i8i2k(), gemm_kernel_i8i2k_m1(), gemm_kernel_i8i2k_m4(), gemm_kernel_i8i4(), gemm_kernel_i8i4_hp(), gemm_kernel_i8i4_hp_m1(), gemm_kernel_i8i4_hp_m4(), gemm_kernel_i8i4_m1() (+14 more)

### Community 219 - "ggml_backend_cpu_context"
Cohesion: 0.17
Nodes (12): ggml_threadpool_t, ggml_backend_cpu_context, abort_callback, abort_callback_data, n_threads, threadpool, use_ref, work_data (+4 more)

### Community 221 - "spine_mem_pool_manager"
Cohesion: 0.11
Nodes (16): align_up(), vector, pool_chunk, base, fd, free_blocks, size, spine_mem_pool_hugetlb_1g (+8 more)

### Community 222 - "tinyBLAS_Q0_PPC"
Cohesion: 0.10
Nodes (17): acc_t, ArrayType, compute(), ggml_fp16_t, pack_q8_block(), tinyBLAS_Q0_PPC, A, B (+9 more)

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
Cohesion: 0.09
Nodes (21): BLOC_POS(), gemm_Mx8(), gemm_small(), mma_instr, mma_instr<ggml_bf16_t>, mma_instr<ggml_fp16_t>, packNormal(), tinyBLAS_HP16_PPC (+13 more)

### Community 238 - "ggml_are_same_shape"
Cohesion: 0.09
Nodes (30): ggml_compute_forward_add1(), ggml_compute_forward_add1_bf16_bf16(), ggml_compute_forward_add1_bf16_f32(), ggml_compute_forward_add1_f16_f16(), ggml_compute_forward_add1_f16_f32(), ggml_compute_forward_add1_f32(), ggml_compute_forward_add1_q_f32(), ggml_compute_forward_count_equal_i32() (+22 more)

### Community 239 - "ggml_kleidiai_context"
Cohesion: 0.22
Nodes (9): cpu_feature, cpu_feature_to_string(), ggml_kleidiai_context, chunk_multiplier, features, kernels_q4, kernels_q8, sme_thread_cap (+1 more)

### Community 251 - "spine_env_info"
Cohesion: 0.08
Nodes (29): vector, spine_mem_pool_backend, spine_core_info, arch_id, core_id, get_spine_core_info, spine_env_info, aicpu_id_offset (+21 more)

### Community 252 - "ggml_graph_dump_dot"
Cohesion: 0.27
Nodes (10): FILE, wchar_t, ggml_fopen(), ggml_graph_dump_dot(), ggml_graph_dump_dot_leaf_edge(), ggml_graph_dump_dot_node_edge(), ggml_graph_find(), ggml_graph_get_parent() (+2 more)

### Community 260 - "app_status_notice.dart"
Cohesion: 0.14
Nodes (13): Color, IconData, AppStatusNotice, AppStatusTone, _AppStatusVisual, build, color, icon (+5 more)

### Community 272 - "app_state_panel.dart"
Cohesion: 0.14
Nodes (13): actionLabel, AppStatePanel, _AppStatePanelKind, build, empty, error, icon, _kind (+5 more)

### Community 273 - "quantize_q5_0"
Cohesion: 0.47
Nodes (6): quantize_row_q5_0(), block_q5_0, dequantize_row_q5_0(), quantize_q5_0(), quantize_row_q5_0_impl(), quantize_row_q5_0_ref()

### Community 274 - "platform_asr_device_risk_monitor.dart"
Cohesion: 0.17
Nodes (11): android_proc_asr_device_risk_monitor.dart, asr_engine.dart, AsrRiskPlatform, changes, createPlatformAsrDeviceRiskMonitor, _currentPlatform, _currentRss, inspect (+3 more)

### Community 276 - "model_manifest_parser.dart"
Cohesion: 0.05
Nodes (40): Database?, DatabaseFactory, channelCount, RecordingContinuityProbe, run, sampleRate, 0, _compareVersions (+32 more)

### Community 285 - "Step 21：C++ Whisper 质量交付基线"
Cohesion: 0.13
Nodes (14): 10. OCR 代码审查, 1. 产品与架构边界, 2. 工具链, 3. 可复现基线, 4. 已确认缺口, 5.1 公开回归轨道, 5.2 确定性非语音烟测轨道, 5.3 阶段 0～4 自动发布评估 (+6 more)

### Community 308 - "Step 23～24：官方 VAD、预览与最终转录"
Cohesion: 0.29
Nodes (6): 1. 固定资产与原生边界, 2. 会中预览, 3. 最终转录, 4. 自动化与模拟器证据, 5. Hard Gate 3～4, Step 23～24：官方 VAD、预览与最终转录

### Community 309 - "ggml_opt_result_t"
Cohesion: 0.22
Nodes (11): ggml_opt_result_t, ggml_opt_result, ggml_opt_result_free(), ggml_opt_result_init(), loss, loss_per_datapoint, ncorrect, ndata (+3 more)

### Community 310 - "LocalFactFooter"
Cohesion: 0.67
Nodes (3): 合并本地音频事实说明, 本地事实音频底栏替代方案, LocalFactFooter

### Community 313 - "ggml_cgraph"
Cohesion: 0.18
Nodes (11): ggml_cgraph, grad_accs, grads, leafs, n_leafs, n_nodes, nodes, order (+3 more)

### Community 314 - "Step 22：Whisper 解码参数评测"
Cohesion: 0.33
Nodes (5): 1. 已实现能力, 2. 候选 Profile, 3. 可复现评测, 4. Hard Gate 2, Step 22：Whisper 解码参数评测

### Community 333 - "dart:io"
Cohesion: 0.06
Nodes (36): dart:io, _copyAsset, data, main, _modelAsset, download, requireHttps, ModelManifestParser (+28 more)

### Community 336 - "nrow_block_q2_k"
Cohesion: 0.40
Nodes (5): nrow_block_q2_k, qs, scales, scales16, zeros16

### Community 339 - "whisper_quality_metrics_test.dart"
Cohesion: 0.25
Nodes (7): _asVadObservation, _declarePipelines, _input, main, samples, ../../../tool/benchmarks/whisper_quality_metrics.dart, WhisperQualityMetricsException

### Community 343 - "Q: start meeting readiness model installation whisper initialization failure"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: start meeting readiness model installation whisper initialization failure, Source Nodes

### Community 345 - "quantize_q4_0"
Cohesion: 0.47
Nodes (6): quantize_row_q4_0(), block_q4_0, dequantize_row_q4_0(), quantize_q4_0(), quantize_row_q4_0_impl(), quantize_row_q4_0_ref()

### Community 359 - "WhisperWorker"
Cohesion: 0.50
Nodes (4): _IsolateWhisperWorker, WhisperWorker, _FakeWorker, _FakeWorker

### Community 360 - "nrow_block_q5_1"
Cohesion: 0.40
Nodes (5): nrow_block_q5_1, qh, qs, scales16, zp

### Community 366 - "ggml_opt_dataset"
Cohesion: 0.13
Nodes (17): ggml_opt_dataset_t, ggml_backend_buffer_t, vector, get_opt_pars, ggml_opt_dataset, buf, ctx, data (+9 more)

### Community 367 - "ffigen.dart"
Cohesion: 0.20
Nodes (9): package:ffigen/ffigen.dart, bindings, generator, header, includedFunctions, libclangPath, main, packageRoot (+1 more)

### Community 391 - "dart:async"
Cohesion: 0.06
Nodes (32): dart:async, ../../../../../domain/models/asr_preview.dart, int get, _FailingVoiceActivitySegmenter, accept, _availableEndSample, dispose, _disposed (+24 more)

### Community 392 - "ggml_bf16_t"
Cohesion: 0.22
Nodes (9): ggml_bf16_t, ggml_bf16_to_fp32(), ggml_bf16_to_fp32_row(), ggml_fp32_to_bf16(), ggml_fp32_to_bf16_row(), ggml_fp32_to_bf16_row_ref(), ggml_compute_bf16_to_fp32(), ggml_compute_fp32_to_bf16() (+1 more)

### Community 393 - "tinyBLAS"
Cohesion: 0.12
Nodes (16): array, ggml_compute_params, size, TA, TB, TC, packNormalInt4(), tinyBLAS (+8 more)

### Community 394 - "whisper_layer_decoder"
Cohesion: 0.08
Nodes (25): whisper_layer_decoder, attn_k_w, attn_ln_0_b, attn_ln_0_w, attn_ln_1_b, attn_ln_1_w, attn_q_b, attn_q_w (+17 more)

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
Cohesion: 0.25
Nodes (20): ggml_tensor, make_block_q5_1x32(), repack(), repack_q2_k_to_q2_k_32_bl(), repack_q3_k_to_q3_k_32_bl(), repack_q4_0_to_q4_0_16_bl(), repack_q4_0_to_q4_0_256_32_bl_ref(), repack_q4_0_to_q4_0_32_bl() (+12 more)

### Community 400 - ".compute_forward_qx"
Cohesion: 0.15
Nodes (16): ceil_div_size(), cpu::tensor_traits, ggml_compute_params, kleidiai_is_weight_header_valid(), kleidiai_sme_thread_cap(), kleidiai_weight_header, kleidiai_weight_header_from_ptr(), magic (+8 more)

### Community 401 - "pack_qs"
Cohesion: 0.12
Nodes (22): acc_C<block_q8_0, block_q4_0, is_acc>, acc_C<block_q8_0, block_q8_0, is_acc>, bytes_from_nibbles_128(), bytes_from_nibbles_32(), bytes_from_nibbles_64(), convert_B_packed_format(), block_iq4_xs, block_q4_0 (+14 more)

### Community 403 - "ggml_graph_compute"
Cohesion: 0.13
Nodes (23): clear_numa_thread_affinity(), ggml_graph_compute(), ggml_graph_compute_kickoff(), ggml_graph_compute_secondary_thread(), ggml_graph_compute_thread(), ggml_graph_compute_with_ctx(), ggml_thread_apply_affinity(), ggml_thread_apply_priority() (+15 more)

### Community 404 - "whisper_context"
Cohesion: 0.08
Nodes (25): map, whisper_context, itype, model, path_model, state, t_load_us, t_start_us (+17 more)

### Community 405 - "ggml_unravel_index"
Cohesion: 0.22
Nodes (9): ggml_get_f32_1d(), ggml_get_f32_nd(), ggml_get_i32_1d(), ggml_get_i32_nd(), ggml_set_f32_1d(), ggml_set_f32_nd(), ggml_set_i32_1d(), ggml_set_i32_nd() (+1 more)

### Community 407 - "weight_buft_supported"
Cohesion: 0.07
Nodes (35): buft_list_t, ggml_op, byteswap(), byteswap_tensor(), byteswap_tensor_data(), ggml_backend_buffer_type_t, ggml_backend_dev_t, ggml_tensor (+27 more)

### Community 409 - "quantize_row_q8_1_ref"
Cohesion: 0.29
Nodes (7): quantize_row_q8_1(), quantize_row_q8_1(), quantize_row_q8_1(), quantize_row_q8_1(), quantize_row_q8_1_generic(), block_q8_1, quantize_row_q8_1_ref()

### Community 411 - "spine_tcm.h"
Cohesion: 0.26
Nodes (19): spine_mem_pool_tcm_init(), spine_tcm_block_info(), spine_tcm_default_handle(), spine_tcm_handle_bind(), spine_tcm_handle_reset(), spine_tcm_is_available(), spine_tcm_mem_force_release(), spine_tcm_mem_free() (+11 more)

### Community 413 - "get_scale_min_k4"
Cohesion: 0.29
Nodes (11): block_q4_K, block_q5_K, dequantize_row_q4_K(), dequantize_row_q5_K(), get_scale_min_k4(), quantize_q4_K(), quantize_q5_K(), quantize_row_q4_K_impl() (+3 more)

### Community 414 - "gguf_reader"
Cohesion: 0.17
Nodes (10): gguf_reader_callback_t, gguf_init_from_callback(), gguf_read_emplace_helper(), gguf_reader, callback, data_offset, max_chunk_read, nbytes_remain (+2 more)

### Community 415 - "ggml-cpu/common.h"
Cohesion: 0.11
Nodes (14): bf16_to_f32(), f16_to_f32(), f32_to_bf16(), f32_to_f16(), ggml_fa_tile_config, KV, Q, ggml_bf16_t (+6 more)

### Community 416 - "ggml_quantize_chunk"
Cohesion: 0.22
Nodes (15): quantize_row_q4_1(), ggml_quantize_chunk(), ggml_quantize_requires_imatrix(), ggml_row_size(), block_q4_1, dequantize_row_q4_1(), quantize_mxfp4(), quantize_nvfp4() (+7 more)

### Community 417 - "app_failure.dart"
Cohesion: 0.17
Nodes (11): AppFailure, code, diagnosticContext, FailureRecoverability, FailureStage, FailureUserAction, modelId, modelVersion (+3 more)

### Community 418 - "MessageHandler"
Cohesion: 0.33
Nodes (6): HWND, LPARAM, LRESULT, UINT, WPARAM, MessageHandler

### Community 419 - "ggml_backend_dev_t"
Cohesion: 0.08
Nodes (46): dl_handle_ptr, ggml_backend_dev_t, ggml_backend_reg_t, ggml_backend_dev_backend_reg(), ggml_backend_dev_description(), ggml_backend_dev_init(), ggml_backend_dev_name(), ggml_backend_dev_type() (+38 more)

### Community 420 - "MeetingDetailViewModel"
Cohesion: 0.40
Nodes (5): _MeetingActionsOperations, _MeetingAudioOperations, _MeetingSummaryOperations, _MeetingTranscriptOperations, MeetingDetailViewModel

### Community 421 - "ffi.Opaque"
Cohesion: 0.67
Nodes (3): ffi.Opaque, mt_whisper_context, mt_whisper_vad_context

### Community 422 - "gguf_get_n_tensors"
Cohesion: 0.29
Nodes (8): gguf_add_tensor(), gguf_find_tensor(), gguf_get_n_tensors(), gguf_get_tensor_name(), gguf_get_tensor_offset(), gguf_get_tensor_size(), gguf_get_tensor_type(), gguf_set_tensor_data()

### Community 424 - "asr_model_registry.dart"
Cohesion: 0.15
Nodes (12): asr_model.dart, AsrModelDescriptor get, alpha, _byId, defaultModel, defaultModelId, findById, models (+4 more)

### Community 425 - "gguf_set_kv"
Cohesion: 0.33
Nodes (16): gguf_check_reserved_keys(), gguf_remove_key(), gguf_set_arr_str(), gguf_set_kv(), gguf_set_val_bool(), gguf_set_val_f32(), gguf_set_val_f64(), gguf_set_val_i16() (+8 more)

### Community 426 - "atomic_load_explicit"
Cohesion: 0.29
Nodes (10): atomic_int, LONG, atomic_fetch_add(), atomic_load(), atomic_load_explicit(), atomic_store(), ggml_graph_compute_check_for_work(), ggml_graph_compute_poll_for_work() (+2 more)

### Community 427 - "ggml_cpu_fp16_to_fp32"
Cohesion: 0.67
Nodes (3): ggml_fp16_t, ggml_cpu_fp16_to_fp32(), ggml_cpu_fp32_to_fp16()

### Community 428 - "ggml_compute_forward"
Cohesion: 0.11
Nodes (25): apply_binary_op(), binary_op(), ggml_compute_params, ggml_tensor, ggml_compute_forward_add_non_quantized(), ggml_compute_forward_div(), ggml_compute_forward_mul(), ggml_compute_forward_sub() (+17 more)

### Community 430 - "x86/cpu-feats.cpp"
Cohesion: 0.50
Nodes (3): bitset, cpuid(), cpuidex()

### Community 431 - "Q: clang: warning: -Wl,-z,max-page-size=16384: linker input unused 是否影响 Android 16KB page-size 兼容性"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: clang: warning: -Wl,-z,max-page-size=16384: linker input unused 是否影响 Android 16KB page-size 兼容性, Source Nodes

### Community 432 - "spine_mem_pool.cpp"
Cohesion: 0.12
Nodes (13): hugetlb_1g_region, dma_addr, flags, reserved, size, is_power_of_two(), spine_mem_pool_alloc(), spine_mem_pool_free() (+5 more)

### Community 433 - "ggml_conv_2d_dw_params"
Cohesion: 0.12
Nodes (18): ggml_compute_forward_conv_2d_dw(), ggml_compute_forward_conv_2d_dw_cwhn(), ggml_compute_forward_conv_2d_dw_whcn(), ggml_conv_2d_dw_params, batch, channels, dilation_x, dilation_y (+10 more)

### Community 435 - "AppDelegate"
Cohesion: 0.16
Nodes (10): Any, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, AppDelegate, Bool, AppDelegate, Bool (+2 more)

### Community 436 - "amx/common.h"
Cohesion: 0.21
Nodes (12): func_t, balance211(), div_up(), ggml_compute_params, T, parallel_for(), parallel_for_ggml(), ggml_compute_params (+4 more)

### Community 437 - "pool_allocation"
Cohesion: 0.17
Nodes (10): iterator, align_up_uintptr(), free_block, offset, size, pool_allocation, base, chunk_base (+2 more)

### Community 438 - "kleidiai_collect_kernel_chain"
Cohesion: 0.29
Nodes (13): GGML_KLEIDIAI_MAX_KERNEL_SLOTS, align_up(), array, ggml_kleidiai_kernels, ggml_backend_cpu_kleidiai_buffer_type_get_alloc_size(), kleidiai_collect_kernel_chain(), kleidiai_collect_kernel_chain_common(), kleidiai_collect_q4_chain() (+5 more)

### Community 439 - "ggml_tensor"
Cohesion: 0.30
Nodes (12): ggml_compute_params, ggml_tensor, forward_cont_with_permute(), forward_cpy_with_permute(), forward_get_rows(), forward_norm_f32(), forward_repeat_dim1(), forward_repeat_nrows() (+4 more)

### Community 440 - "data_control.dart"
Cohesion: 0.20
Nodes (9): databaseBytes, DiagnosticReport, fields, freeBytes, LocalStorageUsage, meetingBytes, modelBytes, toJsonText (+1 more)

### Community 441 - "Win32Window"
Cohesion: 0.13
Nodes (19): RECT, unique_ptr, DartProject, FlutterWindow, flutter_controller_, FlutterWindow::FlutterWindow(), OnCreate, OnDestroy (+11 more)

### Community 442 - "quantize_row_nvfp4_ref"
Cohesion: 0.18
Nodes (12): block_nvfp4, ggml_vec_dot_nvfp4_q8_0_generic(), quantize_row_mxfp4(), quantize_row_nvfp4(), ggml_fp32_to_ue4m3(), ggml_ue4m3_to_fp32(), best_index_mxfp4(), block_mxfp4 (+4 more)

### Community 445 - "unpack_A"
Cohesion: 0.18
Nodes (8): acc_C<block_q8_1, block_q4_1, is_acc>, block_q8_1, TA, TC, tinygemm_kernel_amx(), tinygemm_kernel_avx, tinygemm_kernel_vnni<block_q8_K, block_iq4_xs, float, BLOCK_M, BLOCK_N, BLOCK_K>, unpack_A()

### Community 447 - "ggml_opt_fit"
Cohesion: 0.22
Nodes (10): ggml_opt_get_optimizer_params, ggml_time_us(), ggml_backend_sched_t, ggml_tensor, map, ggml_opt_default_params(), ggml_opt_fit(), map_tensor() (+2 more)

### Community 448 - "prepare_whisper_quality_corpus.dart"
Cohesion: 0.17
Nodes (11): corpus, index, main, manifest, output, outputFile, repositoryRoot, requiredEvidenceClass (+3 more)

### Community 449 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.17
Nodes (10): audioplayers_darwin, connectivity_plus, FlutterPluginRegistry, FlutterViewController, Foundation, RegisterGeneratedPlugins(), record_macos, share_plus (+2 more)

### Community 450 - "make_block_q4_0x32"
Cohesion: 0.20
Nodes (10): block_q4_0x32, block_q4_0x32x256, blocks, block_q4_1x32x256, blocks, zps, block_q4_0, block_q4_0x16 (+2 more)

### Community 451 - "FILE"
Cohesion: 0.25
Nodes (8): FILE, gguf_file_reader, file, offset, gguf_init_from_file(), gguf_init_from_file_ptr(), gguf_write_to_file(), gguf_write_to_file_ptr()

### Community 452 - "MessageHandler"
Cohesion: 0.36
Nodes (10): HWND, LPARAM, LRESULT, UINT, WPARAM, EnableFullDpiSupportIfAvailable(), GetHandle, GetThisFromHandle (+2 more)

### Community 454 - "block_q8_K"
Cohesion: 0.22
Nodes (5): acc_C<block_q8_K, block_iq4_xs, is_acc>, acc_C<block_q8_K, block_q4_K, is_acc>, acc_C<block_q8_K, block_q5_K, is_acc>, acc_C<block_q8_K, block_q6_K, is_acc>, block_q8_K

### Community 456 - "q8k_blk_size"
Cohesion: 0.25
Nodes (9): gemm_kernel_i8i2k_mrow_ref(), gemm_kernel_i8i3k(), gemm_kernel_i8i3k_m1(), gemm_kernel_i8i3k_m4(), gemm_kernel_i8i3k_mrow_ref(), q8k_blk_size(), quantize_a_4row_i8k(), quantize_a_nrow_i8k_ref() (+1 more)

### Community 462 - ".supports_op"
Cohesion: 0.29
Nodes (6): cpu::extra_buffer_type, ggml_backend_dev_t, ggml_tensor, extra_buffer_type, ggml_backend_cpu_kleidiai_buffer_type(), ggml_ne()

### Community 463 - "ime_kernels.h"
Cohesion: 0.15
Nodes (13): nrow_block_mxfp4, e, qh, qs, nrow_block_q3_k, hmask, qs, scales (+5 more)

### Community 464 - "block_with_zp"
Cohesion: 0.25
Nodes (8): block, d, qs, block_with_zp, d, qs, zp, ggml_half

### Community 465 - "flash_attn_ext_f16_one_chunk_inner_vlen1024_vf16_mrow"
Cohesion: 0.31
Nodes (9): align_up(), ggml_fp16_t, vfloat32m4_t, flash_attn_ext_f16_one_chunk_inner_vlen1024_vf16_m1(), flash_attn_ext_f16_one_chunk_inner_vlen1024_vf16_mrow(), flash_attn_ext_supported_d_vlen1024_vf16(), flash_attn_ext_supported_shape_vlen1024_vf16(), forward_flash_attn_ext_f16_one_chunk_vlen1024_vf16() (+1 more)

### Community 467 - "gguf_context"
Cohesion: 0.25
Nodes (8): gguf_context, alignment, data, info, kv, offset, size, version

### Community 468 - "rvv_kernels.h"
Cohesion: 0.17
Nodes (6): gemm_kernel_i8i4_hp_mrow_ref(), div_round_up(), q8_hp_blk_size(), quantize_a_4row_i8_hp(), quantize_a_nrow_i8_hp_ref(), quantize_a_row_i8_hp()

### Community 469 - "whisper_global_cache"
Cohesion: 0.38
Nodes (4): whisper_global_cache, cos_vals, hann_window, sin_vals

### Community 470 - "gguf_tensor_info"
Cohesion: 0.67
Nodes (3): gguf_tensor_info, offset, t

### Community 472 - "Step 20：whisper.cpp 正式替换"
Cohesion: 0.33
Nodes (5): Step 20：whisper.cpp 正式替换, 变更, 已验证, 未完成, 真机复验入口

### Community 478 - "quantize_row_iq3_xxs_impl"
Cohesion: 0.18
Nodes (11): block_iq3_s, block_iq3_xxs, dequantize_row_iq3_s(), dequantize_row_iq3_xxs(), iq3_find_best_neighbour(), quantize_iq3_s(), quantize_iq3_xxs(), quantize_row_iq3_s_impl() (+3 more)

### Community 479 - "tile_config_t"
Cohesion: 0.33
Nodes (6): tile_config_t, colsb, palette_id, reserved_0, rows, start_row

### Community 481 - "quantize_q5_1"
Cohesion: 0.47
Nodes (6): block_q5_1, quantize_row_q5_1(), dequantize_row_q5_1(), quantize_q5_1(), quantize_row_q5_1_impl(), quantize_row_q5_1_ref()

### Community 483 - "local_data_control.dart"
Cohesion: 0.33
Nodes (5): LocalDataControlService, buildDiagnostics, LocalDataControlPort, measure, ../models/data_control.dart

### Community 484 - "ggml_kleidiai_select_kernels"
Cohesion: 0.47
Nodes (6): cpu_feature, ggml_kleidiai_kernels, ggml_tensor, ggml_kleidiai_select_kernels(), ggml_kleidiai_select_kernels_q4_0(), ggml_kleidiai_select_kernels_q8_0()

### Community 485 - "repack_q4_k_to_q4_1_16_bl"
Cohesion: 0.29
Nodes (8): block_q4_1x16, block_q4_1x32, block_q4_1, get_scale_min_k4(), make_block_q4_1x16(), make_block_q4_1x32(), repack_q4_k_to_q4_1_16_bl(), repack_q4_k_to_q4_1_32_bl()

### Community 486 - "ggml_backend_dev_props"
Cohesion: 0.25
Nodes (8): ggml_backend_dev_props, caps, description, device_id, memory_free, memory_total, name, type

### Community 487 - "hbm.cpp"
Cohesion: 0.36
Nodes (6): ggml_backend_buffer_t, ggml_backend_buffer_type_t, ggml_backend_cpu_hbm_buffer_free_buffer(), ggml_backend_cpu_hbm_buffer_type(), ggml_backend_cpu_hbm_buffer_type_alloc_buffer(), ggml_backend_cpu_hbm_buffer_type_get_name()

### Community 488 - "kleidiai_block_args"
Cohesion: 0.33
Nodes (6): ggml_type, kleidiai_block_args, lhs_bl, pack_bl, rhs_bl, kleidiai_get_block_args()

### Community 491 - "nrow_block_q5_0"
Cohesion: 0.40
Nodes (5): nrow_block_q5_0, qh, qs, scales16, make_block_q5_0x32()

### Community 492 - "quantize_row_iq2_s_impl"
Cohesion: 0.25
Nodes (8): block_iq2_s, dequantize_row_iq2_s(), iq2_find_best_neighbour(), quantize_iq2_s(), quantize_iq2_xs(), quantize_row_iq2_s_impl(), quantize_row_iq2_s_ref(), quantize_row_iq2_xs_impl()

### Community 494 - "ggml-quants.c"
Cohesion: 0.07
Nodes (35): block_iq1_m, block_iq1_s, block_iq2_xs, block_iq2_xxs, block_q1_0, block_tq1_0, block_tq2_0, best_index_int8() (+27 more)

### Community 496 - "ggml_scale_impl"
Cohesion: 0.16
Nodes (11): ggml_abort_callback_t, GGML_API, ggml_add1(), ggml_add1_impl(), ggml_add1_inplace(), ggml_is_padded_1d(), ggml_scale_bias(), ggml_scale_bias_inplace() (+3 more)

### Community 502 - "ime_env.cpp"
Cohesion: 0.19
Nodes (12): spine_mem_pool_backend, hex_string_to_u16(), parse_mem_backend(), spine_env_info::spine_env_info(), spine_mem_pool_backend_to_string(), spine_mem_pool_shared_mem_free(), spine_mem_pool_tcm_info, available (+4 more)

### Community 503 - "atomic_flag_test_and_set"
Cohesion: 0.50
Nodes (4): atomic_flag, atomic_flag_clear(), atomic_flag_test_and_set(), atomic_bool

### Community 505 - "WhisperWorkerFactory"
Cohesion: 0.50
Nodes (4): OfficialWhisperWorkerFactory, WhisperWorkerFactory, _FakeWorkerFactory, _FakeWorkerFactory

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
- **4834 isolated node(s):** `schemaVersion`, `minAppVersion`, `models`, `_MeetingFlowFixture`, `_modelAsset` (+4829 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **171 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

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

- **Why does `_string` connect `_string` to `use_cases/evaluate_alpha_release.dart`, `cpuid_x86`, `vector`, `size`, `whisper_state`, `whisper_full_with_state`, `whisper_context`, `ggml_backend_meta_context`, `gguf_reader`, `ggml_backend_dev_t`, `gguf_set_kv`, `gguf.cpp`, `x86/cpu-feats.cpp`, `whisper.cpp`, `ggml-cpu.cpp`, `ggml-backend-reg.cpp`, `size`, `whisper_vad_model`, `data`, `vector`, `whisper_model`, `meettrace_whisper.cpp`, `ime_env.cpp`, `ggml-backend-meta.cpp`?**
  _High betweenness centrality (0.171) - this node is a cross-community bridge._
- **Why does `cpuid_x86` connect `cpuid_x86` to `_string`, `x86/cpu-feats.cpp`, `ggml_backend_cpu_x86_score`?**
  _High betweenness centrality (0.015) - this node is a cross-community bridge._
- **Why does `whisper_model_load()` connect `size` to `ggml_dup_tensor`, `ggml_backend_dev_t`, `ggml_is_contiguous`, `whisper.cpp`, `ggml-alloc.c`, `whisper_context`, `whisper_full_with_state`, `ggml-backend.cpp`, `weight_buft_supported`, `_string`, `vector`, `ggml_opt_fit`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **Are the 98 inferred relationships involving `ggml_nrows()` (e.g. with `get_thread_range()` and `ggml_get_n_tasks()`) actually correct?**
  _`ggml_nrows()` has 98 INFERRED edges - model-reasoned connections that need verification._
- **Are the 93 inferred relationships involving `ggml_compute_forward()` (e.g. with `ggml_compute_forward_div()` and `ggml_compute_forward_mul()`) actually correct?**
  _`ggml_compute_forward()` has 93 INFERRED edges - model-reasoned connections that need verification._
- **What connects `schemaVersion`, `minAppVersion`, `models` to the rest of the system?**
  _4834 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `meeting_detail_view_model.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.017241379310344827 - nodes in this community are weakly interconnected._
