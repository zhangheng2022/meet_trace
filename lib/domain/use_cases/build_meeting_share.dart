import '../models/meeting.dart';
import '../models/transcript.dart';

enum MeetingShareFormat { plainText, markdown }

final class MeetingShareDocument {
  const MeetingShareDocument({
    required this.subject,
    required this.text,
    required this.fileName,
  });

  final String subject;
  final String text;
  final String fileName;
}

final class BuildMeetingShareUseCase {
  const BuildMeetingShareUseCase();

  MeetingShareDocument execute({
    required Meeting meeting,
    required TranscriptSnapshot snapshot,
    required MeetingShareFormat format,
  }) {
    if (!snapshot.isCurrentFinalTranscript(
      activeSnapshotId: meeting.activeTranscriptSnapshotId,
    )) {
      throw ArgumentError('分享只能读取当前已完成的最终转录');
    }
    final title = meeting.title.trim().isEmpty ? '未命名会议' : meeting.title;
    final startedAt = meetingStartTimeLabel(meeting.createdAt);
    final text = switch (format) {
      MeetingShareFormat.plainText => _plainText(title, startedAt, snapshot),
      MeetingShareFormat.markdown => _markdown(title, startedAt, snapshot),
    };
    return MeetingShareDocument(
      subject: title,
      text: text,
      fileName:
          '${_safeFileName(title)}.'
          '${format == MeetingShareFormat.markdown ? 'md' : 'txt'}',
    );
  }
}

String _plainText(String title, String startedAt, TranscriptSnapshot snapshot) {
  final buffer = StringBuffer()
    ..writeln(title)
    ..writeln('会议时间：$startedAt')
    ..writeln()
    ..writeln('最终转录');
  for (final segment in snapshot.segments) {
    buffer.writeln(
      '[${_range(segment.startMs, segment.endMs)}] '
      '${_speaker(segment.speakerId)}：${segment.text}',
    );
  }
  buffer
    ..writeln()
    ..writeln('由会迹从本机最终转录导出；不包含原始音频。');
  return buffer.toString().trimRight();
}

String _markdown(String title, String startedAt, TranscriptSnapshot snapshot) {
  final buffer = StringBuffer()
    ..writeln('# $title')
    ..writeln()
    ..writeln('**会议时间**：$startedAt')
    ..writeln()
    ..writeln('## 最终转录')
    ..writeln();
  for (final segment in snapshot.segments) {
    buffer.writeln(
      '- **${_range(segment.startMs, segment.endMs)} · '
      '${_speaker(segment.speakerId)}**：${segment.text}',
    );
  }
  buffer
    ..writeln()
    ..writeln('> 由会迹从本机最终转录导出；不包含原始音频。');
  return buffer.toString().trimRight();
}

String _speaker(String? speakerId) =>
    speakerId?.trim().isNotEmpty == true ? speakerId!.trim() : '说话人 1';

String _range(int startMs, int endMs) =>
    '${_timestamp(startMs)}–${_timestamp(endMs)}';

String _timestamp(int milliseconds) {
  final totalSeconds = milliseconds ~/ 1000;
  final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _safeFileName(String value) {
  final sanitized = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  return sanitized.isEmpty ? '会议记录' : sanitized;
}
