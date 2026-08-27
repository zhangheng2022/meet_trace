import 'package:flutter/widgets.dart';
import 'package:flutter/widget_previews.dart';

import '../../../../app/application.dart';
import '../meettrace_brand_mark.dart';

@Preview(name: 'Logo 轨迹归位 · 浅色', group: 'UI-00 品牌动效', size: Size(430, 320))
Widget meetTraceBrandMotionPreview() => const Application(
  home: Center(child: MeetTraceAnimatedWordmark(disableAnimations: false)),
);

@Preview(
  name: 'Logo 轨迹归位 · 深色',
  group: 'UI-00 品牌动效',
  size: Size(430, 320),
  brightness: Brightness.dark,
)
Widget meetTraceBrandMotionDarkPreview() => meetTraceBrandMotionPreview();
