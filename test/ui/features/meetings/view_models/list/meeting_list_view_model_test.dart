import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/meeting_readiness.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/ports/repositories.dart';
import 'package:meettrace/domain/use_cases/delete_meeting.dart';
import 'package:meettrace/ui/core/view_state.dart';
import 'package:meettrace/ui/features/meetings/view_models/list/meeting_list_view_model.dart';

import '../../../../../support/model_selection_fakes.dart';

void main() {
  test('先显示加载，再响应本地会议流的正常与失败状态', () async {
    final repository = _StreamingMeetingRepository();
    final viewModel = MeetingListViewModel(
      meetings: repository,
      readinessChecker: TestMeetingReadinessChecker(),
      deletion: _deletion(repository),
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
        defaultModelVersion: AsrModelRegistry.alpha.defaultModel.version,
        defaultModelName: 'SenseVoice',
        defaultModelAvailable: true,
      ),
    );
    final viewModel = MeetingListViewModel(
      meetings: repository,
      readinessChecker: readiness,
      deletion: _deletion(repository),
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

  test('仅允许删除未录音且未处于后台处理的会议', () {
    final repository = _StreamingMeetingRepository();
    final viewModel = MeetingListViewModel(
      meetings: repository,
      readinessChecker: TestMeetingReadinessChecker(),
      deletion: _deletion(repository),
    );

    expect(
      viewModel.canDeleteMeeting(_meeting(state: MeetingState.recording)),
      isFalse,
    );
    expect(
      viewModel.canDeleteMeeting(_meeting(state: MeetingState.processing)),
      isFalse,
    );
    expect(
      viewModel.canDeleteMeeting(_meeting(state: MeetingState.completed)),
      isTrue,
    );
    expect(
      viewModel.canDeleteMeeting(_meeting(state: MeetingState.failed)),
      isTrue,
    );

    viewModel.dispose();
  });

  test('删除期间只标记目标会议并在成功后清除状态', () async {
    final repository = _StreamingMeetingRepository();
    final files = _BlockingFileDeletionService();
    final viewModel = MeetingListViewModel(
      meetings: repository,
      readinessChecker: TestMeetingReadinessChecker(),
      deletion: DeleteMeetingUseCase(meetings: repository, files: files),
    );
    final meeting = _meeting(state: MeetingState.completed);
    repository.emit([meeting]);
    final operation = viewModel.deleteMeeting(meeting);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.isDeletingMeeting(meeting.id), isTrue);
    expect(viewModel.canDeleteMeeting(meeting), isFalse);
    files.release();
    expect(await operation, isTrue);
    expect(viewModel.isDeletingMeeting(meeting.id), isFalse);
    expect(repository.deleted, [meeting.id]);
    expect(viewModel.deleteErrorMessage, isNull);

    viewModel.dispose();
    await repository.dispose();
  });

  test('删除失败时保留会议并暴露可恢复错误', () async {
    final repository = _StreamingMeetingRepository(failDelete: true);
    final viewModel = MeetingListViewModel(
      meetings: repository,
      readinessChecker: TestMeetingReadinessChecker(),
      deletion: _deletion(repository),
    );
    final meeting = _meeting(state: MeetingState.completed);
    repository.emit([meeting]);

    expect(await viewModel.deleteMeeting(meeting), isFalse);
    expect(viewModel.deleteErrorMessage, '删除失败，会议数据仍保留');
    expect(repository.deleted, isEmpty);

    viewModel.dispose();
    await repository.dispose();
  });
}

final class _StreamingMeetingRepository implements MeetingRepository {
  _StreamingMeetingRepository({this.failDelete = false});

  final bool failDelete;
  final StreamController<List<Meeting>> _controller =
      StreamController<List<Meeting>>.broadcast();
  final List<String> deleted = [];
  List<Meeting> _meetings = const [];

  void emit(List<Meeting> meetings) {
    _meetings = List.of(meetings);
    _controller.add(List.unmodifiable(_meetings));
  }

  void fail(Object error) => _controller.addError(error);

  Future<void> dispose() => _controller.close();

  @override
  Future<void> delete(String meetingId) async {
    if (failDelete) {
      throw StateError('数据库删除失败');
    }
    deleted.add(meetingId);
    _meetings = [
      for (final meeting in _meetings)
        if (meeting.id != meetingId) meeting,
    ];
    _controller.add(List.unmodifiable(_meetings));
  }

  @override
  Future<Meeting?> getById(String meetingId) async {
    for (final meeting in _meetings) {
      if (meeting.id == meetingId) {
        return meeting;
      }
    }
    return null;
  }

  @override
  Future<void> save(Meeting meeting) async {}

  @override
  Stream<List<Meeting>> watchAll() => _controller.stream;
}

DeleteMeetingUseCase _deletion(_StreamingMeetingRepository repository) =>
    DeleteMeetingUseCase(
      meetings: repository,
      files: const _ImmediateFileDeletionService(),
    );

final class _ImmediateFileDeletionService
    implements MeetingFileDeletionService {
  const _ImmediateFileDeletionService();

  @override
  Future<StagedMeetingDeletion> stage(String meetingId) async =>
      const _TestStagedDeletion();
}

final class _BlockingFileDeletionService implements MeetingFileDeletionService {
  final Completer<void> _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<StagedMeetingDeletion> stage(String meetingId) async {
    await _gate.future;
    return const _TestStagedDeletion();
  }
}

final class _TestStagedDeletion implements StagedMeetingDeletion {
  const _TestStagedDeletion();

  @override
  Future<void> commit() async {}

  @override
  Future<void> rollback() async {}
}

Meeting _meeting({MeetingState state = MeetingState.processing}) => Meeting(
  id: 'meeting-1',
  title: '产品评审',
  createdAt: DateTime.utc(2026, 7, 24),
  status: state,
  audioDurationMs: 60000,
  recordingModelId: 'paraformer',
  recordingModelVersion: '1',
);
