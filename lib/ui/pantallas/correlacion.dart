import 'package:flutter/material.dart';

import '../../datos/analisis.dart';
import '../../datos/datos.dart';
import '../../datos/modelos.dart';
import '../comun.dart';
import '../tema.dart';
import 'comidas.dart';

class PantallaCorrelacion extends StatefulWidget {
  const PantallaCorrelacion({super.key});

  @override
  State<PantallaCorrelacion> createState() => _PantallaCorrelacionState();
}

class _PantallaCorrelacionState extends State<PantallaCorrelacion> {
  int dias = 90;
  int ventana = 180;

  @override
  Widget build(BuildContext context) => ConDatos(builder: (c, d) {
        final p = d.perfil;
        final pares = emparejarComidas(d, dias: dias, ventanaMin: ventana);
        final conDelta = pares.where((x) => x.delta != null).toList();
        final mediaDespues = media(pares.map((x) => x.despues.valor));
        final mediaDelta = media(conDelta.map((x) => x.delta!));
        final altasDespues = pares.where((x) => x.despues.valor > p.metaMax).length;

        Widget grupo(String titulo, Map<String, String> nombres, String Function(ParComida) clave) {
          final g = <String, List<ParComida>>{};
          for (final x in pares) {
            g.putIfAbsent(clave(x), () => []).add(x);
          }
          if (g.isEmpty) return Seccion(titulo, child: const Vacio('Sin datos suficientes'));
          return Seccion(titulo,
              child: Column(children: [
                for (final k in nombres.keys.where(g.containsKey))
                  Builder(builder: (c) {
                    final l = g[k]!;
                    final md = media(l.map((x) => x.despues.valor))!;
                    final dl = media(l.where((x) => x.delta != null).map((x) => x.delta!));
                    final col = Tema.nivel(nivelDe(md.round(), p));
                    return BarraProporcion(
                      '${nombres[k]} (${l.length})',
                      (md - 70) / 180,
                      '${md.round()}${dl != null ? '  ${dl >= 0 ? '+' : ''}${dl.round()}' : ''}',
                      col,
                    );
                  }),
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Glucosa media después y subida media respecto a antes de comer (mg/dL).',
                      style: TextStyle(fontSize: 11, color: Tema.gris)),
                ),
              ]));
        }

        final top = [...pares]..sort((a, b) => (b.delta ?? (b.despues.valor - 110)).compareTo(a.delta ?? (a.despues.valor - 110)));

        return Pagina([
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 30, label: Text('30 d')),
                  ButtonSegment(value: 90, label: Text('90 d')),
                  ButtonSegment(value: 365, label: Text('1 año')),
                ],
                selected: {dias},
                onSelectionChanged: (s) => setState(() => dias = s.first),
              ),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 120, label: Text('hasta 2 h')),
                  ButtonSegment(value: 180, label: Text('hasta 3 h')),
                ],
                selected: {ventana},
                onSelectionChanged: (s) => setState(() => ventana = s.first),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          FilaDatos([
            Dato('Comidas con medida después', '${pares.length}', sub: '${conDelta.length} con medida antes'),
            Dato('Glucosa después', mediaDespues == null ? '—' : '${mediaDespues.round()}',
                unidad: mediaDespues == null ? '' : 'mg/dL',
                color: mediaDespues == null ? null : Tema.nivel(nivelDe(mediaDespues.round(), p))),
            Dato('Subida media', mediaDelta == null ? '—' : '${mediaDelta >= 0 ? '+' : ''}${mediaDelta.round()}',
                unidad: mediaDelta == null ? '' : 'mg/dL',
                color: mediaDelta == null ? null : (mediaDelta > 60 ? Tema.alta : mediaDelta > 30 ? Tema.aviso : Tema.ok)),
            Dato('Por encima de ${p.metaMax}', pares.isEmpty ? '—' : '${(altasDespues * 100 / pares.length).round()}',
                unidad: pares.isEmpty ? '' : '%', sub: '$altasDespues comidas'),
          ]),
          if (pares.length < 5)
            const Nota('Faltan datos para sacar conclusiones',
                'Apunta las comidas con su hora y mide antes de comer y a las 2 horas. Con 10-15 comidas ya se ven diferencias.',
                icono: Icons.tips_and_updates_outlined),
          Columnas(
            izquierda: [
              grupo('Por índice glucémico', const {'bajo': 'IG bajo', 'medio': 'IG medio', 'alto': 'IG alto'}, (x) => x.comida.ig),
              grupo('Por comida del día', {for (final t in TipoComida.lista) t.clave: t.nombre}, (x) => x.comida.tipo),
            ],
            derecha: [
              Seccion('Las que más te suben',
                  child: top.isEmpty
                      ? const Vacio('Sin datos')
                      : Column(children: [
                          for (final x in top.take(8))
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              onTap: () => abrirComida(context, x.comida),
                              title: Text(x.comida.alimentos, maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                  '${fechaBonita(x.comida.fecha)} · ${TipoComida.nombreDe(x.comida.tipo)}'
                                  '${x.antes != null ? ' · antes ${x.antes!.valor}' : ''} · a los ${x.minutosDespues} min'),
                              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                                ValorGlucosa(x.despues.valor, tam: 16),
                                if (x.delta != null)
                                  Text('${x.delta! >= 0 ? '+' : ''}${x.delta}', style: const TextStyle(fontSize: 11.5, color: Tema.gris)),
                              ]),
                            ),
                        ])),
            ],
          ),
        ]);
      });
}
