import 'dart:math';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../modelos/modelos_velia.dart';
import '../datos/frases_bonitas.dart';

class CuentaVelia {
  const CuentaVelia({
    required this.uid,
    required this.email,
    required this.rol,
    required this.nombre,
    this.telefono = '',
    this.parentesco = '',
    this.adultoId,
  });

  final String uid;
  final String email;
  final String rol;
  final String nombre;
  final String telefono;
  final String parentesco;
  final String? adultoId;

  factory CuentaVelia.fromMap(String uid, Map<String, dynamic> data) =>
      CuentaVelia(
        uid: uid,
        email: data['email'] as String? ?? '',
        rol: data['role'] as String? ?? 'family',
        nombre: data['nombre'] as String? ?? '',
        telefono: data['telefono'] as String? ?? '',
        parentesco: data['parentesco'] as String? ?? '',
        adultoId: data['adultId'] as String?,
      );
}

class ServicioNubeVelia extends ChangeNotifier {
  ServicioNubeVelia._();
  static final ServicioNubeVelia instancia = ServicioNubeVelia._();

  FirebaseAuth? _auth;
  FirebaseFirestore? _db;
  CuentaVelia? _cuenta;
  PerfilAdulto? _adultoSeleccionado;
  bool _inicializado = false;
  double _escalaTexto = 1.2;
  bool _altoContraste = true;

  bool get inicializado => _inicializado;
  double get escalaTexto => _escalaTexto;
  bool get altoContraste => _altoContraste;
  User? get usuarioAuth => _auth?.currentUser;
  CuentaVelia? get cuenta => _cuenta;
  PerfilAdulto? get adultoSeleccionado => _adultoSeleccionado;
  bool get esAdmin => _cuenta?.rol == 'admin';
  bool get esFamiliarPrincipal =>
      _cuenta?.rol == 'family' && _adultoSeleccionado?.ownerUid == _cuenta?.uid;
  FirebaseFirestore get _firestore => _db!;
  FirebaseAuth get _firebaseAuth => _auth!;

  /// Comprueba si la cuenta actual puede modificar el perfil del adulto.
  Future<bool> puedeEditarAdulto(String id) async {
    if (esAdmin) return true;
    final adulto = await obtenerAdulto(id);
    return _cuenta?.rol == 'family' && adulto?.ownerUid == _cuenta?.uid;
  }

  /// Conecta Firebase y recupera la sesión guardada en el dispositivo.
  Future<void> inicializar() async {
    _auth = FirebaseAuth.instance;
    _db = FirebaseFirestore.instance;
    _db!.settings = const Settings(persistenceEnabled: true);
    _inicializado = true;
    await cargarCuentaActual();
  }

  /// Carga la cuenta y el perfil adulto asociados a la sesión actual.
  Future<CuentaVelia?> cargarCuentaActual() async {
    final uid = usuarioAuth?.uid;
    if (uid == null) {
      _cuenta = null;
      _adultoSeleccionado = null;
      notifyListeners();
      return null;
    }
    final snapshot = await _firestore.collection('users').doc(uid).get();
    if (!snapshot.exists) {
      await _firebaseAuth.signOut();
      _cuenta = null;
      _adultoSeleccionado = null;
      notifyListeners();
      return null;
    }
    _cuenta = CuentaVelia.fromMap(uid, snapshot.data()!);
    if (_cuenta!.rol == 'adult') {
      final id = _cuenta!.adultoId;
      _adultoSeleccionado = id == null ? null : await obtenerAdulto(id);
    } else {
      final adultos = await listarAdultosDeCuenta(uid);
      _adultoSeleccionado = adultos.isEmpty ? null : adultos.first;
    }
    if (_adultoSeleccionado != null)
      await _cargarAccesibilidadLocal(_adultoSeleccionado!.id);
    notifyListeners();
    return _cuenta;
  }

