import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:gnsklad/tehhclass.dart';
import 'package:vibration/vibration.dart';
import 'package:vibration/vibration_presets.dart';

import 'package:volume_controller/volume_controller.dart';

// Scanner payloads are never logged. Both native scanner transports share this parser.
int? taraBarcode(String value) {
  final text = value.trim();
  if (!RegExp(r'^\d{1,10}$').hasMatch(text)) return null;
  final code = int.tryParse(text);
  if (code == null) return null;
  return (code > 1500000000 && code < 1600000000) ||
          (code > 12000000 && code < 99000000)
      ? code
      : null;
}

// Existing name is used by navigation.
// ignore: camel_case_types
class tars extends StatefulWidget {
  final bool active;
  final int userId;
  final Stream<String>? scans;
  final Future<Map<int, String>> Function()? loadCatalog;
  const tars(
      {super.key,
      this.active = true,
      this.userId = 0,
      this.scans,
      this.loadCatalog});
  @override
  State<tars> createState() => _TarsState();
}

class _TarsState extends State<tars>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  String countasdasd = '', zakazid = '', nakleyka = '';
  late Animation<Color?> animation;
  late AnimationController _controller;
  Map<int, String> spiss = {};
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _retry;
  bool _ready = false, _loading = false, _resumed = true, _processing = false;
  int _request = 0, statuss = 0;
  String? _catalogMessage;
  bool get _active =>
      mounted &&
      widget.active &&
      _resumed &&
      ModalRoute.of(context)?.isCurrent != false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 6));
    animation = ColorTween(begin: Colors.greenAccent, end: Colors.white)
        .animate(_controller)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    // Subscribe synchronously, before any HTTP request. IndexedStack keeps this
    // state alive while hidden, so navigation/lifecycle must explicitly gate it.
    if (widget.scans != null) {
      _subscriptions.add(widget.scans!.listen(_onScan));
    } else {
      _subscriptions.add(tehhclass.receiver.messages.listen((event) {
        final data = event.data;
        final value =
            data?['SCAN_BARCODE1'] ?? data?['scandata'] ?? data?['value'];
        if (value is String || value is int) _onScan(value.toString());
      }));
      _subscriptions.add(
          tehhclass.dw.onScanResult.listen((event) => _onScan(event.data)));
      _subscriptions.add(tehhclass.dw.onScannerStatus.listen((event) {
        if (!_active || !_ready || _processing) return;
        setState(() {
          if (event.status.index == 1) {
            statuss = 1;
          } else if (event.status.index == 0 && statuss == 1) {
            statuss = countasdasd.isEmpty ? 0 : 3;
          }
        });
      }));
    }
    _retry = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_active && !_ready) _load();
    });
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(covariant tars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userId != oldWidget.userId) {
      ++_request;
      _loading = false;
      _ready = false;
      spiss = {};
      countasdasd = '';
      zakazid = '';
      nakleyka = '';
      statuss = 0;
    }
    if (widget.active && !_ready) _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed && widget.active && !_ready) _load();
  }

  Future<Map<int, String>> _fetchCatalog() async {
    final client = http.Client();
    late http.Response response;
    try {
      response = await client
          .get(Uri.http('172.16.4.104:3000', '/getalltars',
              {'nik': tehhclass.user_nik, 'pass': tehhclass.user_pass}))
          .timeout(const Duration(seconds: 15));
    } finally {
      client.close();
    }
    if (response.statusCode != 200) {
      throw const FormatException('Catalog unavailable');
    }
    final rows = jsonDecode(response.body);
    if (rows is! List) throw const FormatException('Invalid catalog');
    final result = <int, String>{};
    for (final row in rows) {
      if (row is! Map || row['ID'] is! int || row['NAME'] is! String) {
        throw const FormatException('Invalid catalog row');
      }
      result[row['ID'] as int] = row['NAME'] as String;
    }
    return result;
  }

  Future<void> _load() async {
    if (_loading || !mounted) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _catalogMessage = null;
    });
    try {
      final catalog = await (widget.loadCatalog ?? _fetchCatalog)();
      if (!mounted || request != _request) return;
      setState(() {
        spiss = catalog;
        _ready = true;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() => _catalogMessage =
          'Не удалось загрузить тары. Проверьте связь с фабрикой — приложение повторит попытку автоматически.');
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _onScan(String value) async {
    if (!_active || _processing) return;
    final code = taraBarcode(value);
    if (code == null) return;
    if (!_ready) {
      _load();
      return;
    }
    _processing = true;
    try {
      if (statuss == 1) setState(() => statuss = 2);
      await findtara(code);
    } catch (_) {
      if (mounted) {
        setState(() => statuss = countasdasd.isEmpty ? 0 : 3);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Результат операции не подтверждён. Проверьте его перед повторным сканированием.')));
      }
    } finally {
      _processing = false;
    }
  }

  bool flag_vibral_det_v_taru = false;
  Future<void> findtara(int sh_curr) async {
    // int sh_curr = 1530000101;
    // int sh_curr = 12519856;
    if ((sh_curr > 1500000000) && (sh_curr < 1600000000)) {
      //если тара
      setState(() {
        countasdasd = '';
        zakazid = '';
        nakleyka = '';
      });
      res_DetalKode = sh_curr - 1500000000;
      if (spiss[res_DetalKode] == null) {
        countasdasd = "нет тары";
      } else {
        countasdasd = "${spiss[res_DetalKode]}";
      }
      statuss = 3;
      flag_vibral_det_v_taru = false;
      setState(() {});
    } else if ((sh_curr > 12000000) && (sh_curr < 99000000)) {
      // если деталь
      if (flag_vibral_det_v_taru) {
        statuss = 3;

        setState(() {});
        //   playErrorSound();
        _controller.reset();
        _controller.forward();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Сначала снова отсканируй тару',
              style: TextStyle(color: Colors.white), // белый текст
            ),
            backgroundColor: Colors.red, // красный фон
            behavior: SnackBarBehavior
                .floating, // можно добавить чтобы "висел" над контентом
            duration: Duration(seconds: 2),
          ),
        );

        return;
      }
      if (countasdasd == '' || countasdasd == "нет тары") return;
      setState(() {
        zakazid = '';
        nakleyka = '';
      });

      int idmagazupak = sh_curr - 12000000;
      var response = await http.get(Uri.parse(
          'http://172.16.4.104:3000/setmtara?id=${idmagazupak}&mtaraid=${res_DetalKode}&nik=${tehhclass.user_nik}&pass=${tehhclass.user_pass}'));
      if (!mounted) return;
      var otvet = json.decode(response.body);
      zakazid = otvet[0]['MAGAZINE_ID'].toString();
      nakleyka = otvet[0]['CONCATENATION'].toString();
      _controller.reset();
      _controller.forward();
      statuss = 3;
      flag_vibral_det_v_taru = true;
      setState(() {});
    }
  }

  AudioPlayer? _audioPlayer;

  Future<void> playErrorSound() async {
    try {
      VolumeController.instance.showSystemUI = false;
      //    double volume = await VolumeController.instance.getVolume();
      await VolumeController.instance.setVolume(1);

      Vibration.vibrate(preset: VibrationPreset.doubleBuzz);

      await (_audioPlayer ??= AudioPlayer())
          .play(AssetSource('sounds/error-126627.mp3'));

      //   await VolumeController.instance.setVolume(volume);
    } catch (e) {
      print('Ошибка воспроизведения звука: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retry?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _audioPlayer?.dispose();
    _controller.dispose();

    super.dispose();
  }

  int res_DetalKode = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Тары"),
        ),
        body: Center(
            child: !_ready
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_catalogMessage ?? 'Загрузка справочника тар…'))
                : statuss == 0
                    ? Text("Отсканируй штрихкод тары")
                    : statuss != 3
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              Text("Сканирую...")
                            ],
                          )
                        : AnimatedContainer(
                            color: zakazid == ''
                                ? Colors.transparent
                                : animation.value,
                            width: double.infinity,
                            duration: Duration(milliseconds: 4),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    countasdasd,
                                    style: TextStyle(fontSize: 68),
                                  ),
                                  countasdasd == '' || zakazid == ""
                                      ? Container()
                                      : Column(
                                          children: [
                                            SizedBox(
                                              height: 10,
                                            ),
                                            Text(
                                              "Заказ",
                                              style: TextStyle(fontSize: 24),
                                            ),
                                            Text(
                                              "${zakazid}",
                                              style: TextStyle(fontSize: 36),
                                            ),
                                            Text(
                                              "${nakleyka}",
                                              style: TextStyle(
                                                  fontSize: 106,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        )
                                ]))));
  }
}
