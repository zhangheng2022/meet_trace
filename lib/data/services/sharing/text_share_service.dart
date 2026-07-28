import 'package:share_plus/share_plus.dart';

import '../../../domain/ports/text_share.dart';
import '../../../domain/use_cases/build_meeting_share.dart';

export '../../../domain/ports/text_share.dart';

final class SharePlusTextShareService implements TextShareService {
  const SharePlusTextShareService();

  @override
  Future<void> share(MeetingShareDocument document) async {
    await SharePlus.instance.share(
      ShareParams(
        text: document.text,
        subject: document.subject,
        title: document.subject,
      ),
    );
  }
}
