import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gnsklad/main.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'gallery_screen.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  postav name;

  CameraScreen({
    required this.name,
    required this.cameras,
  });

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  @override
  void initState() {
    initializeCamera(selectedCamera); //Initially selectedCamera = 0
    super.initState();
    fistasdib();
  }

  fistasdib() async {
    //очиститм локальные файлы старые
    final cacheDir = await getTemporaryDirectory();
    var asdasdasd = await dirContents(cacheDir);
    for (var asd in asdasdasd) {
      await File(asd.path).delete();
      print(asd.path);
    }
  }

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

  Future<List<FileSystemEntity>> dirContents(Directory dir) {
    var files = <FileSystemEntity>[];
    var completer = Completer<List<FileSystemEntity>>();
    var lister = dir.list(recursive: false);
    lister.listen((file) => files.add(file),
        // should also register onError
        onDone: () => completer.complete(files));
    return completer.future;
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    super.dispose();
  }

  bool animphoto = false;

  double _kPickerSheetHeight = 350.0;

  Widget _buildBottomPicker(Widget picker) {
    return Container(
      height: _kPickerSheetHeight,
      padding: const EdgeInsets.only(top: 6.0),
      color: CupertinoColors.white,
      child: DefaultTextStyle(
        style: const TextStyle(
          color: CupertinoColors.black,
          fontSize: 22.0,
        ),
        child: GestureDetector(
          // Blocks taps from propagating to the modal sheet and popping.
          onTap: () {},
          child: SafeArea(
            top: false,
            child: picker,
          ),
        ),
      ),
    );
  }

  DateTime dateTime = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
              child: FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                // If the Future is complete, display the preview.
                return Container(
                    width: MediaQuery.of(context).size.width,
                    child: FittedBox(
                      fit: BoxFit.fitWidth,
                      child: Container(
                        height: MediaQuery.of(context).size.width *
                            _controller.value.aspectRatio,
                        width: MediaQuery.of(context).size.width,
                        child: CameraPreview(
                          _controller,
                          child: AnimatedContainer(
                            //  width: animphoto ? 200.0 : 100.0,
                            //   height: animphoto ? 100.0 : 200.0,
                            color:
                                animphoto ? Colors.white70 : Colors.transparent,
                            //    alignment:
                            //    animphoto ? Alignment.center : AlignmentDirectional.topCenter,
                            duration: const Duration(seconds: 1),
                            curve: Curves.fastOutSlowIn,

                            child: animphoto
                                ? Center(
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 35),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () async {


                    if (capturedImages.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("Ничего не сфотографировано"),
                      ));

                      return;
                    }


                    showCupertinoModalPopup<void>(
                      context: context,
                      builder: (BuildContext context) {
                        return _buildBottomPicker(
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                  child: CupertinoDatePicker(
                                mode: CupertinoDatePickerMode.date,
                                initialDateTime: dateTime,
                                onDateTimeChanged: (DateTime newDateTime) {
                                  if (mounted) {
                                    print(
                                        "Your Selected Date: ${newDateTime.day}");
                                    setState(() => dateTime = newDateTime);
                                  }
                                },
                              )),
                              Row(

                                children: [

                                  Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: Container(
                                     // width: double.,
                                      child: ElevatedButton(
                                        onPressed: () async {



                                          Navigator.of(context).pop();




                                          if (animphoto) return;
                                          setState(() {
                                            animphoto = true;
                                          });

                                          final pdf = pw.Document();

                                          for (var elem in capturedImages) {
                                            final image = pw.MemoryImage(
                                              File(elem.path).readAsBytesSync(),
                                            );

                                            pdf.addPage(pw.Page(build: (pw.Context context) {
                                              return pw.Center(
                                                child: pw.Image(image),
                                              ); // Center
                                            })); // Page
                                          }
                                          var pathsave =
                                          (await getTemporaryDirectory()).path + "/example.pdf";
                                          final file = File(pathsave);
                                          await file.writeAsBytes(await pdf.save());

                                          var postUri =
                                          Uri.parse("https://teplogico.ru/gn0/${widget.name.id}/${dateTime.millisecondsSinceEpoch/1000}");

                                          http.MultipartRequest request =
                                          new http.MultipartRequest("POST", postUri);

                                          http.MultipartFile multipartFile =
                                          await http.MultipartFile.fromPath(
                                          'file_input', pathsave);

                                          request.files.add(multipartFile);

                                          http.StreamedResponse response = await request.send();
                                          print(response.statusCode);

                                          capturedImages.clear();

                                          await Future.delayed(Duration(milliseconds: 500));

                                          setState(() {
                                          animphoto = false;
                                          });

                                          //         capturedImages

                                        },
                                        style: ElevatedButton.styleFrom(
                                         // primary: Colors.pinkAccent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(25),
                                          ),
                                       //   elevation: 15.0,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Text(
                                            'ОТПРАВИТЬ',
                                            style: TextStyle(fontSize: 15),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.end,
                              )
                            ],
                          ),
                        );
                      },
                    );



                    return;
                    if (widget.cameras.length > 1) {
                      setState(() {
                        selectedCamera = selectedCamera == 0 ? 1 : 0;
                        initializeCamera(selectedCamera);
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('No secondary camera found'),
                        duration: const Duration(seconds: 2),
                      ));
                    }
                  },
                  icon: Icon(
                    Icons.check_circle_sharp,
                    color: Colors.green,
                    size: 50,
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                ),
                GestureDetector(
                  onTap: () async {
                    if (animphoto) return;
                    setState(() {
                      animphoto = true;
                    });

                    await _initializeControllerFuture;
                    var xFile = await _controller.takePicture();
                    setState(() {
                      capturedImages.add(File(xFile.path));
                    });

                    await Future.delayed(Duration(milliseconds: 500));

                    print("sfotal2");

                    setState(() {
                      animphoto = false;
                    });

/*
                    if(animphoto)return;
                    setState(() {
                      animphoto=true;
                    });
                    await _initializeControllerFuture;
                    var xFile = await _controller.takePicture();
                    setState(() {
                      capturedImages.add(File(xFile.path));
                    });
                    print("sfotal");

                    await Future.delayed(Duration(milliseconds: 500));

                    print("sfotal2");


                    setState(() {
                      animphoto=false;
                    });
                 //   return;
                    var postUri = Uri.parse("https://teplogico.ru/gn0/${widget.name.id}");

                    http.MultipartRequest request =
                        new http.MultipartRequest("POST", postUri);

                    http.MultipartFile multipartFile =
                        await http.MultipartFile.fromPath(
                            'file_input', xFile.path);

                    request.files.add(multipartFile);

                    http.StreamedResponse response = await request.send();

                    print(response.statusCode);
                    print(await File(xFile.path).exists());
                    await File(xFile.path).delete();
                    print(await File(xFile.path).exists());
                    */
                  },
                  child: Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (capturedImages.isEmpty) return;
                    print(capturedImages[0]);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => GalleryScreen(
                                images: capturedImages)));
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
    );
  }
}
