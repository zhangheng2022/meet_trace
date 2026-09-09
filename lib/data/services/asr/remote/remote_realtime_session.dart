import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../../domain/models/transcription_profile.dart';
import 'pcm16_resampler.dart';

final class RemoteAsrProtocolException implements Exception {
  const RemoteAsrProtocolException(this.code);
  final String code;
  @override
  String toString() => code;
}

final class RemoteRealtimePiece {
  const RemoteRealtimePiece({
    required this.id,
    required this.startMs,
    required this.endMs,
    required this.text,
    required this.isFinal,
  });
  final String id;
  final int startMs;
  final int endMs;
  final String text;
  final bool isFinal;
}

typedef RemoteWebSocketConnector = Future<WebSocket> Function(
  Uri endpoint,
  Map<String, String> headers,
  Duration timeout,
);

/// WebSocket.connect 本身不关闭重定向；仅暴露它需要的 openUrl 并显式关闭。
final class _NoRedirectClient implements HttpClient {
  _NoRedirectClient(this.client);
  final HttpClient client;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      await client.openUrl(method, url)
        ..followRedirects = false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<WebSocket> connectRemoteWebSocket(
  Uri endpoint,
  Map<String, String> headers,
  Duration timeout,
) async {
  final client = HttpClient()..connectionTimeout = timeout;
  var abandoned = false;
  final connecting = WebSocket.connect(
    endpoint.toString(),
    headers: headers,
    customClient: _NoRedirectClient(client),
    compression: CompressionOptions.compressionOff,
    maxPayloadLength: 1024 * 1024,
  );
  // 超时后迟到的握手也必须释放，不能留下后台连接。
  unawaited(
    connecting.then((socket) async {
      if (abandoned) await socket.close();
    }, onError: (Object _) {}),
  );
  try {
    final socket = await connecting.timeout(timeout);
    client.close();
    return socket;
  } on Object {
    abandoned = true;
    client.close(force: true);
    rethrow;
  }
}

/// 仅实现 OpenAI transcription 会话；没有说话人或逐词时间戳的推断。
final class RemoteRealtimeSession {
  RemoteRealtimeSession({
    required this.profile,
    required this.headers,
    required this.prefix,
    required this.onPiece,
    required this.onFailure,
    this.collectResults = false,
    this.connector = connectRemoteWebSocket,
  }) {
    _ready.future.ignore();
  }

  final TranscriptionProfile profile;
  final Map<String, String> headers;
  final String prefix;
  final void Function(RemoteRealtimePiece) onPiece;
  final void Function(String) onFailure;
  final bool collectResults;
  final RemoteWebSocketConnector connector;
  final _resampler = Pcm16To24Resampler();
  final _ready = Completer<void>();
  final Queue<_Turn> _unbound = Queue<_Turn>();
  final Map<String, _Turn> _items = {};
  final Queue<String> _completedIds = Queue<String>();
  final Set<_Turn> _waiting = {};
  final List<RemoteRealtimePiece> _results = [];
  WebSocket? _socket;
  StreamSubscription<Object?>? _subscription;
  _Turn? _current;
  String? _failure;
  int _samples = 0;
  int _sequence = 0;
  int? _originMs;
  bool _closed = false;
  bool _finishing = false;

  Duration get timeout => Duration(seconds: profile.requestTimeoutSeconds);
  int get inputSamples => _samples;
  List<RemoteRealtimePiece> get results =>
      List<RemoteRealtimePiece>.unmodifiable(
        <RemoteRealtimePiece>[..._results]
          ..sort((a, b) => a.startMs.compareTo(b.startMs)),
      );

