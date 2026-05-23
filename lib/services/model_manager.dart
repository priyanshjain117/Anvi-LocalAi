import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:fllama/fllama.dart';
import 'package:path_provider/path_provider.dart';
import '../core/utils/download_progress.dart';
import '../models/llm_model.dart';

class ModelManager {
  static final ModelManager _instance = ModelManager._internal();
  factory ModelManager() => _instance;
  ModelManager._internal();

  String? _contextId;
  LLMModel? _loadedModel;

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

    final result = await Fllama.instance()?.initContext(path,
        nCtx: 2048, // Context window size
        nGpuLayers: 33,
        emitLoadProgress: true);

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

  Stream<String> chat(String userMessage) async* {
    if (_contextId == null) {
      throw StateError('No model loaded — call loadModel() first.');
    }

    // Note: Added </s> tags to help the model know when turns end
    final prompt =
        '<|system|>\nYou are a helpful AI assistant running fully on-device. '
        'Be concise.\n</s>\n'
        '<|user|>\n$userMessage\n</s>\n'
        '<|assistant|>\n';

    final controller = StreamController<String>();

    final sub = Fllama.instance()?.onTokenStream?.listen((data) {
      final fn = data['function'];

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
      nPredict: 512,
      temperature: 0.7,
      topP: 0.9,
      penaltyRepeat: 1.1,
      stop: ['<|user|>', '<|system|>', '</s>'],
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

  // ── Stop / cleanup ─────────────────────────────────────────────────────────

  void stopGeneration() {
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
