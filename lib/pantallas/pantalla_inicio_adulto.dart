import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../modelos/modelos_velia.dart';
import '../servicios/servicio_nube_velia.dart';
import '../tema/colores.dart';
import '../widgets/gesto_accesible.dart';

class PantallaInicioAdulto extends StatefulWidget {
  const PantallaInicioAdulto({super.key, required this.adulto});
  final PerfilAdulto adulto;
  @override
  State<PantallaInicioAdulto> createState() => _PantallaInicioAdultoState();
}

class _PantallaInicioAdultoState extends State<PantallaInicioAdulto> {
  final _service = ServicioNubeVelia.instancia;
  late Stream<(List<HorarioBienestar>, List<ElementoRutina>, List<CitaVelia>)>
      _data;
  bool _sending = false;
  bool _holding = false;
  bool _emergencyTriggered = false;
  int _streak = 0;
  Timer? _emergencyTimer;
  Timer? _clockTimer;
  @override
  void dispose() {
    _emergencyTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    _service.consultarRacha(widget.adulto.id).then((v) {
      if (mounted) setState(() => _streak = v);
    });
  }

  void _load() {
    _data = _service.escucharDatosAdulto(widget.adulto.id);
  }

  String _clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  /// Arma una frase breve con la acción, el horario y el periodo.
  String _descripcionRutina(ElementoRutina item) {
    final esMedicamento = item.tipo == TipoRutina.medicamento;
    final partes = <String>[
      esMedicamento ? 'Medicamento: ${item.nombre}.' : 'Actividad: ${item.nombre}.',
    ];
    if (esMedicamento && item.dosis.trim().isNotEmpty) {
      partes.add('Toma ${item.dosis}.');
    }
    if (item.modo == ModoHorario.intervalo) {
      partes.add(
        'Cada ${item.intervaloHoras ?? 8} horas, empezando a las ${_horaHablada(item.horaInicio ?? '08:00')}.',
      );
    } else if (item.horas.isNotEmpty) {
      partes.add(
        'A las ${item.horas.map(_horaHablada).join(' y a las ')}.',
      );
    } else {
      partes.add('Horario pendiente.');
    }
    partes.add('${_diasHablados(item.dias)}.');
    partes.add(_periodoHablado(item));
    return partes.join(' ');
  }

  String _horaHablada(String valor) {
    final partes = valor.split(':');
    if (partes.length != 2) return valor;
    final hora = int.tryParse(partes[0]);
    final minuto = int.tryParse(partes[1]);
    if (hora == null || minuto == null) return valor;
    final hora12 = hora % 12 == 0 ? 12 : hora % 12;
    final periodo = hora == 0 || hora >= 19
        ? 'de la noche'
        : hora < 6
            ? 'de la madrugada'
            : hora < 12
                ? 'de la mañana'
                : 'de la tarde';
    return minuto == 0
        ? '$hora12 $periodo'
        : '$hora12 con ${minuto.toString().padLeft(2, '0')} $periodo';
  }

