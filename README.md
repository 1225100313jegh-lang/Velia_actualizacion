# Velia

Velia es una app Flutter para coordinar el cuidado cotidiano de adultos mayores y su familia. La app usa Firebase Authentication y Cloud Firestore. No usa Cloud Functions ni notificaciones push.

## Roles y navegacion

- Familiar principal: crea su cuenta y configura uno o varios adultos, contactos, horarios, rutina, citas y accesibilidad.
- Adulto mayor: entra con el PIN que genera Velia. En una pantalla encuentra Estoy bien, rutina, citas y Emergencia.
- Familiar invitado: canjea un codigo de un solo uso que vence en 24 horas y tiene acceso de consulta.
- Administrador: consulta adultos agrupados por familiar y archiva o restaura perfiles.

El familiar conserva las pestanas Inicio, Horario y Calendario. Perfil y configuracion se abren desde el engrane.

## Firebase

El archivo android/app/google-services.json se asocia al paquete Android com.example.velia. Firebase Authentication y Cloud Firestore ya estan conectados al proyecto velia-1a9ea. La base estandar esta en northamerica-south1 (Mexico), y la configuracion Email/Password esta en firebase.json.

1. Ejecuta flutter pub get y flutter run.
2. Para publicar cambios de reglas: firebase deploy --only firestore:rules.
3. Para modificar los proveedores de acceso: edita firebase.json y ejecuta firebase deploy --only auth.

El proyecto esta en el plan Spark, sin metodo de pago asociado. Firebase incluye cuotas gratuitas; si se excede la cuota de un producto, su uso se interrumpe hasta el siguiente ciclo en vez de generar un cobro automatico. Consulta los limites vigentes antes de una demostracion.

## Datos y permisos

Firestore almacena perfiles, contactos, rutina, citas, horarios de bienestar, historial, accesibilidad, invitaciones, vinculos y las 100 frases del adulto. Firebase Auth conserva la sesion. El familiar principal edita; el adulto registra avisos y emergencias; familiares invitados consultan. Los perfiles archivados se conservan.

Cada adulto tiene un PIN de seis digitos generado automaticamente. El familiar principal puede consultarlo o renovarlo desde Perfil.

Los avisos de retraso a los cinco y diez minutos se registran para que la familia los vea al sincronizar. Sin push no llegan a otro telefono mientras Velia esta cerrada.

Los recordatorios de rutina y citas son locales para los siguientes siete dias. Velia los actualiza al abrirse o al cambiar datos en ese telefono. Emergencia registra el evento y en Android marca al contacto principal despues del permiso de llamada.

## Accesibilidad

El adulto tiene una vista vertical, texto ampliable, alto contraste ajustable y lectura en voz alta. Se respeta TalkBack. Un toque activa, dos leen y tres detienen la lectura en las acciones y tarjetas principales. El boton Estoy bien se ve gris fuera del periodo que configura la familia.

## Carpetas principales

- lib/servicios/servicio_nube_velia.dart: Authentication, Firestore y sincronizacion.
- lib/servicios/notificaciones_locales_velia.dart: recordatorios locales.
- lib/servicios/servicio_lectura_velia.dart: lectura TTS.
- lib/modelos/modelos_velia.dart: perfiles, contactos, rutina, horarios y citas.
- lib/pantallas/: acceso, registro, navegacion, ajustes y administracion.
- lib/config/firebase_options.dart: opciones Firebase Android.
- firestore.rules: permisos de Firestore.

Las capturas que ya estan en screenshots corresponden a la version anterior y deben actualizarse.
