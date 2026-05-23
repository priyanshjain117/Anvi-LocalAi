import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/anvi_colors.dart';
import '../core/theme/anvi_spacing.dart';
import '../core/utils/download_progress.dart';
import '../core/utils/formatters.dart';
import '../core/widgets/ambient_background.dart';
import '../core/widgets/anvi_logo.dart';
import '../core/widgets/glass_panel.dart';
import '../core/widgets/pressable_scale.dart';
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
  final Map<String, DownloadProgress> _details = {};
  final Map<String, CancelToken> _cancelTokens = {};
  String? _downloading;
  String? _loading;

  @override
  void initState() {
    super.initState();
    _checkDownloaded();
  }

  Future<void> _checkDownloaded() async {
    for (final model in availableModels) {
      _downloaded[model.fileName] = await _manager.isDownloaded(model);
    }
    if (mounted) setState(() {});
  }

  Future<void> _handleModel(LLMModel model) async {
    HapticFeedback.selectionClick();
    final isReady = _downloaded[model.fileName] ?? false;

    if (!isReady) {
      final token = CancelToken();
      _cancelTokens[model.fileName] = token;
      setState(() {
        _downloading = model.fileName;
        _progress[model.fileName] = 0;
        _details.remove(model.fileName);
      });

      try {
        await _manager.download(
          model,
          onProgress: (value) =>
              setState(() => _progress[model.fileName] = value),
          onDetailedProgress: (value) =>
              setState(() => _details[model.fileName] = value),
          cancelToken: token,
        );
        setState(() {
          _downloaded[model.fileName] = true;
          _downloading = null;
        });
      } catch (error) {
        setState(() => _downloading = null);
        if (!mounted) return;
        final message = error is DioException && CancelToken.isCancel(error)
            ? 'Download cancelled'
            : 'Download failed: $error';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
        return;
      }
    }

    setState(() => _loading = model.fileName);
    try {
      await _manager.loadModel(model);
    } catch (error) {
      setState(() => _loading = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load model: $error')),
        );
      }
      return;
    }
    setState(() => _loading = null);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: ChatScreen(model: model),
          ),
        ),
      );
    }
  }

  void _cancelDownload(LLMModel model) {
    _cancelTokens[model.fileName]?.cancel('User cancelled');
    _cancelTokens.remove(model.fileName);
  }

  Future<void> _deleteModel(LLMModel model) async {
    HapticFeedback.selectionClick();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${model.name}?'),
        content: Text(
          'This removes ${Formatters.bytes(model.sizeBytes)} from this device. You can download it again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _manager.deleteModel(model);
      if (!mounted) return;
      setState(() {
        _downloaded[model.fileName] = false;
        _progress.remove(model.fileName);
        _details.remove(model.fileName);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${model.name} deleted from device')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final tablet = width >= 760;
    final groups = [
      'Starter phones',
      'Phones (6-8 GB RAM)',
      'Phones/Tablets (12-16 GB RAM)',
    ];
    final groupedModels = {
      for (final group in groups)
        group: availableModels
            .where((model) => model.deviceGroup == group)
            .toList(growable: false),
    };

    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  tablet ? 40 : 22,
                  22,
                  tablet ? 40 : 22,
                  0,
                ),
                sliver: SliverToBoxAdapter(child: _Header(tablet: tablet)),
              ),
              for (final group in groups) ...[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    tablet ? 40 : 22,
                    28,
                    tablet ? 40 : 22,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _ModelSectionHeader(
                      title: group,
                      count: groupedModels[group]?.length ?? 0,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    tablet ? 40 : 22,
                    14,
                    tablet ? 40 : 22,
                    group == groups.last ? 120 : 4,
                  ),
                  sliver: SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: width >= 1120
                          ? 3
                          : width >= 720
                              ? 2
                              : 1,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      mainAxisExtent: width < 390
                          ? 328
                          : width >= 720
                              ? 304
                              : 312,
                    ),
                    itemCount: groupedModels[group]?.length ?? 0,
                    itemBuilder: (context, index) {
                      final model = groupedModels[group]![index];
                      return _ModelCard(
                        model: model,
                        isDownloaded: _downloaded[model.fileName] ?? false,
                        isDownloading: _downloading == model.fileName,
                        isLoading: _loading == model.fileName,
                        progress: _progress[model.fileName] ?? 0,
                        details: _details[model.fileName],
                        onTap: () => _handleModel(model),
                        onCancel: () => _cancelDownload(model),
                        onDelete: () => _deleteModel(model),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelSectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _ModelSectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        _Badge(label: '$count options'),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final bool tablet;

  const _Header({required this.tablet});

  @override
  Widget build(BuildContext context) {
    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            AnviLogo(size: 48),
            SizedBox(width: 14),
            Text(
              'Anvi',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          'Local AI model marketplace',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          'Download once. Load into memory. Chat privately with llama.cpp running fully offline on this device.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white60,
                height: 1.45,
              ),
        ),
      ],
    );

    if (!tablet) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          intro,
          const SizedBox(height: 22),
          const _CapabilityPanel(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: intro),
        const SizedBox(width: 28),
        const Expanded(flex: 2, child: _CapabilityPanel()),
      ],
    );
  }
}

