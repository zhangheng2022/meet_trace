import '../models/meeting.dart';
import '../models/transcript.dart';

enum MeetingShareFormat { plainText, markdown }

final class MeetingShareDocument {
  const MeetingShareDocument({required this.subject, required this.text});

  final String subject;
  final String text;
}

final class BuildMeetingShareUseCase {
  const BuildMeetingShareUseCase({
    this.copy = const MeetingShareCopy.chinese(),
    this.dateTimeFormatter = meetingStartTimeLabel,
    this.speakerLabelBuilder = _defaultSpeakerLabel,
  });

  final MeetingShareCopy copy;
  final String Function(DateTime) dateTimeFormatter;
  final String Function(int number) speakerLabelBuilder;

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
    final trimmedTitle = meeting.title.trim();
    final title = trimmedTitle.isEmpty ? copy.untitledMeeting : trimmedTitle;
    final startedAt = dateTimeFormatter(meeting.createdAt);
    final text = switch (format) {
      MeetingShareFormat.plainText => _plainText(
        title,
        startedAt,
        snapshot,
        copy,
        speakerLabelBuilder,
      ),
      MeetingShareFormat.markdown => _markdown(
        title,
        startedAt,
        snapshot,
        copy,
        speakerLabelBuilder,
      ),
    };
    return MeetingShareDocument(subject: title, text: text);
  }
}

final class MeetingShareCopy {
  const MeetingShareCopy({
    required this.untitledMeeting,
    required this.meetingTimeLabel,
    required this.finalTranscriptTitle,
    required this.speakerFallback,
    required this.exportFooter,
    required this.labelSeparator,
  });

  const MeetingShareCopy.chinese()
    : untitledMeeting = '未命名会议',
      meetingTimeLabel = '会议时间',
      finalTranscriptTitle = '最终转录',
      speakerFallback = '说话人 1',
      exportFooter = '由会迹从本机最终转录导出；不包含原始音频。',
      labelSeparator = '：';

  final String untitledMeeting;
  final String meetingTimeLabel;
  final String finalTranscriptTitle;
  final String speakerFallback;
  final String exportFooter;
  final String labelSeparator;
}

String _plainText(
  String title,
  String startedAt,
  TranscriptSnapshot snapshot,
  MeetingShareCopy copy,
  String Function(int number) speakerLabelBuilder,
) {
  final buffer = StringBuffer()
    ..writeln(title)
    ..writeln('${copy.meetingTimeLabel}${copy.labelSeparator}$startedAt')
    ..writeln()
    ..writeln(copy.finalTranscriptTitle);
  for (final segment in snapshot.segments) {
    buffer.writeln(
      '[${_range(segment.startMs, segment.endMs)}] '
      '${_speaker(segment.speakerId, copy, speakerLabelBuilder)}'
      '${copy.labelSeparator}${segment.text}',
    );
  }
  buffer
    ..writeln()
    ..writeln(copy.exportFooter);
  return buffer.toString().trimRight();
}

String _markdown(
  String title,
  String startedAt,
  TranscriptSnapshot snapshot,
  MeetingShareCopy copy,
  String Function(int number) speakerLabelBuilder,
) {
  final buffer = StringBuffer()
    ..writeln('# $title')
    ..writeln()
    ..writeln('**${copy.meetingTimeLabel}**${copy.labelSeparator}$startedAt')
    ..writeln()
    ..writeln('## ${copy.finalTranscriptTitle}')
    ..writeln();
  for (final segment in snapshot.segments) {
    buffer.writeln(
      '- **${_range(segment.startMs, segment.endMs)} · '
      '${_speaker(segment.speakerId, copy, speakerLabelBuilder)}**'
      '${copy.labelSeparator}${segment.text}',
    );
  }
  buffer
    ..writeln()
    ..writeln('> ${copy.exportFooter}');
  return buffer.toString().trimRight();
}

String _speaker(
  String? speakerId,
  MeetingShareCopy copy,
  String Function(int number) speakerLabelBuilder,
) {
  final normalized = speakerId?.trim();
  if (normalized == null || normalized.isEmpty) {
    return copy.speakerFallback;
  }
  final automatic = RegExp(r'^speaker-(\d+)$').firstMatch(normalized);
  final number = automatic == null ? null : int.tryParse(automatic.group(1)!);
  return number == null ? normalized : speakerLabelBuilder(number);
}

String _defaultSpeakerLabel(int number) => '说话人 $number';

String _range(int startMs, int endMs) =>
    '${_timestamp(startMs)}–${_timestamp(endMs)}';

String _timestamp(int milliseconds) {
  final totalSeconds = milliseconds ~/ 1000;
  final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
