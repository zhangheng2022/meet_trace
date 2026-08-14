import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../../../../domain/models/meeting.dart';
import '../../../../../../theme/theme.dart';
import '../../../../../core/app_sheet.dart';
import '../../../../../core/app_text_field.dart';

final class RenameMeetingSheet extends StatefulWidget {
  const RenameMeetingSheet({
    required this.meeting,
    required this.onSave,
    super.key,
  });

  final Meeting meeting;
  final Future<bool> Function(String title) onSave;

  @override
  State<RenameMeetingSheet> createState() => _RenameMeetingSheetState();
}

final class _RenameMeetingSheetState extends State<RenameMeetingSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.meeting.title)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.meeting.title.length,
        );
  bool _saving = false;
  bool _saveFailed = false;

  String get _normalized => normalizeMeetingTitle(_controller.text);

  String? get _validationMessage =>
      switch (meetingTitleIssue(_controller.text)) {
        MeetingTitleIssue.empty => '请输入会议标题',
        MeetingTitleIssue.multiline => '会议标题只能使用单行文本',
        MeetingTitleIssue.tooLong => '会议标题最多 $meetingTitleMaxLength 个字符',
        null => null,
      };

  bool get _canSave =>
      !_saving &&
      _validationMessage == null &&
      _normalized != widget.meeting.title;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    return PopScope(
      canPop: !_saving,
      child: AppSheetSurface(
        surfaceKey: const ValueKey('rename-meeting-sheet'),
        title: '重命名会议',
        description: '只修改显示标题，不会改变事实音频、会议时间、转录或处理状态。',
        semanticsLabel: '重命名会议',
        footer: LayoutBuilder(
          builder: (context, constraints) {
            final cancel = FButton(
              key: const ValueKey('cancel-rename-meeting'),
              variant: FButtonVariant.outline,
              size: FButtonSizeVariant.lg,
              onPress: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('取消'),
            );
            final save = FButton(
              key: const ValueKey('save-rename-meeting'),
              size: FButtonSizeVariant.lg,
              onPress: _canSave ? () => unawaited(_save()) : null,
              child: Text(_saving ? '正在保存' : '保存标题'),
            );
            if (constraints.maxWidth < appStyle.dualActionMinWidth ||
                MediaQuery.textScalerOf(context).scale(1) > 1.4) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  save,
                  SizedBox(height: appStyle.spaceSm),
                  cancel,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: cancel),
                SizedBox(width: appStyle.spaceSm),
                Expanded(child: save),
              ],
            );
          },
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              key: const ValueKey('rename-meeting-title-field'),
              controller: _controller,
              label: '会议标题',
              hint: '输入会议标题',
              maxLength: meetingTitleMaxLength,
              autofocus: true,
              enabled: !_saving,
              errorText: _validationMessage,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() => _saveFailed = false),
              onSubmitted: (_) {
                if (_canSave) {
                  unawaited(_save());
                }
              },
            ),
            if (_saveFailed) ...[
              SizedBox(height: appStyle.spaceSm),
              Text(
                '重命名失败，原会议标题仍保留。请重试。',
                key: const ValueKey('rename-meeting-save-error'),
                style: context.theme.typography.body.sm.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_canSave) {
      return;
    }
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    final saved = await widget.onSave(_controller.text);
    if (!mounted) {
      return;
    }
    if (saved) {
      Navigator.of(context).pop(_normalized);
      return;
    }
    setState(() {
      _saving = false;
      _saveFailed = true;
    });
  }
}
