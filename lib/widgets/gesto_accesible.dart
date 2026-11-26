import 'dart:async';
import 'package:flutter/material.dart';
import '../servicios/servicio_lectura_velia.dart';

/// Una pulsación ejecuta; dos leen; tres detienen el dictado.
class GestoAccesible extends StatefulWidget {
  const GestoAccesible({
    super.key,
    required this.texto,
    required this.child,
    this.onSingleTap,
  });
  final String texto;
  final Widget child;
  final VoidCallback? onSingleTap;

  @override
  State<GestoAccesible> createState() => _GestoAccesibleState();
}

class _GestoAccesibleState extends State<GestoAccesible> {
  Timer? _timer;
  int _taps = 0;

  @override
  void initState() {
    super.initState();
    ServicioLecturaVelia.instancia.preparar();
  }

  /// Ejecuta, lee o detiene la acción según la cantidad de toques.
  void _up(PointerEvent event) {
    _taps++;
    _timer?.cancel();
    if (_taps == 3) {
      _taps = 0;
      ServicioLecturaVelia.instancia.detener();
      return;
    }
    if (_taps == 2) {
      // Leer al segundo toque conserva el permiso de audio del navegador.
      ServicioLecturaVelia.instancia.leer(widget.texto);
      _timer = Timer(const Duration(milliseconds: 700), () => _taps = 0);
      return;
    }
    _timer = Timer(const Duration(milliseconds: 700), () {
      _taps = 0;
      widget.onSingleTap?.call();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        button: widget.onSingleTap != null,
        label: widget.texto,
        onTap: widget.onSingleTap,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerUp: _up,
          child: IgnorePointer(child: widget.child),
        ),
      );
}