class _CapabilityPanel extends StatelessWidget {
  const _CapabilityPanel();

  @override
  Widget build(BuildContext context) {
    final downloaded = availableModels.length;
    return GlassPanel(
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Device AI Capsule',
            style: TextStyle(fontSize: 13, color: AnviColors.champagne),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Metric(label: 'Runtime', value: 'llama.cpp'),
              const SizedBox(width: 12),
              _Metric(label: 'Privacy', value: 'Offline'),
              const SizedBox(width: 12),
              _Metric(label: 'Models', value: '$downloaded'),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Recommended: start with TinyLlama on phones, then move up when you have enough RAM and patience for richer responses.',
            style: TextStyle(color: Colors.white54, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.white38)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  final LLMModel model;
  final bool isDownloaded;
  final bool isDownloading;
  final bool isLoading;
  final double progress;
  final DownloadProgress? details;
  final VoidCallback onTap;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  const _ModelCard({
    required this.model,
    required this.isDownloaded,
    required this.isDownloading,
    required this.isLoading,
    required this.progress,
    required this.details,
    required this.onTap,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final busy = isDownloading || isLoading;
    return PressableScale(
      onTap: busy ? null : onTap,
      child: GlassPanel(
        glow: isDownloaded || model.recommended,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ModelGlyph(model: model),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              model.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (model.recommended) ...[
                            const SizedBox(width: 8),
                            const _Badge(label: 'Recommended'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        model.performanceLabel,
                        style: const TextStyle(
                            color: AnviColors.champagne, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _Status(
                  isDownloaded: isDownloaded,
                  isDownloading: isDownloading,
                  isLoading: isLoading,
                  progress: progress,
                ),
                if (isDownloaded && !busy) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Delete model',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: Colors.white54,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            const SizedBox(height: AnviSpacing.lg),
            Text(
              model.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, height: 1.35),
            ),
            const Spacer(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoPill(
                    icon: Icons.storage_rounded,
                    label: Formatters.bytes(model.sizeBytes)),
                _InfoPill(icon: Icons.memory_rounded, label: model.ramLabel),
                const _InfoPill(icon: Icons.lock_rounded, label: 'Offline'),
              ],
            ),
            if (isDownloading) ...[
              const SizedBox(height: 14),
              _DownloadBar(
                  progress: progress, details: details, onCancel: onCancel),
            ],
            if (isLoading) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(
                minHeight: 3,
                color: AnviColors.moltenGold,
                backgroundColor: Colors.white12,
              ),
              const SizedBox(height: 8),
              const Text('Loading GGUF weights into memory...',
                  style: TextStyle(fontSize: 12, color: Colors.white38)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModelGlyph extends StatelessWidget {
  final LLMModel model;

  const _ModelGlyph({required this.model});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [AnviColors.crimson, AnviColors.ember, AnviColors.champagne],
        ),
        boxShadow: [
          BoxShadow(
              color: AnviColors.ember.withValues(alpha: 0.3), blurRadius: 18),
        ],
      ),
      child: Center(
        child: Text(
          model.name.characters.first,
          style: const TextStyle(
            color: AnviColors.voidBlack,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  final bool isDownloaded;
  final bool isDownloading;
  final bool isLoading;
  final double progress;

  const _Status({
    required this.isDownloaded,
    required this.isDownloading,
    required this.isLoading,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }
    if (isDownloading) {
      return SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(
          value: progress,
          strokeWidth: 3,
          color: AnviColors.moltenGold,
          backgroundColor: Colors.white12,
        ),
      );
    }
    if (isDownloaded) return const _Badge(label: 'Ready');
    return const Icon(Icons.download_rounded, color: AnviColors.champagne);
  }
}

class _Badge extends StatelessWidget {
  final String label;

  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AnviColors.champagne.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AnviColors.champagne.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AnviColors.champagne,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AnviColors.champagne),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }
}

class _DownloadBar extends StatelessWidget {
  final double progress;
  final DownloadProgress? details;
  final VoidCallback onCancel;

  const _DownloadBar({
    required this.progress,
    required this.details,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            color: AnviColors.moltenGold,
            backgroundColor: Colors.white12,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                '${details?.percentLabel ?? '0.0%'}  ${details?.speedLabel ?? '--'}  ETA ${details?.etaLabel ?? '--'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ),
            TextButton(
              onPressed: onCancel,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ],
    );
  }
}
