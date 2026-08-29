import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';

import '../../../../../domain/models/meeting.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../core/app_state_panel.dart';
import '../../view_models/recording/recording_session_view_model.dart';
import 'recording_session_view.dart';

/// 先完成页面转场，再在静态准备页上创建原生 VAD，避免阻塞路由动画。
final class RecordingBootstrapView extends StatefulWidget {
  const RecordingBootstrapView({
    required this.createViewModel,
    required this.onFinished,
    super.key,
  });

  final RecordingSessionViewModel Function() createViewModel;
  final ValueChanged<Meeting> onFinished;

  @override
  State<RecordingBootstrapView> createState() => _RecordingBootstrapViewState();
}

final class _RecordingBootstrapViewState extends State<RecordingBootstrapView> {
  Animation<double>? _routeAnimation;
  RecordingSessionViewModel? _viewModel;
  bool _initializationScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (identical(animation, _routeAnimation)) {
      return;
    }
    _routeAnimation?.removeStatusListener(_handleRouteAnimation);
    _routeAnimation = animation;
    animation?.addStatusListener(_handleRouteAnimation);
    if (animation == null || animation.status == AnimationStatus.completed) {
      _scheduleInitialization();
    }
  }

  void _handleRouteAnimation(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _scheduleInitialization();
    }
  }

  void _scheduleInitialization() {
    if (_initializationScheduled || _viewModel != null) {
      return;
    }
    _initializationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final viewModel = widget.createViewModel();
      if (!mounted) {
        viewModel.dispose();
        return;
      }
      setState(() => _viewModel = viewModel);
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel;
    if (viewModel != null) {
      return RecordingSessionView(
        viewModel: viewModel,
        onFinished: widget.onFinished,
      );
    }
    return PopScope(
      canPop: false,
      child: FScaffold(
        childPad: false,
        header: FHeader.nested(title: Text(context.l10n.appName)),
        child: AppStatePanel.loading(label: context.l10n.startingRecording),
      ),
    );
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleRouteAnimation);
    _viewModel?.dispose();
    super.dispose();
  }
}
