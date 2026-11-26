import 'package:flutter/material.dart';
import '../modelos/modelos_velia.dart';
import '../servicios/servicio_nube_velia.dart';
import '../servicios/notificaciones_locales_velia.dart';
import '../tema/colores.dart';

class PantallaHorarioNube extends StatefulWidget {
  const PantallaHorarioNube(
      {super.key, required this.adulto, required this.puedeEditar});
  final PerfilAdulto adulto;
  final bool puedeEditar;

  @override
  State<PantallaHorarioNube> createState() => _PantallaHorarioNubeState();
}

class _PantallaHorarioNubeState extends State<PantallaHorarioNube> {
  late Stream<List<ElementoRutina>> _stream;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant PantallaHorarioNube oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adulto.id != widget.adulto.id) _cargar();
  }

  void _cargar() =>
      _stream = ServicioNubeVelia.instancia.escucharRutina(widget.adulto.id);

  Future<void> _editar([ElementoRutina? item]) async {
    final resultado = await showDialog<ElementoRutina>(
      context: context,
      builder: (_) => _DialogoRutina(item: item),
    );
    if (resultado == null) return;
    await ServicioNubeVelia.instancia
        .guardarRutina(widget.adulto.id, resultado);
    await NotificacionesLocalesVelia.instancia.sincronizar(widget.adulto);
    if (mounted) setState(_cargar);
  }

  Future<void> _eliminar(ElementoRutina item) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Quitar de la rutina'),
              content:
                  Text('¿Quieres quitar “${item.nombre}” y sus recordatorios?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Quitar')),
              ],
            ));
    if (ok == true) {
      await ServicioNubeVelia.instancia
          .eliminarRutina(widget.adulto.id, item.id);
      await NotificacionesLocalesVelia.instancia.sincronizar(widget.adulto);
      if (mounted) setState(_cargar);
    }
  }

  String _horario(ElementoRutina item) {
    if (item.modo == ModoHorario.intervalo) {
      return 'Cada ${item.intervaloHoras ?? 8} horas · desde ${item.horaInicio ?? '08:00'}';
    }
    return item.horas.isEmpty ? 'Horario pendiente' : item.horas.join(' · ');
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<ElementoRutina>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(
                child: Text('No se pudo cargar el horario: ${snapshot.error}'));
          final items = snapshot.data ?? const <ElementoRutina>[];
          final today = DateTime.now();
          final dia = today.weekday;
          final hoy = items
              .where((item) =>
                  item.activo &&
                  item.dias.contains(dia) &&
                  (item.periodoIndeterminado ||
                      item.fechaFin == null ||
                      !item.fechaFin!.isBefore(
                          DateTime(today.year, today.month, today.day))) &&
                  (item.fechaInicio == null ||
                      !item.fechaInicio!.isAfter(
                          DateTime(today.year, today.month, today.day))))
              .toList();
          hoy.sort((a, b) => _orden(a).compareTo(_orden(b)));
          return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                const Text('Rutina diaria',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                const Text(
                    'Medicamentos y actividades, ordenados por horario.'),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  const Card(
                      child: ListTile(
                          leading: Icon(Icons.event_note),
                          title: Text('Aún no hay una rutina'),
                          subtitle: Text(
                              'El familiar puede agregar medicamentos o actividades.'))),
                if (items.isNotEmpty && hoy.isEmpty)
                  const Card(
                      child: ListTile(
                          title: Text('Hoy no hay elementos programados.'))),
                ...hoy.map((item) => Card(
                      margin: const EdgeInsets.only(bottom: 9),
                      child: ListTile(
                        minVerticalPadding: 14,
                        leading: CircleAvatar(
                          backgroundColor: item.tipo == TipoRutina.medicamento
                              ? Colors.orange.shade50
                              : Colors.green.shade50,
                          child: Icon(
                              item.tipo == TipoRutina.medicamento
                                  ? Icons.medication
                                  : Icons.directions_walk,
                              color: item.tipo == TipoRutina.medicamento
                                  ? colorNaranja
                                  : Colors.green.shade700),
                        ),
                        title: Text(item.nombre,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '${item.tipo == TipoRutina.medicamento && item.dosis.isNotEmpty ? '${item.dosis}\n' : ''}${_horario(item)}',
                            style: const TextStyle(fontSize: 16)),
                        isThreeLine: item.tipo == TipoRutina.medicamento,
                        trailing: widget.puedeEditar
                            ? PopupMenuButton<String>(
                                onSelected: (v) => v == 'edit'
                                    ? _editar(item)
                                    : _eliminar(item),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'edit', child: Text('Editar')),
                                  PopupMenuItem(
                                      value: 'delete', child: Text('Quitar'))
                                ],
                              )
                            : null,
                      ),
                    )),
                if (widget.puedeEditar) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                          onPressed: () => _editar(),
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar a la rutina'))),
                ],
              ]);
        },
      );

  int _orden(ElementoRutina item) {
    final hora = item.modo == ModoHorario.intervalo
        ? item.horaInicio
        : (item.horas.isEmpty ? null : item.horas.first);
    if (hora == null) return 0;
    final parts = hora.split(':');
    return (int.tryParse(parts.first) ?? 0) * 60 +
        (parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0);
  }
}

