import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../domain/models/asr_model.dart';
import '../../../../theme/theme.dart';

final class LockedRecordingModelView extends StatelessWidget {
  const LockedRecordingModelView({
    required this.descriptor,
    required this.modelVersion,
    super.key,
  });

  final AsrModelDescriptor descriptor;
  final String modelVersion;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return FCard(
      child: Padding(
        padding: EdgeInsets.all(appStyle.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('本场转录模型', style: theme.typography.display.sm),
                ),
                FBadge(
                  variant: FBadgeVariant.secondary,
                  child: const Text('已锁定'),
                ),
              ],
            ),
            SizedBox(height: appStyle.spaceSm),
            Text(descriptor.displayName, style: theme.typography.body.md),
            Text(
              '版本 $modelVersion；会中和最终转录均使用此模型。',
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
