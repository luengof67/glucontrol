import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../services/fb.dart';
import '../services/imagenes.dart';
import 'modelos.dart';

/// Nombres de las colecciones dentro de `glucontrol/{uid}`.
class Col {
  static const lecturas = 'lecturas';
  static const hba1c = 'hba1c';
  static const vitales = 'vitales';
  static const comidas = 'comidas';
  static const medicamentos = 'medicamentos';
  static const tomas = 'tomas';
  static const recordatorios = 'recordatorios';
  static const citas = 'citas';
  static const informes = 'informes';
  static const contactos = 'contactos';
  static const todas = [
    lecturas, hba1c, vitales, comidas, medicamentos, tomas,
    recordatorios, citas, informes, contactos,
  ];
}

/// Todos los datos del usuario, siempre al día.
///
/// - Escucha Firestore en tiempo real: lo que se apunta en el móvil aparece
///   en el PC al momento, y al revés.
/// - Guarda una copia en un archivo del dispositivo para abrir la app sin
///   conexión (en Windows Firestore va sin copia local, ver Fb).
/// - Al guardar no espera a que llegue al servidor: Firestore lo enseña al
///   instante y lo sube cuando puede.
class Datos extends ChangeNotifier {
  Datos._();
  static final Datos i = Datos._();

  String? uid;
  Perfil perfil = Perfil();
  List<Lectura> lecturas = [];
  List<Hba1c> hba1c = [];
  List<Vital> vitales = [];
  List<Comida> comidas = [];
  List<Medicamento> medicamentos = [];
  List<Toma> tomas = [];
  List<Recordatorio> recordatorios = [];
  List<Cita> citas = [];
  List<Informe> informes = [];
  List<Contacto> contactos = [];

  /// Último error de Firebase (p. ej. faltan las reglas de seguridad).
  String? error;

  /// ¿Ha llegado ya algo (de la copia local o de Firebase)?
  bool listo = false;
  bool _deServidor = false;
  bool get sincronizado => _deServidor;

  final _subs = <StreamSubscription>[];
  final Map<String, Map<String, Map<String, dynamic>>> _crudo = {};
  Map<String, dynamic> _perfilCrudo = {};
  Timer? _temporizadorCache;

  DocumentReference<Map<String, dynamic>> get _raiz =>
      Fb.db.collection('glucontrol').doc(uid);
  CollectionReference<Map<String, dynamic>> col(String c) => _raiz.collection(c);

  // ─── Arranque y parada ──────────────────────────────────────────────────

  Future<void> iniciar(String nuevoUid) async {
    if (uid == nuevoUid && _subs.isNotEmpty) return;
    await parar();
    uid = nuevoUid;
    await _leerCache();
    _escuchar();
  }

