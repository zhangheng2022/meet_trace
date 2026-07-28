import '../use_cases/build_meeting_share.dart';

abstract interface class TextShareService {
  Future<void> share(MeetingShareDocument document);
}
