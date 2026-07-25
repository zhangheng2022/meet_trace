import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../domain/use_cases/delete_meeting.dart';
import 'app_file_layout.dart';

final class MeetingDirectoryDeletionService
    implements MeetingFileDeletionService {
  const MeetingDirectoryDeletionService({
    required this.layout,
    this.now = DateTime.now,
  });

  final AppFileLayout layout;
  final DateTime Function() now;

  @override
  Future<StagedMeetingDeletion> stage(String meetingId) async {
    final source = layout.meetingDirectory(meetingId);
    _requireWithinMeetingsRoot(source);
    final directory = Directory(source);
    if (!await directory.exists()) {
      return const _NoopStagedMeetingDeletion();
    }
    final stagedPath = p.join(
      layout.meetingsRoot,
      '.deleting-$meetingId-${now().microsecondsSinceEpoch}',
    );
    _requireWithinMeetingsRoot(stagedPath);
    await directory.rename(stagedPath);
    return _DirectoryStagedMeetingDeletion(
      originalPath: source,
      stagedPath: stagedPath,
      meetingsRoot: layout.meetingsRoot,
    );
  }

  void _requireWithinMeetingsRoot(String candidate) {
    final root = p.normalize(p.absolute(layout.meetingsRoot));
    final normalized = p.normalize(p.absolute(candidate));
    if (normalized == root || !p.isWithin(root, normalized)) {
      throw StateError('拒绝操作会议数据根目录之外的路径');
    }
  }
}

final class _NoopStagedMeetingDeletion implements StagedMeetingDeletion {
  const _NoopStagedMeetingDeletion();

  @override
  Future<void> commit() async {}

  @override
  Future<void> rollback() async {}
}

final class _DirectoryStagedMeetingDeletion implements StagedMeetingDeletion {
  const _DirectoryStagedMeetingDeletion({
    required this.originalPath,
    required this.stagedPath,
    required this.meetingsRoot,
  });

  final String originalPath;
  final String stagedPath;
  final String meetingsRoot;

  @override
  Future<void> commit() async {
    _validate(stagedPath);
    final staged = Directory(stagedPath);
    if (await staged.exists()) {
      await staged.delete(recursive: true);
    }
  }

  @override
  Future<void> rollback() async {
    _validate(originalPath);
    _validate(stagedPath);
    final staged = Directory(stagedPath);
    if (!await staged.exists()) {
      return;
    }
    if (await Directory(originalPath).exists()) {
      throw StateError('会议目录已存在，无法恢复暂存数据');
    }
    await staged.rename(originalPath);
  }

  void _validate(String candidate) {
    final root = p.normalize(p.absolute(meetingsRoot));
    final normalized = p.normalize(p.absolute(candidate));
    if (normalized == root || !p.isWithin(root, normalized)) {
      throw StateError('拒绝操作会议数据根目录之外的路径');
    }
  }
}
