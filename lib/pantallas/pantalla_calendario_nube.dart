import 'package:flutter/material.dart';
import '../modelos/modelos_velia.dart';
import '../servicios/servicio_nube_velia.dart';
import '../servicios/notificaciones_locales_velia.dart';
import '../tema/colores.dart';

class PantallaCalendarioNube extends StatefulWidget {
  const PantallaCalendarioNube(
      {super.key, required this.adulto, required this.puedeEditar});
  final PerfilAdulto adulto;
  final bool puedeEditar;

  @override
  State<PantallaCalendarioNube> createState() => _PantallaCalendarioNubeState();
}

class _PantallaCalendarioNubeState extends State<PantallaCalendarioNube> {
  late Stream<List<CitaVelia>> _stream;
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant PantallaCalendarioNube oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adulto.id != widget.adulto.id) _cargar();
  }

  void _cargar() =>
      _stream = ServicioNubeVelia.instancia.escucharCitas(widget.adulto.id);

  Future<void> _editar([CitaVelia? cita]) async {
    final nueva = await showDialog<CitaVelia>(
        context: context, builder: (_) => _DialogoCita(cita: cita));
    if (nueva == null) return;
    await ServicioNubeVelia.instancia.guardarCita(widget.adulto.id, nueva);
    await NotificacionesLocalesVelia.instancia.sincronizar(widget.adulto);
    if (mounted) setState(_cargar);
  }

  Future<void> _estado(CitaVelia cita, EstadoCita estado) async {
    await ServicioNubeVelia.instancia.guardarCita(
        widget.adulto.id,
        CitaVelia(
          id: cita.id,
          asunto: cita.asunto,
          fecha: cita.fecha,
          recordatorioDias: cita.recordatorioDias,
          estado: estado,
          recurring: cita.recurring,
          reglaRecurrencia: cita.reglaRecurrencia,
        ));
    await NotificacionesLocalesVelia.instancia.sincronizar(widget.adulto);
    if (mounted) setState(_cargar);
  }

  Future<void> _programarSiguiente(CitaVelia cita) async {
    final siguiente = await showDialog<CitaVelia>(
        context: context,
        builder: (_) => _DialogoCita(
              cita: CitaVelia(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  asunto: cita.asunto,
                  fecha: DateTime.now().add(const Duration(days: 30)),
                  recordatorioDias: cita.recordatorioDias,
                  recurring: cita.recurring,
                  reglaRecurrencia: cita.reglaRecurrencia),
              titulo: 'Programar siguiente cita',
            ));
    if (siguiente != null) {
      await _estado(cita, EstadoCita.reprogramada);
      await ServicioNubeVelia.instancia
          .guardarCita(widget.adulto.id, siguiente);
      await NotificacionesLocalesVelia.instancia.sincronizar(widget.adulto);
      if (mounted) setState(_cargar);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<CitaVelia>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(
                child:
                    Text('No se pudo cargar el calendario: ${snapshot.error}'));
          final citas = snapshot.data ?? const <CitaVelia>[];
          final ahora = DateTime.now();
          final proximas = citas
              .where((c) =>
                  c.fecha.isAfter(ahora) && c.estado == EstadoCita.programada)
              .toList();
          final historial = citas
              .where((c) =>
                  !c.fecha.isAfter(ahora) || c.estado != EstadoCita.programada)
              .toList();
          return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                const Text('Próximas citas',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                if (proximas.isEmpty)
                  const Card(
                      child: ListTile(title: Text('No hay citas próximas.'))),
                ...proximas.map((c) => _tarjeta(c, pasada: false)),
                const SizedBox(height: 18),
                const Text('Historial de citas',
                    style:
                        TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                if (historial.isEmpty)
                  const Card(
                      child: ListTile(
                          title: Text('El historial aparecerá aquí.'))),
                ...historial.map((c) => _tarjeta(c, pasada: true)),
                if (widget.puedeEditar) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                          onPressed: () => _editar(),
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar cita'))),
                ],
              ]);
        },
      );

  Widget _tarjeta(CitaVelia cita, {required bool pasada}) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
              backgroundColor:
                  pasada ? Colors.grey.shade100 : Colors.orange.shade50,
              child: Icon(Icons.local_hospital,
                  color: pasada ? Colors.grey : colorNaranja)),
          title: Text(cita.asunto,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
              '${_fecha(cita.fecha)}\n${_estadoTexto(cita.estado)} · Aviso ${cita.recordatorioDias == 0 ? 'el mismo día' : '${cita.recordatorioDias} días antes'}${cita.recurring ? ' · Repetición: ${cita.reglaRecurrencia}' : ''}'),
          isThreeLine: true,
          trailing: widget.puedeEditar
              ? PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _editar(cita);
                    if (v == 'done') _estado(cita, EstadoCita.realizada);
                    if (v == 'cancel') _estado(cita, EstadoCita.cancelada);
                    if (v == 'reschedule') _programarSiguiente(cita);
                  },
                  itemBuilder: (_) => [
                    if (!pasada)
                      const PopupMenuItem(
                          value: 'done', child: Text('Marcar realizada')),
                    if (!pasada)
                      const PopupMenuItem(
                          value: 'cancel', child: Text('Cancelar cita')),
                    const PopupMenuItem(
                        value: 'reschedule',
                        child: Text('Programar siguiente cita')),
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  ],
                )
              : null,
        ),
      );

  String _estadoTexto(EstadoCita s) => switch (s) {
        EstadoCita.programada => 'Programada',
        EstadoCita.realizada => 'Realizada',
        EstadoCita.cancelada => 'Cancelada',
        EstadoCita.reprogramada => 'Reprogramada',
      };

  String _fecha(DateTime d) =>
      '${d.day}/${d.month}/${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _DialogoCita extends StatefulWidget {
  const _DialogoCita({this.cita, this.titulo = 'Programar cita'});
  final CitaVelia? cita;
  final String titulo;
  @override
  State<_DialogoCita> createState() => _DialogoCitaState();
}

