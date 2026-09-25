package com.nchauzov.gn.gnsklad

import android.content.Intent
import android.content.pm.PackageInfo
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private var installPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gnsklad/updates")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "validateApk" -> {
                            val path = call.argument<String>("path") ?: error("Не указан файл APK")
                            val apk = packageManager.getPackageArchiveInfo(path, 0)
                                ?: error("Сервер вернул повреждённый APK или другой файл")
                            val installed = packageManager.getPackageInfo(packageName, 0)
                            check(apk.packageName == packageName) { "APK предназначен для другого приложения" }
                            check(versionCode(apk) > versionCode(installed)) { "В скачанном APK нет более новой сборки" }
                            check(apk.versionName == call.argument<String>("version")) {
                                "Версия APK не совпадает с записью на сервере. Попробуйте позже."
                            }
                            val expected = call.argument<Number>("build")?.toLong()
                            check(expected == null || versionCode(apk) == expected) {
                                "Номер сборки APK не совпадает с записью на сервере. Попробуйте позже."
                            }
                            result.success(true)
                        }
                        "requestInstallPermission" -> {
                            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()) {
                                result.success(true)
                            } else if (installPermissionResult != null) {
                                result.error("busy", "Запрос разрешения уже открыт", null)
                            } else {
                                installPermissionResult = result
                                try {
                                    startActivityForResult(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                        Uri.parse("package:$packageName")), 7102)
                                } catch (e: Exception) {
                                    installPermissionResult = null
                                    throw e
                                }
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("update_error", e.message, null)
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun versionCode(info: PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode else info.versionCode.toLong()

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 7102) {
            installPermissionResult?.success(Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                packageManager.canRequestPackageInstalls())
            installPermissionResult = null
        }
    }
}
