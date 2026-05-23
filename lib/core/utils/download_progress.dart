import 'formatters.dart';

class DownloadProgress {
  final int received;
  final int total;
  final double progress;
  final double bytesPerSecond;
  final Duration? eta;

  const DownloadProgress({
    required this.received,
    required this.total,
    required this.progress,
    required this.bytesPerSecond,
    required this.eta,
  });

  String get percentLabel =>
      '${(progress * 100).clamp(0, 100).toStringAsFixed(1)}%';
  String get speedLabel => bytesPerSecond <= 0
      ? '--'
      : '${Formatters.bytes(bytesPerSecond.round())}/s';
  String get etaLabel => Formatters.duration(eta);
}
