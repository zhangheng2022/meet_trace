import '../models/meeting.dart';
import '../models/summary.dart';
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
    required Summary? summary,
    required MeetingShareFormat format,
  }) {
    if (!snapshot.isEligibleForSummary(
      activeSnapshotId: meeting.activeTranscriptSnapshotId,
    )) {
      throw ArgumentError('分享只能读取当前已完成的最终转录');
    }
    final title = meeting.title.trim().isEmpty ? '未命名会议' : meeting.title;
    final text = switch (format) {
      MeetingShareFormat.plainText => _plainText(title, snapshot, summary),
      MeetingShareFormat.markdown => _markdown(title, snapshot, summary),
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

String _plainText(String title, TranscriptSnapshot snapshot, Summary? summary) {
  final buffer = StringBuffer()
    ..writeln(title)
    ..writeln()
    ..writeln('最终转录');
  for (final segment in snapshot.segments) {
    buffer.writeln(
      '[${_range(segment.startMs, segment.endMs)}] '
      '${_speaker(segment.speakerId)}：${segment.text}',
    );
  }
  _writePlainSummary(buffer, summary);
  buffer
    ..writeln()
    ..writeln('由研会 AI 从本机最终转录导出；不包含原始音频。');
  return buffer.toString().trimRight();
}

String _markdown(String title, TranscriptSnapshot snapshot, Summary? summary) {
  final buffer = StringBuffer()
    ..writeln('# $title')
    ..writeln()
    ..writeln('## 最终转录')
    ..writeln();
  for (final segment in snapshot.segments) {
    buffer.writeln(
      '- **${_range(segment.startMs, segment.endMs)} · '
      '${_speaker(segment.speakerId)}**：${segment.text}',
    );
  }
  _writeMarkdownSummary(buffer, summary);
  buffer
    ..writeln()
    ..writeln('> 由研会 AI 从本机最终转录导出；不包含原始音频。');
  return buffer.toString().trimRight();
}

void _writePlainSummary(StringBuffer buffer, Summary? summary) {
  if (summary == null) {
    return;
  }
  buffer
    ..writeln()
    ..writeln('AI 生成总结${summary.status == SummaryStatus.stale ? '（已过期）' : ''}')
    ..writeln(summary.overview);
  _writePlainItems(buffer, '关键结论', summary.keyPoints);
  _writePlainItems(buffer, '行动项', summary.actionItems);
}

void _writePlainItems(
  StringBuffer buffer,
  String title,
  List<SummaryItem> items,
) {
  if (items.isEmpty) {
    return;
  }
  buffer.writeln(title);
  for (final item in items) {
    buffer.writeln('- ${item.text}${item.isPendingReview ? '【待核对】' : ''}');
    for (final evidence in item.evidence) {
      buffer.writeln(
        '  证据 ${_range(evidence.startMs, evidence.endMs)}：${evidence.quote}',
      );
    }
  }
}

void _writeMarkdownSummary(StringBuffer buffer, Summary? summary) {
  if (summary == null) {
    return;
  }
  buffer
    ..writeln()
    ..writeln(
      '## AI 生成总结${summary.status == SummaryStatus.stale ? '（已过期）' : ''}',
    )
    ..writeln()
    ..writeln(summary.overview);
  _writeMarkdownItems(buffer, '关键结论', summary.keyPoints);
  _writeMarkdownItems(buffer, '行动项', summary.actionItems);
}

void _writeMarkdownItems(
  StringBuffer buffer,
  String title,
  List<SummaryItem> items,
) {
  if (items.isEmpty) {
    return;
  }
  buffer
    ..writeln()
    ..writeln('### $title');
  for (final item in items) {
    buffer.writeln('- ${item.text}${item.isPendingReview ? ' **【待核对】**' : ''}');
    for (final evidence in item.evidence) {
      buffer.writeln(
        '  - 证据 ${_range(evidence.startMs, evidence.endMs)}：'
        '${evidence.quote}',
      );
    }
  }
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
