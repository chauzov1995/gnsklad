import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class GalleryScreen extends StatefulWidget {
  List<File> images;

  final bool readOnly;
  final Future<void> Function(File)? onDelete;
  GalleryScreen(
      {Key? key, required this.images, this.readOnly = false, this.onDelete})
      : super(key: key);

  @override
  _GalleryScreenState createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late PageController _pageController;
  bool deleting = false;

  Future<void> deleteCurrent() async {
    if (deleting || widget.images.isEmpty) return;
    final index =
        (_pageController.page ?? 0).round().clamp(0, widget.images.length - 1);
    final file = widget.images[index];
    if (widget.onDelete != null) {
      final yes = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Удалить снимок?'),
                content:
                    const Text('Этот снимок не будет отправлен на фабрику.'),
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
    }
    setState(() => deleting = true);
    try {
      await widget.onDelete?.call(file);
      widget.images.remove(file);
      if (!mounted) return;
      if (widget.images.isEmpty) {
        setState(() => deleting = false);
        Navigator.pop(context);
        return;
      }
      setState(() => deleting = false);
      _pageController.jumpToPage(index.clamp(0, widget.images.length - 1));
    } catch (_) {
      if (mounted) {
        setState(() => deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Не удалось удалить снимок. Он сохранён на устройстве.')));
      }
    }
  }

  @override
  void initState() {
    _pageController = PageController(initialPage: widget.images.length - 1);
    super.initState();
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: !deleting,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Предпросмотр'),
            actions: <Widget>[
              if (!widget.readOnly)
                IconButton(
                  icon: const Icon(
                    Icons.delete_forever,
                    //color: Colors.black,
                  ),
                  onPressed: deleting ? null : deleteCurrent,
                )
            ],
          ),
          body: PhotoViewGallery.builder(
            pageController: _pageController,

            itemCount: widget.images.length,
            // customSize: Size(200,200),
            builder: (context, index) {
              return PhotoViewGalleryPageOptions.customChild(
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: FileImage(widget.images[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    alignment: Alignment.bottomCenter,
                    child: Text(
                      "${index + 1}/${widget.images.length}",
                      style: TextStyle(
                          fontSize: 40,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                                color: Colors.black.withOpacity(0.3),
                                offset: const Offset(5, 5),
                                blurRadius: 15),
                          ]),
                    ),
                  ) /* add child content here */,
                ), //Image.asset(  images[index].path,),
                //   imageProvider: AssetImage(images[index].path,),
                //initialScale: PhotoViewComputedScale.contained * 1,
                minScale: PhotoViewComputedScale.contained * 0.8,
                maxScale: PhotoViewComputedScale.covered * 2,
              );
            },
            //   scrollPhysics: BouncingScrollPhysics(),
            backgroundDecoration: const BoxDecoration(
              //    borderRadius:BorderRadius.all(Radius.circular(20)),
              color: Colors.black,
            ),
            scrollDirection: Axis.vertical,
            enableRotation: false,
            loadingBuilder: (context, event) => Center(
              child: SizedBox(
                width: 60.0,
                height: 60.0,
                child: CircularProgressIndicator(
                  backgroundColor: Colors.blue,
                  value: event == null
                      ? 0
                      : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
                ),
              ),
            ),
          ),
        ));
  }
}
