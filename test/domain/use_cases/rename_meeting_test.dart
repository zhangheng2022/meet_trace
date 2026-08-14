import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/ports/repositories.dart';
import 'package:meettrace/domain/use_cases/rename_meeting.dart';

void main() {
  test('规范化标题后使用字段级更新并返回最新会议', () async {
    final repository = _MeetingRepository(_meeting());
    final useCase = RenameMeetingUseCase(meetings: repository);

    final renamed = await useCase.execute(
      meetingId: 'meeting-1',
      title: '  产品评审会  ',
    );

    expect(renamed.title, '产品评审会');
    expect(repository.updatedTitles, ['产品评审会']);
  });

  test('标题未变化时不写数据库', () async {
    final repository = _MeetingRepository(_meeting());
    final useCase = RenameMeetingUseCase(meetings: repository);

    final current = await useCase.execute(
      meetingId: 'meeting-1',
      title: '  周会 ',
    );

    expect(current.title, '周会');
    expect(repository.updatedTitles, isEmpty);
  });
}

final class _MeetingRepository implements MeetingRepository {
  _MeetingRepository(this.value);

  Meeting? value;
  final List<String> updatedTitles = [];

  @override
  Future<Meeting?> getById(String meetingId) async =>
      value?.id == meetingId ? value : null;

  @override
  Future<Meeting> updateTitle({
    required String meetingId,
    required String title,
  }) async {
    updatedTitles.add(title);
    return value = value!.rename(title);
  }

  @override
  Future<void> delete(String meetingId) async {}

  @override
  Future<void> save(Meeting meeting) async => value = meeting;

  @override
  Stream<List<Meeting>> watchAll() => const Stream.empty();
}

Meeting _meeting() => Meeting(
  id: 'meeting-1',
  title: '周会',
  createdAt: DateTime.utc(2026, 8, 14),
  status: MeetingState.processing,
  audioDurationMs: 60000,
  recordingModelId: 'sense-voice',
  recordingModelVersion: '2024-07-17',
);
