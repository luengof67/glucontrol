import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../datos/analisis.dart';
import '../datos/datos.dart';
import '../datos/modelos.dart';

/// Asistente con Claude (API de Anthropic).
///
/// La clave de la API la pone el usuario en Ajustes y se guarda cifrada en
/// cada dispositivo (no se sube a Firebase). Los datos de salud solo salen
/// del dispositivo cuando se pulsa un botón del asistente o se analiza una
/// foto, y van directos a Anthropic.
class IA {
  static const _almacen = FlutterSecureStorage();
  static const _kClave = 'gc_api_key';

  static Future<String?> clave() async {
    final k = await _almacen.read(key: _kClave);
    return (k == null || k.trim().isEmpty) ? null : k.trim();
  }

  static Future<void> guardarClave(String? k) async {
    if (k == null || k.trim().isEmpty) {
      await _almacen.delete(key: _kClave);
    } else {
      await _almacen.write(key: _kClave, value: k.trim());
    }
  }

  static const sistema =
      'Eres un asistente especializado en diabetes y control glucémico, integrado en la app GluControl. '
      'Ayudas al paciente a entender sus datos, ver patrones y preparar la consulta con su médico.\n\n'
      'PRINCIPIOS:\n'
      '- Responde siempre en español, claro, cercano y sin alarmismo.\n'
      '- Cita datos concretos de sus registros (fechas, valores, momentos del día).\n'
      '- Distingue lo que se ve en los datos de las recomendaciones generales.\n'
      '- Las decisiones de tratamiento (dosis, cambios de medicación) son siempre del médico: no indiques dosis.\n'
      '- Si hay valores peligrosos (menos de 54 o más de 300 mg/dL repetidos), dilo claramente y recomienda contactar con el médico o urgencias.\n'
      '- Párrafos cortos y listas cuando ayuden. Sin tablas.\n'
      '- Si faltan datos para responder, dilo y sugiere qué registrar.\n'
      '- Nunca inventes datos.';

  static const rapidos = <String, (String, String)>{
    'glucemia': (
      'Glucemia',
      'Analiza mi glucemia: tendencias, momentos del día con peor control, tiempo en rango y variabilidad, y recomendaciones prácticas basadas en mis datos.'
    ),
    'comidas': (
      'Comidas',
      'Analiza mi diario de comidas y cómo me sube la glucosa después de comer: qué comidas o tipos de comida me suben más y qué podría cambiar.'
    ),
    'medicacion': (
      'Medicación',
      'Revisa mi medicación: tomas registradas, stock y si los horarios encajan con mi perfil de glucemia. Sin proponer cambios de dosis.'
    ),
    'vitales': (
      'Peso y tensión',
      'Analiza mis registros de peso y tensión arterial (objetivo en diabetes < 130/80) y su evolución.'
    ),
    'consulta': (
      'Preparar consulta',
      'Prepárame un resumen para la próxima consulta con mi médico: control glucémico, HbA1c, medicación, peso y tensión, y las 3-5 preguntas más importantes que debería hacerle.'
    ),
    'riesgos': (
      'Alertas',
      'Busca en todos mis registros alertas y patrones de riesgo: hipoglucemias, hiperglucemias mantenidas, stock crítico, tensión alta u otros.'
    ),
  };

