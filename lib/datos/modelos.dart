// Modelos de GluControl.
//
// Las fechas se guardan como texto 'aaaa-mm-dd' y las horas como 'hh:mm',
// igual que en la versión HTML: así los backups antiguos se importan tal
// cual y ordenar por fecha es ordenar texto.

String _s(Map m, String k, [String d = '']) {
  final v = m[k];
  if (v == null) return d;
  return v.toString();
}

int? _i(Map m, String k) {
  final v = m[k];
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse(v.toString().trim());
}

double? _d(Map m, String k) {
  final v = m[k];
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().trim().replaceAll(',', '.'));
}

List<String> _ls(Map m, String k) {
  final v = m[k];
  if (v is List) return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  if (v is String && v.trim().isNotEmpty) {
    return v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
  return [];
}

/// Quita las claves nulas para no llenar Firestore de campos vacíos.
Map<String, dynamic> _limpio(Map<String, dynamic> m) =>
    Map.of(m)..removeWhere((k, v) => v == null || (v is String && v.isEmpty && k != 'notas'));

/// Fecha+hora de un registro como DateTime (para ordenar y comparar).
DateTime momentoDe(String fecha, String hora) {
  final f = DateTime.tryParse(fecha) ?? DateTime(2000);
  final p = hora.split(':');
  final h = p.isNotEmpty ? int.tryParse(p[0]) ?? 0 : 0;
  final mi = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
  return DateTime(f.year, f.month, f.day, h, mi);
}

/// Base común: id del documento en Firestore.
abstract class Registro {
  String id;
  Registro(this.id);
  Map<String, dynamic> aMapa();
}

// ─── Glucemia ──────────────────────────────────────────────────────────────

class Momento {
  final String clave, nombre, corto;
  const Momento(this.clave, this.nombre, this.corto);

  static const lista = [
    Momento('ayunas', 'En ayunas', 'Ayunas'),
    Momento('antes_desayuno', 'Antes del desayuno', 'A. desayuno'),
    Momento('despues_desayuno', 'Después del desayuno', 'D. desayuno'),
    Momento('antes_comida', 'Antes de comer', 'A. comida'),
    Momento('despues_comida', 'Después de comer', 'D. comida'),
    Momento('antes_cena', 'Antes de cenar', 'A. cena'),
    Momento('despues_cena', 'Después de cenar', 'D. cena'),
    Momento('antes_dormir', 'Antes de dormir', 'A. dormir'),
    Momento('noche', 'De madrugada', 'Madrugada'),
    Momento('otro', 'Otro momento', 'Otro'),
  ];

  static Momento de(String clave) =>
      lista.firstWhere((m) => m.clave == clave, orElse: () => Momento(clave, clave, clave));

  bool get esDespues => clave.startsWith('despues_');

  /// Sugerencia de momento según la hora del día (al abrir "Nueva medición").
  static String sugerido(DateTime t) {
    final h = t.hour + t.minute / 60;
    if (h < 5) return 'noche';
    if (h < 9) return 'ayunas';
    if (h < 11.5) return 'despues_desayuno';
    if (h < 14) return 'antes_comida';
    if (h < 17.5) return 'despues_comida';
    if (h < 21) return 'antes_cena';
    if (h < 23) return 'despues_cena';
    return 'antes_dormir';
  }
}

class Lectura extends Registro {
  String fecha, hora, momento, notas;
  int valor;
  Lectura(super.id,
      {required this.fecha,
      required this.hora,
      required this.momento,
      required this.valor,
      this.notas = ''});

  DateTime get cuando => momentoDe(fecha, hora);

  factory Lectura.deMapa(String id, Map m) => Lectura(id,
      fecha: _s(m, 'fecha'),
      hora: _s(m, 'hora', '00:00'),
      momento: _s(m, 'momento', 'otro'),
      valor: _i(m, 'valor') ?? 0,
      notas: _s(m, 'notas'));

  @override
  Map<String, dynamic> aMapa() => _limpio(
      {'fecha': fecha, 'hora': hora, 'momento': momento, 'valor': valor, 'notas': notas});
}

class Hba1c extends Registro {
  String fecha, centro, notas;
  double valor;
  Hba1c(super.id, {required this.fecha, required this.valor, this.centro = '', this.notas = ''});

  factory Hba1c.deMapa(String id, Map m) => Hba1c(id,
      fecha: _s(m, 'fecha'),
      valor: _d(m, 'valor') ?? 0,
      centro: _s(m, 'centro'),
      notas: _s(m, 'notas'));

  @override
  Map<String, dynamic> aMapa() =>
      _limpio({'fecha': fecha, 'valor': valor, 'centro': centro, 'notas': notas});
}

// ─── Peso y tensión ────────────────────────────────────────────────────────

class Vital extends Registro {
  String fecha, hora;
  double? peso;
  int? ts, td, pulso;
  Vital(super.id, {required this.fecha, required this.hora, this.peso, this.ts, this.td, this.pulso});

  DateTime get cuando => momentoDe(fecha, hora);

  factory Vital.deMapa(String id, Map m) => Vital(id,
      fecha: _s(m, 'fecha'),
      hora: _s(m, 'hora', '00:00'),
      peso: _d(m, 'peso'),
      ts: _i(m, 'ts'),
      td: _i(m, 'td'),
      pulso: _i(m, 'pulso'));

  @override
  Map<String, dynamic> aMapa() => _limpio(
      {'fecha': fecha, 'hora': hora, 'peso': peso, 'ts': ts, 'td': td, 'pulso': pulso});
}

// ─── Alimentación ──────────────────────────────────────────────────────────

class TipoComida {
  final String clave, nombre;
  const TipoComida(this.clave, this.nombre);
  static const lista = [
    TipoComida('desayuno', 'Desayuno'),
    TipoComida('almuerzo', 'Media mañana'),
    TipoComida('comida', 'Comida'),
    TipoComida('merienda', 'Merienda'),
    TipoComida('cena', 'Cena'),
    TipoComida('otro', 'Otro'),
  ];
  static String nombreDe(String c) =>
      lista.firstWhere((t) => t.clave == c, orElse: () => TipoComida(c, c)).nombre;

  static String sugerido(DateTime t) {
    final h = t.hour;
    if (h < 11) return 'desayuno';
    if (h < 13) return 'almuerzo';
    if (h < 17) return 'comida';
    if (h < 20) return 'merienda';
    return 'cena';
  }
}

class Comida extends Registro {
  String fecha, hora, tipo, alimentos, ig, notas;
  int kcal;
  int? hc; // gramos de hidratos (nuevo en la v10)
  Comida(super.id,
      {required this.fecha,
      required this.hora,
      required this.tipo,
      required this.alimentos,
      this.kcal = 0,
      this.hc,
      this.ig = 'medio',
      this.notas = ''});

  DateTime get cuando => momentoDe(fecha, hora);

  factory Comida.deMapa(String id, Map m) => Comida(id,
      fecha: _s(m, 'fecha'),
      hora: _s(m, 'hora', '00:00'),
      tipo: _s(m, 'tipo', 'otro'),
      alimentos: _s(m, 'alimentos'),
      kcal: _i(m, 'kcal') ?? 0,
      hc: _i(m, 'hc'),
      ig: _s(m, 'ig', 'medio'),
      notas: _s(m, 'notas'));

  @override
  Map<String, dynamic> aMapa() => _limpio({
        'fecha': fecha,
        'hora': hora,
        'tipo': tipo,
        'alimentos': alimentos,
        'kcal': kcal,
        'hc': hc,
        'ig': ig,
        'notas': notas
      });
}

// ─── Medicación ────────────────────────────────────────────────────────────

class Medicamento extends Registro {
  String nombre, dosis, tipo, notas;
  List<String> horarios;
  int stock, alerta;
  bool avisar; // notificación a cada horario (nuevo en la v10)
  Medicamento(super.id,
      {required this.nombre,
      this.dosis = '',
      this.tipo = 'Comprimido',
      this.horarios = const [],
      this.stock = 0,
      this.alerta = 10,
      this.notas = '',
      this.avisar = false});

  /// Días que quedan al ritmo de sus horarios.
  int get diasRestantes => horarios.isEmpty ? stock : stock ~/ horarios.length;
  bool get agotado => stock <= 0;
  bool get stockBajo => !agotado && stock <= alerta;

  factory Medicamento.deMapa(String id, Map m) => Medicamento(id,
      nombre: _s(m, 'nombre'),
      dosis: _s(m, 'dosis'),
      tipo: _s(m, 'tipo', 'Comprimido'),
      horarios: _ls(m, 'horarios'),
      stock: _i(m, 'stock') ?? 0,
      alerta: _i(m, 'alerta') ?? 10,
      notas: _s(m, 'notas'),
      avisar: m['avisar'] == true);

  @override
  Map<String, dynamic> aMapa() => {
        'nombre': nombre,
        'dosis': dosis,
        'tipo': tipo,
        'horarios': horarios,
        'stock': stock,
        'alerta': alerta,
        'notas': notas,
        'avisar': avisar,
      };
}

class Toma extends Registro {
  String medId, nombre, dosis, fecha, hora;
  String horario; // a qué horario corresponde ('08:00'), vacío si es suelta
  Toma(super.id,
      {required this.medId,
      required this.nombre,
      this.dosis = '',
      required this.fecha,
      required this.hora,
      this.horario = ''});

  DateTime get cuando => momentoDe(fecha, hora);

  factory Toma.deMapa(String id, Map m) => Toma(id,
      medId: _s(m, 'medId'),
      nombre: _s(m, 'nombre'),
      dosis: _s(m, 'dosis'),
      fecha: _s(m, 'fecha'),
      hora: _s(m, 'hora', '00:00'),
      horario: _s(m, 'horario'));

  @override
  Map<String, dynamic> aMapa() => _limpio({
        'medId': medId,
        'nombre': nombre,
        'dosis': dosis,
        'fecha': fecha,
        'hora': hora,
        'horario': horario
      });
}

// ─── Recordatorios ─────────────────────────────────────────────────────────

class Recordatorio extends Registro {
  String nombre, hora, tipo;
  List<int> dias; // 0 = domingo ... 6 = sábado (como en JS)
  bool activo;
  Recordatorio(super.id,
      {required this.nombre,
      required this.hora,
      this.tipo = 'otro',
      this.dias = const [0, 1, 2, 3, 4, 5, 6],
      this.activo = true});

  factory Recordatorio.deMapa(String id, Map m) => Recordatorio(id,
      nombre: _s(m, 'nombre'),
      hora: _s(m, 'hora', '09:00'),
      tipo: _s(m, 'tipo', 'otro'),
      dias: (m['dias'] is List)
          ? (m['dias'] as List).map((e) => int.tryParse(e.toString()) ?? -1).where((e) => e >= 0 && e <= 6).toList()
          : [0, 1, 2, 3, 4, 5, 6],
      activo: m['activo'] != false);

  @override
  Map<String, dynamic> aMapa() =>
      {'nombre': nombre, 'hora': hora, 'tipo': tipo, 'dias': dias, 'activo': activo};
}

// ─── Citas, informes y contactos ───────────────────────────────────────────

class Cita extends Registro {
  String fecha, hora, tipo, especialista, notas;
  Cita(super.id,
      {required this.fecha, required this.hora, this.tipo = 'med', this.especialista = '', this.notas = ''});

  DateTime get cuando => momentoDe(fecha, hora);

  factory Cita.deMapa(String id, Map m) => Cita(id,
      fecha: _s(m, 'fecha'),
      hora: _s(m, 'hora', '09:00'),
      tipo: _s(m, 'tipo', 'med'),
      especialista: _s(m, 'especialista'),
      notas: _s(m, 'notas'));

  @override
  Map<String, dynamic> aMapa() => _limpio(
      {'fecha': fecha, 'hora': hora, 'tipo': tipo, 'especialista': especialista, 'notas': notas});

  static const tipos = {'med': 'Médico/a', 'enf': 'Enfermería', 'ana': 'Análisis', 'otro': 'Otro'};
}

class Informe extends Registro {
  String titulo, fecha, tipo, medico, contenido;
  String? foto; // JPEG en base64, comprimido
  Informe(super.id,
      {required this.titulo,
      required this.fecha,
      this.tipo = 'analisis',
      this.medico = '',
      this.contenido = '',
      this.foto});

  factory Informe.deMapa(String id, Map m) {
    var foto = m['foto']?.toString();
    if (foto != null && foto.startsWith('data:')) {
      final coma = foto.indexOf(',');
      foto = coma >= 0 ? foto.substring(coma + 1) : null;
    }
    return Informe(id,
        titulo: _s(m, 'titulo'),
        fecha: _s(m, 'fecha'),
        tipo: _s(m, 'tipo', 'analisis'),
        medico: _s(m, 'medico'),
        contenido: _s(m, 'contenido'),
        foto: (foto == null || foto.isEmpty) ? null : foto);
  }

  @override
  Map<String, dynamic> aMapa() => _limpio({
        'titulo': titulo,
        'fecha': fecha,
        'tipo': tipo,
        'medico': medico,
        'contenido': contenido,
        'foto': foto
      });

  static const tipos = {'analisis': 'Análisis', 'prueba': 'Prueba diagnóstica', 'cita': 'Resumen de cita'};
}

class Contacto extends Registro {
  String nombre, tel, tipo, rel;
  Contacto(super.id, {required this.nombre, required this.tel, this.tipo = 'fam', this.rel = ''});

  factory Contacto.deMapa(String id, Map m) =>
      Contacto(id, nombre: _s(m, 'nombre'), tel: _s(m, 'tel'), tipo: _s(m, 'tipo', 'fam'), rel: _s(m, 'rel'));

  @override
  Map<String, dynamic> aMapa() => _limpio({'nombre': nombre, 'tel': tel, 'tipo': tipo, 'rel': rel});

  static const tipos = {'med': 'Médico/a', 'fam': 'Familiar', 'urg': 'Urgencias'};
}

// ─── Perfil y ajustes (un solo documento) ──────────────────────────────────

class Perfil {
  String nombre, tipo, fechaNac, medico;
  double? altura, pesoObjetivo;
  int metaMin, metaMax;
  double metaHba;
  int horasAviso; // aviso "llevas X h sin medir" (0 = nunca)
  String modeloIA;

  Perfil({
    this.nombre = '',
    this.tipo = 'Tipo 2',
    this.fechaNac = '',
    this.medico = '',
    this.altura,
    this.pesoObjetivo,
    this.metaMin = 70,
    this.metaMax = 180,
    this.metaHba = 7,
    this.horasAviso = 8,
    this.modeloIA = modeloIAPorDefecto,
  });

  static const modeloIAPorDefecto = 'claude-sonnet-5-5';

  factory Perfil.deMapa(Map m) => Perfil(
        nombre: _s(m, 'nombre'),
        tipo: _s(m, 'tipo', 'Tipo 2'),
        fechaNac: _s(m, 'fechaNac'),
        medico: _s(m, 'medico'),
        altura: _d(m, 'altura'),
        pesoObjetivo: _d(m, 'pesoObjetivo'),
        metaMin: _i(m, 'metaMin') ?? 70,
        metaMax: _i(m, 'metaMax') ?? 180,
        metaHba: _d(m, 'metaHba') ?? 7,
        horasAviso: _i(m, 'horasAviso') ?? 8,
        modeloIA: _s(m, 'modeloIA', modeloIAPorDefecto),
      );

  Map<String, dynamic> aMapa() => {
        'nombre': nombre,
        'tipo': tipo,
        'fechaNac': fechaNac,
        'medico': medico,
        'altura': altura,
        'pesoObjetivo': pesoObjetivo,
        'metaMin': metaMin,
        'metaMax': metaMax,
        'metaHba': metaHba,
        'horasAviso': horasAviso,
        'modeloIA': modeloIA,
      };

  double? imc(double? peso) {
    if (peso == null || altura == null || altura! <= 0) return null;
    final m = altura! / 100;
    return (peso / (m * m) * 10).round() / 10;
  }
}
