import 'dart:async';

import 'package:material_ui/material_ui.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../domain/models/transcription_profile.dart';
import '../../../../l10n/l10n.dart';
import '../../../../theme/theme.dart';
import '../../../core/app_back_icon.dart';
import '../../../core/app_dialog.dart';
import '../../../core/app_page_body.dart';
import '../../../core/app_text_field.dart';
import '../view_models/transcription_sources_view_model.dart';

String transcriptionSourceMode(
  AppLocalizations l10n,
  TranscriptionProfile profile,
) => profile.isLocal
    ? l10n.sourceLocal
    : profile.protocol == TranscriptionProtocol.realtimeTranscription
    ? l10n.sourceRealtime
    : l10n.sourceAfterMeeting;

final class TranscriptionSourcesView extends StatefulWidget {
  const TranscriptionSourcesView({
    required this.viewModel,
    this.selecting = false,
    super.key,
  });
  final TranscriptionSourcesViewModel viewModel;
  final bool selecting;

  @override
  State<TranscriptionSourcesView> createState() =>
      _TranscriptionSourcesViewState();
}

final class _TranscriptionSourcesViewState
    extends State<TranscriptionSourcesView> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.viewModel.load());
  }

  Future<void> _edit([TranscriptionProfile? profile]) async {
    final viewModel = widget.viewModel;
    viewModel.clearFeedback();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _SourceEditor(viewModel: viewModel, profile: profile),
      ),
    );
    viewModel.clearFeedback();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final l10n = context.l10n;
      final vm = widget.viewModel;
      final spacing = context.theme.style.app.spaceMd;
      return FScaffold(
        header: FHeader.nested(
          title: Text(
            widget.selecting
                ? l10n.chooseTranscriptionSource
                : l10n.transcriptionSources,
          ),
          prefixes: [
            FHeaderAction(
              icon: AppBackIcon(semanticsLabel: l10n.cancel),
              onPress: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        child: AppPageBody(
          child: ListView(
            children: [
              Text(
                widget.selecting
                    ? l10n.sourceLockedNotice
                    : l10n.sourceRemotePrivacy,
              ),
              SizedBox(height: spacing),
              if (vm.failed)
                Text(
                  vm.requiresFreshCredentials
                      ? l10n.sourceCredentialsRequired
                      : l10n.sourceFailure,
                  style: TextStyle(color: context.theme.colors.destructive),
                ),
              if (vm.probeSucceeded) Text(l10n.sourceProbeSuccess),
              for (final profile in vm.items)
                Padding(
                  padding: EdgeInsets.only(bottom: spacing),
                  child: FCard(
                    child: Padding(
                      padding: EdgeInsets.all(spacing),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${profile.name}${profile.id == vm.defaultId ? ' · ${l10n.sourceDefault}' : ''}',
                            style: context.theme.typography.body.lg,
                          ),
                          Text(transcriptionSourceMode(l10n, profile)),
                          if (!profile.isLocal)
                            Text(
                              '${profile.endpoint!.host} · ${profile.modelId}',
                            ),
                          SizedBox(height: spacing),
                          if (widget.selecting)
                            FButton(
                              key: ValueKey('select-source-${profile.id}'),
                              onPress: vm.busy
                                  ? null
                                  : () => Navigator.of(context).pop(profile),
                              child: Text(l10n.sourceSelect),
                            )
                          else
                            Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children: [
                                FButton(
                                  variant: FButtonVariant.outline,
                                  onPress: vm.busy || profile.id == vm.defaultId
                                      ? null
                                      : () => unawaited(vm.setDefault(profile)),
                                  child: Text(l10n.sourceSetDefault),
                                ),
                                if (!profile.isLocal) ...[
                                  FButton(
                                    variant: FButtonVariant.outline,
                                    onPress: vm.busy
                                        ? null
                                        : () => unawaited(_edit(profile)),
                                    child: Text(l10n.edit),
                                  ),
                                  if (vm.probe != null)
                                    FButton(
                                      variant: FButtonVariant.outline,
                                      onPress: vm.busy
                                          ? null
                                          : () => unawaited(_probe(profile)),
                                      child: Text(l10n.sourceProbeAction),
                                    ),
                                  FButton(
                                    variant: FButtonVariant.outline,
                                    onPress: vm.busy
                                        ? null
                                        : () => unawaited(_delete(profile)),
                                    child: Text(l10n.delete),
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              FButton(
                variant: FButtonVariant.outline,
                onPress: vm.busy ? null : () => unawaited(_edit()),
                child: Text(l10n.addOnlineSource),
              ),
            ],
          ),
        ),
      );
    },
  );

  Future<void> _probe(TranscriptionProfile profile) async {
    final l10n = context.l10n;
    if (await showAppConfirmDialog(
              context: context,
              semanticsLabel: l10n.sourceProbe,
              title: l10n.sourceProbe,
              message: l10n.sourceProbeConfirm,
              cancelLabel: l10n.cancel,
              confirmLabel: l10n.sourceAcceptStart,
            ) ==
            true &&
        mounted) {
      await widget.viewModel.testConnection(profile);
    }
  }

  Future<void> _delete(TranscriptionProfile profile) async {
    final l10n = context.l10n;
    if (await showAppConfirmDialog(
              context: context,
              semanticsLabel: l10n.delete,
              title: l10n.delete,
              message: l10n.sourceRemoveConfirm,
              cancelLabel: l10n.cancel,
              confirmLabel: l10n.delete,
              destructive: true,
            ) ==
            true &&
        mounted) {
      await widget.viewModel.delete(profile);
    }
  }
}

final class _SourceEditor extends StatefulWidget {
  const _SourceEditor({required this.viewModel, this.profile});
  final TranscriptionSourcesViewModel viewModel;
  final TranscriptionProfile? profile;
  @override
  State<_SourceEditor> createState() => _SourceEditorState();
}

final class _SourceEditorState extends State<_SourceEditor> {
  late TranscriptionProtocol _protocol =
      widget.profile?.protocol ?? TranscriptionProtocol.audioTranscriptions;
  late final _name = TextEditingController(text: widget.profile?.name);
  late final _endpoint = TextEditingController(
    text: widget.profile?.endpoint?.toString(),
  );
  late final _model = TextEditingController(text: widget.profile?.modelId);
  final _apiKey = TextEditingController();
  final _headers = TextEditingController();
  late final _language = TextEditingController(
    text: widget.profile?.language ?? 'auto',
  );
  late final _prompt = TextEditingController(text: widget.profile?.prompt);
  late final _limit = TextEditingController(
    text:
        '${(widget.profile?.maxUploadBytes ?? 24 * 1024 * 1024) / (1024 * 1024)}',
  );
  late final _timeout = TextEditingController(
    text: '${widget.profile?.requestTimeoutSeconds ?? 120}',
  );
  bool _invalidLimit = false;
  bool _invalidTimeout = false;
  bool _advancedExpanded = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _endpoint,
      _model,
      _apiKey,
      _headers,
      _language,
      _prompt,
      _limit,
      _timeout,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final uploadBytes =
        (double.tryParse(_limit.text) ?? double.nan) * 1024 * 1024;
    final timeout = int.tryParse(_timeout.text);
    widget.viewModel.clearFeedback();
    setState(() {
      _invalidLimit = !uploadBytes.isFinite || uploadBytes < 1024;
      _invalidTimeout = timeout == null || timeout < 1 || timeout > 3600;
    });
    if (_invalidLimit || _invalidTimeout) return;
    final success = await widget.viewModel.save(
      previous: widget.profile,
      name: _name.text,
      protocol: _protocol,
      endpoint: _endpoint.text,
      modelId: _model.text,
      apiKey: _apiKey.text,
      headersJson: _headers.text,
      language: _language.text,
      prompt: _prompt.text,
      maxUploadBytes: uploadBytes.round(),
      requestTimeoutSeconds: timeout!,
    );
    if (success && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final l10n = context.l10n;
      final vm = widget.viewModel;
      final spacing = context.theme.style.app.spaceMd;
      Widget field(
        TextEditingController controller,
        String label, {
        bool secret = false,
      }) => Padding(
        padding: EdgeInsets.only(bottom: spacing),
        child: AppTextField(
          controller: controller,
          label: label,
          enabled: !vm.busy,
          obscureText: secret,
          errorText: controller == _timeout && _invalidTimeout
              ? l10n.sourceTimeoutInvalid
              : null,
          onChanged: (_) {
            if (controller == _limit && _invalidLimit) {
              setState(() => _invalidLimit = false);
            }
            if (controller == _timeout && _invalidTimeout) {
              setState(() => _invalidTimeout = false);
            }
          },
        ),
      );
      return PopScope(
        canPop: !vm.busy,
        child: FScaffold(
          header: FHeader.nested(
            title: Text(
              widget.profile == null ? l10n.addOnlineSource : l10n.sourceEdit,
            ),
            prefixes: [
              FHeaderAction(
                icon: AppBackIcon(semanticsLabel: l10n.cancel),
                onPress: vm.busy ? null : () => Navigator.of(context).pop(),
              ),
            ],
          ),
          child: AppPageBody(
            child: ListView(
              children: [
                field(_name, l10n.sourceName),
                FSelectMenuTile<TranscriptionProtocol>(
                  key: ValueKey(_protocol),
                  title: Text(l10n.sourceProtocol),
                  details: Text(_protocolLabel(_protocol)),
                  enabled: !vm.busy,
                  selectControl: FMultiValueControl.managedRadio(
                    initial: _protocol,
                    onChange: (values) {
                      if (values.firstOrNull case final value?) {
                        setState(() => _protocol = value);
                      }
                    },
                  ),
                  menu: [
                    for (final protocol in TranscriptionProtocol.values.where(
                      (p) => p != TranscriptionProtocol.local,
                    ))
                      FSelectTile(
                        value: protocol,
                        title: Text(_protocolLabel(protocol)),
                      ),
                  ],
                ),
                SizedBox(height: spacing),
                Text(
                  _protocol == TranscriptionProtocol.realtimeTranscription
                      ? l10n.sourceRealtime
                      : l10n.sourceAfterMeeting,
                ),
                SizedBox(height: spacing),
                field(_endpoint, l10n.sourceEndpoint),
                field(_model, l10n.sourceModel),
                Text(
                  '${l10n.sourceCredentialsHelp} {}',
                  style: context.theme.typography.body.sm,
                ),
                SizedBox(height: spacing),
                field(_apiKey, l10n.sourceApiKey, secret: true),
                FAccordion(
                  control: FAccordionControl.lifted(
                    expanded: (_) => _advancedExpanded,
                    onChange: (_, expanded) =>
                        setState(() => _advancedExpanded = expanded),
                  ),
                  children: [
                    FAccordionItem(
                      title: Text(l10n.sourceAdvanced),
                      child: Column(
                        children: [
                          SizedBox(height: spacing),
                          field(_headers, l10n.sourceHeaders, secret: true),
                          field(_language, l10n.sourceLanguage),
                          field(_prompt, l10n.sourcePrompt),
                          field(_limit, l10n.sourceUploadLimit),
                          field(_timeout, l10n.sourceTimeout),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacing),
                if (_invalidLimit || vm.failed)
                  Padding(
                    padding: EdgeInsets.only(bottom: spacing),
                    child: Text(
                      vm.requiresFreshCredentials
                          ? l10n.sourceCredentialsRequired
                          : l10n.sourceFailure,
                      style: TextStyle(color: context.theme.colors.destructive),
                    ),
                  ),
                FButton(
                  key: const ValueKey('save-transcription-source'),
                  onPress: vm.busy ? null : () => unawaited(_save()),
                  child: Text(vm.busy ? l10n.saving : l10n.save),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

String _protocolLabel(TranscriptionProtocol protocol) => switch (protocol) {
  TranscriptionProtocol.local => 'SenseVoice',
  TranscriptionProtocol.audioTranscriptions => 'Audio Transcriptions',
  TranscriptionProtocol.chatAudio => 'Chat Audio',
  TranscriptionProtocol.realtimeTranscription => 'Realtime Transcription',
};