class _DialogoRutina extends StatefulWidget {
  const _DialogoRutina({this.item});
  final ElementoRutina? item;
  @override
  State<_DialogoRutina> createState() => _DialogoRutinaState();
}

class _DialogoRutinaState extends State<_DialogoRutina> {
  late final _nombre = TextEditingController(text: widget.item?.nombre ?? '');
  late final _dosis = TextEditingController(text: widget.item?.dosis ?? '');
  late final _intervalo =
      TextEditingController(text: '${widget.item?.intervaloHoras ?? 8}');
  late TipoRutina _tipo = widget.item?.tipo ?? TipoRutina.medicamento;
  late ModoHorario _modo = widget.item?.modo ?? ModoHorario.horasFijas;
  late List<String> _horas = [...?widget.item?.horas];
  late String? _horaInicio = widget.item?.horaInicio ?? '08:00';
  late List<int> _dias = [...?widget.item?.dias]..sort();
  late DateTime? _fechaInicio = widget.item?.fechaInicio ?? DateTime.now();
  late DateTime? _fechaFin = widget.item?.fechaFin;
  late bool _indeterminado = widget.item?.periodoIndeterminado ?? false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _dosis.dispose();
    _intervalo.dispose();
    super.dispose();
  }

  Future<String?> _seleccionarHora(String initial) async {
    final parts = initial.split(':');
    final result = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
            hour: int.tryParse(parts.first) ?? 8,
            minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0));
    return result == null
        ? null
        : '${result.hour.toString().padLeft(2, '0')}:${result.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _fecha({required bool inicio}) async {
    final initial = (inicio ? _fechaInicio : _fechaFin) ?? DateTime.now();
    final value = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2000),
        lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (value != null)
      setState(() {
        if (inicio)
          _fechaInicio = value;
        else
          _fechaFin = value;
      });
  }

  void _guardar() {
    if (_nombre.text.trim().isEmpty) {
      setState(() => _error = 'Escribe un nombre.');
      return;
    }
    if (_dias.isEmpty) {
      setState(() => _error = 'Elige al menos un día.');
      return;
    }
    if (_modo == ModoHorario.horasFijas && _horas.isEmpty) {
      setState(() => _error = 'Agrega al menos una hora.');
      return;
    }
    final intervalo = int.tryParse(_intervalo.text);
    if (_modo == ModoHorario.intervalo &&
        (intervalo == null || intervalo < 1 || intervalo > 24)) {
      setState(() => _error = 'El intervalo debe ser de 1 a 24 horas.');
      return;
    }
    if (!_indeterminado &&
        (_fechaInicio == null ||
            _fechaFin == null ||
            _fechaFin!.isBefore(_fechaInicio!))) {
      setState(() => _error = 'Selecciona inicio y fin del periodo.');
      return;
    }
    final id =
        widget.item?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    Navigator.pop(
        context,
        ElementoRutina(
          id: id,
          tipo: _tipo,
          nombre: _nombre.text.trim(),
          dosis: _tipo == TipoRutina.medicamento ? _dosis.text.trim() : '',
          modo: _modo,
          horas: _horas,
          intervaloHoras: intervalo ?? 8,
          horaInicio: _horaInicio,
          dias: _dias,
          fechaInicio: _fechaInicio,
          fechaFin: _fechaFin,
          periodoIndeterminado: _indeterminado,
        ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title:
            Text(widget.item == null ? 'Agregar a la rutina' : 'Editar rutina'),
        content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              SegmentedButton<TipoRutina>(
                segments: const [
                  ButtonSegment(
                      value: TipoRutina.medicamento,
                      label: Text('Medicamento'),
                      icon: Icon(Icons.medication)),
                  ButtonSegment(
                      value: TipoRutina.actividad,
                      label: Text('Actividad'),
                      icon: Icon(Icons.directions_walk))
                ],
                selected: {_tipo},
                onSelectionChanged: (s) => setState(() => _tipo = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _nombre,
                  decoration: InputDecoration(
                      labelText: _tipo == TipoRutina.medicamento
                          ? 'Nombre del medicamento'
                          : 'Nombre de la actividad')),
              if (_tipo == TipoRutina.medicamento)
                TextField(
                    controller: _dosis,
                    decoration: const InputDecoration(labelText: 'Dosis')),
              const SizedBox(height: 12),
              DropdownButtonFormField<ModoHorario>(
                value: _modo,
                decoration: const InputDecoration(
                    labelText: 'Cómo programar el horario'),
                items: const [
                  DropdownMenuItem(
                      value: ModoHorario.horasFijas,
                      child: Text('Horas específicas')),
                  DropdownMenuItem(
                      value: ModoHorario.intervalo,
                      child: Text('Cada cierto número de horas'))
                ],
                onChanged: (v) =>
                    setState(() => _modo = v ?? ModoHorario.horasFijas),
              ),
              if (_modo == ModoHorario.horasFijas) ...[
                const SizedBox(height: 8),
                ..._horas.map((h) => ListTile(
                    title: Text('Hora: $h'),
                    trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _horas.remove(h))))),
                TextButton.icon(
                    onPressed: () async {
                      final value = await _seleccionarHora('08:00');
                      if (value != null)
                        setState(() {
                          if (!_horas.contains(value)) _horas.add(value);
                          _horas.sort();
                        });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar hora')),
              ] else ...[
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: _intervalo,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Intervalo en horas'))),
                  const SizedBox(width: 10),
                  TextButton(
                      onPressed: () async {
                        final v =
                            await _seleccionarHora(_horaInicio ?? '08:00');
                        if (v != null) setState(() => _horaInicio = v);
                      },
                      child: Text('Inicio ${_horaInicio ?? ''}'))
                ]),
              ],
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Días de repetición')),
              Wrap(
                  spacing: 4,
                  children: List.generate(7, (i) {
                    final d = i + 1;
                    final labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
                    return FilterChip(
                        label: Text(labels[i]),
                        selected: _dias.contains(d),
                        onSelected: (v) => setState(() {
                              if (v) {
                                _dias.add(d);
                              } else {
                                _dias.remove(d);
                              }
                              _dias.sort();
                            }));
                  })),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Periodo indeterminado'),
                  value: _indeterminado,
                  onChanged: (v) => setState(() => _indeterminado = v)),
              if (!_indeterminado)
                Row(children: [
                  Expanded(
                      child: TextButton(
                          onPressed: () => _fecha(inicio: true),
                          child: Text(_fechaInicio == null
                              ? 'Fecha de inicio'
                              : 'Inicio ${_fechaInicio!.day}/${_fechaInicio!.month}/${_fechaInicio!.year}'))),
                  Expanded(
                      child: TextButton(
                          onPressed: () => _fecha(inicio: false),
                          child: Text(_fechaFin == null
                              ? 'Fecha de fin'
                              : 'Fin ${_fechaFin!.day}/${_fechaFin!.month}/${_fechaFin!.year}')))
                ]),
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
