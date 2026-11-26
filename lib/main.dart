import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:async';
import 'config/firebase_options.dart';
import 'pantallas/pantalla_configuracion_firebase.dart';
import 'pantallas/pantalla_inicio_sesion.dart';
import 'pantallas/pantalla_principal_nube.dart';
import 'servicios/servicio_nube_velia.dart';
import 'tema/colores.dart';

/// Prepara Firebase y abre la aplicación.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? error;
  if (FirebaseOptionsVelia.configured) {
    try {
      await Firebase.initializeApp(
          options: FirebaseOptionsVelia.currentPlatform);
      await ServicioNubeVelia.instancia.inicializar();
    } catch (e) {
      error = e.toString();
    }
  }
  runApp(AplicacionVelia(firebaseError: error));
}

class AplicacionVelia extends StatelessWidget {
  const AplicacionVelia({super.key, this.firebaseError});
  final String? firebaseError;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: ServicioNubeVelia.instancia,
        builder: (context, _) => MaterialApp(
          title: 'Velia',
          locale: const Locale('es', 'MX'),
          supportedLocales: const [Locale('es', 'MX')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: colorNaranja,
              primary: colorNaranja,
              contrastLevel:
                  ServicioNubeVelia.instancia.altoContraste ? 1.0 : 0.0,
            ),
            scaffoldBackgroundColor: colorFondo,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler:
                  TextScaler.linear(ServicioNubeVelia.instancia.escalaTexto),
            ),
            child: child!,
          ),
          home: _ArranqueVelia(firebaseError: firebaseError),
        ),
      );
}

class _ArranqueVelia extends StatefulWidget {
  const _ArranqueVelia({this.firebaseError});
  final String? firebaseError;
  @override
  State<_ArranqueVelia> createState() => _ArranqueVeliaState();
}

class _ArranqueVeliaState extends State<_ArranqueVelia> {
  bool _termino = false;
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _termino = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_termino) {
      if (!FirebaseOptionsVelia.configured)
        return const PantallaConfiguracionFirebase();
      if (widget.firebaseError != null)
        return PantallaConfiguracionFirebase(error: widget.firebaseError);
      return const _PuertaVelia();
    }
    return const Scaffold(
      body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(
            radius: 48,
            backgroundColor: colorNaranja,
            child: Icon(Icons.favorite, color: Colors.white, size: 52)),
        SizedBox(height: 14),
        Text('Velia',
            style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: colorNaranja)),
      ])),
    );
  }
}

class _PuertaVelia extends StatelessWidget {
  const _PuertaVelia();

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: ServicioNubeVelia.instancia,
        builder: (context, _) {
          final servicio = ServicioNubeVelia.instancia;
          if (servicio.usuarioAuth == null || servicio.cuenta == null) {
            return const PantallaInicioSesion();
          }
          return const PantallaPrincipalFirebase();
        },
      );
}
