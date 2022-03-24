import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gnsklad/main.dart';
import 'package:http/http.dart' as http;

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

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    super.dispose();
  }
bool animphoto=false;
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
                          _controller,child: AnimatedContainer(
                        //  width: animphoto ? 200.0 : 100.0,
                       //   height: animphoto ? 100.0 : 200.0,
                          color: animphoto ? Colors.white70 : Colors.transparent,
                      //    alignment:
                      //    animphoto ? Alignment.center : AlignmentDirectional.topCenter,
                          duration: const Duration(seconds: 1),
                          curve: Curves.fastOutSlowIn,

                          child: animphoto?Center(child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [Icon(Icons.cloud_upload,size: 75, color: Colors.black),Text("Отправка на сервер",style: TextStyle(fontSize: 18),)],),):Container(),
                        ) ,
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
                  onPressed: () {
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
                  icon: Icon(Icons.switch_camera_rounded, color: Colors.white),
                ),
                GestureDetector(
                  onTap: () async {
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
                    //    if (capturedImages.isEmpty) return;
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => GalleryScreen(widget.name)));
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
