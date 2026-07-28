import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/repositories/repository_contracts.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/meeting_readiness.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/ui/core/view_state.dart';
import 'package:meettrace/ui/features/meetings/view_models/meeting_list_view_model.dart';

import '../../../../support/model_selection_fakes.dart';

void main() {
  test('先显示加载，再响应本地会议流的正常与失败状态', () async {
    final repository = _StreamingMeetingRepository();
    final viewModel = MeetingListViewModel(
      meetings: repository,
      readinessChecker: TestMeetingReadinessChecker(),
    );

    expect(viewModel.state, isA<ViewLoading<List<Meeting>>>());
    viewModel.load();
    repository.emit([_meeting()]);
    await Future<void>.delayed(Duration.zero);

    final data = viewModel.state as ViewData<List<Meeting>>;
    expect(data.value.single.title, '产品评审');

    repository.fail(StateError('database unavailable'));
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.state, isA<ViewError<List<Meeting>>>());

    viewModel.dispose();
    await repository.dispose();
  });

  test('加载首页时执行无权限弹窗的真实预检并暴露阻塞状态', () async {
    final repository = _StreamingMeetingRepository();
    final readiness = TestMeetingReadinessChecker(
      result: MeetingReadiness(
        microphonePermissionGranted: false,
        freeBytes: minimumRecordingFreeBytes,
        defaultModelId: 'paraformer',
        defaultModelName: '标准模型（Paraformer）',
        defaultModelAvailable: true,
      ),
    );
    final viewModel = MeetingListViewModel(
      meetings: repository,
      readinessChecker: readiness,
    );

    viewModel.load();
    await Future<void>.delayed(Duration.zero);

    expect(readiness.permissionRequests, [false]);
    expect(
      viewModel.readiness.status,
      MeetingReadinessStatus.microphonePermissionRequired,
    );
    expect(viewModel.readiness.issueCount, 1);

    viewModel.dispose();
    await repository.dispose();
  });
}

final class _StreamingMeetingRepository implements MeetingRepository {
  final StreamController<List<Meeting>> _controller =
      StreamController<List<Meeting>>.broadcast();

  void emit(List<Meeting> meetings) => _controller.add(meetings);

  void fail(Object error) => _controller.addError(error);

  Future<void> dispose() => _controller.close();

  @override
  Future<void> delete(String meetingId) async {}

  @override
  Future<Meeting?> getById(String meetingId) async => null;

  @override
  Future<void> save(Meeting meeting) async {}

  @override
  Stream<List<Meeting>> watchAll() => _controller.stream;
}

Meeting _meeting() => Meeting(
  id: 'meeting-1',
  title: '产品评审',
  createdAt: DateTime.utc(2026, 7, 24),
  status: MeetingState.processing,
  audioDurationMs: 60000,
  requestedModelId: 'paraformer',
  recordingModelId: 'paraformer',
  recordingModelVersion: '1',
);
