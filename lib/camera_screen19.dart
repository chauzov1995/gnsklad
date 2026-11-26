import 'package:flutter/material.dart';
import 'camera_screen.dart';
import 'main.dart';

/// Keeps the system-camera fallback on the same durable PDF workflow.
class CameraScreen19 extends StatelessWidget {
  final postav name;
  const CameraScreen19({super.key, required this.name});
  @override
  Widget build(BuildContext context) =>
      CameraScreen(name: name, cameras: const [], useSystemCamera: true);
}
