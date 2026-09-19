import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kindbeamer/src/state/documents.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('stk_ingest');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  File write(String name, int size) {
    final f = File('${tmp.path}/$name');
    f.writeAsBytesSync(List.filled(size, 0x41));
    return f;
  }

  test('accepts pdf and epub drops', () {
    final pdf = write('paper.pdf', 2048);
    final epub = write('book.epub', 4096);
    final items = Ingest.itemsFor([pdf.path, epub.path]);
    expect(items, hasLength(2));
    expect(items[0].format.inputFormat, 'PDF');
    expect(items[1].format.inputFormat, 'EPUB');
    expect(items[0].size, 2048);
    expect(items[1].size, 4096);
    expect(items[0].title, 'paper');
    expect(items[1].title, 'book');
  });

  test('rejects unsupported extensions and duplicates', () {
    final pdf = write('a.pdf', 10);
    final exe = write('evil.exe', 10);
    final out = Ingest.filterAccepted([pdf.path, exe.path, pdf.path]);
    expect(out, [pdf.path]);
  });

  test('file:// urls are resolved', () {
    final pdf = write('b.pdf', 10);
    final out = Ingest.filterAccepted([Uri.file(pdf.path).toString()]);
    expect(out, [pdf.path]);
  });

  test('unsupported paths are reported for the skip notice', () {
    final pdf = write('c.pdf', 10);
    final exe = write('evil.exe', 10);
    final zip = write('bundle.zip', 10);
    expect(
      Ingest.unsupported([pdf.path, exe.path, Uri.file(zip.path).toString()]),
      [exe.path, zip.path],
    );
    expect(Ingest.unsupported([pdf.path]), isEmpty);
  });

  test('metadata sent to the service is never empty', () {
    final pdf = write('d.pdf', 10);
    final item = Ingest.itemsFor([pdf.path]).single;
    expect(item.effectiveTitle, 'd');
    expect(item.effectiveAuthor, 'Unknown');

    item.title = '   ';
    item.author = '  Jane Roe ';
    expect(item.effectiveTitle, 'd', reason: 'blank title falls back');
    expect(item.effectiveAuthor, 'Jane Roe');

    item.title = 'x' * 400;
    expect(item.effectiveTitle.length, DocItem.metadataLimit);
  });

  test('human readable sizes', () {
    expect(DocItem.humanSize(512), '512 B');
    expect(DocItem.humanSize(9680 * 1024 ~/ 10), startsWith('968'));
    expect(DocItem.humanSize(10 * 1024 * 1024), '10.00 MB');
  });
}
