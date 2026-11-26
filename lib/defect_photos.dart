import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'warehouse_photos.dart';

class DefectPhotos {
  static late WarehouseQueue queue;
  static Future<void> start() async {
    queue = WarehouseQueue(
        Directory(
            '${(await getApplicationSupportDirectory()).path}/glass-defects-v1'),
        deliver: upload);
    await queue.startDelivery();
  }

  static Future<void> upload(PhotoJob job) async {
    final detail =
        jsonDecode(await job.source.readAsString())['detail'] as String;
    final expected = (await sha256.bind(job.file.openRead()).first).toString();
    final data = jsonDecode(utf8.decode(await PhotoApi.request(
        '/v1/defects/orders/${job.order}/${job.id}?detail=${Uri.encodeQueryComponent(detail)}&capturedAt=${job.created}',
        file: job.file)));
    if (data['saved'] != true ||
        data['upload'] != job.id ||
        data['order'] != job.order ||
        data['iddetal'] != detail ||
        data['sourceSha256'] != expected ||
        data['id'] is! int) {
      throw const PhotoProblem('Фабрика не подтвердила сохранение фото брака');
    }
  }

  static Future<List<dynamic>> list({String? order, String? detail}) async {
    final query = {
      if (detail != null) 'detail': detail,
      if (order != null) 'order': order
    };
    return jsonDecode(utf8.decode(await PhotoApi.request(
        Uri(path: '/v1/defects', queryParameters: query).toString()))) as List;
  }

  static Future<Uint8List> read(int id) =>
      PhotoApi.request('/v1/defects/files/$id');
  static Future<void> remove(int id) async {
    final row = jsonDecode(utf8.decode(
        await PhotoApi.request('/v1/defects/files/$id', method: 'DELETE')));
    if (row['deleted'] != true || row['id'] != id) {
      throw const PhotoProblem('Удаление не подтверждено');
    }
  }
}

class DefectImage extends StatefulWidget {
  const DefectImage(this.id, {super.key, this.fit = BoxFit.contain});
  final int id;
  final BoxFit fit;
  @override
  State<DefectImage> createState() => _DefectImageState();
}

class _DefectImageState extends State<DefectImage> {
  late Future<Uint8List> bytes = DefectPhotos.read(widget.id);
  @override
  void didUpdateWidget(DefectImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.id != oldWidget.id) bytes = DefectPhotos.read(widget.id);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
      future: bytes,
      builder: (_, s) {
        if (s.hasError) return const Icon(Icons.broken_image_outlined);
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return Image.memory(s.data!, fit: widget.fit);
      });
}