  /// Resumen de todos los datos para darle contexto al asistente.
  static String contexto(Datos d) {
    final p = d.perfil;
    final r28 = Resumen.de(ultimosDias(d.lecturas, 28), p);
    String n(double? v, [int dec = 0]) => v == null ? '-' : v.toStringAsFixed(dec);
    final b = StringBuffer()
      ..writeln('=== DATOS DEL PACIENTE EN GLUCONTROL (hoy ${fechaBonita(hoyTexto())}) ===')
      ..writeln('Perfil: diabetes ${p.tipo}${p.fechaNac.isNotEmpty ? ', nacido el ${fechaBonita(p.fechaNac)}' : ''}'
          '${p.altura != null ? ', altura ${p.altura!.round()} cm' : ''}.')
      ..writeln('Objetivos: glucemia ${p.metaMin}-${p.metaMax} mg/dL, HbA1c < ${p.metaHba} %.')
      ..writeln()
      ..writeln('## GLUCEMIA (28 días)')
      ..writeln('Medidas: ${r28.n}; media ${n(r28.media)} mg/dL; DE ${n(r28.sd)}; CV ${n(r28.cv)} %; '
          'GMI ${n(r28.gmi, 1)} %; en rango ${n(r28.tir)} %; bajas ${r28.hipos}; '
          'muy altas (>250) ${r28.bandas[Nivel.muyAlta]}; mín ${r28.minimo}; máx ${r28.maximo}.');
    final pm = mediasPorMomento(ultimosDias(d.lecturas, 28));
    if (pm.isNotEmpty) {
      b.writeln('Media por momento: ${pm.entries.map((e) => '${Momento.de(e.key).corto} ${e.value.$1.round()} (${e.value.$2})').join('; ')}.');
    }
    b.writeln('Últimas 40 medidas:');
    for (final l in d.lecturas.take(40)) {
      b.writeln('- ${l.fecha} ${l.hora} ${Momento.de(l.momento).corto}: ${l.valor}${l.notas.isNotEmpty ? ' (${l.notas})' : ''}');
    }
    b
      ..writeln()
      ..writeln('## HbA1c');
    for (final h in d.hba1c.take(6)) {
      b.writeln('- ${h.fecha}: ${h.valor} %');
    }
    if (d.hba1c.isEmpty) b.writeln('Sin datos');
    b
      ..writeln()
      ..writeln('## PESO Y TENSIÓN (últimos 8)');
    for (final v in d.vitales.take(8)) {
      b.writeln('- ${v.fecha}: peso ${v.peso ?? '-'} kg, IMC ${p.imc(v.peso) ?? '-'}, '
          'tensión ${v.ts != null ? '${v.ts}/${v.td}' : '-'}, pulso ${v.pulso ?? '-'}');
    }
    if (p.pesoObjetivo != null) b.writeln('Peso objetivo: ${p.pesoObjetivo} kg');
    b
      ..writeln()
      ..writeln('## MEDICACIÓN');
    for (final m in d.medicamentos) {
      b.writeln('- ${m.nombre} ${m.dosis} (${m.tipo}), horarios ${m.horarios.join(', ')}, stock ${m.stock}');
    }
    final hoy = hoyTexto();
    b.writeln('Tomas de hoy: ${d.tomas.where((t) => t.fecha == hoy).map((t) => '${t.nombre} ${t.hora}').join(', ')}');
    b
      ..writeln()
      ..writeln('## COMIDAS (últimas 20)');
    final pares = {for (final x in emparejarComidas(d, dias: 30)) x.comida.id: x};
    for (final c in d.comidas.take(20)) {
      final par = pares[c.id];
      b.writeln('- ${c.fecha} ${c.hora} ${TipoComida.nombreDe(c.tipo)}: ${c.alimentos}'
          '${c.kcal > 0 ? ', ${c.kcal} kcal' : ''}${c.hc != null ? ', ${c.hc} g HC' : ''}, IG ${c.ig}'
          '${par != null ? ' → después ${par.despues.valor} mg/dL a los ${par.minutosDespues} min${par.delta != null ? ' (${par.delta! >= 0 ? '+' : ''}${par.delta})' : ''}' : ''}');
    }
    b
      ..writeln()
      ..writeln('## CITAS PRÓXIMAS');
    for (final c in d.citas.where((c) => c.fecha.compareTo(hoy) >= 0).take(5)) {
      b.writeln('- ${c.fecha} ${c.hora}: ${Cita.tipos[c.tipo] ?? c.tipo} ${c.especialista}');
    }
    b
      ..writeln()
      ..writeln('## INFORMES RECIENTES');
    for (final i in d.informes.take(5)) {
      final cont = i.contenido.length > 300 ? '${i.contenido.substring(0, 300)}…' : i.contenido;
      b.writeln('- ${i.fecha} ${i.titulo}: $cont');
    }
    b.writeln('=== FIN ===');
    return b.toString();
  }

