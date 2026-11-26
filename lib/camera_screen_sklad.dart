import 'dart:io';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'warehouse_photos.dart';
import 'defect_photos.dart';

import 'gallery_screen.dart';

class camera_screen_sklad extends StatefulWidget {
  final List<CameraDescription> cameras;
  String name;
  int politon = 0;
  bool brak = false;
  String iddetal = "";

  camera_screen_sklad(
      {Key? key,
      required this.name,
      required this.cameras,
      this.politon = 0,
      this.brak = false,
      this.iddetal = ""})
      : super(key: key);

  @override
  _camera_screen_skladState createState() => _camera_screen_skladState();
}

class _camera_screen_skladState extends State<camera_screen_sklad> {
  @override
  void initState() {
    initializeCamera(selectedCamera); //Initially selectedCamera = 0

    super.initState();
  }

  WarehouseQueue get queue =>
      widget.brak ? DefectPhotos.queue : WarehouseQueue.instance;

  late CameraController _controller; //To control the camera
  late Future<void>
      _initializeControllerFuture; //Future to wait until camera initializes
  int selectedCamera = 0;
  List<File> capturedImages = [];

  initializeCamera(int cameraIndex) async {
    _controller = CameraController(
      // Get a specific camera from the list of available cameras.
      widget.cameras[cameraIndex],
      // Define the resolution to use.
      ResolutionPreset.max,
    );

    // Next, initialize the controller. This returns a Future.
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    super.dispose();
  }

  bool animphoto = false;

  final List<PhotoJob> staged = [];
  Future<void> remember(File f, {int? capturedAt}) async {
    final job = await queue.stage(widget.name, widget.politon, f,
        capturedAt: capturedAt, detail: widget.brak ? widget.iddetal : null);
    staged.add(job);
    capturedImages.add(job.draft);
  }

  void cameraError() {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Не удалось сохранить снимок. Проверьте свободное место на устройстве.')));
  }

  Future<void> pickImages() async {
    if (animphoto) return;
    setState(() => animphoto = true);
    try {
      final result = await FilePicker.platform.pickFiles(
          type: widget.brak ? FileType.image : FileType.custom,
          allowedExtensions:
              widget.brak ? null : ['jpg', 'jpeg', 'png', 'webp'],
          allowMultiple: true);
      for (final path in result?.paths ?? <String?>[]) {
        if (path != null) await remember(File(path));
      }
    } catch (_) {
      cameraError();
    } finally {
      if (mounted) setState(() => animphoto = false);
    }
  }

  Future<void> delaydoto() async {
    {
      // return;

      if (animphoto) return;
      setState(() {
        animphoto = true;
      });

      try {
        await _initializeControllerFuture;
        final capturedAt = DateTime.now().millisecondsSinceEpoch;
        final picture = await _controller.takePicture();
        await remember(File(picture.path), capturedAt: capturedAt);
        if (!widget.brak) {
          try {
            await File(picture.path).delete();
          } on FileSystemException {/* OS cache cleanup */}
        }
      } catch (_) {
        cameraError();
      } finally {
        if (mounted) setState(() => animphoto = false);
      }
    }
  }

  Future<bool?> _showBackDialog() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Уйти?'),
          content: const Text(
            'Имеются несохранённые данные',
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('Остаться'),
              onPressed: () {
                Navigator.pop(context, false);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: Text('Сохранить и закрыть'),
              onPressed: () {
                Navigator.pop(context, true);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) {
            return;
          }
          if (animphoto) return;
          bool shouldPop = true;
          if (!capturedImages.isEmpty) {
            shouldPop = await _showBackDialog() ?? false;
          }
          if (shouldPop) await queue.confirm(staged);
          if (context.mounted && shouldPop) {
            Navigator.pop(context);
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Column(
            children: [
              Expanded(
                  child: FutureBuilder<void>(
                future: _initializeControllerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    // If the Future is complete, display the preview.
                    return SizedBox(
                        width: MediaQuery.of(context).size.width,
                        child: FittedBox(
                          fit: BoxFit.fitWidth,
                          child: SizedBox(
                            height: MediaQuery.of(context).size.width *
                                _controller.value.aspectRatio,
                            width: MediaQuery.of(context).size.width,
                            child: CameraPreview(
                              _controller,
                              child: AnimatedContainer(
                                //  width: animphoto ? 200.0 : 100.0,
                                //   height: animphoto ? 100.0 : 200.0,
                                color: animphoto
                                    ? Colors.white70
                                    : Colors.transparent,
                                //    alignment:
                                //    animphoto ? Alignment.center : AlignmentDirectional.topCenter,
                                duration: const Duration(seconds: 1),
                                curve: Curves.fastOutSlowIn,

                                child: animphoto
                                    ? const Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.cloud_upload,
                                                size: 75, color: Colors.black),
                                            Text(
                                              "Отправка на сервер",
                                              style: TextStyle(fontSize: 18),
                                            )
                                          ],
                                        ),
                                      )
                                    : Container(),
                              ),
                            ),
                          )
                          // new CameraPreview(_controller),

                          ,
                        ));
                  } else {
                    // Otherwise, display a loading indicator.
                    return const Center(child: CircularProgressIndicator());
                  }
                },
              )),

              //  ),

              Container(
                color: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 35),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () async {
                        if (capturedImages.isEmpty) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text("Ничего не сфотографировано"),
                          ));

                          return;
                        }

                        if (animphoto) return;
                        setState(() {
                          animphoto = true;
                        });

                        try {
                          await queue.confirm(staged);
                          if (context.mounted) Navigator.pop(context);
                        } catch (_) {
                          cameraError();
                          if (mounted) setState(() => animphoto = false);
                        }
                      },
                      icon: const Icon(
                        Icons.check_circle_sharp,
                        color: Colors.green,
                        size: 50,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 0),
                    ),
                    GestureDetector(
                      onTap: () async {
                        await delaydoto();
                      },
                      child: Container(
                        height: 60,
                        width: 60,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        if (capturedImages.isEmpty || animphoto) return;
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => GalleryScreen(
                                    images: capturedImages,
                                    onDelete: (file) async {
                                      final job = staged.singleWhere(
                                          (j) => j.draft.path == file.path);
                                      await queue.discardDraft(job);
                                      staged.remove(job);
                                    })));
                        if (mounted) setState(() {});
                      },
                      child: Container(
                        height: 60,
                        width: 60,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white),
                          color: Colors.black,
                          image: capturedImages.isNotEmpty
                              ? DecorationImage(
                                  image: FileImage(capturedImages.last),
                                  fit: BoxFit.cover)
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 130), // поднимаем на 200 px
            child: FloatingActionButton(
              onPressed: pickImages,
              child: const Icon(Icons.photo_library),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        ));
  }
}
