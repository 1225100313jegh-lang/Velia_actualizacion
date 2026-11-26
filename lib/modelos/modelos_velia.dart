import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoRutina { medicamento, actividad }

enum ModoHorario { horasFijas, intervalo }

enum EstadoCita { programada, realizada, cancelada, reprogramada }

class ContactoEmergencia {
  const ContactoEmergencia({
    required this.nombre,
    required this.telefono,
    required this.parentesco,
    this.principal = false,
  });

  final String nombre;
  final String telefono;
  final String parentesco;
  final bool principal;

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'telefono': telefono,
        'parentesco': parentesco,
        'principal': principal,
      };

  factory ContactoEmergencia.fromMap(Map<String, dynamic> map) =>
      ContactoEmergencia(
        nombre: map['nombre'] as String? ?? '',
        telefono: map['telefono'] as String? ?? '',
        parentesco: map['parentesco'] as String? ?? '',
        principal: map['principal'] as bool? ?? false,
      );
}

class PerfilAdulto {
  const PerfilAdulto({
    required this.id,
    required this.nombre,
    this.fechaNacimiento,
    this.padecimientos = const [],
    this.alergias = const [],
    this.contactos = const [],
    this.estado = 'active',
    this.ownerUid = '',
    this.adultUid = '',
  });

  final String id;
  final String nombre;
  final DateTime? fechaNacimiento;
  final List<String> padecimientos;
  final List<String> alergias;
  final List<ContactoEmergencia> contactos;
  final String estado;
  final String ownerUid;
  final String adultUid;

  factory PerfilAdulto.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final nacimiento = data['fechaNacimiento'];
    return PerfilAdulto(
      id: doc.id,
      nombre: data['nombre'] as String? ?? '',
      fechaNacimiento: nacimiento is Timestamp ? nacimiento.toDate() : null,
      padecimientos: List<String>.from(data['padecimientos'] ?? const []),
      alergias: List<String>.from(data['alergias'] ?? const []),
      contactos: (data['contactos'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ContactoEmergencia.fromMap)
          .toList(),
      estado: data['status'] as String? ?? 'active',
      ownerUid: data['ownerUid'] as String? ?? '',
      adultUid: data['adultUid'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap(
          {required String ownerUid, required String adultUid}) =>
      {
        'nombre': nombre,
        'fechaNacimiento': fechaNacimiento == null
            ? null
            : Timestamp.fromDate(fechaNacimiento!),
        'padecimientos': padecimientos,
        'alergias': alergias,
        'contactos': contactos.map((c) => c.toMap()).toList(),
        'status': estado,
        'ownerUid': ownerUid,
        'adultUid': adultUid,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class ElementoRutina {
  const ElementoRutina({
    required this.id,
    required this.tipo,
    required this.nombre,
    this.dosis = '',
    this.modo = ModoHorario.horasFijas,
    this.horas = const [],
    this.intervaloHoras,
    this.horaInicio,
    this.dias = const [1, 2, 3, 4, 5, 6, 7],
    this.fechaInicio,
    this.fechaFin,
    this.periodoIndeterminado = false,
    this.activo = true,
  });

  final String id;
  final TipoRutina tipo;
  final String nombre;
  final String dosis;
  final ModoHorario modo;
  final List<String> horas;
  final int? intervaloHoras;
  final String? horaInicio;
  final List<int> dias;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final bool periodoIndeterminado;
  final bool activo;

  factory ElementoRutina.fromDocument(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final inicio = d['fechaInicio'];
    final fin = d['fechaFin'];
    return ElementoRutina(
      id: doc.id,
      tipo: d['tipo'] == 'medicamento'
          ? TipoRutina.medicamento
          : TipoRutina.actividad,
      nombre: d['nombre'] as String? ?? '',
      dosis: d['dosis'] as String? ?? '',
      modo: d['modo'] == 'intervalo'
          ? ModoHorario.intervalo
          : ModoHorario.horasFijas,
      horas: List<String>.from(d['horas'] ?? const []),
      intervaloHoras: d['intervaloHoras'] as int?,
      horaInicio: d['horaInicio'] as String?,
      dias: List<int>.from(d['dias'] ?? const [1, 2, 3, 4, 5, 6, 7]),
      fechaInicio: inicio is Timestamp ? inicio.toDate() : null,
      fechaFin: fin is Timestamp ? fin.toDate() : null,
      periodoIndeterminado: d['periodoIndeterminado'] as bool? ?? false,
      activo: d['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'tipo': tipo.name,
        'nombre': nombre,
        'dosis': dosis,
        'modo': modo.name,
        'horas': horas,
        'intervaloHoras': intervaloHoras,
        'horaInicio': horaInicio,
        'dias': dias,
        'fechaInicio':
            fechaInicio == null ? null : Timestamp.fromDate(fechaInicio!),
        'fechaFin': fechaFin == null ? null : Timestamp.fromDate(fechaFin!),
        'periodoIndeterminado': periodoIndeterminado,
        'activo': activo,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class HorarioBienestar {
  const HorarioBienestar({
    required this.id,
    required this.horaEsperada,
    required this.inicioActivo,
    required this.finActivo,
    this.dias = const [1, 2, 3, 4, 5, 6, 7],
    this.activo = true,
  });

  final String id;
  final String horaEsperada;
  final String inicioActivo;
  final String finActivo;
  final List<int> dias;
  final bool activo;

  factory HorarioBienestar.fromDocument(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return HorarioBienestar(
      id: doc.id,
      horaEsperada: data['horaEsperada'] as String? ?? '08:00',
      inicioActivo: data['inicioActivo'] as String? ?? '07:30',
      finActivo: data['finActivo'] as String? ?? '08:10',
      dias: List<int>.from(data['dias'] ?? const [1, 2, 3, 4, 5, 6, 7]),
      activo: data['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'horaEsperada': horaEsperada,
        'inicioActivo': inicioActivo,
        'finActivo': finActivo,
        'dias': dias,
        'activo': activo,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class CitaVelia {
  const CitaVelia({
    required this.id,
    required this.asunto,
    required this.fecha,
    this.recordatorioDias = 1,
    this.estado = EstadoCita.programada,
    this.recurring = false,
    this.reglaRecurrencia = '',
  });

  final String id;
  final String asunto;
  final DateTime fecha;
  final int recordatorioDias;
  final EstadoCita estado;
  final bool recurring;
  final String reglaRecurrencia;

  factory CitaVelia.fromDocument(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final timestamp = data['fecha'];
    return CitaVelia(
      id: doc.id,
      asunto: data['asunto'] as String? ?? '',
      fecha: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      recordatorioDias: data['recordatorioDias'] as int? ?? 1,
      estado: EstadoCita.values.firstWhere(
        (e) => e.name == data['estado'],
        orElse: () => EstadoCita.programada,
      ),
      recurring: data['recurrente'] as bool? ?? false,
      reglaRecurrencia: data['reglaRecurrencia'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'asunto': asunto,
        'fecha': Timestamp.fromDate(fecha),
        'recordatorioDias': recordatorioDias,
        'estado': estado.name,
        'recurrente': recurring,
        'reglaRecurrencia': reglaRecurrencia,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
