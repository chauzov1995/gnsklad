# gnsklad

Складское приложение Flutter для Android, включая терминал 70 Series (Android 10).

## Сборка и запуск

Настройки проекта рассчитаны на Flutter 3.47.5, JDK 21, Gradle 8.14.3,
Android Gradle Plugin 8.11.1 и Kotlin 2.2.20. Нужны Android SDK 36
и NDK 28.0.12433566. Минимальная версия Android — 7.0 (API 24).

Укажите установленную JDK 21 вместо Java 25, поставляемой с Android Studio:

```powershell
flutter config --jdk-dir "C:\path\to\jdk-21"
flutter pub get
flutter build apk --debug --target-platform android-arm64
flutter devices
flutter run -d 2706086
```

Параметр `--jdk-dir` сохраняется в настройках Flutter текущего пользователя.
После его изменения перезапустите Android Studio. Если проект Android открыт
отдельно, выберите ту же JDK в настройке Gradle JDK.

В `android/gradle/gradle-daemon-jvm.properties` закреплена Java 21 для Gradle.
Gradle найдёт установленную JDK, в том числе в `%USERPROFILE%\.jdks`, даже если
Android Studio запускает оболочку Gradle своей встроенной Java 25.

В `pubspec.yaml` есть локальная зависимость `flutter_broadcasts`.
Её каталог должен существовать; на другом компьютере нужно исправить путь.

## Особенности Windows

Инкрементальная компиляция Kotlin отключена, поскольку проект и Pub Cache
могут находиться на разных дисках. Иначе Kotlin падает с `different roots`
при сохранении кешей.

Для Gradle выделено до 4 ГБ памяти и ограничено число параллельных задач
до двух: прежнего лимита 1,5 ГБ не хватало для обработки библиотек Flutter.
Приведённая команда собирает APK для ARM64, используемой на 70 Series.

Если Java выдаёт `Unable to establish loopback connection` с причиной
`UnixDomainSockets.connect: Invalid argument`, проверьте отдельный каталог
для локальных сокетов. На рабочем компьютере проблема воспроизводилась
в Windows TEMP и исчезла после создания папки `.jdks\sockets` в профиле
пользователя и добавления строки в `conf\net.properties` выбранной JDK:

```properties
jdk.net.unixdomain.tmpdir=C:/Users/USER/.jdks/sockets
```

Подставьте существующий полный путь. При обновлении JDK настройку нужно
перенести в новую установку, если проблема с TEMP сохраняется.
