# Guía de funciones de Velia

Esta guía resume para qué sirve cada función principal. El código conserva sus nombres actuales; los comentarios junto a las funciones explican su propósito en español sencillo.

## Inicio de la aplicación

En `lib/main.dart`, `main` prepara Flutter y Firebase antes de abrir la app. `AplicacionVelia` crea la ventana principal y decide qué pantalla mostrar según la sesión y el estado de Firebase.

## Cuenta, perfiles y datos en la nube

En `lib/servicios/servicio_nube_velia.dart`, `ServicioNubeVelia` concentra las operaciones de Firebase:

- `inicializar` prepara la conexión y recupera la sesión activa.
- `cargarCuentaActual` obtiene la cuenta y el perfil adulto asociado.
- `registrarFamiliar`, `iniciarSesionFamiliar` e `iniciarSesionAdulto` crean o abren cada tipo de cuenta.
- `crearAdulto`, `guardarAdulto`, `archivarAdulto` y `restaurarAdulto` administran perfiles de adultos.
- `consultarPin` y `restablecerPin` permiten al familiar principal consultar o renovar el PIN del adulto.
- `crearInvitacion`, `aceptarInvitacion`, `listarFamiliaresVinculados` y `desvincularFamiliar` administran familiares con acceso de consulta.
- `listarRutina`, `escucharRutina`, `guardarRutina` y `eliminarRutina` consultan y actualizan las actividades y medicamentos.
- `listarCitas`, `escucharCitas`, `guardarCita` y `eliminarCita` administran las citas del calendario.
- `listarHorariosBienestar` y `guardarHorarioBienestar` consultan y guardan el horario permitido para el aviso «Estoy bien».
- `registrarEstoyBien` guarda el aviso y actualiza la racha; `consultarRacha` y `obtenerFraseBonitaDelDia` consultan la recompensa diaria.
- `sincronizarAlertasBienestar`, `registrarEventoEmergencia` y `registrarHistorial` guardan los avisos y eventos importantes.
- `escucharHistorial`, `listarHistorial`, `escucharResumen` y `escucharDatosAdulto` entregan información actualizada a las pantallas.
- `guardarAccesibilidad` y `cargarAccesibilidad` conservan las preferencias visuales del adulto.
- `cerrarSesion` termina la sesión actual.

## Estado local y modo de demostración

`lib/estado/estado_app.dart` contiene `EstadoApp`, que mantiene datos temporales para los paneles de demostración. Sus funciones permiten iniciar o cerrar sesión, cambiar de panel y agregar, editar o eliminar medicamentos, rutinas y eventos. `registrarBienestar` agrega un aviso local y `marcarAvisosLeidos` limpia los avisos pendientes.

`lib/servicios/servicio_velia.dart` conserva el servicio local basado en preferencias del dispositivo. Sus funciones cubren cuentas de demostración, vínculos, perfil, accesibilidad, avisos y operaciones locales de citas y medicamentos. La versión conectada a Firebase usa `ServicioNubeVelia`.

## Formularios, formatos y navegación

En `lib/utilidades/validadores.dart`, `validarObligatorio`, `validarNombre`, `validarCorreo` y `validarContrasena` revisan los datos antes de guardar un formulario.

En `lib/utilidades/formatos.dart`, `formatearFecha`, `formatearHora` y `describirMomento` preparan fechas y horas para mostrarlas en pantalla.

En `lib/utilidades/navegacion.dart`, `panelSegunRol` elige el panel y `irAlPanel` abre el panel de la cuenta activa.

## Accesibilidad y avisos del dispositivo

En `lib/servicios/servicio_lectura_velia.dart`, `leer` reproduce en voz alta el texto indicado y `detener` corta la lectura actual.

En `lib/servicios/notificaciones_locales_velia.dart`, `sincronizar` programa avisos del dispositivo para la rutina y las citas próximas.

En `lib/widgets/gesto_accesible.dart`, `_up` interpreta los toques: uno ejecuta la acción, dos leen el texto y tres detienen la lectura.

## Pantallas principales

Las pantallas de `lib/pantallas/` conectan botones y formularios con los servicios. Los nombres que empiezan con `_` son acciones internas de cada pantalla: por ejemplo, `_guardar` valida y guarda un formulario, `_eliminar` borra un registro y `_cargar` solicita los datos que se mostrarán.
