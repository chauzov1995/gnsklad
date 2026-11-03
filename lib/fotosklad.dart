import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'camera_screen_sklad.dart';
import 'tehhclass.dart';
import 'warehouse_photos.dart';

class WarehousePhotosPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const WarehousePhotosPage(this.cameras, {super.key});
  @override
  State<WarehousePhotosPage> createState() => _WarehouseState();
}

class _WarehouseState extends State<WarehousePhotosPage> {
  final input = TextEditingController();
  String order = '', notice = '';
  List<String> names = [];
  List<PhotoJob> local = [];
  bool hasQueuedPhotos = false;
  int generation = 0;
  StreamSubscription? scanner, zebra;
  @override
  void initState() {
    super.initState();
    scanner = tehhclass.receiver.messages.listen((event) {
      final d = event.data;
      if (tehhclass.selectedIndex == 1 && d != null) {
        final value = d['SCAN_BARCODE1'] ?? d['scandata'] ?? d['value'];
        if (value != null) select(value.toString());
      }
    });
    zebra = tehhclass.dw.onScanResult.listen((e) {
      if (tehhclass.selectedIndex == 1) select(e.data);
    });
    WarehouseQueue.instance.addListener(refresh);
    refresh();
  }

  void select(String value) {
    final next = value.trim();
    input.text = next;
    setState(() {
      order = next;
      names = [];
      local = [];
      notice = '';
    });
    refresh();
  }

  Future<void> refresh() async {
    final g = ++generation;
    final current = order;
    final jobs = await WarehouseQueue.instance.jobs();
    if (!mounted || g != generation) return;
    setState(() {
      hasQueuedPhotos = jobs.isNotEmpty;
      local = jobs.where((job) => job.order == current).toList();
    });
    if (!WarehouseQueue.orderPattern.hasMatch(current)) return;
    try {
      final result = await PhotoApi.list(current);
      if (mounted && g == generation) {
        setState(() {
          names = result;
          notice = '';
        });
      }
    } catch (e) {
      if (mounted && g == generation) {
        setState(() => notice = e is PhotoProblem
            ? e.message
            : 'Нет связи с фабрикой. Снимки остаются на устройстве.');
      }
    }
  }

  @override
  void dispose() {
    WarehouseQueue.instance.removeListener(refresh);
    scanner?.cancel();
    zebra?.cancel();
    input.dispose();
    super.dispose();
  }

  Widget preview(Widget image) => Scaffold(
      appBar: AppBar(title: Text('Заказ $order')),
      body: Center(child: InteractiveViewer(maxScale: 5, child: image)));
  Widget tile(Widget thumb, Widget Function() full, {String? archiveName}) =>
      InkWell(
          onTap: () async {
            await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => archiveName == null
                        ? preview(full())
                        : _ArchivePreview(order, archiveName)));
            if (mounted) await refresh();
          },
          child: ClipRect(child: SizedBox.expand(child: thumb)));

  Widget localTile(PhotoJob job) {
    final image = File(job.file.existsSync() ? job.file.path : job.draft.path);
    Widget pic({bool small = false}) => Image.file(image,
        cacheWidth: small ? 260 : null,
        fit: small ? BoxFit.cover : BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.image));
    return tile(pic(small: true), () => pic());
  }

  @override
  Widget build(BuildContext context) {
    final valid = WarehouseQueue.orderPattern.hasMatch(order);
    return Scaffold(
        appBar: AppBar(title: const Text('Ящик с фурнитурой'), actions: [
          if (hasQueuedPhotos)
            IconButton(
                tooltip: 'Очередь всех заказов',
                icon: const Icon(Icons.cloud_upload_outlined),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const _QueuePage()))),
        ]),
        body: Column(children: [
          const SizedBox(height: 8),
          Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                  controller: input,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) {
                    if (order.isNotEmpty) {
                      setState(() {
                        generation++;
                        order = '';
                        names = [];
                        local = [];
                        notice = '';
                      });
                      refresh();
                    }
                  },
                  onSubmitted: select,
                  decoration: InputDecoration(
                      labelText: 'Заказ',
                      hintText: 'Заказ',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                          icon: const Icon(Icons.clear_sharp,
                              color: Colors.black),
                          onPressed: () => select('')),
                      border: const OutlineInputBorder(
                          borderRadius:
                              BorderRadius.all(Radius.circular(25)))))),
          if (order.isNotEmpty && !valid) const Text('Проверьте номер заказа'),
          if (notice.isNotEmpty) Text(notice),
          Expanded(
              child: GridView.count(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  padding: const EdgeInsets.all(2),
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  children: [
                for (final j in local) localTile(j),
                for (final n in names)
                  if (!local.any((j) => n == '${j.order}_${j.id}.jpg'))
                    tile(
                        _RemotePhoto(order, n,
                            small: true, key: ValueKey('$order/$n')),
                        () => _RemotePhoto(order, n),
                        archiveName: n)
              ]))
        ]),
        floatingActionButton: !valid
            ? null
            : FloatingActionButton(
                child: const Icon(Icons.photo_camera),
                onPressed: () async {
                  final target = order;
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => camera_screen_sklad(
                              name: target, cameras: widget.cameras)));
                  if (mounted) refresh();
                }));
  }
}

