import 'package:flutter/material.dart';
import '../servicios/servicio_nube_velia.dart';
import '../tema/colores.dart';

class PantallaAccesibilidadNube extends StatefulWidget {
  const PantallaAccesibilidadNube({super.key, required this.adultoId});
  final String adultoId;
  @override
  State<PantallaAccesibilidadNube> createState() =>
      _PantallaAccesibilidadNubeState();
}

class _PantallaAccesibilidadNubeState extends State<PantallaAccesibilidadNube> {
  final _service = ServicioNubeVelia.instancia;
  double? _scale;
  bool? _contrast;
  @override
  void initState() {
    super.initState();
    _scale = _service.escalaTexto;
    _contrast = _service.altoContraste;
  }

  Future<void> _save() async {
    await _service.guardarAccesibilidad(widget.adultoId,
        escala: _scale, altoContraste: _contrast);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: const Text('Accesibilidad'),
          backgroundColor: colorNaranja,
          foregroundColor: Colors.white),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Ajusta cómo se ve la pantalla del adulto mayor.',
            style: TextStyle(fontSize: 18)),
        const SizedBox(height: 22),
        Text('Tamaño del texto: ${((_scale ?? 1.2) * 100).round()}%',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Slider(
            min: 1,
            max: 1.8,
            divisions: 8,
            value: (_scale ?? 1.2).clamp(1, 1.8).toDouble(),
            label: '${((_scale ?? 1.2) * 100).round()}%',
            onChanged: (v) => setState(() => _scale = v),
            onChangeEnd: (_) => _save()),
        const Card(
            child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                    'Vista previa: Hola, María. Estoy aquí para ayudarte.',
                    style: TextStyle(fontSize: 21)))),
        SwitchListTile(
            title: const Text('Alto contraste', style: TextStyle(fontSize: 18)),
            subtitle: const Text('Facilita distinguir texto y botones.'),
            value: _contrast ?? true,
            onChanged: (v) {
              setState(() => _contrast = v);
              _save();
            }),
        const ListTile(
            leading: Icon(Icons.record_voice_over, color: colorNaranja),
            title: Text('Lectura de controles'),
            subtitle: Text(
                'La app respeta TalkBack y las opciones de lectura del teléfono.')),
        const ListTile(
            leading: Icon(Icons.touch_app, color: colorNaranja),
            title: Text('Gestos sencillos'),
            subtitle: Text(
                'Un toque activa, dos toques leen y tres detienen la lectura cuando TalkBack está apagado.')),
      ]));
}