  /// Llamada a la API. [mensajes]: lista de (rol, texto) con rol 'user' o 'assistant'.
  static Future<String> preguntar(String modelo, List<(String, String)> mensajes,
      {String? sistemaExtra, int maxTokens = 2000}) async {
    final k = await clave();
    if (k == null) throw ErrorIA('Falta la clave de la API de Anthropic. Ponla en Ajustes.');
    return _llamar(k, {
      'model': modelo,
      'max_tokens': maxTokens,
      'system': sistemaExtra == null ? sistema : '$sistema\n\n$sistemaExtra',
      'messages': [
        for (final (rol, texto) in mensajes) {'role': rol, 'content': texto}
      ],
    });
  }

  /// Analiza la foto de un plato. Devuelve alimentos, kcal, hc (g) e ig.
  static Future<Map<String, dynamic>> analizarPlato(String modelo, Uint8List jpeg) async {
    final k = await clave();
    if (k == null) throw ErrorIA('Falta la clave de la API de Anthropic. Ponla en Ajustes.');
    final texto = await _llamar(k, {
      'model': modelo,
      'max_tokens': 600,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {'type': 'base64', 'media_type': 'image/jpeg', 'data': base64Encode(jpeg)}
            },
            {
              'type': 'text',
              'text': 'Analiza esta foto de comida para una persona con diabetes. Responde SOLO con un '
                  'objeto JSON, sin markdown:\n'
                  '{"alimentos": "lista separada por comas con cantidad aproximada", "kcal": número, '
                  '"hc": gramos_de_hidratos_número, "ig": "bajo|medio|alto"}\n'
                  'IG del plato en conjunto: bajo < 55, medio 55-70, alto > 70. Sé conservador.'
            }
          ]
        }
      ],
    });
    final limpio = texto.replaceAll(RegExp(r'```(json)?'), '').trim();
    final ini = limpio.indexOf('{'), fin = limpio.lastIndexOf('}');
    if (ini < 0 || fin <= ini) throw ErrorIA('La respuesta no se ha podido leer.');
    return jsonDecode(limpio.substring(ini, fin + 1)) as Map<String, dynamic>;
  }

  static Future<String> _llamar(String k, Map<String, dynamic> cuerpo) async {
    final http.Response r;
    try {
      r = await http
          .post(Uri.parse('https://api.anthropic.com/v1/messages'),
              headers: {
                'content-type': 'application/json',
                'x-api-key': k,
                'anthropic-version': '2023-06-01',
              },
              body: jsonEncode(cuerpo))
          .timeout(const Duration(seconds: 120));
    } catch (_) {
      throw ErrorIA('Sin conexión con el asistente. Revisa internet.');
    }
    final body = utf8.decode(r.bodyBytes);
    if (r.statusCode != 200) {
      String detalle = '';
      try {
        detalle = (jsonDecode(body)['error']?['message'] ?? '').toString();
      } catch (_) {}
      throw ErrorIA(switch (r.statusCode) {
        401 => 'La clave de la API no es válida. Revísala en Ajustes.',
        404 => 'El modelo "${cuerpo['model']}" no existe. Cámbialo en Ajustes. $detalle',
        429 => 'Demasiadas peticiones o sin saldo en la cuenta de Anthropic. $detalle',
        529 => 'El servicio está saturado. Prueba en un momento.',
        _ => 'Error ${r.statusCode}. $detalle',
      });
    }
    final j = jsonDecode(body) as Map<String, dynamic>;
    return [
      for (final b in (j['content'] as List? ?? []))
        if (b is Map && b['type'] == 'text') b['text'].toString()
    ].join('\n').trim();
  }
}

class ErrorIA implements Exception {
  final String mensaje;
  ErrorIA(this.mensaje);
  @override
  String toString() => mensaje;
}
