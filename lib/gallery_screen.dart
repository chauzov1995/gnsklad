import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class GalleryScreen extends StatelessWidget {
  final List<File> images;
   GalleryScreen({Key? key, required this.images}) : super(key: key){


for(var asdasd in images){

  print(asdasd.path);
}
   }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Предпросмотр'),
      ),
      body: PhotoViewGallery.builder(

        itemCount: images.length,
       // customSize: Size(200,200),
        builder: (context, index) {
          return PhotoViewGalleryPageOptions.customChild(
child: Container(
  decoration: BoxDecoration(
    image: DecorationImage(
      image: FileImage(images[index]),
      fit: BoxFit.cover,
    ),
  ),
  child: Container(
    padding: EdgeInsets.all(20),
    alignment: Alignment.bottomCenter,
    child:  Text("${index+1}/${images.length}",style: TextStyle(fontSize: 40,color: Colors.white,shadows: [
    Shadow(
        color: Colors.black.withOpacity(0.3),
        offset: const Offset(5, 5),
        blurRadius: 15),
  ]),),) /* add child content here */,
) ,//Image.asset(  images[index].path,),
         //   imageProvider: AssetImage(images[index].path,),
            //initialScale: PhotoViewComputedScale.contained * 1,
            minScale: PhotoViewComputedScale.contained * 0.8,
            maxScale: PhotoViewComputedScale.covered * 2,
          );
        },
     //   scrollPhysics: BouncingScrollPhysics(),
        backgroundDecoration: BoxDecoration(

      //    borderRadius:BorderRadius.all(Radius.circular(20)),
          color: Colors.black,
        ),
        scrollDirection:Axis.vertical,
        enableRotation:false,
        loadingBuilder: (context, event) => Center(
          child: Container(
            width: 60.0,
            height: 60.0,
            child: CircularProgressIndicator(
              backgroundColor:Colors.blue,
              value: event == null
                  ? 0
                  : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
            ),
          ),
        ),
      ),
    );
  }
}