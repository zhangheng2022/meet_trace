import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../../../l10n/l10n.dart';
import '../../../../../../theme/theme.dart';
import '../../../../../core/app_page_body.dart';
import '../../../view_models/detail/meeting_detail_view_model.dart';
import '../audio/meeting_audio_actions.dart';
import '../widgets/meeting_result_layout.dart';

final class MeetingProcessingView extends StatelessWidget {
  const MeetingProcessingView({required this.viewModel, super.key});

  final MeetingDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return SingleChildScrollView(
      child: AppPageBody(
        width: AppPageWidth.reading,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MeetingIdentity(viewModel: viewModel),
            SizedBox(height: appStyle.spaceLg),
            AudioEvidenceStrip(viewModel: viewModel),
            SizedBox(height: appStyle.spaceXl),
            _ProcessingLedger(viewModel: viewModel),
          ],
        ),
      ),
    );
  }
}

final class _ProcessingLedger extends StatelessWidget {
  const _ProcessingLedger({required this.viewModel});

  final MeetingDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final modelName = viewModel.sourceModel.displayName;
    final l10n = context.l10n;
    final outcome = viewModel.diarizationAvailable
        ? l10n.finalShowsSpeakers
        : l10n.speakerSeparationUnavailableOutcome;
    return Semantics(
      key: const ValueKey('meeting-processing-ledger'),
      container: true,
      liveRegion: true,
      label: l10n.processingSemanticsLabel(modelName, outcome),
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colors.card,
            border: Border.symmetric(
              horizontal: BorderSide(
                color: theme.colors.border,
                width: appStyle.dividerWidth,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: appStyle.spaceMd,
              vertical: appStyle.spaceLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FProgress(semanticsLabel: l10n.generatingFinalResult),
                SizedBox(height: appStyle.spaceLg),
                Text(
                  l10n.generatingFinalResult,
                  style: theme.typography.display.lg,
                ),
                SizedBox(height: appStyle.spaceXs),
                Text(
                  l10n.modelProcessingFullRecording(modelName),
                  style: theme.typography.body.md,
                ),
                SizedBox(height: appStyle.spaceSm),
                Text(
                  outcome,
                  key: const ValueKey('meeting-processing-outcome'),
                  style: theme.typography.body.sm.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
                SizedBox(height: appStyle.spaceLg),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: theme.colors.border,
                        width: appStyle.dividerWidth,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(top: appStyle.spaceSm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          FLucideIcons.fileAudio,
                          size: 20,
                          color: theme.colors.mutedForeground,
                        ),
                        SizedBox(width: appStyle.spaceSm),
                        Expanded(
                          child: Text(
                            l10n.sourceAudioNotRewritten,
                            key: const ValueKey(
                              'meeting-processing-audio-safety',
                            ),
                            style: theme.typography.body.sm.copyWith(
                              color: theme.colors.mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
