import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../modelos/modelos_velia.dart';
import '../servicios/servicio_nube_velia.dart';
import '../servicios/notificaciones_locales_velia.dart';
import '../tema/colores.dart';
import 'pantalla_accesibilidad_nube.dart';
import 'pantalla_administrador_nube.dart';
import 'pantalla_calendario_nube.dart';
import 'pantalla_horario_nube.dart';
import 'pantalla_perfil_nube.dart';
import 'pantalla_inicio_sesion.dart';
import 'pantalla_inicio_adulto.dart';

class PantallaPrincipalFirebase extends StatefulWidget {
  const PantallaPrincipalFirebase({super.key});

  @override
  State<PantallaPrincipalFirebase> createState() =>
      _PantallaPrincipalFirebaseState();
}

class _PantallaPrincipalFirebaseState extends State<PantallaPrincipalFirebase> {
  final _servicio = ServicioNubeVelia.instancia;
  late Future<List<PerfilAdulto>> _adultos;

  @override
  void initState() {
    super.initState();
    _cargarAdultos();
    _syncNotificaciones();
  }

  Future<void> _syncNotificaciones() async {
    final adulto = _servicio.adultoSeleccionado;
    if (adulto == null || _servicio.esAdmin) return;
    try {
      await NotificacionesLocalesVelia.instancia.sincronizar(adulto);
    } catch (_) {
      // La app sigue funcionando si el teléfono no habilita notificaciones.
    }
  }

  void _cargarAdultos() {
    final cuenta = _servicio.cuenta;
    _adultos = cuenta == null || cuenta.rol == 'admin'
        ? Future.value(const [])
        : _servicio.listarAdultosDeCuenta(cuenta.uid);
  }

  Future<void> _cerrarSesion() async {
    await _servicio.cerrarSesion();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PantallaInicioSesion()),
        (_) => false);
  }

  Future<void> _abrirPerfil() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const PantallaPerfilNube()));
    if (mounted) {
      setState(_cargarAdultos);
      final seleccionado = _servicio.adultoSeleccionado;
      if (seleccionado != null) {
        await _servicio.seleccionarAdulto(seleccionado.id);
        await _syncNotificaciones();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cuenta = _servicio.cuenta;
    if (cuenta == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (cuenta.rol == 'admin')
      return PantallaAdministradorNube(onCerrarSesion: _cerrarSesion);
    if (cuenta.rol == 'adult') {
      final perfil = _servicio.adultoSeleccionado;
      if (perfil == null)
        return const Scaffold(
            body: Center(child: Text('No se encontró el perfil vinculado.')));
      return Scaffold(
        appBar: AppBar(
          backgroundColor: colorNaranja,
          foregroundColor: Colors.white,
          title: Text('Hola, ${perfil.nombre}',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
                tooltip: 'Accesibilidad',
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            PantallaAccesibilidadNube(adultoId: perfil.id)))),
            IconButton(
                tooltip: 'Cerrar sesión',
                icon: const Icon(Icons.logout),
                onPressed: _cerrarSesion),
          ],
        ),
        body: PantallaInicioAdulto(adulto: perfil),
      );
    }
    return FutureBuilder<List<PerfilAdulto>>(
      future: _adultos,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final adultos = snapshot.data ?? const <PerfilAdulto>[];
        final activo = _servicio.adultoSeleccionado;
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: colorNaranja,
              foregroundColor: Colors.white,
              title: adultos.isEmpty
                  ? const Text('Velia · Familia')
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: adultos.any((a) => a.id == activo?.id)
                            ? activo!.id
                            : adultos.first.id,
                        dropdownColor: colorNaranja,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold),
                        iconEnabledColor: Colors.white,
                        items: adultos
                            .map((a) => DropdownMenuItem(
                                value: a.id, child: Text(a.nombre)))
                            .toList(),
                        onChanged: (id) async {
                          if (id != null) await _servicio.seleccionarAdulto(id);
                          await _syncNotificaciones();
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
              actions: [
                IconButton(
                    tooltip: 'Perfil y configuración',
                    icon: const Icon(Icons.settings),
                    onPressed: _abrirPerfil),
                IconButton(
                    tooltip: 'Cerrar sesión',
                    icon: const Icon(Icons.logout),
                    onPressed: _cerrarSesion),
              ],
              bottom: const TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: [
                  Tab(icon: Icon(Icons.home_outlined), text: 'Inicio'),
                  Tab(icon: Icon(Icons.access_time), text: 'Horario'),
                  Tab(icon: Icon(Icons.calendar_month), text: 'Calendario'),
                ],
              ),
            ),
            body: activo == null
                ? _SinAdultos(onAgregar: _abrirPerfil)
                : TabBarView(children: [
                    _InicioFamiliarNube(adulto: activo),
                    PantallaHorarioNube(
                        adulto: activo,
                        puedeEditar:
                            _servicio.esFamiliarPrincipal || _servicio.esAdmin),
                    PantallaCalendarioNube(
                        adulto: activo,
                        puedeEditar:
                            _servicio.esFamiliarPrincipal || _servicio.esAdmin),
                  ]),
          ),
        );
      },
    );
  }
}

