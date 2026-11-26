import 'package:flutter/material.dart';
import '../modelos/modelos_velia.dart';
import '../servicios/servicio_nube_velia.dart';
import '../tema/colores.dart';
import 'pantalla_accesibilidad_nube.dart';
import 'pantalla_agregar_adulto.dart';

class PantallaPerfilNube extends StatefulWidget {
  const PantallaPerfilNube({super.key});
  @override
  State<PantallaPerfilNube> createState() => _PantallaPerfilNubeState();
}

class _PantallaPerfilNubeState extends State<PantallaPerfilNube> {
  final _service = ServicioNubeVelia.instancia;
  late Future<List<PerfilAdulto>> _adultos;
  @override
  void initState() {
    super.initState();
    _adultos = _service.listarAdultosDeCuenta(_service.cuenta!.uid);
  }

  void _reload() => setState(
      () => _adultos = _service.listarAdultosDeCuenta(_service.cuenta!.uid));

  /// Vincula una cuenta de Google con la cuenta familiar activa.
  Future<void> _vincularGoogle() async {
    try {
      await _service.vincularGoogleActual();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuenta de Google vinculada.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _pin(PerfilAdulto adulto, {bool renovar = false}) async {
    try {
      final pin = renovar
          ? await _service.restablecerPin(adulto.id)
          : await _service.consultarPin(adulto.id);
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text(renovar
                    ? 'Nuevo PIN de ${adulto.nombre}'
                    : 'PIN de ${adulto.nombre}'),
                content: SelectableText(pin,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 34,
                        letterSpacing: 7,
                        fontWeight: FontWeight.bold)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'))
                ],
              ));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _invitar(PerfilAdulto adulto) async {
    try {
      final code = await _service.crearInvitacion(adulto.id);
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Invitación familiar'),
                content: SelectableText(
                    'Comparte este código de un solo uso. Vence en 24 horas.\n\n$code',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Listo'))
                ],
              ));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final family = _service.cuenta!;
    final canManage = _service.esFamiliarPrincipal || _service.esAdmin;
    return Scaffold(
        appBar: AppBar(
            title: const Text('Perfil y configuración'),
            backgroundColor: colorNaranja,
            foregroundColor: Colors.white),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
              child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(family.nombre),
                  subtitle: Text(family.email),
                  trailing: Text(
                      canManage ? 'Familiar principal' : 'Solo consulta'))),
          if (family.rol == 'family')
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(_service.tieneGoogleVinculado
                    ? 'Google vinculado'
                    : 'Vincular con Google'),
                subtitle: Text(_service.tieneGoogleVinculado
                    ? 'Puedes usar Google para iniciar sesión.'
                    : 'Vincula Google para iniciar sesión con esa cuenta.'),
                trailing: _service.tieneGoogleVinculado
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.link),
                onTap: _service.tieneGoogleVinculado ? null : _vincularGoogle,
              ),
            ),
          const SizedBox(height: 8),
          const Text('Personas a tu cuidado',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          FutureBuilder<List<PerfilAdulto>>(
              future: _adultos,
              builder: (context, s) {
                if (s.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (s.hasError)
                  return Text('No se pudieron cargar los perfiles: ${s.error}');
                final adults = s.data ?? const <PerfilAdulto>[];
                return Column(children: [
                  ...adults.map((a) => Card(
                          child: ExpansionTile(
                              leading: const Icon(Icons.elderly,
                                  color: colorNaranja),
                              title: Text(a.nombre),
                              subtitle: Text(
                                  '${a.contactos.length} contactos · ${a.padecimientos.length} padecimientos'),
                              children: [
                            if (!canManage) ...[
                              ListTile(
                                  leading:
                                      const Icon(Icons.medical_information),
                                  title: Text(a.padecimientos.isEmpty
                                      ? 'Sin padecimientos registrados'
                                      : a.padecimientos.join(', '))),
                              ...a.contactos.map((c) => ListTile(
                                  leading: const Icon(Icons.contact_phone),
                                  title: Text(c.nombre),
                                  subtitle:
                                      Text('${c.parentesco} · ${c.telefono}'))),
                            ],
                            if (canManage) ...[
                              ListTile(
                                  leading: const Icon(Icons.edit),
                                  title: const Text('Editar perfil'),
                                  onTap: () async {
                                    await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                PantallaAgregarAdulto(
                                                    perfil: a)));
                                    if (mounted) _reload();
                                  }),
                              ListTile(
                                  leading: const Icon(Icons.key),
                                  title: const Text('Ver PIN'),
                                  onTap: () => _pin(a)),
                              ListTile(
                                  leading: const Icon(Icons.key_off),
                                  title: const Text('Renovar PIN'),
                                  onTap: () => _pin(a, renovar: true)),
                              ListTile(
                                  leading: const Icon(Icons.person_add_alt_1),
                                  title: const Text(
                                      'Invitar familiar de consulta'),
                                  onTap: () => _invitar(a)),
                              ListTile(
                                  leading: const Icon(Icons.accessibility_new),
                                  title: const Text('Accesibilidad del adulto'),
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              PantallaAccesibilidadNube(
                                                  adultoId: a.id)))),
                              _AvisosBienestar(adultoId: a.id),
                              _AccesosFamiliar(adultoId: a.id),
                            ],
                          ]))),
                  if (canManage)
                    Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const PantallaAgregarAdulto()));
                              if (mounted) _reload();
                            },
                            icon: const Icon(Icons.person_add),
                            label: const Text('Agregar adulto'))),
                ]);
              }),
        ]));
  }
}

class _AccesosFamiliar extends StatefulWidget {
  const _AccesosFamiliar({required this.adultoId});
  final String adultoId;
  @override
  State<_AccesosFamiliar> createState() => _AccesosFamiliarState();
}