  Future<void> initialize() async {
    _ready.future.ignore();
    try {
      final socket = await connector(profile.endpoint!, headers, timeout);
      if (_closed) {
        await socket.close();
        throw const RemoteAsrProtocolException('asr.remote.cancelled');
      }
      _socket = socket;
      socket.pingInterval = const Duration(seconds: 15);
      _subscription = socket.listen(
        _receive,
        onError: (Object _) => _fail('asr.remote.connection_failed'),
        onDone: () {
          if (!_closed) _fail('asr.remote.connection_closed');
        },
      );
      _send({
        'type': 'session.update',
        'session': {
          'type': 'transcription',
          'audio': {
            'input': {
              'format': {'type': 'audio/pcm', 'rate': 24000},
              'transcription': {
                'model': profile.modelId,
                if (profile.language != 'auto') 'language': profile.language,
                if (profile.prompt.isNotEmpty) 'prompt': profile.prompt,
              },
              'turn_detection': null,
            },
          },
        },
      });
      await _ready.future.timeout(timeout);
      _check();
    } on TimeoutException {
      _fail('asr.remote.timeout');
      throw const RemoteAsrProtocolException('asr.remote.timeout');
    } on Object {
      if (_failure == null) _fail('asr.remote.connection_failed');
      throw RemoteAsrProtocolException(_failure!);
    }
  }

  /// 预览最长 2 秒提交，最终重放最长 8 秒；不使用本地 VAD 丢弃静音。
  Future<void> add(Float32List samples, {required int startMs}) async {
    _check();
    if (_finishing) throw const RemoteAsrProtocolException('asr.remote.closed');
    _originMs ??= startMs;
    final expectedMs = _originMs! + _samples * 1000 ~/ 16000;
    if ((startMs - expectedMs).abs() > 1) {
      _fail('asr.remote.audio_discontinuity');
      _check();
    }
    var offset = 0;
    final turnSamples = (collectResults ? 8 : 2) * 16000;
    while (offset < samples.length) {
      _check();
      if (_current != null && _samples - _current!.startSample >= turnSamples) {
        _commit();
      }
      _current ??= _Turn(++_sequence, _samples);
      final count = (samples.length - offset).clamp(
        0,
        turnSamples - (_samples - _current!.startSample),
      );
      final part = Float32List.sublistView(samples, offset, offset + count);
      _samples += count;
      _current!.endSample = _samples;
      _append(_resampler.add(part));
      offset += count;
    }
  }

  Future<void> flush() async {
    _check();
    if (_current != null) {
      _append(_resampler.flushBoundary());
      final length = _current!.endSample - _current!.startSample;
      if (length < 1600) _append(Uint8List((1600 - length) * 3));
      _commit();
    }
  }

  Future<void> finish() async {
    _check();
    if (_finishing) return;
    _finishing = true;
    try {
      _append(_resampler.finish());
      if (_current != null) {
        // OpenAI commit 至少需 100ms；只给派生流补尾静音，时间仍指向原 PCM。
        final length = _current!.endSample - _current!.startSample;
        if (length < 1600) _append(Uint8List((1600 - length) * 3));
        _commit();
      }
      await Future.wait(_waiting.map((turn) => turn.done.future))
          .timeout(timeout);
      _check();
    } on TimeoutException {
      _fail('asr.remote.timeout');
      throw const RemoteAsrProtocolException('asr.remote.timeout');
    } finally {
      await close();
    }
  }

  void _append(Uint8List bytes) {
    // 每条 JSON 最多携带 200ms 24k PCM，避免大块输入绕过网络内存界限。
    for (var offset = 0; offset < bytes.length; offset += 9600) {
      final end = (offset + 9600).clamp(0, bytes.length);
      _send({
        'type': 'input_audio_buffer.append',
        'audio': base64Encode(Uint8List.sublistView(bytes, offset, end)),
      });
    }
  }

  void _commit() {
    if (_waiting.length >= 8) {
      _fail('asr.remote.backlog_exceeded');
      _check();
    }
    final turn = _current!;
    turn.done.future.ignore();
    _waiting.add(turn);
    turn.deadline = Timer(timeout, () => _fail('asr.remote.timeout'));
    if (turn.itemId == null) _unbound.add(turn);
    _current = null;
    _send({'type': 'input_audio_buffer.commit'});
  }

  void _send(Map<String, Object?> value) {
    _check();
    _socket!.add(jsonEncode(value));
  }

