import 'package:flutter/material.dart';
import 'defect_photos.dart';

class DefectPhotoViewer extends StatefulWidget {
  const DefectPhotoViewer(this.id, {super.key});
  final int id;
  @override
  State<DefectPhotoViewer> createState() => _ViewerState();
}

class _ViewerState extends State<DefectPhotoViewer> {
  bool busy = false;
  Future<void> remove() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Удалить фото брака?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Отмена')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Удалить')),
              ],
            ));
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await DefectPhotos.remove(widget.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Фото брака'), actions: [
          IconButton(
              onPressed: busy ? null : remove,
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete)),
        ]),
        body: Center(child: InteractiveViewer(child: DefectImage(widget.id))),
      );
}
