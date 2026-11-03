import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'camera_screen.dart';
import 'camera_screen19.dart';
import 'gallery_screen_s.dart';
import 'main.dart';
import 'supplier_documents.dart';
import 'tehhclass.dart';
import 'warehouse_photos.dart';

// Existing public name is used by the main navigation.
// ignore: camel_case_types
class postavshikir extends StatefulWidget {
  final List<CameraDescription> cameras;
  const postavshikir(this.cameras, {super.key});
  @override
  State<postavshikir> createState() => _SuppliersState();
}

class _SuppliersState extends State<postavshikir> {
  final _search = TextEditingController();
  List<postav> _suppliers = [];
  StreamSubscription<dynamic>? _broadcast, _scan;
  String? _notice;
  bool _loading = true;
  SupplierQueue get queue => SupplierQueue.instance;
  @override
  void initState() {
    super.initState();
    _broadcast = tehhclass.receiver.messages.listen((message) {
      final data = message.data;
      if (data == null) return;
      final value = data['value'] ?? data['scandata'] ?? data['SCAN_BARCODE1'];
      if (value != null) _searchCode(value.toString());
    });
    _scan =
        tehhclass.dw.onScanResult.listen((result) => _searchCode(result.data));
    _load();
  }

  void _searchCode(String text) {
    if (!mounted ||
        tehhclass.selectedIndex != 0 ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() => _search.text = text);
  }

  @override
  void dispose() {
    _broadcast?.cancel();
    _scan?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _display(List<Map<String, dynamic>> rows) async {
    final values = rows.map(postav.fromJson).toList();
    final ranking = <int, int>{};
    try {
      for (final row
          in await tehhclass.database.rawQuery('SELECT id, sort FROM Test')) {
        if (row['id'] is int) {
          ranking[row['id'] as int] = (row['sort'] as int?) ?? 0;
        }
      }
    } catch (_) {}
    values.sort((a, b) => (ranking[b.id] ?? 0).compareTo(ranking[a.id] ?? 0));
    if (mounted) setState(() => _suppliers = values);
  }

  Future<void> _load() async {
    await _display(await queue.cachedCatalog());
    try {
      await queue.refreshCatalog();
      await _display(await queue.cachedCatalog());
      if (mounted) setState(() => _notice = null);
    } catch (e) {
      if (mounted) {
        setState(() => _notice = _suppliers.isEmpty
            ? (e is PhotoProblem
                ? e.message
                : 'Подключитесь к фабричной сети, чтобы получить поставщиков.')
            : 'Нет связи с фабрикой. Используется сохранённый список; документы отправятся после подключения.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.toUpperCase();
    final visible = _suppliers
        .where((s) =>
            s.name!.toUpperCase().contains(query) ||
            s.inn!.toUpperCase().contains(query))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Поставщики'), actions: [
        ListenableBuilder(
            listenable: queue,
            builder: (_, __) => FutureBuilder<List<SupplierJob>>(
                future: queue.jobs(),
                builder: (context, snapshot) => (snapshot.data?.isNotEmpty ==
                            true ||
                        queue.recoveryIssues.isNotEmpty)
                    ? IconButton(
                        tooltip: 'Очередь документов',
                        icon: const Icon(Icons.cloud_upload_outlined),
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SupplierPendingScreen())))
                    : const SizedBox.shrink())),
      ]),
      body: Column(children: [
        if (_loading) const LinearProgressIndicator(),
        if (_notice != null)
          Padding(padding: const EdgeInsets.all(8), child: Text(_notice!)),
        Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                    labelText: 'Поставщик',
                    hintText: 'Поставщик (можно ИНН)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                        icon: const Icon(Icons.clear_sharp),
                        onPressed: () => setState(() => _search.clear())),
                    border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(25)))))),
        Expanded(
            child: RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final supplier = visible[index];
                      return ListTile(
                          title: Text(supplier.name!),
                          subtitle: Text('ИНН: ${supplier.inn}'),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => sdkver >= 21
                                      ? CameraScreen(
                                          name: supplier,
                                          cameras: widget.cameras)
                                      : CameraScreen19(name: supplier))),
                          trailing: IconButton(
                              icon: const Icon(Icons.arrow_forward_sharp),
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          GalleryScreen2(supplier)))));
                    }))),
      ]),
    );
  }
}