class _DialogoCitaState extends State<_DialogoCita> {
  late final _asunto = TextEditingController(text: widget.cita?.asunto ?? '');
  late DateTime _fecha =
      widget.cita?.fecha ?? DateTime.now().add(const Duration(days: 1));
  late int _aviso = widget.cita?.recordatorioDias ?? 1;
  late bool _recurrente = widget.cita?.recurring ?? false;
  late String _regla = widget.cita?.reglaRecurrencia ?? 'mensual';
  String? _error;

  @override
  void dispose() {
    _asunto.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final date = await showDatePicker(
        context: context,
        initialDate: _fecha,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_fecha));
    if (time != null)
      setState(() => _fecha =
          DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  void _guardar() {
    if (_asunto.text.trim().isEmpty) {
      setState(() => _error = 'Escribe el asunto de la cita.');
      return;
    }
    final id =
        widget.cita?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    Navigator.pop(
        context,
        CitaVelia(
            id: id,
            asunto: _asunto.text.trim(),
            fecha: _fecha,
            recordatorioDias: _aviso,
            estado: widget.cita?.estado ?? EstadoCita.programada,
            recurring: _recurrente,
            reglaRecurrencia: _regla));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.titulo),
        content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: _asunto,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      labelText:
                          'Asunto (puedes incluir clínica o profesional)',
                      border: OutlineInputBorder())),
              const SizedBox(height: 12),
              Card(
                  child: ListTile(
                      leading:
                          const Icon(Icons.calendar_month, color: colorNaranja),
                      title: Text(
                          '${_fecha.day}/${_fecha.month}/${_fecha.year} · ${_fecha.hour.toString().padLeft(2, '0')}:${_fecha.minute.toString().padLeft(2, '0')}'),
                      trailing: const Icon(Icons.edit_calendar),
                      onTap: _elegirFecha)),
              DropdownButtonFormField<int>(
                  value: _aviso,
                  decoration: const InputDecoration(
                      labelText: 'Avisar con anticipación'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('El mismo día')),
                    DropdownMenuItem(value: 1, child: Text('1 día antes')),
                    DropdownMenuItem(value: 3, child: Text('3 días antes')),
                    DropdownMenuItem(value: 7, child: Text('1 semana antes')),
                    DropdownMenuItem(value: 14, child: Text('2 semanas antes'))
                  ],
                  onChanged: (v) => setState(() => _aviso = v ?? 1)),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Se repetirá'),
                  value: _recurrente,
                  onChanged: (v) => setState(() => _recurrente = v)),
              if (_recurrente)
                DropdownButtonFormField<String>(
                    value: _regla,
                    decoration:
                        const InputDecoration(labelText: 'Frecuencia conocida'),
                    items: const [
                      DropdownMenuItem(
                          value: 'semanal', child: Text('Cada semana')),
                      DropdownMenuItem(
                          value: 'mensual', child: Text('Cada mes')),
                      DropdownMenuItem(value: 'anual', child: Text('Cada año'))
                    ],
                    onChanged: (v) => setState(() => _regla = v ?? 'mensual')),
              if (_error != null)
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
            ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(onPressed: _guardar, child: const Text('Guardar'))
        ],
      );
}
