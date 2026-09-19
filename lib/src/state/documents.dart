import 'dart:io';

import 'package:path/path.dart' as p;

class DocFormat {
  const DocFormat._(this.extension, this.inputFormat, this.label);

  final String extension;
  final String inputFormat;
  final String label;

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
  ];

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
  }) : title = title ?? _defaultTitle(name);

  final String path;
  final String name;
  final int size;
  final DocFormat format;
  String title;
  String author;

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
  static List<String> filterAccepted(Iterable<String> paths) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in paths) {
      final path = raw.startsWith('file://') ? Uri.parse(raw).toFilePath() : raw;
      if (DocFormat.forPath(path) == null) continue;
      if (!seen.add(path)) continue;
      out.add(path);
    }
    return out;
  }

  static List<DocItem> itemsFor(Iterable<String> paths) {
    final items = <DocItem>[];
    for (final path in filterAccepted(paths)) {
      final file = File(path);
      final size = file.existsSync() ? file.lengthSync() : 0;
      items.add(DocItem(
        path: path,
        name: p.basename(path),
        size: size,
        format: DocFormat.forPath(path)!,
      ));
    }
    return items;
  }
}
