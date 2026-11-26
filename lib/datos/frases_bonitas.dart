const _iniciosFrase = <String>[
  'Me alegra que estés aquí.',
  'Tu presencia hace bien a quienes te quieren.',
  'Hoy también hay motivos pequeños para sonreír.',
  'Tu historia está llena de momentos valiosos.',
  'Mereces un día tranquilo y bonito.',
  'Hay mucho cariño alrededor de ti.',
  'Cada paso que das tiene valor.',
  'Tu manera de ser deja huellas lindas.',
  'Hoy puedes avanzar a tu propio ritmo.',
  'Qué bonito es compartir este día contigo.',
];

const _cierresFrase = <String>[
  'Tu compañía es un regalo para tu familia.',
  'No tienes que hacer todo de una vez.',
  'Siempre hay alguien que piensa en ti con cariño.',
  'Las cosas sencillas también llenan el corazón.',
  'Has superado mucho y sigues adelante.',
  'Tu sonrisa puede iluminar una habitación.',
  'Un momento de descanso también es un logro.',
  'Lo que eres importa mucho.',
  'Hoy es una nueva oportunidad para estar en calma.',
  'Eres querido tal como eres.',
];

/// Cien combinaciones que se guardan en Firestore para cada perfil adulto.
List<String> get frasesBonitasVelia => [
      for (final inicio in _iniciosFrase)
        for (final cierre in _cierresFrase) '$inicio $cierre',
    ];