  Future<void> parar() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _temporizadorCache?.cancel();
    uid = null;
    _deServidor = false;
    listo = false;
  }

  void _escuchar() {
    _subs.add(_raiz.snapshots().listen((d) {
      _perfilCrudo = d.data() ?? {};
      perfil = Perfil.deMapa(_perfilCrudo);
      _deServidor = true;
      _cambio();
    }, onError: _fallo));
    for (final c in Col.todas) {
      _subs.add(col(c).snapshots().listen((q) {
        _crudo[c] = {for (final d in q.docs) d.id: d.data()};
        _aplicar(c);
        _deServidor = true;
        error = null;
        _cambio();
      }, onError: _fallo));
    }
  }

  void _fallo(Object e) {
    final t = e.toString();
    error = t.contains('permission-denied')
        ? 'Firebase no deja leer los datos de GluControl: faltan las reglas de '
            'seguridad de la colección "glucontrol" (ver README).'
        : 'Error de conexión con Firebase: $t';
    notifyListeners();
  }

  /// Convierte los datos crudos de una colección en su lista ordenada.
  void _aplicar(String c) {
    final m = _crudo[c] ?? {};
    List<T> lista<T>(T Function(String, Map) f) =>
        [for (final e in m.entries) f(e.key, e.value)];
    switch (c) {
      case Col.lecturas:
        lecturas = lista(Lectura.deMapa)..sort((a, b) => b.cuando.compareTo(a.cuando));
      case Col.hba1c:
        hba1c = lista(Hba1c.deMapa)..sort((a, b) => b.fecha.compareTo(a.fecha));
      case Col.vitales:
        vitales = lista(Vital.deMapa)..sort((a, b) => b.cuando.compareTo(a.cuando));
      case Col.comidas:
        comidas = lista(Comida.deMapa)..sort((a, b) => b.cuando.compareTo(a.cuando));
      case Col.medicamentos:
        medicamentos = lista(Medicamento.deMapa)
          ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      case Col.tomas:
        tomas = lista(Toma.deMapa)..sort((a, b) => b.cuando.compareTo(a.cuando));
      case Col.recordatorios:
        recordatorios = lista(Recordatorio.deMapa)..sort((a, b) => a.hora.compareTo(b.hora));
      case Col.citas:
        citas = lista(Cita.deMapa)..sort((a, b) => a.cuando.compareTo(b.cuando));
      case Col.informes:
        informes = lista(Informe.deMapa)..sort((a, b) => b.fecha.compareTo(a.fecha));
      case Col.contactos:
        contactos = lista(Contacto.deMapa)..sort((a, b) => a.nombre.compareTo(b.nombre));
    }
  }

  void _cambio() {
    listo = true;
    notifyListeners();
    _temporizadorCache?.cancel();
    _temporizadorCache = Timer(const Duration(seconds: 2), _escribirCache);
  }

  // ─── Copia local ────────────────────────────────────────────────────────

  Future<File?> _archivoCache() async {
    if (kIsWeb || uid == null) return null;
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}glucontrol_$uid.json');
  }

  Future<void> _leerCache() async {
    try {
      final f = await _archivoCache();
      if (f == null || !await f.exists()) return;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      _perfilCrudo = Map<String, dynamic>.from(j['perfil'] ?? {});
      perfil = Perfil.deMapa(_perfilCrudo);
      final cols = Map<String, dynamic>.from(j['cols'] ?? {});
      for (final c in Col.todas) {
        final m = Map<String, dynamic>.from(cols[c] ?? {});
        _crudo[c] = {for (final e in m.entries) e.key: Map<String, dynamic>.from(e.value)};
        _aplicar(c);
      }
      listo = true;
      notifyListeners();
    } catch (_) {
      // Copia dañada: se ignora, Firebase la rehace.
    }
  }

  Future<void> _escribirCache() async {
    if (!_deServidor) return; // no machacar la copia con datos a medias
    try {
      final f = await _archivoCache();
      if (f == null) return;
      await f.writeAsString(jsonEncode({'perfil': _perfilCrudo, 'cols': _crudo}));
    } catch (_) {}
  }

  // ─── Guardar y borrar ───────────────────────────────────────────────────

  /// Guarda (alta o edición). Devuelve el id.
  String guardar(String c, Registro r) {
    final ref = r.id.isEmpty ? col(c).doc() : col(c).doc(r.id);
    r.id = ref.id;
    ref.set(r.aMapa()).catchError(_fallo);
    return r.id;
  }

  void borrar(String c, String id) {
    col(c).doc(id).delete().catchError(_fallo);
  }

  void guardarPerfil() {
    _raiz.set(perfil.aMapa(), SetOptions(merge: true)).catchError(_fallo);
    notifyListeners();
  }

  /// Registra una toma y descuenta una unidad del stock.
  void tomar(Medicamento m, {String horario = ''}) {
    final ahora = DateTime.now();
    guardar(
        Col.tomas,
        Toma('',
            medId: m.id,
            nombre: m.nombre,
            dosis: m.dosis,
            fecha: fechaTexto(ahora),
            hora: horaTexto(ahora),
            horario: horario));
    if (m.stock > 0) {
      col(Col.medicamentos).doc(m.id).update({'stock': FieldValue.increment(-1)}).catchError(_fallo);
    }
  }

  /// Deshace una toma y devuelve la unidad al stock.
  void deshacerToma(Toma t) {
    borrar(Col.tomas, t.id);
    if (medicamentos.any((m) => m.id == t.medId)) {
      col(Col.medicamentos).doc(t.medId).update({'stock': FieldValue.increment(1)}).catchError(_fallo);
    }
  }

  // ─── Copias de seguridad ────────────────────────────────────────────────

  /// Copia completa en JSON (formato v10; se puede volver a importar).
  String exportarJson() {
    final cols = <String, dynamic>{};
    for (final c in Col.todas) {
      cols[c] = [
        for (final e in (_crudo[c] ?? {}).entries) {'id': e.key, ...e.value}
      ];
    }
    return const JsonEncoder.withIndent(' ').convert({
      'app': 'GluControl',
      'version': 10,
      'fecha': DateTime.now().toIso8601String(),
      'perfil': perfil.aMapa(),
      ...cols,
    });
  }

  /// Importa un backup de GluControl: HTML v4 (GL, ME...), HTML v9 (gl, me...)
  /// o de esta app (lecturas, medicamentos...). Los registros conservan su id,
  /// así que importar dos veces el mismo archivo no duplica nada.
  /// Devuelve un resumen de lo importado.
  Future<String> importar(Map<String, dynamic> j) async {
    final equivalencias = <String, List<String>>{
      Col.lecturas: ['GL', 'gl', 'lecturas'],
      Col.hba1c: ['HB', 'hb', 'hba1c'],
      Col.vitales: ['VT', 'vt', 'vitales'],
      Col.comidas: ['AL', 'al', 'comidas'],
      Col.medicamentos: ['ME', 'me', 'medicamentos'],
      Col.tomas: ['TM', 'tm', 'tomas'],
      Col.recordatorios: ['RE', 're', 'recordatorios'],
      Col.citas: ['CI', 'ci', 'citas'],
      Col.informes: ['IN', 'in', 'informes'],
      Col.contactos: ['CONT', 'cont', 'contactos'],
    };
    final esHtml = j['app'] != 'GluControl';
    String idDe(Object? v) {
      final s = (v ?? '').toString();
      if (s.isEmpty) return col(Col.lecturas).doc().id;
      return esHtml ? 'h$s' : s;
    }

    final escrituras = <(String, String, Map<String, dynamic>)>[];
    final resumen = <String>[];
    for (final e in equivalencias.entries) {
      List? lista;
      for (final k in e.value) {
        if (j[k] is List) {
          lista = j[k] as List;
          break;
        }
      }
      if (lista == null || lista.isEmpty) continue;
      var n = 0;
      for (final x in lista) {
        if (x is! Map) continue;
        final m = Map<String, dynamic>.from(x);
        final id = idDe(m.remove('id'));
        Map<String, dynamic> datos;
        switch (e.key) {
          case Col.lecturas:
            datos = Lectura.deMapa(id, m).aMapa();
          case Col.hba1c:
            datos = Hba1c.deMapa(id, m).aMapa();
          case Col.vitales:
            datos = Vital.deMapa(id, m).aMapa();
          case Col.comidas:
            datos = Comida.deMapa(id, m).aMapa();
          case Col.medicamentos:
            datos = Medicamento.deMapa(id, m).aMapa();
          case Col.tomas:
            final t = Toma.deMapa(id, m);
            if (esHtml && t.medId.isNotEmpty) t.medId = 'h${t.medId}';
            datos = t.aMapa();
          case Col.recordatorios:
            datos = Recordatorio.deMapa(id, m).aMapa();
          case Col.citas:
            datos = Cita.deMapa(id, m).aMapa();
          case Col.informes:
            final inf = Informe.deMapa(id, m);
            if (inf.foto != null) inf.foto = await Imagenes.ajustarBase64(inf.foto!);
            datos = inf.aMapa();
          default:
            datos = Contacto.deMapa(id, m).aMapa();
        }
        escrituras.add((e.key, id, datos));
        n++;
      }
      resumen.add('$n ${_nombreCol(e.key)}');
    }

    // Perfil: v4 lo trae en "perfil", v9 en "cfg", v10 en "perfil".
    final p = Map<String, dynamic>.from(j['perfil'] ?? {});
    final cfg = Map<String, dynamic>.from(j['cfg'] ?? {});
    if (cfg['altura'] != null) p['altura'] = cfg['altura'];
    if (cfg['alerta_horas'] != null) p['horasAviso'] = cfg['alerta_horas'];
    if (cfg['peso_objetivo'] != null) p['pesoObjetivo'] = cfg['peso_objetivo'];
    if (p.isNotEmpty) {
      final nuevo = Perfil.deMapa({...perfil.aMapa(), ...p..removeWhere((k, v) => v == null || v == '')});
      perfil = nuevo;
      guardarPerfil();
      resumen.add('perfil');
    }

    // Por lotes de 400 (Firestore admite 500 por lote).
    for (var k = 0; k < escrituras.length; k += 400) {
      final lote = Fb.db.batch();
      for (final (c, id, datos) in escrituras.skip(k).take(400)) {
        lote.set(col(c).doc(id), datos);
      }
      try {
        await lote.commit().timeout(const Duration(seconds: 60));
      } on TimeoutException {
        // Sin conexión: se sube cuando vuelva.
      }
    }
    return resumen.isEmpty ? 'El archivo no tiene datos de GluControl.' : 'Importado: ${resumen.join(', ')}.';
  }

  static String _nombreCol(String c) => switch (c) {
        Col.lecturas => 'glucemias',
        Col.hba1c => 'HbA1c',
        Col.vitales => 'registros de peso/tensión',
        Col.comidas => 'comidas',
        Col.medicamentos => 'medicamentos',
        Col.tomas => 'tomas',
        Col.recordatorios => 'recordatorios',
        Col.citas => 'citas',
        Col.informes => 'informes',
        _ => 'contactos',
      };
}

// ─── Fechas como texto ──────────────────────────────────────────────────────

String _dos(int n) => n.toString().padLeft(2, '0');
String fechaTexto(DateTime d) => '${d.year}-${_dos(d.month)}-${_dos(d.day)}';
String horaTexto(DateTime d) => '${_dos(d.hour)}:${_dos(d.minute)}';
String hoyTexto() => fechaTexto(DateTime.now());

/// '2026-11-22' → '22/11/2026'
String fechaBonita(String f) {
  final p = f.split('-');
  if (p.length != 3) return f;
  return '${p[2]}/${p[1]}/${p[0]}';
}

/// '2026-11-22' → '22/11'
String fechaCorta(String f) {
  final p = f.split('-');
  if (p.length != 3) return f;
  return '${p[2]}/${p[1]}';
}