  /// Registra una cuenta familiar y guarda sus datos básicos.
  Future<CuentaVelia> registrarFamiliar({
    required String email,
    required String contrasena,
    required String nombre,
    String telefono = '',
    String parentesco = '',
    String? codigoInvitacion,
  }) async {
    final credencial = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: contrasena,
    );
    final uid = credencial.user!.uid;
    final datos = {
      'role': 'family',
      'email': email.trim().toLowerCase(),
      'nombre': nombre.trim(),
      'telefono': telefono.trim(),
      'parentesco': parentesco.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    };
    await _firestore.collection('users').doc(uid).set(datos);
    _cuenta = CuentaVelia.fromMap(uid, datos);
    if (codigoInvitacion != null && codigoInvitacion.trim().isNotEmpty) {
      await aceptarInvitacion(codigoInvitacion.trim());
    }
    notifyListeners();
    return _cuenta!;
  }

  Future<CuentaVelia> iniciarSesionFamiliar(
      {required String email, required String contrasena}) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: contrasena,
    );
    final cuenta = await cargarCuentaActual();
    if (cuenta == null || (cuenta.rol != 'family' && cuenta.rol != 'admin')) {
      await _firebaseAuth.signOut();
      throw FirebaseAuthException(
          code: 'wrong-role',
          message: 'Esta cuenta no corresponde al familiar.');
    }
    return cuenta;
  }

  /// Inicia sesión del adulto con su PIN único.
  Future<CuentaVelia> iniciarSesionAdulto(String pin) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw FirebaseAuthException(
          code: 'invalid-pin', message: 'El PIN debe tener 6 dígitos.');
    }
    await _firebaseAuth.signInWithEmailAndPassword(
      email: _correoInternoAdulto(pin),
      password: pin,
    );
    final cuenta = await cargarCuentaActual();
    if (cuenta == null ||
        cuenta.rol != 'adult' ||
        _adultoSeleccionado == null) {
      await _firebaseAuth.signOut();
      throw FirebaseAuthException(
          code: 'invalid-pin', message: 'No se encontró el perfil de adulto.');
    }
    if (_adultoSeleccionado!.adultUid != cuenta.uid ||
        _adultoSeleccionado!.estado != 'active') {
      await _firebaseAuth.signOut();
      _cuenta = null;
      _adultoSeleccionado = null;
      throw FirebaseAuthException(
          code: 'invalid-pin', message: 'El PIN ya no está activo.');
    }
    return cuenta;
  }

  /// Crea el perfil del adulto y su cuenta de acceso con PIN.
  Future<PerfilAdulto> crearAdulto({
    required String nombre,
    DateTime? fechaNacimiento,
    List<String> padecimientos = const [],
    List<String> alergias = const [],
    List<ContactoEmergencia> contactos = const [],
  }) async {
    final principal = _cuenta;
    if (principal == null || (principal.rol != 'family' && !esAdmin)) {
      throw StateError(
          'Inicia sesión con una cuenta familiar para agregar un adulto.');
    }
    final adultoRef = _firestore.collection('adults').doc();
    final pinCredencial = await _crearCuentaAuthAdulto(adultoRef.id);
    final perfil = PerfilAdulto(
      id: adultoRef.id,
      nombre: nombre.trim(),
      fechaNacimiento: fechaNacimiento,
      padecimientos: padecimientos,
      alergias: alergias,
      contactos: contactos,
      ownerUid: principal.uid,
      adultUid: pinCredencial.uid,
    );
    final batch = _firestore.batch();
    batch.set(
        adultoRef,
        perfil.toMap(
          ownerUid: principal.uid,
          adultUid: pinCredencial.uid,
        ));
    batch.set(_firestore.collection('users').doc(pinCredencial.uid), {
      'role': 'adult',
      'nombre': nombre.trim(),
      'adultId': adultoRef.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(adultoRef.collection('private').doc('credentials'), {
      'pin': pinCredencial.pin,
      'loginEmail': _correoInternoAdulto(pinCredencial.pin),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _firestore
          .collection('users')
          .doc(principal.uid)
          .collection('adultLinks')
          .doc(adultoRef.id),
      {'adultId': adultoRef.id, 'role': 'owner', 'inviteId': null},
    );
    batch.set(adultoRef.collection('members').doc(principal.uid), {
      'uid': principal.uid,
      'role': 'owner',
      'nombre': principal.nombre,
      'email': principal.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
    for (var i = 0; i < frasesBonitasVelia.length; i++) {
      batch.set(
          adultoRef.collection('phrases').doc(i.toString().padLeft(3, '0')), {
        'texto': frasesBonitasVelia[i],
      });
    }
    await batch.commit();
    _adultoSeleccionado = perfil;
    notifyListeners();
    return perfil;
  }

  Future<({String pin, String uid})> _crearCuentaAuthAdulto(
      String adultId) async {
    final secondary = await Firebase.initializeApp(
      name: 'velia-adult-${adultId.substring(0, 8)}',
      options: Firebase.app().options,
    );
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondary);
    try {
      for (var intento = 0; intento < 8; intento++) {
        final pin = _generarPin();
        try {
          final user = await secondaryAuth.createUserWithEmailAndPassword(
            email: _correoInternoAdulto(pin),
            password: pin,
          );
          return (pin: pin, uid: user.user!.uid);
        } on FirebaseAuthException catch (error) {
          if (error.code != 'email-already-in-use') rethrow;
        }
      }
      throw StateError('No se pudo generar un PIN único. Inténtalo de nuevo.');
    } finally {
      await secondaryAuth.signOut();
      await secondary.delete();
    }
  }

  /// Devuelve el PIN del adulto al familiar principal.
  Future<String> consultarPin(String adultoId) async {
    final cuenta = _cuenta;
    if (cuenta == null) throw StateError('Inicia sesión primero.');
    final snapshot = await _firestore
        .collection('adults')
        .doc(adultoId)
        .collection('private')
        .doc('credentials')
        .get();
    final pin = snapshot.data()?['pin'] as String?;
    if (pin == null) throw StateError('El PIN no está disponible.');
    return pin;
  }

  /// Genera y guarda un PIN nuevo para el adulto.
  Future<String> restablecerPin(String adultoId) async {
    final cuenta = _cuenta;
    if (cuenta == null) throw StateError('Inicia sesión primero.');
    final adulto = await obtenerAdulto(adultoId);
    if (adulto == null || (adulto.ownerUid != cuenta.uid && !esAdmin)) {
      throw StateError('Solo el familiar principal puede renovar el PIN.');
    }
    final nueva = await _crearCuentaAuthAdulto(adultoId);
    final batch = _firestore.batch();
    batch.update(_firestore.collection('adults').doc(adultoId), {
      'adultUid': nueva.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_firestore.collection('users').doc(nueva.uid), {
      'role': 'adult',
      'nombre': adulto.nombre,
      'adultId': adultoId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
        _firestore
            .collection('adults')
            .doc(adultoId)
            .collection('private')
            .doc('credentials'),
        {
          'pin': nueva.pin,
          'loginEmail': _correoInternoAdulto(nueva.pin),
          'updatedAt': FieldValue.serverTimestamp(),
        });
    await batch.commit();
    return nueva.pin;
  }

  /// Lista los perfiles adultos asociados a una cuenta familiar.
  Future<List<PerfilAdulto>> listarAdultosDeCuenta(String uid) async {
    final links = await _firestore
        .collection('users')
        .doc(uid)
        .collection('adultLinks')
        .get();
    final results = <PerfilAdulto>[];
    for (final link in links.docs) {
      final adulto = await obtenerAdulto(link.id);
      if (adulto != null && adulto.estado == 'active') results.add(adulto);
    }
    results.sort((a, b) => a.nombre.compareTo(b.nombre));
    return results;
  }

  /// Lista los perfiles adultos disponibles para administración.
  Future<List<PerfilAdulto>> listarTodosLosAdultos() async {
    if (!esAdmin) throw StateError('Acceso solo para administración.');
    final docs = await _firestore.collection('adults').get();
    return docs.docs.map(PerfilAdulto.fromDocument).toList();
  }

  /// Busca un perfil adulto por su identificador.
  Future<PerfilAdulto?> obtenerAdulto(String id) async {
    final doc = await _firestore.collection('adults').doc(id).get();
    if (!doc.exists) return null;
    return PerfilAdulto.fromDocument(doc);
  }

  /// Define qué perfil adulto se mostrará en la sesión familiar.
  Future<void> seleccionarAdulto(String id) async {
    final perfil = await obtenerAdulto(id);
    if (perfil == null) throw StateError('No se encontró el perfil.');
    _adultoSeleccionado = perfil;
    await _cargarAccesibilidadLocal(id);
    notifyListeners();
  }

  /// Crea un código para invitar a otro familiar con acceso de consulta.
  Future<String> crearInvitacion(String adultoId) async {
    if (!await puedeEditarAdulto(adultoId)) {
      throw StateError('Solo el familiar principal puede invitar a otros.');
    }
    final code = _generarToken();
    await _firestore.collection('invitations').doc(code).set({
      'adultId': adultoId,
      'ownerUid': _cuenta!.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt':
          Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
      'redeemedBy': null,
      'redeemedAt': null,
    });
    return code;
  }

  /// Acepta el código y vincula al familiar invitado con el adulto.
  Future<void> aceptarInvitacion(String code) async {
    final uid = usuarioAuth?.uid;
    if (uid == null || _cuenta?.rol != 'family') {
      throw StateError(
          'Inicia sesión con la cuenta familiar que recibirá la invitación.');
    }
    final inviteRef = _firestore.collection('invitations').doc(code);
    await _firestore.runTransaction((tx) async {
      final invite = await tx.get(inviteRef);
      final data = invite.data();
      if (data == null || data['redeemedBy'] != null) {
        throw StateError('El código ya se usó o no existe.');
      }
      final expiry = (data['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiry)) throw StateError('El código venció.');
      final adultId = data['adultId'] as String;
      tx.update(inviteRef, {
        'redeemedBy': uid,
        'redeemedAt': FieldValue.serverTimestamp(),
      });
      tx.set(
          _firestore
              .collection('users')
              .doc(uid)
              .collection('adultLinks')
              .doc(adultId),
          {
            'adultId': adultId,
            'role': 'viewer',
            'inviteId': code,
          });
      tx.set(
          _firestore
              .collection('adults')
              .doc(adultId)
              .collection('members')
              .doc(uid),
          {
            'uid': uid,
            'role': 'viewer',
            'nombre': _cuenta!.nombre,
            'email': _cuenta!.email,
            'inviteId': code,
            'createdAt': FieldValue.serverTimestamp(),
          });
    });
    await cargarCuentaActual();
  }

  Future<void> desvincularFamiliar(String adultoId, String familiarUid) async {
    final adulto = await obtenerAdulto(adultoId);
    if (!esAdmin && (adulto == null || adulto.ownerUid != _cuenta?.uid)) {
      throw StateError('Solo el familiar principal puede quitar accesos.');
    }
    final batch = _firestore.batch();
    batch.delete(_firestore
        .collection('users')
        .doc(familiarUid)
        .collection('adultLinks')
        .doc(adultoId));
    batch.delete(_firestore
        .collection('adults')
        .doc(adultoId)
        .collection('members')
        .doc(familiarUid));
    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> listarFamiliaresVinculados(
      String adultoId) async {
    final adulto = await obtenerAdulto(adultoId);
    if (!esAdmin && (adulto == null || adulto.ownerUid != _cuenta?.uid)) {
      throw StateError('Solo el familiar principal puede administrar accesos.');
    }
    final docs = await _subcoleccion(adultoId, 'members').get();
    return docs.docs.map((d) => {'uid': d.id, ...d.data()}).toList();
  }

  /// Guarda los cambios del perfil adulto en Firestore.
  Future<void> guardarAdulto(PerfilAdulto perfil) async {
    if (!await puedeEditarAdulto(perfil.id)) {
      throw StateError('Solo el familiar principal puede editar este perfil.');
    }
    await _firestore.collection('adults').doc(perfil.id).update({
      'nombre': perfil.nombre,
      'fechaNacimiento': perfil.fechaNacimiento == null
          ? null
          : Timestamp.fromDate(perfil.fechaNacimiento!),
      'padecimientos': perfil.padecimientos,
      'alergias': perfil.alergias,
      'contactos': perfil.contactos.map((c) => c.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _adultoSeleccionado = perfil;
    notifyListeners();
  }

  /// Desactiva y archiva el perfil adulto.
  Future<void> archivarAdulto(String adultoId) async {
    if (!esAdmin) throw StateError('Acceso solo para administración.');
    await _firestore.collection('adults').doc(adultoId).update({
      'status': 'archived',
      'archivedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reactiva un perfil adulto archivado.
  Future<void> restaurarAdulto(String adultoId) async {
    if (!esAdmin) throw StateError('Acceso solo para administración.');
    await _firestore.collection('adults').doc(adultoId).update({
      'status': 'active',
      'archivedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  CollectionReference<Map<String, dynamic>> _subcoleccion(
          String adultoId, String nombre) =>
      _firestore.collection('adults').doc(adultoId).collection(nombre);

  /// Lee la rutina y los medicamentos guardados para el adulto.
  Future<List<ElementoRutina>> listarRutina(String adultoId) async {
    final docs = await _subcoleccion(adultoId, 'routine').get();
    return docs.docs.map(ElementoRutina.fromDocument).toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));
  }

  /// Escucha cambios de rutina y medicamentos en tiempo real.
  Stream<List<ElementoRutina>> escucharRutina(String adultoId) =>
      _subcoleccion(adultoId, 'routine').snapshots().map((snapshot) =>
          snapshot.docs.map(ElementoRutina.fromDocument).toList()
            ..sort((a, b) => a.nombre.compareTo(b.nombre)));

  /// Crea o actualiza una actividad de la rutina.
  Future<void> guardarRutina(String adultoId, ElementoRutina item) async {
    if (!await puedeEditarAdulto(adultoId))
      throw StateError('Sin permiso de edición.');
    await _subcoleccion(adultoId, 'routine').doc(item.id).set(item.toMap());
    await registrarHistorial(adultoId, 'rutina', 'Se guardó ${item.nombre}');
  }

  /// Elimina una actividad de la rutina del adulto.
  Future<void> eliminarRutina(String adultoId, String id) async {
    if (!await puedeEditarAdulto(adultoId))
      throw StateError('Sin permiso de edición.');
    await _subcoleccion(adultoId, 'routine').doc(id).delete();
  }

  /// Lee las citas guardadas para el adulto.
  Future<List<CitaVelia>> listarCitas(String adultoId) async {
    final docs = await _subcoleccion(adultoId, 'appointments').get();
    return docs.docs.map(CitaVelia.fromDocument).toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
  }

  /// Escucha cambios en las citas en tiempo real.
  Stream<List<CitaVelia>> escucharCitas(String adultoId) =>
      _subcoleccion(adultoId, 'appointments').snapshots().map((snapshot) =>
          snapshot.docs.map(CitaVelia.fromDocument).toList()
            ..sort((a, b) => a.fecha.compareTo(b.fecha)));

  /// Crea o actualiza una cita del calendario.
  Future<void> guardarCita(String adultoId, CitaVelia cita) async {
    if (!await puedeEditarAdulto(adultoId))
      throw StateError('Sin permiso de edición.');
    await _subcoleccion(adultoId, 'appointments')
        .doc(cita.id)
        .set(cita.toMap());
    await registrarHistorial(adultoId, 'cita', 'Se guardó ${cita.asunto}');
  }

  /// Elimina una cita del calendario.
  Future<void> eliminarCita(String adultoId, String id) async {
    if (!await puedeEditarAdulto(adultoId))
      throw StateError('Sin permiso de edición.');
    await _subcoleccion(adultoId, 'appointments').doc(id).delete();
  }

  Future<List<HorarioBienestar>> listarHorariosBienestar(
      String adultoId) async {
    final docs = await _subcoleccion(adultoId, 'checkInSchedules').get();
    return docs.docs.map(HorarioBienestar.fromDocument).toList();
  }

  Future<void> guardarHorarioBienestar(
      String adultoId, HorarioBienestar horario) async {
    if (!await puedeEditarAdulto(adultoId))
      throw StateError('Sin permiso de edición.');
    await _subcoleccion(adultoId, 'checkInSchedules')
        .doc(horario.id)
        .set(horario.toMap());
  }

  /// Guarda el aviso de bienestar y actualiza la racha del adulto.
  Future<Map<String, dynamic>> registrarEstoyBien(
      String adultoId, String horarioId) async {
    if (_cuenta?.rol != 'adult')
      throw StateError('Solo el adulto puede confirmar su bienestar.');
    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final schedules = await listarHorariosBienestar(adultoId);
    final scheduledToday = schedules
        .where((h) => h.activo && h.dias.contains(now.weekday))
        .toList();
    final checkIn =
        _subcoleccion(adultoId, 'checkIns').doc('${horarioId}_$dateKey');
    final history = _subcoleccion(adultoId, 'history').doc();
    final progress = _subcoleccion(adultoId, 'checkInState').doc('progress');
    final checkins = _subcoleccion(adultoId, 'checkIns');
    int streak = 0;
    bool streakIncreased = false;
    await _firestore.runTransaction((tx) async {
      final prior = await tx.get(checkIn);
      if (prior.exists)
        throw StateError('Ya avisaste que estás bien en este horario.');
      final dailyDocs = <String, bool>{};
      for (final schedule in scheduledToday) {
        if (schedule.id == horarioId) {
          dailyDocs[schedule.id] = true;
        } else {
          final ref = checkins.doc('${schedule.id}_$dateKey');
          dailyDocs[schedule.id] = (await tx.get(ref)).exists;
        }
      }
      final allDone =
          scheduledToday.isNotEmpty && dailyDocs.values.every((v) => v);
      final existingProgress = await tx.get(progress);
      final old = existingProgress.data() ?? <String, dynamic>{};
      streak = (old['streak'] as num?)?.toInt() ?? 0;
      final lastDate = old['lastCompleteDate'] as String?;
      if (allDone && lastDate != dateKey) {
        final yesterday = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 1));
        final yesterdayKey =
            '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
        streak = lastDate == yesterdayKey ? streak + 1 : 1;
        streakIncreased = true;
        tx.set(
            progress,
            {
              'streak': streak,
              'lastCompleteDate': dateKey,
              'updatedAt': FieldValue.serverTimestamp()
            },
            SetOptions(merge: true));
      }
      tx.set(checkIn, {
        'adultUid': usuarioAuth!.uid,
        'horarioId': horarioId,
        'dateKey': dateKey,
        'createdAt': Timestamp.fromDate(now),
        'punctual': true,
      });
      tx.set(history, {
        'tipo': 'bienestar',
        'detalle': 'Confirmación Estoy bien',
        'fecha': Timestamp.fromDate(now),
        'createdBy': usuarioAuth!.uid,
      });
    });
    return {'racha': streak, 'rachaAumento': streakIncreased};
  }

  /// Devuelve la cantidad actual de días seguidos con aviso a tiempo.
  Future<int> consultarRacha(String adultoId) async {
    final doc =
        await _subcoleccion(adultoId, 'checkInState').doc('progress').get();
    return (doc.data()?['streak'] as num?)?.toInt() ?? 0;
  }

  /// Devuelve la frase asignada al adulto para el día actual.
  Future<String> obtenerFraseBonitaDelDia(String adultoId) async {
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final state = _subcoleccion(adultoId, 'rewards').doc('dailyPhrase');
    final existing = await state.get();
    final data = existing.data();
    if (data?['dateKey'] == dateKey && data?['phrase'] is String) {
      return data!['phrase'] as String;
    }
    final phrases = await _subcoleccion(adultoId, 'phrases').get();
    if (phrases.docs.isEmpty)
      return 'Me alegra que hoy hayas avisado que estás bien.';
    final used = List<String>.from(data?['usedIds'] ?? const <String>[]);
    var available = phrases.docs.where((d) => !used.contains(d.id)).toList();
    final nextUsed = available.isEmpty ? <String>[] : used;
    if (available.isEmpty) available = phrases.docs;
    final selected = available[Random.secure().nextInt(available.length)];
    nextUsed.add(selected.id);
    final phrase = selected.data()['texto'] as String? ??
        'Gracias por compartir este momento.';
    await state.set({
      'dateKey': dateKey,
      'phraseId': selected.id,
      'phrase': phrase,
      'usedIds': nextUsed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return phrase;
  }

  Future<void> sincronizarAlertasBienestar(String adultoId) async {
    if (_cuenta?.rol != 'family' && !esAdmin) return;
    final now = DateTime.now();
    final schedules = await listarHorariosBienestar(adultoId);
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    for (final schedule
        in schedules.where((s) => s.activo && s.dias.contains(now.weekday))) {
      final parts = schedule.horaEsperada.split(':');
      final expected = DateTime(now.year, now.month, now.day,
          int.parse(parts[0]), int.parse(parts[1]));
      final checkIn = await _subcoleccion(adultoId, 'checkIns')
          .doc('${schedule.id}_$dateKey')
          .get();
      if (checkIn.exists) continue;
      for (final minutes in [5, 10]) {
        final due = expected.add(Duration(minutes: minutes));
        if (now.isBefore(due)) continue;
        final id = '${schedule.id}_${dateKey}_$minutes';
        final ref = _subcoleccion(adultoId, 'history').doc('retraso_$id');
        await ref.set({
          'tipo': minutes == 5 ? 'alerta_media' : 'alerta_grave',
          'detalle': minutes == 5
              ? 'Aviso Estoy bien pendiente desde hace 5 minutos.'
              : 'Aviso Estoy bien pendiente desde hace 10 minutos. Verifica personalmente cómo se encuentra.',
          'fecha': Timestamp.fromDate(due),
          'createdBy': usuarioAuth?.uid,
        }, SetOptions(merge: true));
      }
    }
  }

  /// Registra en el historial que se activó la opción de emergencia.
  Future<void> registrarEventoEmergencia(String adultoId) async {
    final uid = usuarioAuth?.uid;
    await _subcoleccion(adultoId, 'history').add({
      'tipo': 'emergencia',
      'detalle': 'Se activó el botón de emergencia',
      'fecha': Timestamp.fromDate(DateTime.now()),
      'createdBy': uid,
    });
  }

  Future<void> registrarHistorial(
      String adultoId, String tipo, String detalle) async {
    await _subcoleccion(adultoId, 'history').add({
      'tipo': tipo,
      'detalle': detalle,
      'fecha': Timestamp.fromDate(DateTime.now()),
      'createdBy': usuarioAuth?.uid,
    });
  }

  Future<List<Map<String, dynamic>>> listarHistorial(String adultoId) async {
    final docs = await _subcoleccion(adultoId, 'history')
        .orderBy('fecha', descending: true)
        .limit(500)
        .get();
    return docs.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Stream<List<Map<String, dynamic>>> escucharHistorial(String adultoId) =>
      _subcoleccion(adultoId, 'history')
          .orderBy('fecha', descending: true)
          .limit(500)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  Stream<(List<ElementoRutina>, List<CitaVelia>, List<Map<String, dynamic>>)>
      escucharResumen(String adultoId) {
    late final StreamController<
            (List<ElementoRutina>, List<CitaVelia>, List<Map<String, dynamic>>)>
        controller;
    StreamSubscription<List<ElementoRutina>>? routineSub;
    StreamSubscription<List<CitaVelia>>? appointmentsSub;
    StreamSubscription<List<Map<String, dynamic>>>? historySub;
    List<ElementoRutina>? routine;
    List<CitaVelia>? appointments;
    List<Map<String, dynamic>>? history;
    void publish() {
      if (routine != null && appointments != null && history != null) {
        controller.add((routine!, appointments!, history!));
      }
    }

    controller = StreamController(onListen: () {
      routineSub = escucharRutina(adultoId).listen((value) {
        routine = value;
        publish();
      }, onError: controller.addError);
      appointmentsSub = escucharCitas(adultoId).listen((value) {
        appointments = value;
        publish();
      }, onError: controller.addError);
      historySub = escucharHistorial(adultoId).listen((value) {
        history = value;
        publish();
      }, onError: controller.addError);
    }, onCancel: () async {
      await routineSub?.cancel();
      await appointmentsSub?.cancel();
      await historySub?.cancel();
    });
    return controller.stream;
  }

  Stream<(List<HorarioBienestar>, List<ElementoRutina>, List<CitaVelia>)>
      escucharDatosAdulto(String adultoId) {
    late final StreamController<
            (List<HorarioBienestar>, List<ElementoRutina>, List<CitaVelia>)>
        controller;
    StreamSubscription<List<HorarioBienestar>>? scheduleSub;
    StreamSubscription<List<ElementoRutina>>? routineSub;
    StreamSubscription<List<CitaVelia>>? appointmentsSub;
    List<HorarioBienestar>? schedules;
    List<ElementoRutina>? routine;
    List<CitaVelia>? appointments;
    void publish() {
      if (schedules != null && routine != null && appointments != null) {
        controller.add((schedules!, routine!, appointments!));
      }
    }

    controller = StreamController(onListen: () {
      scheduleSub = _subcoleccion(adultoId, 'checkInSchedules')
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map(HorarioBienestar.fromDocument).toList())
          .listen((value) {
        schedules = value;
        publish();
      }, onError: controller.addError);
      routineSub = escucharRutina(adultoId).listen((value) {
        routine = value;
        publish();
      }, onError: controller.addError);
      appointmentsSub = escucharCitas(adultoId).listen((value) {
        appointments = value;
        publish();
      }, onError: controller.addError);
    }, onCancel: () async {
      await scheduleSub?.cancel();
      await routineSub?.cancel();
      await appointmentsSub?.cancel();
    });
    return controller.stream;
  }

  /// Guarda el tamaño de texto y el contraste elegidos por el adulto.
  Future<void> guardarAccesibilidad(String adultoId,
      {double? escala, bool? altoContraste}) async {
    if (!await puedeEditarAdulto(adultoId) && _cuenta?.rol != 'adult') {
      throw StateError('La cuenta invitada solo puede consultar.');
    }
    final ref = _subcoleccion(adultoId, 'accessibility').doc('settings');
    await ref.set({
      if (escala != null) 'escalaTexto': escala,
      if (altoContraste != null) 'altoContraste': altoContraste,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': usuarioAuth?.uid,
    }, SetOptions(merge: true));
    if (escala != null) _escalaTexto = escala;
    if (altoContraste != null) _altoContraste = altoContraste;
    notifyListeners();
  }

  /// Lee las preferencias de accesibilidad guardadas para el adulto.
  Future<Map<String, dynamic>> cargarAccesibilidad(String adultoId) async {
    final doc =
        await _subcoleccion(adultoId, 'accessibility').doc('settings').get();
    final data = doc.data() ?? {'escalaTexto': 1.2, 'altoContraste': true};
    _escalaTexto = (data['escalaTexto'] as num?)?.toDouble() ?? 1.2;
    _altoContraste = data['altoContraste'] as bool? ?? true;
    notifyListeners();
    return data;
  }

  Future<void> _cargarAccesibilidadLocal(String adultoId) async {
    final doc =
        await _subcoleccion(adultoId, 'accessibility').doc('settings').get();
    final data = doc.data() ?? const <String, dynamic>{};
    _escalaTexto = (data['escalaTexto'] as num?)?.toDouble() ?? 1.2;
    _altoContraste = data['altoContraste'] as bool? ?? true;
  }

  /// Cierra Firebase y limpia los datos de la sesión actual.
  Future<void> cerrarSesion() async {
    await _firebaseAuth.signOut();
    _cuenta = null;
    _adultoSeleccionado = null;
    notifyListeners();
  }

  String _correoInternoAdulto(String pin) => 'adulto.$pin@velia.app';

  String _generarPin() =>
      List.generate(6, (_) => Random.secure().nextInt(10)).join();

  String _generarToken() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(24, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
