import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/ports/repositories.dart';
import 'package:meettrace/domain/models/domain_exception.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/use_cases/delete_meeting.dart';

void main() {
  test('先暂存会议文件再删除数据库并最终清理文件', () async {
    final meetings = _MeetingRepository();
    final files = _FileDeletionService();
    final useCase = DeleteMeetingUseCase(meetings: meetings, files: files);

    await useCase.execute(meetingId: 'meeting-1');

    expect(files.events, ['stage', 'commit']);
    expect(meetings.deleted, ['meeting-1']);
  });

  test('数据库删除失败时恢复已暂存的会议文件', () async {
    final meetings = _MeetingRepository(failDelete: true);
    final files = _FileDeletionService();
    final useCase = DeleteMeetingUseCase(meetings: meetings, files: files);

    await expectLater(
      useCase.execute(meetingId: 'meeting-1'),
      throwsA(isA<StateError>()),
    );

    expect(files.events, ['stage', 'rollback']);
  });

  for (final state in [MeetingState.recording, MeetingState.processing]) {
    test('${state.name} 状态拒绝删除且不暂存事实文件', () async {
      final meetings = _MeetingRepository(state: state);
      final files = _FileDeletionService();
      final useCase = DeleteMeetingUseCase(meetings: meetings, files: files);

      await expectLater(
        useCase.execute(meetingId: 'meeting-1'),
        throwsA(isA<DomainInvariantViolation>()),
      );

      expect(files.events, isEmpty);
      expect(meetings.deleted, isEmpty);
    });
  }
}

final class _MeetingRepository implements MeetingRepository {
  _MeetingRepository({
    this.failDelete = false,
    MeetingState state = MeetingState.completed,
  }) : meeting = Meeting(
         id: 'meeting-1',
         title: '周会',
         createdAt: DateTime.utc(2026, 7, 25),
         status: state,
         audioDurationMs: 0,
         recordingModelId: 'paraformer',
         recordingModelVersion: '1',
       );

  final bool failDelete;
  final List<String> deleted = [];
  final Meeting meeting;

  @override
  Future<Meeting?> getById(String meetingId) async =>
      meeting.id == meetingId ? meeting : null;

  @override
  Stream<List<Meeting>> watchAll() => Stream.value([meeting]);

  @override
  Future<void> save(Meeting meeting) async {}

  @override
  Future<void> delete(String meetingId) async {
    if (failDelete) {
      throw StateError('数据库删除失败');
    }
    deleted.add(meetingId);
  }
}

final class _FileDeletionService implements MeetingFileDeletionService {
  final List<String> events = [];

  @override
  Future<StagedMeetingDeletion> stage(String meetingId) async {
    events.add('stage');
    return _StagedDeletion(events);
  }
}

final class _StagedDeletion implements StagedMeetingDeletion {
  _StagedDeletion(this.events);

  final List<String> events;

  @override
  Future<void> commit() async {
    events.add('commit');
  }

  @override
  Future<void> rollback() async {
    events.add('rollback');
  }
}
