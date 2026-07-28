// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
// Impeccable · page: startup · world: Evidence Ledger
// THESIS: startup is a short, trustworthy local preparation state, not a blank
// app shell or a decorative brand animation.
// STORY: identify MeetTrace, explain the real local work, then reinforce the
// local-only evidence promise.

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../theme/theme.dart';
import '../../../core/app_responsive.dart';

/// 会迹的本地能力加载页。
final class MeetTraceStartupView extends StatelessWidget {
  const MeetTraceStartupView({super.key});

  @override
  Widget build(BuildContext context) => const _StartupFrame(
    body: _StartupLoadingContent(),
    footer: _LocalEvidencePromise(),
  );
}

/// 会迹的本地能力启动失败页。
final class MeetTraceStartupErrorView extends StatelessWidget {
  const MeetTraceStartupErrorView({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _StartupFrame(
    body: _StartupErrorContent(onRetry: onRetry),
    footer: const _LocalEvidencePromise(),
  );
}

final class _StartupFrame extends StatelessWidget {
  const _StartupFrame({required this.body, required this.footer});

  final Widget body;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      childPad: false,
      child: SafeArea(
        child: AppResponsiveBuilder(
          builder: (context, sizeClass, _) {
            final appStyle = context.theme.style.app;
            final horizontalPadding = switch (sizeClass) {
              AppWindowSizeClass.compact => appStyle.spaceLg,
              AppWindowSizeClass.medium => appStyle.spaceXl,
              AppWindowSizeClass.expanded => appStyle.space2Xl,
            };
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: appStyle.contentMaxWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    appStyle.spaceLg,
                    horizontalPadding,
                    appStyle.spaceLg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, bodyConstraints) {
                            return SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: bodyConstraints.maxHeight,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: body,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: appStyle.spaceLg),
                      footer,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

final class _StartupLoadingContent extends StatelessWidget {
  const _StartupLoadingContent();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Semantics(
      container: true,
      label: '正在启动会迹，准备本地数据与离线模型',
      child: Column(
        key: const ValueKey('meettrace-startup-loading'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Wordmark(),
          SizedBox(height: appStyle.space2Xl),
          FProgress(
            semanticsLabel: '正在准备本地数据与离线模型',
            style: FProgressStyle(
              constraints: BoxConstraints.tightFor(
                height: appStyle.strongBorderWidth,
              ),
              trackDecoration: BoxDecoration(color: theme.colors.border),
              fillDecoration: BoxDecoration(color: theme.colors.foreground),
              motion: const FProgressMotion(
                period: Duration(milliseconds: 900),
                interval: Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                value: 0.28,
              ),
            ),
          ),
          SizedBox(height: appStyle.spaceMd),
          Text('正在准备本地数据与离线模型', style: theme.typography.display.md),
          SizedBox(height: appStyle.spaceXs),
          Text(
            '恢复会议记录，并校验标准转录模型',
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.app.inkSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

final class _StartupErrorContent extends StatelessWidget {
  const _StartupErrorContent({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Semantics(
      container: true,
      label: '会迹本地能力准备未完成',
      child: Column(
        key: const ValueKey('meettrace-startup-error'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Wordmark(),
          SizedBox(height: appStyle.space2Xl),
          Container(
            height: appStyle.strongBorderWidth,
            color: theme.colors.foreground,
          ),
          SizedBox(height: appStyle.spaceMd),
          Text('本地能力准备未完成', style: theme.typography.display.md),
          SizedBox(height: appStyle.spaceXs),
          Text(
            '请确认设备空间充足后重试。已有会议数据不会被删除。',
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.app.inkSecondary,
            ),
          ),
          SizedBox(height: appStyle.spaceLg),
          FButton(
            size: FButtonSizeVariant.lg,
            onPress: onRetry,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

final class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Column(
      key: const ValueKey('meettrace-startup-wordmark'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text('会迹', style: theme.typography.display.xl2),
        ),
        SizedBox(height: appStyle.space2Xs),
        Text(
          'MeetTrace',
          style: theme.typography.body.xs.copyWith(
            color: theme.colors.app.inkSecondary,
          ),
        ),
      ],
    );
  }
}

final class _LocalEvidencePromise extends StatelessWidget {
  const _LocalEvidencePromise();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Semantics(
      container: true,
      label: '无需登录，事实音频仅保存在本机',
      child: Container(
        key: const ValueKey('meettrace-startup-local-evidence'),
        padding: EdgeInsets.only(top: appStyle.spaceMd),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.colors.border,
              width: appStyle.dividerWidth,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(FLucideIcons.shieldCheck),
            SizedBox(width: appStyle.spaceSm),
            Expanded(
              child: Text(
                '无需登录 · 事实音频仅保存在本机',
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.app.inkSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
