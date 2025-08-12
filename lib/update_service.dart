import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:open_filex/open_filex.dart';

class UpdateService {
  final String serverIp = "213.159.210.45"; // IP твоего локального сервера
  final String versionFile = "https://213.159.210.45/appsklad/version.php";
  final String apkFile = "https://213.159.210.45/appsklad/app-release.apk";

  Future<void> checkForUpdate(BuildContext context) async {
    try {
    print("Получаем текущую версию приложения");
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;
print(currentVersion);
      // Получаем последнюю версию с сервера
      final response = await http.get(Uri.parse(versionFile));
    print(response.statusCode);
      if (response.statusCode != 200) return;

      String latestVersion = response.body.trim();
    print(latestVersion);
      if (latestVersion != currentVersion) {
        _showUpdateDialog(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("У вас уже последняя версия")),
        );
      }
    } catch (e) {
      debugPrint("Ошибка проверки обновления: $e");
    }
  }

  void _showUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Доступно обновление"),
        content: const Text("Хотите скачать и установить новую версию?"),
        actions: [
          TextButton(
            child: const Text("Позже"),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: const Text("Обновить"),
            onPressed: () {
              Navigator.pop(ctx);
              downloadAndInstallApk(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> downloadAndInstallApk(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Скачивание обновления...")),
      );

      final dir = await getExternalStorageDirectory();
      final filePath = "${dir!.path}/update.apk";

      final response = await http.get(Uri.parse(apkFile));
      if (response.statusCode == 200) {
        File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Запуск установщика APK
        await OpenFilex.open(filePath);
      } else {
        throw Exception("Ошибка скачивания");
      }
    } catch (e) {
      debugPrint("Ошибка установки: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ошибка при обновлении")),
      );
    }
  }
}
