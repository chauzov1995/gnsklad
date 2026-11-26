import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'main.dart';
import 'supplier_documents.dart';
import 'warehouse_photos.dart';

String supplierDateLabel(String date) {
  final p = date.split('-');
  return p.length == 3 ? '${p[2]}.${p[1]}.${p[0]}' : date;
}

Future<void> openSupplierPdf(BuildContext context,
    {SupplierJob? job, int? supplierId, String? name}) async {
  try {
    final dir = Directory(
        '${(await getApplicationSupportDirectory()).path}/supplier-pdf-view');
    await dir.create(recursive: true);
    final bytes = job != null
        ? await job.pdf.readAsBytes()
        : await SupplierApi.read(supplierId!, name!);
    final file = File(
        '${dir.path}/${job != null ? '${job.id}.pdf' : '${supplierId}_$name'}');
    await file.writeAsBytes(bytes, flush: true);
    final result = await OpenFilex.open(file.path, type: 'application/pdf');
    if (result.type != ResultType.done) {
      throw const PhotoProblem(
          'Установите приложение для просмотра PDF и попробуйте ещё раз.');
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is PhotoProblem
              ? e.message
              : 'Не удалось открыть PDF. Проверьте подключение к фабричной сети.')));
    }
  }
}

class GalleryScreen2 extends StatefulWidget {
  final postav name;
  const GalleryScreen2(this.name, {super.key});
  @override
  State<GalleryScreen2> createState() => _GalleryScreen2State();
}

class _GalleryScreen2State extends State<GalleryScreen2> {
  List<Map<String, dynamic>> _files = [];
  List<SupplierJob> _pending = [];
  String? _error;
  bool _loading = true, _refreshing = false;
  SupplierQueue get queue => SupplierQueue.instance;
  @override
  void initState() {
    super.initState();
    queue.addListener(_changed);
    _refresh();
  }

  @override
  void dispose() {
    queue.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    _refresh();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    final pending = await queue.jobs(supplierId: widget.name.id!);
    if (mounted) setState(() => _pending = pending);
    try {
      final files = await SupplierApi.documents(widget.name.id!);
      if (mounted) {
        setState(() {
          _files = files;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is PhotoProblem
            ? e.message
            : 'Архив пока недоступен. Документы в очереди сохранены на устройстве.');
      }
    } finally {
      final pending = await queue.jobs(supplierId: widget.name.id!);
      _refreshing = false;
      if (mounted) {
        setState(() {
          _pending = pending;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.name.name!)),
        body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_error!)),
                  for (final job in _pending) SupplierPendingTile(job: job),
                  for (final file in _files)
                    ListTile(
                        leading: const Icon(Icons.picture_as_pdf,
                            color: Colors.red, size: 40),
                        title: Text(
                            '${supplierDateLabel(file['date'] as String)}.pdf'),
                        onTap: () => openSupplierPdf(context,
                            supplierId: widget.name.id!,
                            name: file['name'] as String)),
                  if (!_loading &&
                      _error == null &&
                      _files.isEmpty &&
                      _pending.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Документов пока нет')),
                ])),
      );
}

class SupplierPendingTile extends StatelessWidget {
  final SupplierJob job;
  final bool showSupplier;
  const SupplierPendingTile(
      {super.key, required this.job, this.showSupplier = false});
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
      future: job.state(),
      builder: (context, snapshot) => ListTile(
          leading: const Icon(Icons.cloud_upload_outlined, size: 40),
          title: Text(
              '${showSupplier ? '${job.supplierName} · ' : ''}${supplierDateLabel(job.date)}.pdf'),
          subtitle: Text(snapshot.data?['error'] as String? ??
              'Ожидает отправки на фабрику'),
          onTap: () => openSupplierPdf(context, job: job)));
}

class SupplierPendingScreen extends StatelessWidget {
  const SupplierPendingScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Очередь документов')),
        body: ListenableBuilder(
            listenable: SupplierQueue.instance,
            builder: (_, __) => FutureBuilder<List<SupplierJob>>(
                future: SupplierQueue.instance.jobs(),
                builder: (context, snapshot) => ListView(children: [
                      for (final issue in SupplierQueue.instance.recoveryIssues)
                        Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(issue)),
                      for (final job in snapshot.data ?? <SupplierJob>[])
                        SupplierPendingTile(job: job, showSupplier: true),
                      if (snapshot.hasData && snapshot.data!.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Все документы отправлены')),
                    ]))),
      );
}
