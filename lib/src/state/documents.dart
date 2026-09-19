import 'dart:io';

import 'package:path/path.dart' as p;

class DocFormat {
  const DocFormat._(
    this.extension,
    this.inputFormat,
    this.label, {
    this.needsConversion = false,
  });

  final String extension;
  final String inputFormat;
  final String label;

  /// The service has no Markdown input format, so these are converted before
  /// they are uploaded (see `convert/markdown.dart`).
  final bool needsConversion;

  static const supported = [
    DocFormat._('pdf', 'PDF', 'PDF'),
    DocFormat._('epub', 'EPUB', 'EPUB'),
    DocFormat._('mobi', 'MOBI', 'MOBI'),
    DocFormat._('azw3', 'AZW3', 'AZW3'),
    DocFormat._('azw', 'AZW', 'AZW'),
    DocFormat._('txt', 'TXT', 'TXT'),
    DocFormat._('rtf', 'RTF', 'RTF'),
    DocFormat._('doc', 'DOC', 'DOC'),
    DocFormat._('docx', 'DOCX', 'DOCX'),
    DocFormat._('html', 'HTML', 'HTML'),
    DocFormat._('htm', 'HTML', 'HTML'),
    DocFormat._('png', 'PNG', 'PNG'),
    DocFormat._('jpg', 'JPG', 'JPG'),
    DocFormat._('jpeg', 'JPG', 'JPG'),
    DocFormat._('gif', 'GIF', 'GIF'),
    DocFormat._('bmp', 'BMP', 'BMP'),
    DocFormat._('md', 'MD', 'Markdown', needsConversion: true),
    DocFormat._('markdown', 'MD', 'Markdown', needsConversion: true),
  ];

  static DocFormat? forExtension(String extension) {
    for (final format in supported) {
      if (format.extension == extension) return format;
    }
    return null;
  }

  static DocFormat? forPath(String path) {
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    for (final f in supported) {
      if (f.extension == ext) return f;
    }
    return null;
  }
}

class DocItem {
  DocItem({
    required this.path,
    required this.name,
    required this.size,
    required this.format,
    String? title,
    this.author = '',
  }) : title = title ?? _defaultTitle(name),
       uploadPath = path;

  final String path;
  final String name;

  /// The file actually uploaded: the same file, unless it was converted.
  String uploadPath;
  int size;
  DocFormat format;
  String title;
  String author;

  /// Set while a converter is running, and afterwards to say what happened.
  bool converting = false;
  String? conversionNote;

  bool get needsConversion => format.needsConversion;

  /// `SendToKindle` rejects empty metadata ("Member must have length greater
  /// than or equal to 1"), and the official client truncates long values rather
  /// than letting the service refuse them.
  static const int metadataLimit = 255;
  static const String unknownAuthor = 'Unknown';

  String get effectiveTitle {
    final trimmed = title.trim();
    return _clamp(trimmed.isEmpty ? _defaultTitle(name) : trimmed);
  }

  String get effectiveAuthor {
    final trimmed = author.trim();
    return _clamp(trimmed.isEmpty ? unknownAuthor : trimmed);
  }

  static String _clamp(String value) =>
      value.length <= metadataLimit ? value : value.substring(0, metadataLimit);

  static String _defaultTitle(String name) {
    final base = p.basenameWithoutExtension(name);
    return base.isEmpty ? name : base;
  }

  static String humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB'];
    var v = bytes / 1024;
    var u = 0;
    while (v >= 1024 && u < units.length - 1) {
      v /= 1024;
      u++;
    }
    return '${v.toStringAsFixed(2)} ${units[u]}';
  }
}

class Ingest {
  /// `file://` URLs (drag & drop, share intents) become plain paths.
  static String normalize(String raw) =>
      raw.startsWith('file://') ? Uri.parse(raw).toFilePath() : raw;

  static List<String> filterAccepted(Iterable<String> paths) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in paths) {
      final path = normalize(raw);
      if (DocFormat.forPath(path) == null) continue;
      if (!seen.add(path)) continue;
      out.add(path);
    }
    return out;
  }

  /// Paths the app cannot send, so the UI can say what it dropped on the floor.
  static List<String> unsupported(Iterable<String> paths) => paths
      .map(normalize)
      .where((path) => DocFormat.forPath(path) == null)
      .toList();

  static List<DocItem> itemsFor(Iterable<String> paths) {
    final items = <DocItem>[];
    for (final path in filterAccepted(paths)) {
      final file = File(path);
      final size = file.existsSync() ? file.lengthSync() : 0;
      items.add(
        DocItem(
          path: path,
          name: p.basename(path),
          size: size,
          format: DocFormat.forPath(path)!,
        ),
      );
    }
    return items;
  }
}
