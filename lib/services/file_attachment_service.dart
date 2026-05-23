import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/file_attachment.dart';

class FileAttachmentService {
  static const _maxBytes = 8 * 1024 * 1024;
  static const _maxPromptChars = 12000;
  static const _extensions = ['txt', 'md', 'markdown', 'pdf'];

  Future<List<FileAttachment>> pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: _extensions,
      withData: false,
    );
    if (result == null) return const [];

    final attachments = <FileAttachment>[];
    for (final file in result.files) {
      attachments.add(await _parse(file));
    }
    return attachments;
  }

  Future<FileAttachment> _parse(PlatformFile picked) async {
    final path = picked.path;
    final name = picked.name;
    final extension = picked.extension?.toLowerCase() ?? '';
    final size = picked.size;

    if (path == null) {
      return _failed(name, '', extension, size, 'No readable file path.');
    }
    if (!_extensions.contains(extension)) {
      return _failed(name, path, extension, size, 'Unsupported file type.');
    }
    if (size > _maxBytes) {
      return _failed(name, path, extension, size, 'File is larger than 8 MB.');
    }

    try {
      final file = File(path);
      final text = extension == 'pdf'
          ? _extractPdfText(await file.readAsBytes())
          : await _readTextFile(file);
      final cleaned = _normalize(text);
      if (cleaned.isEmpty) {
        return _failed(name, path, extension, size, 'No readable text found.');
      }
      return FileAttachment(
        name: name,
        path: path,
        extension: extension,
        sizeBytes: size,
        text: _clip(cleaned),
      );
    } catch (error) {
      return _failed(name, path, extension, size, 'Could not parse file.');
    }
  }

  Future<String> _readTextFile(File file) async {
    final bytes = await file.readAsBytes();
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  String _extractPdfText(List<int> bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      return PdfTextExtractor(document).extractText();
    } finally {
      document.dispose();
    }
  }

  String _normalize(String value) {
    return value
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{4,}'), '\n\n\n')
        .trim();
  }

  String _clip(String value) {
    if (value.length <= _maxPromptChars) return value;
    final end = math.min(value.length, _maxPromptChars);
    return '${value.substring(0, end)}\n\n[File text truncated for mobile context.]';
  }

  FileAttachment _failed(
    String name,
    String path,
    String extension,
    int size,
    String error,
  ) {
    return FileAttachment(
      name: name,
      path: path,
      extension: extension,
      sizeBytes: size,
      text: '',
      status: AttachmentStatus.failed,
      error: error,
    );
  }
}
