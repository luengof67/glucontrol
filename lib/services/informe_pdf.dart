import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../datos/analisis.dart';
import '../datos/datos.dart';
import '../datos/modelos.dart';
import 'fuentes_pdf.dart';

/// Informe en PDF para llevar a la consulta.
class InformePdf {
  static const _acento = PdfColor.fromInt(0xFF0F7C7C);
  static const _barra = PdfColor.fromInt(0xFF1F2A30);
  static const _gris = PdfColor.fromInt(0xFF6B7780);
  static const _borde = PdfColor.fromInt(0xFFDDE3E6);
  static const _suave = PdfColor.fromInt(0xFFF2F4F5);

  static PdfColor _colorNivel(Nivel n) => switch (n) {
        Nivel.muyBaja => const PdfColor.fromInt(0xFFC62828),
        Nivel.baja => const PdfColor.fromInt(0xFFB26A00),
        Nivel.ok => const PdfColor.fromInt(0xFF2E7D32),
        Nivel.alta => const PdfColor.fromInt(0xFFD9534F),
        Nivel.muyAlta => const PdfColor.fromInt(0xFF8E1B1B),
      };

  static Future<Uint8List> generar(Datos d, {int dias = 30}) async {
    final doc = await FuentesPdf.documento();
    final p = d.perfil;
    final hoy = DateTime.now();
    final desde = fechaTexto(hoy.subtract(Duration(days: dias - 1)));
    final l = ultimosDias(d.lecturas, dias);
    final r = Resumen.de(l, p);
    final pm = mediasPorMomento(l);
    final fechas = fechasUltimos(dias);
    final diarias = mediasDiarias(d.lecturas, fechas);
    final patrones = buscarPatrones(d);
    final vit = d.vitales.where((v) => v.fecha.compareTo(desde) >= 0).toList();
    final pares = emparejarComidas(d, dias: dias);

    pw.Widget titulo(String t) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
          child: pw.Text(t.toUpperCase(),
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _acento, letterSpacing: 1.2)),
        );

    pw.Widget celda(String t, {bool negrita = false, PdfColor? color, pw.TextAlign alinear = pw.TextAlign.left}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: pw.Text(t,
              textAlign: alinear,
              style: pw.TextStyle(fontSize: 8.5, fontWeight: negrita ? pw.FontWeight.bold : null, color: color)),
        );

    pw.Widget tabla(List<String> cab, List<List<String>> filas,
        {Map<int, pw.TableColumnWidth>? anchos, PdfColor? Function(int fila, int col)? color}) {
      return pw.Table(
        border: pw.TableBorder.all(color: _borde, width: .5),
        columnWidths: anchos,
        children: [
          pw.TableRow(
              decoration: const pw.BoxDecoration(color: _suave),
              children: [for (final c in cab) celda(c, negrita: true)]),
          for (var i = 0; i < filas.length; i++)
            pw.TableRow(children: [
              for (var j = 0; j < filas[i].length; j++)
                celda(filas[i][j], color: color?.call(i, j), negrita: color?.call(i, j) != null),
            ]),
        ],
      );
    }

    String n0(double? v) => v == null ? '—' : v.round().toString();
    String n1(double? v) => v == null ? '—' : v.toStringAsFixed(1).replaceAll('.', ',');

    // Diario: filas = días, columnas = momentos
    final momentos = Momento.lista.where((m) => l.any((x) => x.momento == m.clave)).toList();
    final porDia = <String, Map<String, List<Lectura>>>{};
    for (final x in l) {
      porDia.putIfAbsent(x.fecha, () => {}).putIfAbsent(x.momento, () => []).add(x);
    }
    final diasConDatos = porDia.keys.toList()..sort((a, b) => b.compareTo(a));

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 30, 32, 30),
      header: (c) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        margin: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _barra, width: 1.2))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('GLUCONTROL · INFORME PARA CONSULTA',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _barra, letterSpacing: 1.2)),
          pw.Text('${p.nombre.isNotEmpty ? '${p.nombre} · ' : ''}${fechaBonita(desde)} – ${fechaBonita(hoyTexto())}',
              style: const pw.TextStyle(fontSize: 8.5, color: _gris)),
        ]),
      ),
      footer: (c) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Generado con GluControl el ${fechaBonita(hoyTexto())}. Datos registrados por el paciente.',
            style: const pw.TextStyle(fontSize: 7.5, color: _gris)),
        pw.Text('${c.pageNumber} / ${c.pagesCount}', style: const pw.TextStyle(fontSize: 7.5, color: _gris)),
      ]),
      build: (c) => [
        // Paciente
        pw.Wrap(spacing: 18, runSpacing: 4, children: [
          for (final (k, v) in [
            ('Paciente', p.nombre.isEmpty ? '—' : p.nombre),
            ('Diabetes', p.tipo),
            if (p.fechaNac.isNotEmpty) ('Nacimiento', fechaBonita(p.fechaNac)),
            if (p.medico.isNotEmpty) ('Médico', p.medico),
            ('Objetivo glucemia', '${p.metaMin}–${p.metaMax} mg/dL'),
            ('Objetivo HbA1c', '< ${n1(p.metaHba)} %'),
            ('Periodo', 'últimos $dias días'),
          ])
            pw.RichText(
                text: pw.TextSpan(children: [
              pw.TextSpan(text: '$k: ', style: const pw.TextStyle(fontSize: 9, color: _gris)),
              pw.TextSpan(text: v, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ])),
        ]),

        titulo('Resumen de glucemia'),
        tabla(
          ['Medidas', 'Media', 'Tiempo en rango', 'Bajas (<${p.metaMin})', 'Muy bajas (<54)', 'CV', 'HbA1c estimada (GMI)', 'Mín – Máx'],
          [
            [
              '${r.n}',
              '${n0(r.media)} mg/dL',
              '${n0(r.tir)} %',
              '${r.hipos}',
              '${r.bandas[Nivel.muyBaja]}',
              r.cv == null ? '—' : '${n0(r.cv)} %',
              r.gmi == null ? '—' : '${n1(r.gmi)} %',
              r.n == 0 ? '—' : '${r.minimo} – ${r.maximo}',
            ]
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: tabla(['Rango', 'mg/dL', '%'], [
              for (final nv in [Nivel.muyAlta, Nivel.alta, Nivel.ok, Nivel.baja, Nivel.muyBaja])
                [
                  nombreNivel(nv),
                  switch (nv) {
                    Nivel.muyAlta => '> 250',
                    Nivel.alta => '${p.metaMax + 1}–250',
                    Nivel.ok => '${p.metaMin}–${p.metaMax}',
                    Nivel.baja => '54–${p.metaMin - 1}',
                    Nivel.muyBaja => '< 54',
                  },
                  '${n0(r.pct(nv))} %'
                ],
            ], color: (i, j) => j == 2 ? _colorNivel([Nivel.muyAlta, Nivel.alta, Nivel.ok, Nivel.baja, Nivel.muyBaja][i]) : null),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: tabla(['Momento', 'Medidas', 'Media'], [
              for (final e in pm.entries) [Momento.de(e.key).nombre, '${e.value.$2}', n0(e.value.$1)],
            ], color: (i, j) => j == 2 ? _colorNivel(nivelDe(pm.values.elementAt(i).$1.round(), p)) : null),
          ),
        ]),

        if (diarias.whereType<double>().length >= 2) ...[
          titulo('Media diaria (mg/dL)'),
          pw.SizedBox(
            height: 150,
            child: pw.Chart(
              grid: pw.CartesianGrid(
                xAxis: pw.FixedAxis.fromStrings(
                  [for (var i = 0; i < fechas.length; i++) (i % ((fechas.length / 10).ceil()) == 0) ? fechaCorta(fechas[i]) : ''],
                  marginStart: 10,
                  marginEnd: 10,
                  textStyle: const pw.TextStyle(fontSize: 7, color: _gris),
                ),
                yAxis: pw.FixedAxis([40, 70, 100, 140, 180, 250, 320],
                    divisions: true, divisionsColor: _borde, textStyle: const pw.TextStyle(fontSize: 7, color: _gris)),
              ),
              datasets: [
                pw.LineDataSet(
                  drawPoints: true,
                  pointSize: 2,
                  color: _acento,
                  lineWidth: 1.5,
                  data: [
                    for (var i = 0; i < diarias.length; i++)
                      if (diarias[i] != null) pw.PointChartValue(i.toDouble(), diarias[i]!.clamp(40, 320).toDouble()),
                  ],
                ),
              ],
            ),
          ),
        ],

        if (d.hba1c.isNotEmpty) ...[
          titulo('HbA1c'),
          tabla(['Fecha', 'HbA1c', 'Centro'], [
            for (final h in d.hba1c.take(6)) [fechaBonita(h.fecha), '${n1(h.valor)} %', h.centro],
          ]),
        ],

        if (d.medicamentos.isNotEmpty) ...[
          titulo('Medicación'),
          tabla(['Medicamento', 'Dosis', 'Tipo', 'Horarios', 'Tomas apuntadas en el periodo'], [
            for (final m in d.medicamentos)
              [
                m.nombre,
                m.dosis,
                m.tipo,
                m.horarios.join(', '),
                m.horarios.isEmpty
                    ? '${d.tomas.where((t) => t.medId == m.id && t.fecha.compareTo(desde) >= 0).length}'
                    : '${d.tomas.where((t) => t.medId == m.id && t.fecha.compareTo(desde) >= 0).length} de ${m.horarios.length * dias}',
              ],
          ]),
        ],

        if (vit.isNotEmpty) ...[
          titulo('Peso y tensión'),
          tabla(['Fecha', 'Peso', 'IMC', 'Tensión', 'Pulso'], [
            for (final v in vit.take(15))
              [
                fechaBonita(v.fecha),
                v.peso == null ? '' : '${n1(v.peso)} kg',
                n1(p.imc(v.peso)),
                v.ts == null ? '' : '${v.ts}/${v.td}',
                v.pulso == null ? '' : '${v.pulso}',
              ],
          ]),
        ],

        if (pares.length >= 3) ...[
          titulo('Glucosa después de comer'),
          pw.Text(
              '${pares.length} comidas con medida posterior. Media después: ${n0(media(pares.map((x) => x.despues.valor)))} mg/dL'
              '${pares.any((x) => x.delta != null) ? '; subida media: ${n0(media(pares.where((x) => x.delta != null).map((x) => x.delta!)))} mg/dL' : ''}.',
              style: const pw.TextStyle(fontSize: 9)),
        ],

        if (patrones.isNotEmpty) ...[
          titulo('Observaciones automáticas'),
          for (final pt in patrones)
            pw.Bullet(text: '${pt.titulo}: ${pt.texto}', style: const pw.TextStyle(fontSize: 9)),
        ],

        if (diasConDatos.isNotEmpty) ...[
          titulo('Diario de glucemias (mg/dL)'),
          tabla(
            ['Fecha', for (final m in momentos) m.corto],
            [
              for (final f in diasConDatos)
                [
                  fechaBonita(f),
                  for (final m in momentos) (porDia[f]![m.clave] ?? []).map((x) => '${x.valor}').join(' / '),
                ],
            ],
            anchos: {0: const pw.FixedColumnWidth(58)},
            color: (i, j) {
              if (j == 0) return null;
              final ls = porDia[diasConDatos[i]]![momentos[j - 1].clave];
              if (ls == null || ls.isEmpty) return null;
              return _colorNivel(nivelDe(ls.first.valor, p));
            },
          ),
        ],
      ],
    ));
    return doc.save();
  }
}
