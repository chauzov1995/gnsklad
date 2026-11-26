import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'warehouse_photos.dart';

const supplierPdfLimit = 64 * 1024 * 1024;
String documentDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
bool validDocumentDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  final date = DateTime.tryParse(value);
  return date != null && date.year >= 1900 && documentDate(date) == value;
}

class SupplierApi {
  static String path(int id) => '/v1/suppliers/$id/documents';
  static Future<List<Map<String, dynamic>>> suppliers() async =>
      (jsonDecode(utf8.decode(await PhotoApi.request('/v1/suppliers'))) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  static Future<List<Map<String, dynamic>>> documents(int id) async =>
      (jsonDecode(utf8.decode(await PhotoApi.request(path(id)))) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  static Future<Uint8List> read(int id, String name) =>
      PhotoApi.request('${path(id)}/${Uri.encodeComponent(name)}',
          maxResponseBytes: supplierPdfLimit,
          deadline: const Duration(minutes: 2));
  static Future<void> upload(SupplierJob job) async {
    final hash = (await sha256.bind(job.pdf.openRead()).first).toString();
    if (hash != job.hash) {
      throw const PhotoProblem(
          'Локальный PDF повреждён. Он сохранён на устройстве.');
    }
    final r = jsonDecode(utf8.decode(await PhotoApi.request(
        '${path(job.supplierId)}/${job.id}?date=${job.date}',
        file: job.pdf,
        contentType: ContentType('application', 'pdf'),
        deadline: const Duration(minutes: 2))));
    final parts = job.date.split('-');
    final name = '${parts[2]}.${parts[1]}.${parts[0]}_${job.id}.pdf';
    if (r is! Map ||
        r['saved'] != true ||
        r['supplierId'] != job.supplierId ||
        r['date'] != job.date ||
        r['id'] != job.id ||
        r['name'] != name ||
        r['sha256'] != hash ||
        r['pages'] is! int ||
        r['pages'] < 1) {
      throw const PhotoProblem('Фабрика не подтвердила сохранение PDF');
    }
  }
}

class SupplierJob {
  final Directory dir;
  final String id, supplierName, date, hash;
  final int supplierId, created;
  final List<String> pages;
  SupplierJob(this.dir, Map<String, dynamic> m)
      : id = m['id'] as String,
        supplierId = m['supplierId'] as int,
        supplierName = m['supplierName'] as String,
        date = m['date'] as String,
        hash = m['sha256'] as String,
        created = m['created'] as int,
        pages = (m['pages'] as List).cast<String>();
  File get pdf => File('${dir.path}/document.pdf');
  Future<Map<String, dynamic>> state() async {
    try {
      return Map<String, dynamic>.from(
          jsonDecode(await File('${dir.path}/attempt.json').readAsString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> record(Map<String, dynamic> state) async {
    final tmp = File('${dir.path}/attempt.tmp');
    await tmp.writeAsString(jsonEncode(state), flush: true);
    await tmp.rename('${dir.path}/attempt.json');
  }
}

class SupplierQueue extends ChangeNotifier {
  static late SupplierQueue instance;
  final Directory root;
  final Future<void> Function(SupplierJob) deliver;
  final Future<List<Map<String, dynamic>>> Function() loadCatalog;
  final _random = Random.secure();
  Timer? _timer;
  bool _busy = false;
  final List<String> recoveryIssues = [];
  Future<void>? _catalogRefresh;
  SupplierQueue(this.root,
      {this.deliver = SupplierApi.upload,
      this.loadCatalog = SupplierApi.suppliers});
  String _id() => List.generate(
      16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  Directory get pending => Directory('${root.path}/pending');
  Directory drafts(int supplier) => Directory('${root.path}/drafts/$supplier');
  static Future<void> start() async {
    instance = SupplierQueue(Directory(
        '${(await getApplicationSupportDirectory()).path}/supplier-documents-v1'));
    await instance.recover();
    instance._timer =
        Timer.periodic(const Duration(seconds: 15), (_) => instance.kick());
    instance.kick();
  }

  Future<void> recover() async {
    await pending.create(recursive: true);
    recoveryIssues.clear();
    await for (final item in pending.list(followLinks: false)) {
      if (item is! Directory) continue;
      final name = item.uri.pathSegments.where((p) => p.isNotEmpty).last;
      if (!RegExp(r'^\.writing-[0-9a-f]{32}$').hasMatch(name)) continue;
      try {
        final job = await _read(item);
        if ((await sha256.bind(job.pdf.openRead()).first).toString() !=
            job.hash) {
          throw const FormatException();
        }
        await item.rename('${pending.path}/${job.id}');
      } catch (_) {
        recoveryIssues.add(
            'Не завершена запись PDF. Исходные страницы сохранены в камере поставщика.');
      }
    }
    // Committed PDFs own their source pages. Keep originals until the server
    // acknowledges the PDF; draftPages excludes owned pages from re-submission.
    await jobs();
  }

  Future<SupplierJob> _read(Directory dir) async {
    final m = Map<String, dynamic>.from(
        jsonDecode(await File('${dir.path}/meta.json').readAsString()));
    if (m['type'] != 'supplier-pdf' ||
        m['supplierId'] is! int ||
        m['supplierId'] == 0 ||
        m['supplierName'] is! String ||
        m['created'] is! int ||
        !RegExp(r'^[0-9a-f]{32}$').hasMatch(m['id'].toString()) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(m['sha256'].toString()) ||
        !validDocumentDate(m['date'].toString()) ||
        m['pages'] is! List ||
        (m['pages'] as List).any((p) =>
            p is! String || !RegExp(r'^\d+_[0-9a-f]{32}\.jpg$').hasMatch(p))) {
      throw const FormatException('Invalid local document metadata');
    }
    final basename = dir.uri.pathSegments.where((p) => p.isNotEmpty).last;
    if (basename != m['id'] && basename != '.writing-${m['id']}') {
      throw const FormatException();
    }
    return SupplierJob(dir, m);
  }

  Future<List<SupplierJob>> jobs({int? supplierId}) async {
    final result = <SupplierJob>[];
    await for (final item in pending.list(followLinks: false)) {
      if (item is! Directory ||
          !RegExp(r'^[0-9a-f]{32}$').hasMatch(
              item.uri.pathSegments.where((p) => p.isNotEmpty).last)) {
        continue;
      }
      try {
        final job = await _read(item);
        if (supplierId == null || supplierId == job.supplierId) result.add(job);
      } catch (_) {
        const text =
            'Не удалось прочитать запись очереди PDF. Файлы оставлены на устройстве.';
        if (!recoveryIssues.contains(text)) recoveryIssues.add(text);
      }
    }
    return result..sort((a, b) => a.created.compareTo(b.created));
  }

  Future<File> capture(int supplierId, File source) async {
    final folder = drafts(supplierId);
    await folder.create(recursive: true);
    final name = '${DateTime.now().millisecondsSinceEpoch}_${_id()}.jpg';
    final tmp = File('${folder.path}/$name.part');
    final handle = await tmp.open(mode: FileMode.write);
    try {
      await for (final b in source.openRead()) {
        await handle.writeFrom(b);
      }
      await handle.flush();
    } finally {
      await handle.close();
    }
    if (await tmp.length() != await source.length()) {
      throw const PhotoProblem('Не удалось сохранить страницу');
    }
    return tmp.rename('${folder.path}/$name');
  }

  Future<List<File>> draftPages(int supplierId) async {
    final dir = drafts(supplierId);
    await dir.create(recursive: true);
    final owned =
        (await jobs(supplierId: supplierId)).expand((j) => j.pages).toSet();
    return (await dir
        .list(followLinks: false)
        .where((e) =>
            e is File &&
            e.path.endsWith('.jpg') &&
            !owned.contains(e.uri.pathSegments.last))
        .cast<File>()
        .toList())
      ..sort((a, b) => a.path.compareTo(b.path));
  }

  Future<void> discardPage(int supplierId, File page) async {
    if (await page.parent.resolveSymbolicLinks() !=
            await drafts(supplierId).resolveSymbolicLinks() ||
        await FileSystemEntity.isLink(page.path)) {
      throw const PhotoProblem('Не удалось удалить страницу');
    }
    await page.delete();
  }

  static Future<Uint8List> makePdf(List<File> pages) async {
    if (pages.isEmpty) {
      throw const PhotoProblem('Сначала сфотографируйте документы');
    }
    if (pages.length > 500) {
      throw const PhotoProblem(
          'Разделите документ: не больше 500 страниц в одном PDF.');
    }
    final pdf = pw.Document();
    for (final file in pages) {
      final image = pw.MemoryImage(await file.readAsBytes());
      pdf.addPage(pw.Page(build: (_) => pw.Center(child: pw.Image(image))));
    }
    return pdf.save();
  }

  Future<SupplierJob> enqueue(List<File> pages, int supplierId,
      String supplierName, DateTime selectedDate) async {
    final date = documentDate(selectedDate);
    if (supplierId == 0 || !validDocumentDate(date)) {
      throw const PhotoProblem('Проверьте поставщика и дату');
    }
    final expected = await drafts(supplierId).resolveSymbolicLinks();
    for (final page in pages) {
      if (await page.parent.resolveSymbolicLinks() != expected ||
          await FileSystemEntity.isLink(page.path)) {
        throw const PhotoProblem('Страница не сохранена на устройстве');
      }
    }
    final bytes = await makePdf(pages);
    if (bytes.length > supplierPdfLimit) {
      throw const PhotoProblem(
          'PDF больше 64 МБ. Разделите документ на несколько частей.');
    }
    final id = _id(), hash = sha256.convert(bytes).toString();
    final staging = Directory('${pending.path}/.writing-$id');
    await staging.create();
    final m = {
      'type': 'supplier-pdf',
      'id': id,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'date': date,
      'created': DateTime.now().millisecondsSinceEpoch,
      'sha256': hash,
      'pages': pages.map((p) => p.uri.pathSegments.last).toList()
    };
    await File('${staging.path}/meta.json')
        .writeAsString(jsonEncode(m), flush: true);
    final pdf = File('${staging.path}/document.pdf');
    await pdf.writeAsBytes(bytes, flush: true);
    if ((await sha256.bind(pdf.openRead()).first).toString() != hash) {
      throw const PhotoProblem('Не завершена локальная запись PDF');
    }
    final dir = await staging.rename('${pending.path}/$id');
    final job = SupplierJob(dir, m);
    notifyListeners();
    kick();
    return job;
  }

  Future<void> _clearPages(SupplierJob job) async {
    for (final name in job.pages) {
      final file = File('${drafts(job.supplierId).path}/$name');
      if (await file.exists()) await discardPage(job.supplierId, file);
    }
  }

  Future<void> _verify(SupplierJob job) async {
    if (await FileSystemEntity.isLink(job.pdf.path) ||
        await job.dir.parent.resolveSymbolicLinks() !=
            await pending.resolveSymbolicLinks()) {
      throw const PhotoProblem(
          'Не удалось проверить локальную запись PDF. Файлы сохранены.');
    }
    if ((await sha256.bind(job.pdf.openRead()).first).toString() != job.hash) {
      throw const PhotoProblem(
          'Локальный PDF повреждён. Исходные файлы оставлены на устройстве.');
    }
  }

  Future<List<Map<String, dynamic>>> cachedCatalog() async {
    try {
      return (jsonDecode(await File('${root.path}/catalog.json').readAsString())
              as List)
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> refreshCatalog() => _catalogRefresh ??=
      _refreshCatalog().whenComplete(() => _catalogRefresh = null);
  Future<void> _refreshCatalog() async {
    final list = await loadCatalog();
    final ids = <int>{};
    if (list.isEmpty ||
        list.any((s) =>
            s['id'] is! int ||
            s['id'] == 0 ||
            !ids.add(s['id']) ||
            s['name'] is! String ||
            s['inn'] is! String ||
            s['cod'] is! String)) {
      throw const PhotoProblem('Получен некорректный справочник поставщиков');
    }
    await root.create(recursive: true);
    final tmp = File('${root.path}/catalog.tmp');
    await tmp.writeAsString(jsonEncode(list), flush: true);
    await tmp.rename('${root.path}/catalog.json');
  }

  void kick() {
    unawaited(drain().catchError((Object _) {}));
  }

  Future<void> drain() async {
    if (_busy) return;
    _busy = true;
    try {
      for (final job in await jobs()) {
        final state = await job.state(),
            now = DateTime.now().millisecondsSinceEpoch;
        if ((state['next'] as int? ?? 0) > now) continue;
        try {
          await job.record({...state, 'status': 'sending'});
          await _verify(job);
          await deliver(job);
          await _clearPages(job);
          // The PDF leaves the queue only after a validated server receipt.
          await job.dir.delete(recursive: true);
        } catch (e) {
          final count = (state['count'] as int? ?? 0) + 1;
          await job.record({
            'status': 'error',
            'count': count,
            'next': now + min(120, 5 * (1 << min(count, 5))) * 1000,
            'error': e is PhotoProblem
                ? e.message
                : 'Нет связи с фабрикой. PDF сохранён на устройстве.'
          }).catchError((_) {});
        }
        notifyListeners();
      }
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
