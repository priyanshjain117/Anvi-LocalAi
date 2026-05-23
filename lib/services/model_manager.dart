import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:fllama/fllama.dart';
import 'package:path_provider/path_provider.dart';
import '../core/utils/download_progress.dart';
import '../models/chat_turn.dart';
import '../models/file_attachment.dart';
import '../models/llm_model.dart';

class ModelManager {
  static final ModelManager _instance = ModelManager._internal();
  factory ModelManager() => _instance;
  ModelManager._internal();

  String? _contextId;
  LLMModel? _loadedModel;
  int _generationId = 0;

  static const int _contextLength = 2048;
  static const int _reservedOutputTokens = 220;
  static const int _maxPromptTokens = _contextLength - _reservedOutputTokens;

  String? get contextId => _contextId;
  LLMModel? get loadedModel => _loadedModel;
  bool get hasLoadedModel => _contextId != null;

  // ── Paths ──────────────────────────────────────────────────────────────────

  Future<String> modelPath(LLMModel model) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/${model.fileName}';
  }

  Future<bool> isDownloaded(LLMModel model) async {
    final path = await modelPath(model);
    return File(path).exists();
  }

  Future<void> deleteModel(LLMModel model) async {
    if (_loadedModel?.fileName == model.fileName) {
      stopGeneration();
      if (_contextId != null) {
        await Fllama.instance()?.releaseContext(double.parse(_contextId!));
      }
      _contextId = null;
      _loadedModel = null;
    }

    final path = await modelPath(model);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  // ── Download ───────────────────────────────────────────────────────────────

  Future<void> download(
    LLMModel model, {
    required void Function(double progress) onProgress,
    void Function(DownloadProgress progress)? onDetailedProgress,
    CancelToken? cancelToken,
  }) async {
    final path = await modelPath(model);
    final stopwatch = Stopwatch()..start();
    await Dio().download(
      model.downloadUrl,
      path,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (total <= 0) return;
        final progress = received / total;
        onProgress(progress);

        final elapsed = stopwatch.elapsedMilliseconds / 1000;
        final bytesPerSecond = elapsed <= 0 ? 0.0 : received / elapsed;
        final remaining = total - received;
        final eta = bytesPerSecond <= 0
            ? null
            : Duration(seconds: (remaining / bytesPerSecond).round());
        onDetailedProgress?.call(
          DownloadProgress(
            received: received,
            total: total,
            progress: progress,
            bytesPerSecond: bytesPerSecond,
            eta: eta,
          ),
        );
      },
    );
  }

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> loadModel(LLMModel model) async {
    if (_contextId != null) {
      await Fllama.instance()?.releaseContext(double.parse(_contextId!));
      _contextId = null;
      _loadedModel = null;
    }

    final path = await modelPath(model);

    final result = await Fllama.instance()?.initContext(
      path,
      nCtx: _contextLength,
      nBatch: 256,
      nGpuLayers: 33,
      useMlock: false,
      useMmap: true,
      emitLoadProgress: true,
    );

    if (result == null || result['contextId'] == null) {
      throw Exception('fllama: initContext failed — model may be corrupt.');
    }
    _contextId = result['contextId'].toString();
    _loadedModel = model;
  }

  // ── Inference (streaming) ──────────────────────────────────────────────────
  //
  // fllama's completion is triggered via a Map sent over the platform channel.
  // Tokens arrive on onTokenStream with function=="completion" and
  // data["result"]["token"] holding the new token string.
  // End of generation fires function=="completionEnd".

  Stream<String> chat(
    String userMessage, {
    required List<ChatTurn> history,
    List<FileAttachment> attachments = const [],
  }) async* {
    if (_contextId == null) {
      throw StateError('No model loaded — call loadModel() first.');
    }

    final generationId = ++_generationId;
    final prompt = await _buildPrompt(
      userMessage,
      history: history,
      attachments: attachments,
    );

    final controller = StreamController<String>();

    final sub = Fllama.instance()?.onTokenStream?.listen((data) {
      final fn = data['function'];

      if (generationId != _generationId) return;

      if (fn == 'completion') {
        // Safely extract the token depending on how fllama wraps the map
        final token = (data['result'] != null && data['result'] is Map)
            ? (data['result']['token'] ?? '').toString()
            : (data['token'] ?? '').toString();

        if (token.isNotEmpty && !controller.isClosed) {
          controller.add(token);
        }
      } else if (fn == 'completionEnd') {
        if (!controller.isClosed) controller.close();
      }
    });

    // DO NOT 'await' this! Let it run in the background so the stream can yield below.
    Fllama.instance()
        ?.completion(
      double.parse(_contextId!),
      prompt: prompt,
      nPredict: _reservedOutputTokens,
      temperature: 0.28,
      topK: 30,
      topP: 0.82,
      minP: 0.05,
      penaltyLastN: 256,
      penaltyRepeat: 1.18,
      penaltyFreq: 0.08,
      penaltyPresent: 0.02,
      stop: [
        '</assistant>',
        '<user>',
        '</user>',
        '<system>',
        '</system>',
        '<conversation_history>',
      ],
      emitRealtimeCompletion: true, // <--- This wakes up the stream!
    )
        .then((_) {
      // Fallback: Ensure the stream closes when the Future completes
      if (!controller.isClosed) controller.close();
    }).catchError((e) {
      if (!controller.isClosed) controller.addError(e);
    });

    // Immediately yield the stream so the UI can listen while the model thinks
    yield* controller.stream;

    // Clean up the listener when the stream is fully closed
    await sub?.cancel();
  }

  Future<String> _buildPrompt(
    String userMessage, {
    required List<ChatTurn> history,
    required List<FileAttachment> attachments,
  }) async {
    final fileContext = _formatAttachments(attachments);
    var retained = history
        .where((turn) => turn.text.trim().isNotEmpty)
        .toList(growable: true);

    while (retained.isNotEmpty) {
      final prompt = _formatPrompt(
        userMessage,
        history: retained,
        fileContext: fileContext,
      );
      if (await _tokenCount(prompt) <= _maxPromptTokens) return prompt;
      retained.removeAt(0);
    }

    final prompt = _formatPrompt(
      userMessage,
      history: const [],
      fileContext: fileContext,
    );
    if (await _tokenCount(prompt) <= _maxPromptTokens) return prompt;
    return _formatPrompt(
      _clipByCharacters(userMessage, 2600),
      history: const [],
      fileContext: _clipByCharacters(fileContext, 7000),
    );
  }

  String _formatPrompt(
    String userMessage, {
    required List<ChatTurn> history,
    required String fileContext,
  }) {
    final buffer = StringBuffer()
      ..writeln('<system>')
      ..writeln(
          'You are Anvi, a concise and intelligent offline AI assistant running fully on-device.')
      ..writeln()
      ..writeln('Rules:')
      ..writeln('- Answer directly and naturally')
      ..writeln('- Keep responses concise unless user asks otherwise')
      ..writeln('- Never generate fake professionalism')
      ..writeln('- Never generate template/business-email responses')
      ..writeln('- Avoid repetition')
      ..writeln('- Admit uncertainty honestly')
      ..writeln('- Maintain conversational context')
      ..writeln('- Be accurate in math and reasoning')
      ..writeln('</system>')
      ..writeln()
      ..writeln('<conversation_history>');

    if (history.isEmpty) {
      buffer.writeln('[No previous turns]');
    } else {
      for (final turn in history) {
        final tag = turn.role == ChatRole.user ? 'user' : 'assistant';
        buffer
          ..writeln('<$tag>')
          ..writeln(_sanitize(turn.text))
          ..writeln('</$tag>');
      }
    }
    buffer.writeln('</conversation_history>');

    if (fileContext.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('<selected_files>')
        ..writeln(fileContext)
        ..writeln('</selected_files>');
    }

    buffer
      ..writeln()
      ..writeln('<user>')
      ..writeln(_sanitize(userMessage))
      ..writeln('</user>')
      ..writeln()
      ..write('<assistant>');
    return buffer.toString();
  }

  String _formatAttachments(List<FileAttachment> attachments) {
    final ready = attachments.where((file) => file.isReady).toList();
    if (ready.isEmpty) return '';
    final buffer = StringBuffer();
    for (final file in ready.take(3)) {
      buffer
        ..writeln('File: ${file.name}')
        ..writeln('Type: ${file.extension.toUpperCase()}')
        ..writeln('Content:')
        ..writeln(_sanitize(file.text))
        ..writeln();
    }
    return buffer.toString().trim();
  }

  Future<int> _tokenCount(String text) async {
    try {
      final result = await Fllama.instance()
          ?.tokenize(double.parse(_contextId!), text: text);
      final tokens = result?['tokens'];
      if (tokens is List) return tokens.length;
    } catch (_) {
      // Fall through to a conservative character estimate if tokenization fails.
    }
    return (text.length / 3.6).ceil();
  }

  String _sanitize(String value) {
    return value
        .replaceAll('<system>', '')
        .replaceAll('</system>', '')
        .replaceAll('<assistant>', '')
        .replaceAll('</assistant>', '')
        .replaceAll('<user>', '')
        .replaceAll('</user>', '')
        .trim();
  }

  String _clipByCharacters(String value, int maxChars) {
    if (value.length <= maxChars) return value;
    return '${value.substring(0, maxChars)}\n[Truncated for context.]';
  }

  // ── Stop / cleanup ─────────────────────────────────────────────────────────

  void stopGeneration() {
    _generationId++;
    if (_contextId != null) {
      Fllama.instance()?.stopCompletion(contextId: double.parse(_contextId!));
    }
  }

  void dispose() {
    Fllama.instance()?.releaseAllContexts();
    _contextId = null;
    _loadedModel = null;
  }
}