class _AccesosFamiliarState extends State<_AccesosFamiliar> {
  final _service = ServicioNubeVelia.instancia;
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _future = _service.listarFamiliaresVinculados(widget.adultoId);
  }

  void _load() => setState(
      () => _future = _service.listarFamiliaresVinculados(widget.adultoId));
  Future<void> _remove(Map<String, dynamic> person) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Quitar acceso'),
                content: Text(
                    '¿Quitar el acceso de consulta a ${person['nombre'] ?? 'este familiar'}?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Quitar'))
                ]));
    if (ok == true) {
      await _service.desvincularFamiliar(
          widget.adultoId, person['uid'] as String);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, s) {
            if (s.connectionState == ConnectionState.waiting)
              return const ListTile(title: Text('Cargando familiares…'));
            if (s.hasError)
              return ListTile(
                  title: const Text('Accesos familiares'),
                  subtitle: Text('${s.error}'));
            final people = s.data ?? const <Map<String, dynamic>>[];
            return Column(children: [
              const ListTile(
                  leading: Icon(Icons.groups, color: colorNaranja),
                  title: Text('Familiares con acceso'),
                  subtitle: Text(
                      'Los familiares invitados pueden consultar la información.')),
              ...people.map((p) => ListTile(
                  title: Text((p['nombre'] as String?) ?? 'Familiar'),
                  subtitle: Text(p['role'] == 'owner'
                      ? 'Familiar principal'
                      : (p['email'] as String?) ?? 'Solo consulta'),
                  trailing: p['role'] == 'owner'
                      ? null
                      : IconButton(
                          tooltip: 'Quitar acceso',
                          icon: const Icon(Icons.person_remove_alt_1),
                          onPressed: () => _remove(p)))),
            ]);
          });
}

class _AvisosBienestar extends StatefulWidget {
  const _AvisosBienestar({required this.adultoId});
  final String adultoId;
  @override
  State<_AvisosBienestar> createState() => _AvisosBienestarState();
}

class _AvisosBienestarState extends State<_AvisosBienestar> {
  final _service = ServicioNubeVelia.instancia;
  late Future<List<HorarioBienestar>> _future;
  @override
  void initState() {
    super.initState();
    _future = _service.listarHorariosBienestar(widget.adultoId);
  }

  void _reload() => setState(
      () => _future = _service.listarHorariosBienestar(widget.adultoId));
  Future<String?> _time(String? value) async {
    final p = (value ?? '08:00').split(':');
    final result = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])));
    return result == null
        ? null
        : '${result.hour.toString().padLeft(2, '0')}:${result.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _edit([HorarioBienestar? old]) async {
    final now = TimeOfDay.now();
    final nowDate = DateTime.now();
    final suggestedEnd =
        DateTime(nowDate.year, nowDate.month, nowDate.day, now.hour, now.minute)
            .add(const Duration(minutes: 10));
    String format(TimeOfDay time) =>
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    String expected = old?.horaEsperada ?? format(now);
    String start = old?.inicioActivo ?? format(now);
    String end = old?.finActivo ??
        format(TimeOfDay(hour: suggestedEnd.hour, minute: suggestedEnd.minute));
    final result = await showDialog<HorarioBienestar>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDialog) => AlertDialog(
                  title: Text(old == null
                      ? 'Programar aviso Estoy bien'
                      : 'Editar periodo de aviso'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    ListTile(
                        title: const Text('Hora del aviso'),
                        trailing: Text(expected),
                        onTap: () async {
                          final t = await _time(expected);
                          if (t != null) setDialog(() => expected = t);
                        }),
                    ListTile(
                        title: const Text('Activar botón desde'),
                        trailing: Text(start),
                        onTap: () async {
                          final t = await _time(start);
                          if (t != null) setDialog(() => start = t);
                        }),
                    ListTile(
                        title: const Text('Dejar activo hasta'),
                        trailing: Text(end),
                        onTap: () async {
                          final t = await _time(end);
                          if (t != null) setDialog(() => end = t);
                        }),
                    const Text(
                        'Fuera de ese periodo el botón se verá gris. Los avisos de retraso se registran a los 5 y 10 minutos.',
                        textAlign: TextAlign.center),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: () => Navigator.pop(
                            ctx,
                            HorarioBienestar(
                                id: old?.id ??
                                    DateTime.now()
                                        .microsecondsSinceEpoch
                                        .toString(),
                                horaEsperada: expected,
                                inicioActivo: start,
                                finActivo: end,
                                dias:
                                    old?.dias ?? const [1, 2, 3, 4, 5, 6, 7])),
                        child: const Text('Guardar'))
                  ],
                )));
    if (result != null) {
      await _service.guardarHorarioBienestar(widget.adultoId, result);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<HorarioBienestar>>(
      future: _future,
      builder: (context, s) {
        if (s.connectionState == ConnectionState.waiting)
          return const ListTile(title: Text('Cargando horarios de aviso…'));
        final schedules = s.data ?? const <HorarioBienestar>[];
        return Column(children: [
          const ListTile(
              leading: Icon(Icons.notifications_active, color: colorNaranja),
              title: Text('Periodos de “Estoy bien”'),
              subtitle: Text(
                  'Los avisos informativos se generan a los 5 y 10 minutos del horario.')),
          ...schedules.map((h) => ListTile(
              title: Text(
                  '${h.horaEsperada} · disponible ${h.inicioActivo} a ${h.finActivo}'),
              trailing: IconButton(
                  tooltip: 'Editar horario',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _edit(h)))),
          TextButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add_alarm),
              label: const Text('Agregar horario de aviso')),
        ]);
      });
}