class _SinAdultos extends StatelessWidget {
  const _SinAdultos({required this.onAgregar});
  final VoidCallback onAgregar;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.elderly, size: 64, color: colorNaranja),
            const SizedBox(height: 12),
            const Text('Agrega el perfil del adulto mayor para comenzar.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
            const SizedBox(height: 14),
            FilledButton.icon(
                onPressed: onAgregar,
                icon: const Icon(Icons.person_add),
                label: const Text('Agregar adulto')),
          ]),
        ),
      );
}

class _InicioFamiliarNube extends StatefulWidget {
  const _InicioFamiliarNube({required this.adulto});
  final PerfilAdulto adulto;

  @override
  State<_InicioFamiliarNube> createState() => _InicioFamiliarNubeState();
}

class _InicioFamiliarNubeState extends State<_InicioFamiliarNube> {
  final _servicio = ServicioNubeVelia.instancia;
  late Stream<
          (List<ElementoRutina>, List<CitaVelia>, List<Map<String, dynamic>>)>
      _stream;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant _InicioFamiliarNube oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adulto.id != widget.adulto.id) _cargar();
  }

  void _cargar() {
    _stream = _servicio.escucharResumen(widget.adulto.id);
    _servicio.sincronizarAlertasBienestar(widget.adulto.id).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        (List<ElementoRutina>, List<CitaVelia>, List<Map<String, dynamic>>)>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
              child: Text('No se pudo cargar el resumen: ${snapshot.error}'));
        final (rutina, citas, historial) = snapshot.data!;
        final avisosBienestar =
            historial.where((h) => h['tipo'] == 'bienestar').toList();
        final futuras = citas
            .where((c) =>
                c.estado == EstadoCita.programada &&
                c.fecha.isAfter(DateTime.now()))
            .toList();
        final ultima = avisosBienestar.isEmpty ? null : avisosBienestar.first;
        final proximaCita = futuras.isEmpty ? null : futuras.first;
        return RefreshIndicator(
          onRefresh: () async {
            await _servicio.sincronizarAlertasBienestar(widget.adulto.id);
          },
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Card(
                color: ultima == null
                    ? Colors.orange.shade50
                    : Colors.green.shade50,
                child: ListTile(
                  leading: Icon(
                      ultima == null ? Icons.schedule : Icons.check_circle,
                      size: 38,
                      color: ultima == null ? colorNaranja : Colors.green),
                  title: const Text('Estoy bien · último aviso',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(ultima == null
                      ? 'Aún no hay confirmaciones.'
                      : _momento(ultima['fecha'])),
                )),
            const SizedBox(height: 10),
            Card(
                child: ListTile(
              leading:
                  const Icon(Icons.medication, color: colorNaranja, size: 34),
              title: const Text('Próxima rutina',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(rutina.isEmpty
                  ? 'No hay rutinas programadas.'
                  : '${rutina.first.nombre}${rutina.first.dosis.isEmpty ? '' : ' · ${rutina.first.dosis}'}'),
            )),
            const SizedBox(height: 10),
            Card(
                child: ListTile(
              leading: const Icon(Icons.calendar_month,
                  color: colorNaranja, size: 34),
              title: const Text('Próxima cita',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(proximaCita == null
                  ? 'No hay citas próximas.'
                  : '${proximaCita.asunto} · ${_fecha(proximaCita.fecha)}'),
            )),
            const SizedBox(height: 18),
            const Text('Avisos recientes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...historial.take(8).map((h) => Card(
                    child: ListTile(
                  leading: Icon(
                      h['tipo'] == 'emergencia' || h['tipo'] == 'alerta_grave'
                          ? Icons.warning_amber
                          : Icons.notifications_active,
                      color: h['tipo'] == 'emergencia'
                              || h['tipo'] == 'alerta_grave'
                          ? Colors.red
                          : colorNaranja),
                  title: Text(h['detalle'] as String? ?? 'Aviso de Velia'),
                  subtitle: Text(_momento(h['fecha'])),
                  trailing: h['tipo'] == 'emergencia' &&
                          widget.adulto.contactos.isNotEmpty
                      ? IconButton(
                          tooltip: 'Llamar al adulto',
                          icon: const Icon(Icons.call),
                          onPressed: () => _llamar(
                              context,
                              widget.adulto.contactos
                                  .firstWhere((c) => c.principal,
                                      orElse: () =>
                                          widget.adulto.contactos.first)
                                  .telefono))
                      : null,
                ))),
          ]),
        );
      },
    );
  }

  static String _momento(dynamic fecha) {
    DateTime? dt;
    if (fecha is DateTime) dt = fecha;
    if (fecha is Timestamp) dt = fecha.toDate();
    if (dt == null) return 'Fecha pendiente de sincronización';
    return '${dt.day}/${dt.month}/${dt.year} · ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static String _fecha(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} · ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  static Future<void> _llamar(BuildContext context, String telefono) async {
    final uri = Uri(scheme: 'tel', path: telefono);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