class _ArchivePreview extends StatefulWidget {
  final String order, name;
  const _ArchivePreview(this.order, this.name);
  @override
  State<_ArchivePreview> createState() => _ArchivePreviewState();
}

class _ArchivePreviewState extends State<_ArchivePreview> {
  bool deleting = false;
  Future<void> remove() async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Удалить снимок?'),
              content: Text(
                  'Снимок будет удалён из архива заказа ${widget.order}, включая его копию для политона, если она есть.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Отмена')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Удалить')),
              ],
            ));
    if (yes != true || !mounted) return;
    setState(() => deleting = true);
    try {
      await PhotoApi.delete(widget.order, widget.name);
      if (mounted) {
        setState(() => deleting = false);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is PhotoProblem
                ? e.message
                : 'Нет подтверждения удаления. Проверьте связь и повторите.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !deleting,
      child: Scaffold(
        appBar: AppBar(title: Text('Заказ ${widget.order}'), actions: [
          IconButton(
              tooltip: 'Удалить снимок',
              onPressed: deleting ? null : remove,
              icon: const Icon(Icons.delete_outline)),
        ]),
        body: deleting
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: InteractiveViewer(
                    maxScale: 5,
                    child: _RemotePhoto(widget.order, widget.name))),
      ));
}

class _RemotePhoto extends StatefulWidget {
  final String order, name;
  final bool small;
  const _RemotePhoto(this.order, this.name, {this.small = false, super.key});
  @override
  State<_RemotePhoto> createState() => _RemoteState();
}

class _RemoteState extends State<_RemotePhoto> {
  late final Future<Uint8List> bytes = PhotoApi.request(
      '${PhotoApi.listPath(widget.order)}/${Uri.encodeComponent(widget.name)}');
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
      future: bytes,
      builder: (context, s) {
        if (s.hasError) return const Icon(Icons.broken_image);
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return Image.memory(s.data!,
            cacheWidth: widget.small ? 260 : null,
            fit: widget.small ? BoxFit.cover : BoxFit.contain);
      });
}

class _QueuePage extends StatelessWidget {
  const _QueuePage();
  @override
  Widget build(BuildContext context) {
    final q = WarehouseQueue.instance;
    return Scaffold(
        appBar: AppBar(title: const Text('Очередь этого устройства')),
        body: AnimatedBuilder(
            animation: q,
            builder: (_, __) => FutureBuilder<List<PhotoJob>>(
                future: q.jobs(),
                builder: (_, s) {
                  if (s.hasError) {
                    return const Center(
                        child: Text('Не удалось прочитать очередь'));
                  }
                  if (!s.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (s.data!.isEmpty) {
                    return const Center(child: Text('Все снимки доставлены'));
                  }
                  return ListView(children: [
                    for (final j in s.data!)
                      FutureBuilder<Map>(
                          future: j.state(),
                          builder: (_, state) => ListTile(
                              title: Text('Заказ ${j.order}'),
                              subtitle: Text(
                                  '${DateTime.fromMillisecondsSinceEpoch(j.created).toLocal()}\n${state.data?['error'] ?? 'Ожидает отправки'}')))
                  ]);
                })));
  }
}
