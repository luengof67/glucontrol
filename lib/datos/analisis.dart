import 'dart:math' as math;

import 'datos.dart';
import 'modelos.dart';

/// Nivel de una glucemia respecto a los objetivos del perfil.
/// Las bandas extremas (<54 y >250) son las del consenso internacional de
/// tiempo en rango.
enum Nivel { muyBaja, baja, ok, alta, muyAlta }

Nivel nivelDe(int v, Perfil p) {
  if (v < 54) return Nivel.muyBaja;
  if (v < p.metaMin) return Nivel.baja;
  if (v <= p.metaMax) return Nivel.ok;
  if (v <= 250) return Nivel.alta;
  return Nivel.muyAlta;
}

String nombreNivel(Nivel n) => switch (n) {
      Nivel.muyBaja => 'Muy baja',
      Nivel.baja => 'Baja',
      Nivel.ok => 'En rango',
      Nivel.alta => 'Alta',
      Nivel.muyAlta => 'Muy alta',
    };

/// Glucemias de los últimos [dias] días (hoy incluido).
List<Lectura> ultimosDias(List<Lectura> l, int dias) {
  final desde = fechaTexto(DateTime.now().subtract(Duration(days: dias - 1)));
  return l.where((x) => x.fecha.compareTo(desde) >= 0).toList();
}

/// Lista de fechas 'aaaa-mm-dd' de los últimos [dias] días, de la más antigua a hoy.
List<String> fechasUltimos(int dias) {
  final hoy = DateTime.now();
  return [for (var k = dias - 1; k >= 0; k--) fechaTexto(DateTime(hoy.year, hoy.month, hoy.day - k))];
}

double? media(Iterable<num> v) => v.isEmpty ? null : v.fold<double>(0, (s, x) => s + x) / v.length;

/// Resumen estadístico de un grupo de glucemias.
class Resumen {
  final int n;
  final double? media, sd;
  final int minimo, maximo;
  final Map<Nivel, int> bandas;

  Resumen._(this.n, this.media, this.sd, this.minimo, this.maximo, this.bandas);

  factory Resumen.de(List<Lectura> l, Perfil p) {
    final bandas = {for (final n in Nivel.values) n: 0};
    if (l.isEmpty) return Resumen._(0, null, null, 0, 0, bandas);
    final v = l.map((x) => x.valor).toList();
    final m = media(v)!;
    final sd = v.length > 1
        ? math.sqrt(v.fold<double>(0, (s, x) => s + (x - m) * (x - m)) / v.length)
        : 0.0;
    for (final x in v) {
      bandas[nivelDe(x, p)] = bandas[nivelDe(x, p)]! + 1;
    }
    return Resumen._(v.length, m, sd, v.reduce(math.min), v.reduce(math.max), bandas);
  }

  double pct(Nivel nv) => n == 0 ? 0 : bandas[nv]! * 100 / n;
  double get tir => pct(Nivel.ok);
  int get hipos => bandas[Nivel.baja]! + bandas[Nivel.muyBaja]!;

  /// Coeficiente de variación (%). Estable si ≤ 36 %.
  double? get cv => (media == null || media == 0 || n < 2) ? null : sd! * 100 / media!;

  /// Indicador de gestión de glucosa (HbA1c estimada a partir de la media).
  /// Orientativo: con glucómetro (pocas medidas al día) se aleja más que con
  /// sensor continuo.
  double? get gmi => media == null ? null : 3.31 + 0.02392 * media!;
}

/// Media por momento del día.
Map<String, (double, int)> mediasPorMomento(List<Lectura> l) {
  final g = <String, List<int>>{};
  for (final x in l) {
    g.putIfAbsent(x.momento, () => []).add(x.valor);
  }
  return {
    for (final m in Momento.lista)
      if (g.containsKey(m.clave)) m.clave: (media(g[m.clave]!)!, g[m.clave]!.length)
  };
}

/// Media de cada día (null si ese día no hay medidas).
List<double?> mediasDiarias(List<Lectura> l, List<String> fechas) {
  final g = <String, List<int>>{};
  for (final x in l) {
    g.putIfAbsent(x.fecha, () => []).add(x.valor);
  }
  return [for (final f in fechas) g[f] == null ? null : media(g[f]!)];
}

// ─── Patrones ──────────────────────────────────────────────────────────────

enum Gravedad { info, aviso, alerta }

class Patron {
  final Gravedad gravedad;
  final String titulo, texto;
  Patron(this.gravedad, this.titulo, this.texto);
}

