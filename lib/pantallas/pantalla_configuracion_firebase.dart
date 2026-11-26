import 'package:flutter/material.dart';
import '../tema/colores.dart';

class PantallaConfiguracionFirebase extends StatelessWidget {
  const PantallaConfiguracionFirebase({super.key, this.error});
  final String? error;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(24),
                shrinkWrap: true,
                children: [
                  const Icon(Icons.cloud_sync, size: 72, color: colorNaranja),
                  const SizedBox(height: 16),
                  const Text('No se pudo conectar con Firebase',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text(
                    'Verifica que android/app/google-services.json pertenezca a la app com.example.velia y que la conexion a internet este activa.',
                    textAlign: TextAlign.center,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: SelectableText(error!)),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Text(
                    'Auth y Firestore ya estan configurados para Velia. Si acabas de activar un servicio, espera unos minutos y vuelve a abrir la app.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
