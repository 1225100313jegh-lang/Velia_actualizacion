import 'package:flutter/material.dart';
import '../modelos/modelos_velia.dart';
import '../servicios/servicio_nube_velia.dart';
import '../tema/colores.dart';

class PantallaAdministradorNube extends StatefulWidget {
  const PantallaAdministradorNube({super.key, required this.onCerrarSesion});
  final VoidCallback onCerrarSesion;
  @override
  State<PantallaAdministradorNube> createState() =>
      _PantallaAdministradorNubeState();
}

class _PantallaAdministradorNubeState extends State<PantallaAdministradorNube> {
  final _service = ServicioNubeVelia.instancia;
  late Future<List<PerfilAdulto>> _adultos;
  late Future<(int, int)> _conteos;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _adultos = _service.listarTodosLosAdultos();
    _conteos = _adultos.then((adults) async {
      final routineCounts =
          await Future.wait(adults.map((a) => _service.listarRutina(a.id)));
      final appointmentCounts =
          await Future.wait(adults.map((a) => _service.listarCitas(a.id)));
      return (
        routineCounts.fold<int>(0, (sum, list) => sum + list.length),
        appointmentCounts.fold<int>(0, (sum, list) => sum + list.length),
      );
    });
  }

  Future<void> _archive(PerfilAdulto a) async {
    final restore = a.estado == 'archived';
    await (restore
        ? _service.restaurarAdulto(a.id)
        : _service.archivarAdulto(a.id));
    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Administración · Velia'),
            backgroundColor: colorNaranja,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                  tooltip: 'Cerrar sesión',
                  onPressed: widget.onCerrarSesion,
                  icon: const Icon(Icons.logout))
            ]),
        body: FutureBuilder<List<PerfilAdulto>>(
            future: _adultos,
            builder: (context, s) {
              if (s.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (s.hasError)
                return Center(
                    child:
                        Text('No se pudieron cargar los grupos: ${s.error}'));
              final adults = s.data ?? const <PerfilAdulto>[];
              final groups = <String, List<PerfilAdulto>>{};
              for (final a in adults) {
                groups.putIfAbsent(a.ownerUid, () => []).add(a);
              }
              return FutureBuilder<(int, int)>(
                  future: _conteos,
                  builder: (context, countsSnapshot) {
                    final counts = countsSnapshot.data ?? (0, 0);
                    return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Wrap(spacing: 10, runSpacing: 10, children: [
                            _metric('Grupos', groups.length, Icons.groups),
                            _metric('Adultos', adults.length, Icons.elderly),
                            _metric('Rutinas', counts.$1, Icons.medication),
                            _metric('Citas', counts.$2, Icons.calendar_month),
                          ]),
                          const SizedBox(height: 20),
                          const Text('Cuentas por grupo familiar',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          ...groups.entries.map((entry) => Card(
                              child: ExpansionTile(
                                  leading: const Icon(Icons.family_restroom,
                                      color: colorNaranja),
                                  title: Text(
                                      'Grupo ${entry.key.substring(0, entry.key.length < 8 ? entry.key.length : 8)}'),
                                  subtitle:
                                      Text('${entry.value.length} adulto(s)'),
                                  children: entry.value
                                      .map((a) => ListTile(
                                            leading: Icon(a.estado == 'archived'
                                                ? Icons.archive
                                                : Icons.elderly),
                                            title: Text(a.nombre),
                                            subtitle: Text(
                                                'Contactos: ${a.contactos.length} · ${a.estado == 'archived' ? 'Archivado' : 'Activo'}'),
                                            trailing: PopupMenuButton<String>(
                                                onSelected: (v) => _archive(a),
                                                itemBuilder: (_) => [
                                                      PopupMenuItem(
                                                          value: 'toggle',
                                                          child: Text(
                                                              a.estado ==
                                                                      'archived'
                                                                  ? 'Restaurar'
                                                                  : 'Archivar'))
                                                    ]),
                                          ))
                                      .toList()))),
                        ]);
                  });
            }),
      );
  Widget _metric(String label, int? count, IconData icon) => SizedBox(
      width: 155,
      child: Card(
          child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                Icon(icon, color: colorNaranja, size: 28),
                const SizedBox(height: 6),
                Text(count?.toString() ?? '—',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                Text(label)
              ]))));
}
