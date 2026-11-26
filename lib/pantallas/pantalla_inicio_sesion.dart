import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../servicios/servicio_nube_velia.dart';
import '../tema/colores.dart';
import 'pantalla_principal_nube.dart';
import 'pantalla_registro_familiar.dart';

class PantallaInicioSesion extends StatefulWidget {
  const PantallaInicioSesion({super.key});

  @override
  State<PantallaInicioSesion> createState() => _PantallaInicioSesionState();
}

class _PantallaInicioSesionState extends State<PantallaInicioSesion> {
  final _email = TextEditingController();
  final _contrasena = TextEditingController();
  final _pin = TextEditingController();
  bool _esAdulto = false;
  bool _ocultar = true;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _contrasena.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final servicio = ServicioNubeVelia.instancia;
      if (_esAdulto) {
        await servicio.iniciarSesionAdulto(_pin.text.trim());
      } else {
        await servicio.iniciarSesionFamiliar(
            email: _email.text, contrasena: _contrasena.text);
      }
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const PantallaPrincipalFirebase()));
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _mensajeAuth(e));
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _mensajeAuth(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'Revisa el correo electrónico.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'El correo, la contraseña o el PIN no coinciden.',
        'too-many-requests' =>
          'Hubo muchos intentos. Espera un momento e inténtalo de nuevo.',
        'network-request-failed' => 'Revisa la conexión a internet.',
        'invalid-pin' => e.message ?? 'El PIN no es válido.',
        _ => e.message ?? 'No se pudo iniciar sesión.',
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 48,
                      backgroundColor: colorNaranja,
                      child:
                          Icon(Icons.favorite, color: Colors.white, size: 52),
                    ),
                    const SizedBox(height: 14),
                    const Text('Velia',
                        style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: colorNaranja)),
                    const Text('Cuidado digital para nuestros mayores',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                            value: false,
                            icon: Icon(Icons.family_restroom),
                            label: Text('Familiar')),
                        ButtonSegment(
                            value: true,
                            icon: Icon(Icons.elderly),
                            label: Text('Adulto')),
                      ],
                      selected: {_esAdulto},
                      onSelectionChanged: (value) =>
                          setState(() => _esAdulto = value.first),
                    ),
                    const SizedBox(height: 20),
                    if (_esAdulto) ...[
                      TextField(
                        controller: _pin,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        obscureText: true,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: 'PIN de 6 dígitos',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.alternate_email),
                            border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _contrasena,
                        obscureText: _ocultar,
                        onSubmitted: (_) => _ingresar(),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: _ocultar
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            onPressed: () =>
                                setState(() => _ocultar = !_ocultar),
                            icon: Icon(_ocultar
                                ? Icons.visibility
                                : Icons.visibility_off),
                          ),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                          textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _cargando ? null : _ingresar,
                        icon: _cargando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.login),
                        label: Text(_cargando ? 'Ingresando…' : 'Ingresar'),
                      ),
                    ),
                    if (!_esAdulto) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const PantallaRegistroFamiliar()),
                          ),
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('Crear cuenta familiar'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
