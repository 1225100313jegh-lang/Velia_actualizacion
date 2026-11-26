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

  /// Ejecuta, lee o detiene la acción según la cantidad de toques.
  void _up(PointerEvent event) {
    _taps++;
    if (_taps == 3) {
      _timer?.cancel();
      _taps = 0;
      ServicioLecturaVelia.instancia.detener();
      return;
    }
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 420), () {
      final taps = _taps;
      _taps = 0;
      if (taps == 1) {
        widget.onSingleTap?.call();
      } else if (taps == 2) {
        ServicioLecturaVelia.instancia.leer(widget.texto);
      }
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
