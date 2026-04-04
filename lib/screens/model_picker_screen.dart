import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/llm_model.dart';
import '../services/model_manager.dart';
import 'chat_screen.dart';

class ModelPickerScreen extends StatefulWidget {
  const ModelPickerScreen({super.key});

  @override
  State<ModelPickerScreen> createState() => _ModelPickerScreenState();
}

class _ModelPickerScreenState extends State<ModelPickerScreen> {
  final _manager = ModelManager();
  final Map<String, bool> _downloaded = {};
  final Map<String, double> _progress = {};
  final Map<String, CancelToken> _cancelTokens = {};
  String? _downloading;
  String? _loading;

  @override
  void initState() {
    super.initState();
    _checkDownloaded();
  }

  Future<void> _checkDownloaded() async {
    for (final m in availableModels) {
      _downloaded[m.fileName] = await _manager.isDownloaded(m);
    }
    if (mounted) setState(() {});
  }

  Future<void> _handleModel(LLMModel model) async {
    final isReady = _downloaded[model.fileName] ?? false;

    if (!isReady) {
      // ── Download ──
      final token = CancelToken();
      _cancelTokens[model.fileName] = token;
      setState(() {
        _downloading = model.fileName;
        _progress[model.fileName] = 0;
      });

      try {
        await _manager.download(
          model,
          onProgress: (p) => setState(() => _progress[model.fileName] = p),
          cancelToken: token,
        );
        setState(() {
          _downloaded[model.fileName] = true;
          _downloading = null;
        });
      } catch (e) {
        setState(() => _downloading = null);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download failed: $e')),
          );
        }
        return;
      }
    }

    // ── Load into memory ──
    setState(() => _loading = model.fileName);
    try {
      await _manager.loadModel(model);
    } catch (e) {
      setState(() => _loading = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load model: $e')),
        );
      }
      return;
    }
    setState(() => _loading = null);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(model: model)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // Header
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.memory_rounded,
                        color: Color(0xFF00E5FF), size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Local AI',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700)),
                      Text('100% on-device • No internet needed',
                          style:
                              TextStyle(fontSize: 12, color: Colors.white38)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 40),
              const Text('Choose a model',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white54,
                      letterSpacing: 1.2)),
              const SizedBox(height: 16),

              // Model cards
              Expanded(
                child: ListView.separated(
                  itemCount: availableModels.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final model = availableModels[i];
                    return _ModelCard(
                      model: model,
                      isDownloaded: _downloaded[model.fileName] ?? false,
                      isDownloading: _downloading == model.fileName,
                      isLoading: _loading == model.fileName,
                      progress: _progress[model.fileName] ?? 0,
                      onTap: () => _handleModel(model),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Model Card Widget ──────────────────────────────────────────────────────

class _ModelCard extends StatelessWidget {
  final LLMModel model;
  final bool isDownloaded;
  final bool isDownloading;
  final bool isLoading;
  final double progress;
  final VoidCallback onTap;

  const _ModelCard({
    required this.model,
    required this.isDownloaded,
    required this.isDownloading,
    required this.isLoading,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF00E5FF);
    final busy = isDownloading || isLoading;

    return GestureDetector(
      onTap: busy ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDownloaded
                ? accent.withOpacity(0.4)
                : Colors.white.withOpacity(0.07),
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(model.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(model.description,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.white54)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _StatusChip(
                  isDownloaded: isDownloaded,
                  isDownloading: isDownloading,
                  isLoading: isLoading,
                  sizeLabel: model.sizeLabel,
                ),
              ],
            ),

            // Progress bar during download
            if (isDownloading) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(accent),
                ),
              ),
              const SizedBox(height: 6),
              Text('${(progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 11, color: accent)),
            ],

            if (isLoading) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 6),
              const Text('Loading model into memory…',
                  style: TextStyle(fontSize: 11, color: Colors.white38)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isDownloaded;
  final bool isDownloading;
  final bool isLoading;
  final String sizeLabel;

  const _StatusChip({
    required this.isDownloaded,
    required this.isDownloading,
    required this.isLoading,
    required this.sizeLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (isDownloading) {
      return const Icon(Icons.downloading_rounded,
          color: Color(0xFF00E5FF), size: 22);
    }
    if (isDownloaded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF00E5FF).withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('Ready',
            style: TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(sizeLabel,
          style: const TextStyle(color: Colors.white54, fontSize: 12)),
    );
  }
}
