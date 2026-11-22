import 'package:flutter/material.dart';

import '../../datos/analisis.dart';
import '../../datos/datos.dart';
import '../../datos/modelos.dart';
import '../comun.dart';
import '../graficos.dart';
import '../tema.dart';

class PantallaEstadisticas extends StatefulWidget {
  const PantallaEstadisticas({super.key});

  @override
  State<PantallaEstadisticas> createState() => _PantallaEstadisticasState();
}

class _PantallaEstadisticasState extends State<PantallaEstadisticas> {
  int dias = 14;

  @override
  Widget build(BuildContext context) => ConDatos(builder: (c, d) {
        final p = d.perfil;
        final l = ultimosDias(d.lecturas, dias);
        final r = Resumen.de(l, p);
        final fechas = fechasUltimos(dias);
        final pm = mediasPorMomento(l);
        final patrones = buscarPatrones(d);

        // Media de las últimas 12 semanas
        final semanas = <double?>[], etiquetas = <String>[];
        final hoy = DateTime.now();
        for (var w = 11; w >= 0; w--) {
          final fin = DateTime(hoy.year, hoy.month, hoy.day - w * 7);
          final ini = fin.subtract(const Duration(days: 6));
          final a = fechaTexto(ini), b = fechaTexto(fin);
          final s = d.lecturas.where((x) => x.fecha.compareTo(a) >= 0 && x.fecha.compareTo(b) <= 0);
          semanas.add(media(s.map((x) => x.valor)));
          etiquetas.add(fechaCorta(a));
        }

        return Pagina([
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 7, label: Text('7 d')),
                ButtonSegment(value: 14, label: Text('14 d')),
                ButtonSegment(value: 28, label: Text('28 d')),
                ButtonSegment(value: 90, label: Text('90 d')),
              ],
              selected: {dias},
              onSelectionChanged: (s) => setState(() => dias = s.first),
            ),
          ),
          const SizedBox(height: 6),
          FilaDatos([
            Dato('Media', r.media == null ? '—' : '${r.media!.round()}', unidad: r.media == null ? '' : 'mg/dL',
                sub: '${r.n} medidas', color: r.media == null ? null : Tema.nivel(nivelDe(r.media!.round(), p))),
            Dato('Tiempo en rango', r.n == 0 ? '—' : '${r.tir.round()}', unidad: r.n == 0 ? '' : '%', sub: 'objetivo > 70 %',
                color: r.n == 0 ? null : (r.tir >= 70 ? Tema.ok : r.tir >= 50 ? Tema.aviso : Tema.alta)),
            Dato('Variabilidad (CV)', r.cv == null ? '—' : '${r.cv!.round()}', unidad: r.cv == null ? '' : '%',
                sub: r.cv == null ? '' : (r.cv! <= 36 ? 'estable (≤ 36 %)' : 'alta (> 36 %)'),
                color: r.cv == null ? null : (r.cv! <= 36 ? Tema.ok : Tema.aviso)),
            Dato('HbA1c estimada', num1(r.gmi), unidad: r.gmi == null ? '' : '%', sub: 'GMI, orientativa'),
            Dato('Bajas', '${r.hipos}', sub: '${r.bandas[Nivel.muyBaja]} por debajo de 54',
                color: r.hipos == 0 ? Tema.ok : (r.bandas[Nivel.muyBaja]! > 0 ? Tema.error : Tema.aviso)),
            Dato('Desviación', r.sd == null ? '—' : '${r.sd!.round()}', unidad: r.sd == null ? '' : 'mg/dL'),
            Dato('Mínima', r.n == 0 ? '—' : '${r.minimo}', unidad: r.n == 0 ? '' : 'mg/dL'),
            Dato('Máxima', r.n == 0 ? '—' : '${r.maximo}', unidad: r.n == 0 ? '' : 'mg/dL'),
          ]),
          Columnas(
            izquierda: [
              Seccion('Tiempo en rango', child: BarraTiempoEnRango(r)),
              Seccion('Perfil del día', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GraficoDia(lecturas: l, perfil: p),
                const SizedBox(height: 6),
                const Text('Cada punto es una medida, según la hora a la que se tomó.',
                    style: TextStyle(fontSize: 11, color: Tema.gris)),
              ])),
            ],
            derecha: [
              Seccion('Media por momento',
                  child: pm.isEmpty
                      ? const Vacio('Sin datos')
                      : Column(children: [
                          for (final e in pm.entries)
                            BarraProporcion('${Momento.de(e.key).corto} (${e.value.$2})', (e.value.$1 - 40) / 260,
                                '${e.value.$1.round()}', Tema.nivel(nivelDe(e.value.$1.round(), p))),
                        ])),
              Seccion('Media diaria',
                  child: GraficoLinea(
                    valores: mediasDiarias(d.lecturas, fechas),
                    etiquetas: fechas.map(fechaCorta).toList(),
                    bandaMin: p.metaMin.toDouble(),
                    bandaMax: p.metaMax.toDouble(),
                    colorPunto: (v) => Tema.nivel(nivelDe(v.round(), p)),
                  )),
            ],
          ),
          Seccion('Media semanal (12 semanas)',
              child: GraficoLinea(
                valores: semanas,
                etiquetas: etiquetas,
                bandaMin: p.metaMin.toDouble(),
                bandaMax: p.metaMax.toDouble(),
                color: Tema.morado,
              )),
          Rotulo('Observaciones'),
          if (patrones.isEmpty)
            const Nota('Nada destacable', 'No se ven patrones fuera de lo normal en tus registros recientes.',
                color: Tema.ok, icono: Icons.check_circle_outline),
          for (final pt in patrones) Nota.patron(pt),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Son observaciones automáticas de tus registros, no un diagnóstico. Coméntalas con tu médico.',
              style: TextStyle(fontSize: 11, color: Tema.gris),
            ),
          ),
        ]);
      });
}
