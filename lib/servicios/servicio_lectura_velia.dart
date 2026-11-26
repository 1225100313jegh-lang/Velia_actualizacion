import 'package:flutter_tts/flutter_tts.dart';

class ServicioLecturaVelia {
  ServicioLecturaVelia._();
  static final instancia = ServicioLecturaVelia._();
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _prepare() async {
    if (_ready) return;
    await _tts.setLanguage('es-MX');
    await _tts.setSpeechRate(0.43);
    await _tts.setPitch(1.0);
    _ready = true;
  }

  /// Lee en voz alta el texto recibido.
  Future<void> leer(String texto) async {
    await _prepare();
    await _tts.stop();
    await _tts.speak(texto);
  }

  /// Detiene la lectura que está en curso.
  Future<void> detener() => _tts.stop();
}