  String _diasHablados(List<int> dias) {
    const nombres = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo',
    ];
    if (dias.length == 7) return 'Todos los días';
    final seleccionados = dias
        .where((dia) => dia >= 1 && dia <= 7)
        .map((dia) => nombres[dia - 1])
        .toList();
    if (seleccionados.isEmpty) return 'En los días programados';
    return 'Los ${seleccionados.join(', ')}';
  }

  String _periodoHablado(ElementoRutina item) {
    if (item.periodoIndeterminado) return 'Por tiempo indeterminado.';
    final inicio = item.fechaInicio;
    final fin = item.fechaFin;
    if (inicio == null && fin == null) {
      return 'Sin fecha de término definida.';
    }
    if (inicio == null) return 'Hasta el ${_fechaHablada(fin!)}.';
    if (fin == null) return 'Desde el ${_fechaHablada(inicio)}.';
    final dias = fin.difference(inicio).inDays.abs() + 1;
    final duracion = dias % 7 == 0
        ? '${dias ~/ 7} ${dias ~/ 7 == 1 ? 'semana' : 'semanas'}'
        : '$dias ${dias == 1 ? 'día' : 'días'}';
    return 'Por $duracion, del ${_fechaHablada(inicio)} al ${_fechaHablada(fin)}.';
  }

  String _fechaHablada(DateTime fecha) =>
      '${fecha.day} de ${_mesHablado(fecha.month)} de ${fecha.year}';

  String _mesHablado(int mes) => const [
        'enero',
        'febrero',
        'marzo',
        'abril',
        'mayo',
        'junio',
        'julio',
        'agosto',
        'septiembre',
        'octubre',
        'noviembre',
        'diciembre',
      ][mes - 1];

  bool _active(HorarioBienestar h) {
    final now = DateTime.now();
    if (!h.activo || !h.dias.contains(now.weekday)) return false;
    final current = now.hour * 60 + now.minute;
    int minutes(String s) {
      final p = s.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }

    final start = minutes(h.inicioActivo), end = minutes(h.finActivo);
    return start <= end
        ? current >= start && current <= end
        : current >= start || current <= end;
  }

  String _nextActive(List<HorarioBienestar> schedules) {
    final sorted = schedules.where((s) => s.activo).toList()
      ..sort((a, b) => a.inicioActivo.compareTo(b.inicioActivo));
    final next = sorted.firstWhere((s) => _active(s),
        orElse: () => sorted.isEmpty
            ? const HorarioBienestar(
                id: '', horaEsperada: '', inicioActivo: '', finActivo: '')
            : sorted.first);
    return next.id.isEmpty
        ? 'Pídele a tu familiar que programe el horario.'
        : _active(next)
            ? 'Puedes avisar hasta las ${next.finActivo}.'
            : 'Se activa a las ${next.inicioActivo}.';
  }

  Future<void> _checkin(HorarioBienestar h) async {
    setState(() => _sending = true);
    try {
      final premio = await _service.registrarEstoyBien(widget.adulto.id, h.id);
      _streak = (premio['racha'] as int?) ?? _streak;
      final frase = await _service.obtenerFraseBonitaDelDia(widget.adulto.id);
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (_) => _DialogoPremio(
                nombre: widget.adulto.nombre,
                frase: frase,
                racha: (premio['racha'] as int?) ?? 0,
                mostrarRacha: premio['rachaAumento'] == true &&
                    (premio['racha'] as int? ?? 0) >= 3,
              ));
      if (mounted) setState(_load);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo guardar el aviso: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _emergency() async {
    _emergencyTriggered = true;
    await _service.registrarEventoEmergencia(widget.adulto.id);
    final principal = widget.adulto.contactos.where((c) => c.principal);
    final phone = principal.isNotEmpty
        ? principal.first.telefono
        : widget.adulto.contactos.isNotEmpty
            ? widget.adulto.contactos.first.telefono
            : null;
    if (phone == null || phone.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No hay contacto de emergencia configurado.')));
      return;
    }
    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        await const MethodChannel('velia/direct_call')
            .invokeMethod<void>('call', {'phone': phone});
      } else {
        final uri = Uri(scheme: 'tel', path: phone);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo iniciar la llamada: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<
          (List<HorarioBienestar>, List<ElementoRutina>, List<CitaVelia>)>(
      stream: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
              child: Text(
                  'No se pudo cargar tu información. Comprueba la conexión.'));
        final (schedules, routine, appointments) = snapshot.data!;
        final active = schedules.where(_active).toList();
        final upcoming = appointments
            .where((c) =>
                c.estado == EstadoCita.programada &&
                c.fecha.isAfter(DateTime.now()))
            .toList()
          ..sort((a, b) => a.fecha.compareTo(b.fecha));
        final today = DateTime.now();
        final todaysRoutine = routine
            .where((r) =>
                r.activo &&
                r.dias.contains(today.weekday) &&
                (r.periodoIndeterminado ||
                    r.fechaFin == null ||
                    !r.fechaFin!.isBefore(
                        DateTime(today.year, today.month, today.day))))
            .toList();
        return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 92),
            children: [
              Card(
                  color: active.isEmpty
                      ? Colors.grey.shade200
                      : Colors.green.shade100,
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        active.isEmpty || _sending
                            ? Semantics(
                                button: true,
                                label:
                                    'Estoy bien. No está disponible ahora. ${_nextActive(schedules)}',
                                child: SizedBox(
                                    width: double.infinity,
                                    height: 114,
                                    child: FilledButton.icon(
                                      onPressed: null,
                                      style: FilledButton.styleFrom(
                                          backgroundColor: active.isEmpty
                                              ? Colors.grey.shade500
                                              : Colors.green.shade700,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(24))),
                                      icon: _sending
                                          ? const SizedBox(
                                              width: 28,
                                              height: 28,
                                              child: CircularProgressIndicator(
                                                  color: Colors.white))
                                          : TweenAnimationBuilder<double>(
                                              tween: Tween(
                                                  begin: 42,
                                                  end: (48 + _streak * 2)
                                                      .clamp(48, 74)
                                                      .toDouble()),
                                              duration: const Duration(
                                                  milliseconds: 800),
                                              curve: Curves.elasticOut,
                                              builder: (context, size, _) =>
                                                  Icon(Icons.wb_sunny_rounded,
                                                      size: size)),
                                      label: const Text('ESTOY BIEN',
                                          style: TextStyle(
                                              fontSize: 26,
                                              fontWeight: FontWeight.bold)),
                                    )))
                            : GestoAccesible(
                                texto:
                                    'Estoy bien. Toca para avisar a tu familia.',
                                onSingleTap: () => _checkin(active.first),
                                child: SizedBox(
                                    width: double.infinity,
                                    height: 114,
                                    child: FilledButton.icon(
                                      onPressed: () {},
                                      style: FilledButton.styleFrom(
                                          backgroundColor:
                                              Colors.green.shade700,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(24))),
                                      icon: TweenAnimationBuilder<double>(
                                          tween: Tween(
                                              begin: 42,
                                              end: (48 + _streak * 2)
                                                  .clamp(48, 74)
                                                  .toDouble()),
                                          duration:
                                              const Duration(milliseconds: 800),
                                          curve: Curves.elasticOut,
                                          builder: (context, size, _) => Icon(
                                              Icons.wb_sunny_rounded,
                                              size: size)),
                                      label: const Text('ESTOY BIEN',
                                          style: TextStyle(
                                              fontSize: 26,
                                              fontWeight: FontWeight.bold)),
                                    ))),
                        const SizedBox(height: 10),
                        Text(
                            active.isEmpty
                                ? _nextActive(schedules)
                                : 'Disponible hasta las ${active.first.finActivo}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 17)),
                      ]))),
              const SizedBox(height: 10),
              const Text('Tu rutina de hoy',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              if (todaysRoutine.isEmpty)
                const Card(
                    child: ListTile(
                        leading: Icon(Icons.checklist),
                        title: Text(
                            'No tienes actividades programadas para hoy.')))
              else
                ...todaysRoutine.map((r) => GestoAccesible(
                    texto: _descripcionRutina(r),
                    child: Card(
                        child: ListTile(
                            leading: Icon(
                                r.tipo == TipoRutina.medicamento
                                    ? Icons.medication
                                    : Icons.directions_walk,
                                color: colorNaranja,
                                size: 30),
                            title: Text(r.nombre,
                                style: const TextStyle(
                                    fontSize: 19, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                [
                                  if (r.dosis.isNotEmpty) r.dosis,
                                  if (r.modo == ModoHorario.horasFijas)
                                    r.horas.join(', ')
                                  else
                                    'Cada ${r.intervaloHoras} horas'
                                ].join(' · '),
                                style: const TextStyle(fontSize: 16)))))),
              const SizedBox(height: 14),
              const Text('Próximas citas',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              if (upcoming.isEmpty)
                const Card(
                    child: ListTile(
                        leading: Icon(Icons.event_available),
                        title: Text('No tienes citas próximas.')))
              else
                ...upcoming.take(5).map((c) => GestoAccesible(
                    texto:
                        'Próxima cita: ${c.asunto}. El ${_fechaHablada(c.fecha)} a las ${_horaHablada(_clock(c.fecha))}.',
                    child: Card(
                        child: ListTile(
                            leading: const Icon(Icons.calendar_month,
                                color: colorNaranja, size: 30),
                            title: Text(c.asunto,
                                style: const TextStyle(
                                    fontSize: 19, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                '${c.fecha.day}/${c.fecha.month}/${c.fecha.year} · ${_clock(c.fecha)}',
                                style: const TextStyle(fontSize: 17)))))),
              const SizedBox(height: 18),
              Semantics(
                  button: true,
                  label:
                      'Emergencia. Mantén presionado durante tres segundos para llamar al contacto principal.',
                  child: Listener(
                    onPointerDown: (_) {
                      _emergencyTriggered = false;
                      setState(() => _holding = true);
                      _emergencyTimer =
                          Timer(const Duration(seconds: 3), _emergency);
                    },
                    onPointerUp: (_) {
                      _emergencyTimer?.cancel();
                      setState(() => _holding = false);
                    },
                    onPointerCancel: (_) {
                      _emergencyTimer?.cancel();
                      setState(() => _holding = false);
                    },
                    child: SizedBox(
                        height: 70,
                        width: double.infinity,
                        child: FilledButton.icon(
                            onPressed: () {
                              if (!_emergencyTriggered) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Mantén presionado durante 3 segundos para activar la emergencia.')));
                              }
                            },
                            style: FilledButton.styleFrom(
                                backgroundColor: _holding
                                    ? Colors.red.shade900
                                    : Colors.red.shade700),
                            icon: const Icon(Icons.sos, size: 32),
                            label: Text(
                                _holding ? 'Mantén presionado…' : 'EMERGENCIA',
                                style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.bold)))),
                  )),
            ]);
      });
}

class _DialogoPremio extends StatefulWidget {
  const _DialogoPremio(
      {required this.nombre,
      required this.frase,
      required this.racha,
      required this.mostrarRacha});
  final String nombre;
  final String frase;
  final int racha;
  final bool mostrarRacha;
  @override
  State<_DialogoPremio> createState() => _DialogoPremioState();
}

class _DialogoPremioState extends State<_DialogoPremio>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();
  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        icon: ScaleTransition(
            scale:
                CurvedAnimation(parent: _animation, curve: Curves.elasticOut),
            child: Icon(Icons.wb_sunny_rounded,
                size: widget.mostrarRacha ? 74 : 58, color: Colors.orange)),
        title: Text(
            widget.mostrarRacha
                ? '¡${widget.racha} días seguidos!'
                : '¡Qué bueno saber de ti!',
            textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (widget.mostrarRacha)
            const Text('Tu solecito creció. ¡Sigue cuidándote!',
                textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Hola, ${widget.nombre}: ${widget.frase}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18)),
        ]),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Gracias'))
        ],
      );
}
