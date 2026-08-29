import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';

import '../../../../../../domain/models/meeting.dart';
import '../../../../../../l10n/l10n.dart';
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

  String? _validationMessage(AppLocalizations l10n) =>
      switch (meetingTitleIssue(_controller.text)) {
        MeetingTitleIssue.empty => l10n.meetingTitleRequired,
        MeetingTitleIssue.multiline => l10n.meetingTitleSingleLine,
        MeetingTitleIssue.tooLong => l10n.meetingTitleMaxLength(
          meetingTitleMaxLength,
        ),
        null => null,
      };

  bool _canSave(AppLocalizations l10n) =>
      !_saving &&
      _validationMessage(l10n) == null &&
      _normalized != widget.meeting.title;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final appStyle = context.theme.style.app;
    return PopScope(
      canPop: !_saving,
      child: AppSheetSurface(
        surfaceKey: const ValueKey('rename-meeting-sheet'),
        title: l10n.renameMeetingTitle,
        semanticsLabel: l10n.renameMeetingTitle,
        compact: true,
        footer: LayoutBuilder(
          builder: (context, constraints) {
            final cancel = FButton(
              key: const ValueKey('cancel-rename-meeting'),
              variant: FButtonVariant.outline,
              size: FButtonSizeVariant.lg,
              onPress: _saving ? null : () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            );
            final save = FButton(
              key: const ValueKey('save-rename-meeting'),
              size: FButtonSizeVariant.lg,
              onPress: _canSave(l10n) ? () => unawaited(_save(l10n)) : null,
              child: Text(_saving ? l10n.saving : l10n.save),
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
              label: l10n.meetingTitleLabel,
              hint: l10n.meetingTitleHint,
              maxLength: meetingTitleMaxLength,
              counterVisibilityThreshold: 50,
              autofocus: true,
              enabled: !_saving,
              errorText: _validationMessage(l10n),
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() => _saveFailed = false),
              onSubmitted: (_) {
                if (_canSave(l10n)) {
                  unawaited(_save(l10n));
                }
              },
            ),
            if (_saveFailed) ...[
              SizedBox(height: appStyle.spaceSm),
              Text(
                l10n.renameFailedPreserved,
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

  Future<void> _save(AppLocalizations l10n) async {
    if (!_canSave(l10n)) {
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
