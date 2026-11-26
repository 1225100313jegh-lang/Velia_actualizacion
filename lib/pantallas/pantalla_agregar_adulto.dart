import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modelos/modelos_velia.dart';
import '../servicios/servicio_nube_velia.dart';
import '../tema/colores.dart';
import 'pantalla_principal_nube.dart';

class PantallaAgregarAdulto extends StatefulWidget {
  const PantallaAgregarAdulto(
      {super.key, this.esRegistroInicial = false, this.perfil});
  final bool esRegistroInicial;
  final PerfilAdulto? perfil;

  @override
  State<PantallaAgregarAdulto> createState() => _PantallaAgregarAdultoState();
}

class _ContactoBorrador {
  _ContactoBorrador([ContactoEmergencia? value]) {
    if (value != null) {
      nombre.text = value.nombre;
      telefono.text = value.telefono;
      parentesco.text = value.parentesco;
      principal = value.principal;
    }
  }
  final nombre = TextEditingController();
  final telefono = TextEditingController();
  final parentesco = TextEditingController();
  bool principal = false;

  void dispose() {
    nombre.dispose();
    telefono.dispose();
    parentesco.dispose();
  }
}

class _PantallaAgregarAdultoState extends State<PantallaAgregarAdulto> {
  final _nombre = TextEditingController();
  final _padecimientos = TextEditingController();
  final _alergias = TextEditingController();
  late final List<_ContactoBorrador> _contactos;
  DateTime? _nacimiento;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final perfil = widget.perfil;
    _nombre.text = perfil?.nombre ?? '';
    _padecimientos.text = perfil?.padecimientos.join(', ') ?? '';
    _alergias.text = perfil?.alergias.join(', ') ?? '';
    _nacimiento = perfil?.fechaNacimiento;
    _contactos = perfil == null || perfil.contactos.isEmpty
        ? [_ContactoBorrador()]
        : perfil.contactos.map(_ContactoBorrador.new).toList();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _padecimientos.dispose();
    _alergias.dispose();
    for (final c in _contactos) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirNacimiento() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _nacimiento ?? DateTime(1950),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (fecha != null) setState(() => _nacimiento = fecha);
  }

  List<String> _lista(String value) => value
      .split(RegExp(r'[,;\n]'))
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty)
      .toList();

  Future<void> _guardar() async {
    if (_nombre.text.trim().isEmpty) {
      setState(() => _error = 'Escribe el nombre del adulto mayor.');
      return;
    }
    final contactos = _contactos
        .where((c) =>
            c.nombre.text.trim().isNotEmpty ||
            c.telefono.text.trim().isNotEmpty)
        .map((c) => ContactoEmergencia(
              nombre: c.nombre.text.trim(),
              telefono: c.telefono.text.trim(),
              parentesco: c.parentesco.text.trim(),
              principal: c.principal,
            ))
        .toList();
    if (contactos.isNotEmpty && !contactos.any((c) => c.principal)) {
      contactos[0] = ContactoEmergencia(
        nombre: contactos[0].nombre,
        telefono: contactos[0].telefono,
        parentesco: contactos[0].parentesco,
        principal: true,
      );
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final servicio = ServicioNubeVelia.instancia;
      final existente = widget.perfil;
      final adulto = existente == null
          ? await servicio.crearAdulto(
              nombre: _nombre.text,
              fechaNacimiento: _nacimiento,
              padecimientos: _lista(_padecimientos.text),
              alergias: _lista(_alergias.text),
              contactos: contactos,
            )
          : PerfilAdulto(
              id: existente.id,
              nombre: _nombre.text.trim(),
              fechaNacimiento: _nacimiento,
              padecimientos: _lista(_padecimientos.text),
              alergias: _lista(_alergias.text),
              contactos: contactos,
              estado: existente.estado,
              ownerUid: existente.ownerUid,
              adultUid: existente.adultUid,
            );
      if (existente != null) {
        await servicio.guardarAdulto(adulto);
        if (mounted) Navigator.pop(context, true);
        return;
      }
      await servicio.guardarAccesibilidad(adulto.id,
          escala: 1.2, altoContraste: true);
      final pin = await servicio.consultarPin(adulto.id);
      if (!mounted) return;
      await _mostrarPin(pin);
      if (!mounted) return;
      if (widget.esRegistroInicial) {
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (_) => const PantallaPrincipalFirebase()),
            (_) => false);
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _mostrarPin(String pin) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => AlertDialog(
        icon: const Icon(Icons.key, color: colorNaranja, size: 38),
        title: const Text('PIN del adulto mayor'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
              'Compártelo con el adulto. También podrás consultarlo desde su perfil.'),
          const SizedBox(height: 14),
          SelectableText(pin,
              style: const TextStyle(
                  fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 8)),
          const SizedBox(height: 8),
          const Text('Guárdalo para volver a iniciar sesión en su teléfono.',
              textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: pin));
              if (dialog.mounted)
                ScaffoldMessenger.of(dialog).showSnackBar(
                    const SnackBar(content: Text('PIN copiado.')));
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar'),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Listo')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: colorNaranja,
          foregroundColor: Colors.white,
          title: Text(widget.perfil != null
              ? 'Editar perfil del adulto'
              : widget.esRegistroInicial
                  ? 'Configura al adulto mayor'
                  : 'Agregar adulto'),
        ),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(18), children: [
            if (widget.esRegistroInicial)
              const Text('Ahora crea el perfil que usará la otra cuenta.',
                  style: TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            TextField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Nombre del adulto mayor',
                    border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Card(
                child: ListTile(
              leading: const Icon(Icons.cake, color: colorNaranja),
              title: const Text('Fecha de nacimiento'),
              subtitle: Text(_nacimiento == null
                  ? 'Opcional'
                  : '${_nacimiento!.day}/${_nacimiento!.month}/${_nacimiento!.year}'),
              trailing: const Icon(Icons.calendar_month),
              onTap: _elegirNacimiento,
            )),
            const SizedBox(height: 12),
            TextField(
                controller: _padecimientos,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Padecimientos (opcional)',
                    helperText: 'Puedes escribir varios separados por coma.',
                    border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
                controller: _alergias,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Alergias importantes (opcional)',
                    helperText: 'Puedes escribir varias separadas por coma.',
                    border: OutlineInputBorder())),
            const SizedBox(height: 20),
            const Text('Contactos de emergencia',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._contactos.indexed.map((entry) {
              final index = entry.$1;
              final contacto = entry.$2;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                          child: Text('Contacto ${index + 1}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                      if (_contactos.length > 1)
                        IconButton(
                            tooltip: 'Quitar contacto',
                            onPressed: () => setState(() {
                                  _contactos.removeAt(index).dispose();
                                }),
                            icon: const Icon(Icons.delete_outline)),
                    ]),
                    TextField(
                        controller: contacto.nombre,
                        decoration: const InputDecoration(labelText: 'Nombre')),
                    TextField(
                        controller: contacto.telefono,
                        keyboardType: TextInputType.phone,
                        decoration:
                            const InputDecoration(labelText: 'Teléfono')),
                    TextField(
                        controller: contacto.parentesco,
                        decoration:
                            const InputDecoration(labelText: 'Parentesco')),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Contacto principal'),
                      value: contacto.principal,
                      onChanged: (value) => setState(() {
                        for (final c in _contactos) {
                          c.principal = false;
                        }
                        contacto.principal = value ?? false;
                      }),
                    ),
                  ]),
                ),
              );
            }),
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _contactos.add(_ContactoBorrador())),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Agregar contacto'),
                )),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 16),
            SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  icon: _guardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_guardando
                      ? 'Guardando…'
                      : widget.perfil == null
                          ? 'Guardar perfil y generar PIN'
                          : 'Guardar cambios'),
                )),
          ]),
        ),
      );
}
