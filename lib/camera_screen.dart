import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'main.dart';
import 'tehhclass.dart';
import 'gallery_screen.dart';
import 'supplier_documents.dart';
import 'warehouse_photos.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final postav name;
  final bool useSystemCamera;
  const CameraScreen(
      {super.key,
      required this.name,
      required this.cameras,
      this.useSystemCamera = false});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  late Future<void> _ready;
  final List<File> _pages = [];
  bool _busy = false;
  DateTime _date = DateTime.now();
  SupplierQueue get queue => SupplierQueue.instance;
  int get supplierId => widget.name.id!;
  @override
  void initState() {
    super.initState();
    _ready = _initialize();
  }

  Future<void> _initialize() async {
    _pages.addAll(await queue.draftPages(supplierId));
    if (!mounted) return;
    if (!widget.useSystemCamera && widget.cameras.isNotEmpty) {
      _controller = CameraController(widget.cameras.first, ResolutionPreset.max,
          enableAudio: false);
      await _controller!.initialize();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _error(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is PhotoProblem
              ? e.message
              : 'Не удалось завершить действие. Сохранённые страницы остались на устройстве.')));
    }
  }

  Future<void> _capture() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _ready;
      final photo = _controller != null
          ? await _controller!.takePicture()
          : await ImagePicker().pickImage(source: ImageSource.camera);
      if (photo != null) {
        final saved = await queue.capture(supplierId, File(photo.path));
        _pages.add(saved);
      }
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    if (_busy || _pages.isEmpty) return;
    final yes = await showCupertinoModalPopup<bool>(
        context: context,
        builder: (sheet) => Container(
            height: 350,
            color: Colors.white,
            child: SafeArea(
                top: false,
                child: Column(children: [
                  Expanded(
                      child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.date,
                          initialDateTime: _date,
                          minimumYear: 1900,
                          onDateTimeChanged: (value) => _date = value)),
                  Padding(
                      padding: const EdgeInsets.all(20),
                      child: ElevatedButton(
                          onPressed: () => Navigator.pop(sheet, true),
                          child: const Text('ОТПРАВИТЬ'))),
                ]))));
    if (yes != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await queue.enqueue(
          List.of(_pages), supplierId, widget.name.name!, _date);
      _pages.clear();
      // Ranking is cosmetic; it cannot undo the durable enqueue.
      try {
        await tehhclass.database.rawInsert(
            'INSERT OR REPLACE INTO Test(id, sort) VALUES (?, COALESCE((SELECT sort FROM Test WHERE id = ?), 0) + 1)',
            [supplierId, supplierId]);
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'PDF сохранён на устройстве и будет отправлен на фабрику автоматически.')));
      }
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
            child: Column(children: [
          Expanded(
              child: FutureBuilder<void>(
                  future: _ready,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                          child: Text(
                              'Не удалось открыть камеру. Вернитесь и попробуйте ещё раз.',
                              style: TextStyle(color: Colors.white)));
                    }
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return Stack(alignment: Alignment.center, children: [
                      if (_controller != null)
                        CameraPreview(_controller!)
                      else
                        const Icon(Icons.camera_alt,
                            color: Colors.white, size: 80),
                      if (_busy)
                        const ColoredBox(
                            color: Colors.black54,
                            child: Center(child: CircularProgressIndicator())),
                    ]);
                  })),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 35),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.check,
                            color: Colors.green, size: 40),
                        onPressed: _busy || _pages.isEmpty ? null : _confirm),
                    IconButton(
                        icon: const Icon(Icons.circle,
                            color: Colors.white, size: 55),
                        onPressed: _busy ? null : _capture),
                    SizedBox(
                        width: 60,
                        height: 60,
                        child: _pages.isEmpty
                            ? const SizedBox.shrink()
                            : GestureDetector(
                                onTap: _busy
                                    ? null
                                    : () async {
                                        await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => GalleryScreen(
                                                    images: _pages,
                                                    onDelete: (file) =>
                                                        queue.discardPage(
                                                            supplierId,
                                                            file))));
                                        if (mounted) setState(() {});
                                      },
                                child: Image.file(_pages.last,
                                    fit: BoxFit.cover))),
                  ])),
        ])),
      ));
}
