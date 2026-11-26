import 'package:flutter/material.dart';
import '../servicios/servicio_nube_velia.dart';
import '../tema/colores.dart';
import 'pantalla_agregar_adulto.dart';
import 'pantalla_principal_nube.dart';

class PantallaRegistroFamiliar extends StatefulWidget {
  const PantallaRegistroFamiliar({super.key});

  @override
  State<PantallaRegistroFamiliar> createState() =>
      _PantallaRegistroFamiliarState();
}

class _PantallaRegistroFamiliarState extends State<PantallaRegistroFamiliar> {
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _telefono = TextEditingController();
  final _parentesco = TextEditingController();
  final _contrasena = TextEditingController();
  final _codigo = TextEditingController();
  bool _ocultar = true;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _telefono.dispose();
    _parentesco.dispose();
    _contrasena.dispose();
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _crearCuenta() async {
    if (_nombre.text.trim().isEmpty ||
        _correo.text.trim().isEmpty ||
        _contrasena.text.length < 6) {
      setState(() => _error =
          'Completa nombre, correo y una contraseña de 6 caracteres o más.');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ServicioNubeVelia.instancia.registrarFamiliar(
        email: _correo.text,
        contrasena: _contrasena.text,
        nombre: _nombre.text,
        telefono: _telefono.text,
        parentesco: _parentesco.text,
        codigoInvitacion:
            _codigo.text.trim().isEmpty ? null : _codigo.text.trim(),
      );
      if (!mounted) return;
      final esInvitado = _codigo.text.trim().isNotEmpty;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => esInvitado
              ? const PantallaPrincipalFirebase()
              : const PantallaAgregarAdulto(esRegistroInicial: true),
        ),
        (_) => false,
      );
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: colorNaranja,
          foregroundColor: Colors.white,
          title: const Text('Crear cuenta familiar'),
        ),
        body: SafeArea(
          child: Form(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Primero configura tu cuenta',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                    controller: _nombre,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Tu nombre', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: _correo,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: _contrasena,
                    obscureText: _ocultar,
                    decoration: InputDecoration(
                        labelText: 'Contraseña',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _ocultar = !_ocultar),
                            icon: Icon(_ocultar
                                ? Icons.visibility
                                : Icons.visibility_off)))),
                const SizedBox(height: 12),
                TextField(
                    controller: _telefono,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Teléfono (opcional)',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: _parentesco,
                    decoration: const InputDecoration(
                        labelText: 'Parentesco con el adulto (opcional)',
                        border: OutlineInputBorder())),
                const SizedBox(height: 20),
                const Text('¿Te invitó otro familiar?',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                    controller: _codigo,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                        labelText: 'Código de invitación (opcional)',
                        border: OutlineInputBorder())),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _cargando ? null : _crearCuenta,
                    icon: _cargando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.arrow_forward),
                    label: Text(_cargando ? 'Creando cuenta…' : 'Continuar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