  void _receive(Object? message) {
    if (_closed || _failure != null) return;
    try {
      if (message is! String || message.length > 1024 * 1024) {
        throw const FormatException();
      }
      final decoded = jsonDecode(message);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      final type = decoded['type'];
      if (type == 'error' ||
          type == 'conversation.item.input_audio_transcription.failed') {
        _fail('asr.remote.server_rejected');
        return;
      }
      if (type == 'session.updated') {
        if (!_ready.isCompleted) _ready.complete();
        return;
      }
      if (type == 'input_audio_buffer.committed') {
        final id = decoded['item_id'];
        if (id is! String || id.isEmpty) throw const FormatException();
        if (_completedIds.contains(id)) return;
        if (!_items.containsKey(id)) {
          if (_unbound.isEmpty) throw const FormatException();
          _bind(id, _unbound.removeFirst());
        }
        return;
      }
      final isDelta =
          type == 'conversation.item.input_audio_transcription.delta';
      final isComplete =
          type == 'conversation.item.input_audio_transcription.completed';
      if (!isDelta && !isComplete) return;
      final id = decoded['item_id'];
      final text = decoded[isDelta ? 'delta' : 'transcript'];
      if (id is! String || id.isEmpty || text is! String) {
        throw const FormatException();
      }
      if (_completedIds.contains(id)) return;
      var turn = _items[id];
      if (turn == null) {
        // 真流式模型可能在 commit 前输出带 item_id 的 delta。
        turn = _unbound.isNotEmpty ? _unbound.removeFirst() : _current;
        if (turn == null) throw const FormatException();
        _bind(id, turn);
      }
      if (turn.done.isCompleted) return;
      if (isComplete && !_waiting.contains(turn)) {
        throw const FormatException();
      }
      turn.text = isDelta ? turn.text + text : text;
      if (turn.text.length > 65536) throw const FormatException();
      final start = _originMs! + turn.startSample * 1000 ~/ 16000;
      final end = _originMs! + (turn.endSample * 1000 + 15999) ~/ 16000;
      final piece = RemoteRealtimePiece(
        id: '$prefix-${turn.sequence}',
        startMs: start,
        endMs: end > start ? end : start + 1,
        text: turn.text,
        isFinal: isComplete,
      );
      onPiece(piece);
      if (isComplete) {
        if (collectResults && piece.text.trim().isNotEmpty) _results.add(piece);
        _waiting.remove(turn);
        turn.deadline?.cancel();
        _items.remove(id);
        if (_completedIds.length == 128) _completedIds.removeFirst();
        _completedIds.add(id);
        turn.done.complete();
      }
    } on Object {
      _fail('asr.remote.invalid_response');
    }
  }

  void _bind(String id, _Turn turn) {
    turn.itemId = id;
    _items[id] = turn;
  }

  void _check() {
    if (_failure case final code?) throw RemoteAsrProtocolException(code);
    if (_closed) throw const RemoteAsrProtocolException('asr.remote.cancelled');
  }

  void _fail(String code) {
    if (_failure != null || _closed) return;
    _failure = code;
    final error = RemoteAsrProtocolException(code);
    if (!_ready.isCompleted) _ready.completeError(error);
    for (final turn in _waiting) {
      turn.deadline?.cancel();
      if (!turn.done.isCompleted) turn.done.completeError(error);
    }
    onFailure(code);
    unawaited(close());
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final error = RemoteAsrProtocolException(
      _failure ?? 'asr.remote.cancelled',
    );
    if (!_ready.isCompleted) _ready.completeError(error);
    for (final turn in _waiting) {
      turn.deadline?.cancel();
      if (!turn.done.isCompleted) turn.done.completeError(error);
    }
    await _subscription?.cancel();
    try {
      await _socket?.close().timeout(const Duration(seconds: 1));
    } on Object {
      // 已停止接收和发送，关闭失败不影响事实录音。
    }
  }
}

final class _Turn {
  _Turn(this.sequence, this.startSample) : endSample = startSample;
  final int sequence;
  final int startSample;
  int endSample;
  String? itemId;
  String text = '';
  Timer? deadline;
  final done = Completer<void>();
}
