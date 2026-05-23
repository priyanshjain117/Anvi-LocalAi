enum AttachmentStatus { ready, failed }

class FileAttachment {
  final String name;
  final String path;
  final String extension;
  final int sizeBytes;
  final String text;
  final AttachmentStatus status;
  final String? error;

  const FileAttachment({
    required this.name,
    required this.path,
    required this.extension,
    required this.sizeBytes,
    required this.text,
    this.status = AttachmentStatus.ready,
    this.error,
  });

  bool get isReady => status == AttachmentStatus.ready;
}