/// Busca en los datos cosas que merece la pena comentar con el médico.
/// Son observaciones de los registros, no diagnósticos.
List<Patron> buscarPatrones(Datos d) {
  final p = d.perfil;
  final out = <Patron>[];
  final l14 = ultimosDias(d.lecturas, 14);
  final l28 = ultimosDias(d.lecturas, 28);

  // Hipoglucemias
  final muyBajas = l14.where((x) => x.valor < 54).length;
  final bajas = l14.where((x) => x.valor < p.metaMin).length;
  if (muyBajas > 0) {
    out.add(Patron(Gravedad.alerta, 'Hipoglucemias por debajo de 54',
        '$muyBajas medida${muyBajas == 1 ? '' : 's'} por debajo de 54 mg/dL en 14 días. Coméntalo con tu médico: puede hacer falta ajustar el tratamiento.'));
  } else if (bajas >= 2) {
    out.add(Patron(Gravedad.aviso, 'Hipoglucemias repetidas',
        '$bajas medidas por debajo de ${p.metaMin} mg/dL en 14 días.'));
  }

  // Momentos del día que se repiten fuera de rango
  final porMomento = <String, List<int>>{};
  for (final x in l14) {
    porMomento.putIfAbsent(x.momento, () => []).add(x.valor);
  }
  for (final e in porMomento.entries) {
    if (e.value.length < 3) continue;
    final altas = e.value.where((v) => v > p.metaMax).length;
    final m = media(e.value)!.round();
    final nombre = Momento.de(e.key).nombre.toLowerCase();
    if (altas * 2 >= e.value.length) {
      out.add(Patron(Gravedad.aviso, 'Altas ${Momento.de(e.key).corto.toLowerCase()}',
          '$altas de ${e.value.length} medidas $nombre por encima de ${p.metaMax} (media $m mg/dL) en 14 días.'));
    }
  }

  // Ayunas en alto con la noche controlada (posible efecto del alba)
  final ay = porMomento['ayunas'] ?? [];
  final dor = porMomento['antes_dormir'] ?? [];
  if (ay.length >= 3 && dor.length >= 3) {
    final ma = media(ay)!, md = media(dor)!;
    if (ma - md >= 30 && ma > 130) {
      out.add(Patron(Gravedad.info, 'Sube durante la noche',
          'En ayunas tienes de media ${ma.round()} mg/dL y antes de dormir ${md.round()}. Puede ser el efecto del alba o de la cena: buen tema para la consulta.'));
    }
  }

  // Variabilidad
  final r28 = Resumen.de(l28, p);
  if (r28.n >= 10 && (r28.cv ?? 0) > 36) {
    out.add(Patron(Gravedad.aviso, 'Variabilidad alta',
        'Coeficiente de variación del ${r28.cv!.round()} % en 28 días (objetivo ≤ 36 %). Las subidas y bajadas bruscas cuentan tanto como la media.'));
  }

  // Tendencia semana a semana
  final s1 = ultimosDias(d.lecturas, 7);
  final s2 = ultimosDias(d.lecturas, 14).where((x) => !s1.contains(x)).toList();
  if (s1.length >= 4 && s2.length >= 4) {
    final dif = media(s1.map((x) => x.valor))! - media(s2.map((x) => x.valor))!;
    if (dif.abs() >= 15) {
      out.add(Patron(dif > 0 ? Gravedad.aviso : Gravedad.info, dif > 0 ? 'Tendencia al alza' : 'Tendencia a la baja',
          'La media de esta semana está ${dif.abs().round()} mg/dL ${dif > 0 ? 'por encima' : 'por debajo'} de la anterior.'));
    }
  }

  // Tomas de medicación de los últimos 7 días
  for (final m in d.medicamentos) {
    if (m.horarios.isEmpty) continue;
    final esperadas = m.horarios.length * 7;
    final desde = fechaTexto(DateTime.now().subtract(const Duration(days: 6)));
    final hechas = d.tomas.where((t) => t.medId == m.id && t.fecha.compareTo(desde) >= 0).length;
    if (hechas > 0 && hechas < esperadas * 0.8) {
      out.add(Patron(Gravedad.info, 'Tomas de ${m.nombre}',
          'Has apuntado $hechas de $esperadas tomas previstas en 7 días. Si las tomas y no las apuntas, no pasa nada; si se te olvidan, activa el aviso en el medicamento.'));
    }
    if (m.agotado) {
      out.add(Patron(Gravedad.alerta, '${m.nombre} agotado', 'No quedan unidades. Pide receta o repón cuanto antes.'));
    } else if (m.stockBajo) {
      out.add(Patron(Gravedad.aviso, 'Queda poco ${m.nombre}',
          'Quedan ${m.stock} unidades${m.horarios.isNotEmpty ? ' (unos ${m.diasRestantes} días)' : ''}.'));
    }
  }

  out.sort((a, b) => b.gravedad.index.compareTo(a.gravedad.index));
  return out;
}

/// Horas desde la última medida, o null si no hay ninguna.
int? horasSinMedir(Datos d) {
  if (d.lecturas.isEmpty) return null;
  return DateTime.now().difference(d.lecturas.first.cuando).inHours;
}

// ─── Correlación comida → glucosa ──────────────────────────────────────────

class ParComida {
  final Comida comida;
  final Lectura? antes;
  final Lectura despues;
  ParComida(this.comida, this.antes, this.despues);
  int? get delta => antes == null ? null : despues.valor - antes.valor;
  int get minutosDespues => despues.cuando.difference(comida.cuando).inMinutes;
}

/// Para cada comida busca la glucemia de antes (hasta 60 min antes) y la de
/// después (entre 60 y [ventanaMin] minutos, la más cercana a las 2 h).
List<ParComida> emparejarComidas(Datos d, {int dias = 90, int ventanaMin = 180}) {
  final desde = fechaTexto(DateTime.now().subtract(Duration(days: dias)));
  final out = <ParComida>[];
  for (final c in d.comidas) {
    if (c.fecha.compareTo(desde) < 0) continue;
    final t = c.cuando;
    Lectura? antes, despues;
    for (final l in d.lecturas) {
      final m = l.cuando.difference(t).inMinutes;
      if (m >= -60 && m <= 5) {
        if (antes == null || l.cuando.isAfter(antes.cuando)) antes = l;
      } else if (m >= 60 && m <= ventanaMin) {
        if (despues == null || (m - 120).abs() < (despues.cuando.difference(t).inMinutes - 120).abs()) {
          despues = l;
        }
      }
    }
    if (despues != null) out.add(ParComida(c, antes, despues));
  }
  return out;
}
