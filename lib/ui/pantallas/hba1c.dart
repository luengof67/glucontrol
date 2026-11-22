import 'package:flutter/material.dart';

import '../../datos/analisis.dart';
import '../../datos/datos.dart';
import '../../datos/modelos.dart';
import '../comun.dart';
import '../graficos.dart';
import '../tema.dart';

Future<void> abrirHba1c(BuildContext context, [Hba1c? h]) => showDialog(context: context, builder: (_) => _Form(h));

class _Form extends StatefulWidget {
  final Hba1c? h;
  const _Form(this.h);

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late String fecha;
  final valor = TextEditingController(), centro = TextEditingController(), notas = TextEditingController();
  String? error;

  @override
  void initState() {
    super.initState();
    final h = widget.h;
    fecha = h?.fecha ?? hoyTexto();
    if (h != null) {
      valor.text = num1(h.valor);
      centro.text = h.centro;
      notas.text = h.notas;
    }
  }

  void _guardar() {
    final v = leerNum(valor.text);
    if (v == null || v < 3 || v > 20) {
      setState(() => error = 'Valor entre 3 y 20');
      return;
    }
    final h = widget.h ?? Hba1c('', fecha: fecha, valor: v);
    h
      ..fecha = fecha
      ..valor = v
      ..centro = centro.text.trim()
      ..notas = notas.text.trim();
    Datos.i.guardar(Col.hba1c, h);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => DialogoForm(
        titulo: widget.h == null ? 'Nueva HbA1c' : 'Editar HbA1c',
        onGuardar: _guardar,
        onBorrar: widget.h == null
            ? null
            : () async {
                if (await confirmar(context, '¿Eliminar este resultado?')) {
                  Datos.i.borrar(Col.hba1c, widget.h!.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
        campos: [
          Row(children: [
            Expanded(child: CampoFecha('Fecha del análisis', fecha, (v) => setState(() => fecha = v))),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                  controller: valor,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'HbA1c (%)', errorText: error)),
            ),
          ]),
          TextField(controller: centro, decoration: const InputDecoration(labelText: 'Centro / laboratorio')),
          TextField(controller: notas, decoration: const InputDecoration(labelText: 'Notas')),
        ],
      );
}

String etiquetaHba(double v) => v < 5.7 ? 'Normal' : v < 6.5 ? 'Prediabetes' : 'Diabetes';

class PantallaHba1c extends StatelessWidget {
  const PantallaHba1c({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => abrirHba1c(context), icon: const Icon(Icons.add), label: const Text('Resultado')),
        body: ConDatos(builder: (c, d) {
          final p = d.perfil;
          final ult = d.hba1c.isEmpty ? null : d.hba1c.first;
          final gmi = Resumen.de(ultimosDias(d.lecturas, 90), p);
          final serie = d.hba1c.take(12).toList().reversed.toList();
          return Pagina([
            FilaDatos([
              Dato('Última HbA1c', ult == null ? '—' : num1(ult.valor), unidad: ult == null ? '' : '%',
                  sub: ult == null ? '' : '${fechaBonita(ult.fecha)} · ${etiquetaHba(ult.valor)}',
                  color: ult == null ? null : (ult.valor <= p.metaHba ? Tema.ok : Tema.alta)),
              Dato('Tu objetivo', '< ${num1(p.metaHba)}', unidad: '%', sub: 'se cambia en Ajustes'),
              Dato('Estimada (GMI)', num1(gmi.gmi), unidad: gmi.gmi == null ? '' : '%', sub: '90 días, ${gmi.n} medidas'),
              Dato('Cambio', d.hba1c.length < 2 ? '—' : '${d.hba1c[0].valor >= d.hba1c[1].valor ? '+' : ''}${num1(d.hba1c[0].valor - d.hba1c[1].valor)}',
                  unidad: d.hba1c.length < 2 ? '' : 'puntos', sub: 'respecto a la anterior',
                  color: d.hba1c.length < 2 ? null : (d.hba1c[0].valor <= d.hba1c[1].valor ? Tema.ok : Tema.alta)),
            ]),
            Columnas(
              izquierda: [
                Seccion('Evolución',
                    child: GraficoLinea(
                      valores: serie.map((h) => h.valor).toList(),
                      etiquetas: serie.map((h) => fechaCorta(h.fecha)).toList(),
                      bandaMin: 4,
                      bandaMax: p.metaHba,
                      decimales: 1,
                      color: Tema.morado,
                      colorPunto: (v) => v <= p.metaHba ? Tema.ok : Tema.alta,
                    )),
                const Nota('Cómo leerla',
                    'Menos de 5,7 %: normal · 5,7–6,4 %: prediabetes · 6,5 % o más: diabetes. '
                        'En diabetes el objetivo habitual es < 7 %, pero lo fija tu médico. '
                        'La estimada (GMI) sale de tus glucemias y es solo orientativa.',
                    icono: Icons.info_outline),
              ],
              derecha: [
                Seccion('Historial',
                    padding: EdgeInsets.zero,
                    child: d.hba1c.isEmpty
                        ? const Vacio('Sin resultados')
                        : Column(children: [
                            for (final h in d.hba1c)
                              ListTile(
                                onTap: () => abrirHba1c(context, h),
                                title: Text('${num1(h.valor)} %', style: const TextStyle(fontWeight: FontWeight.w800)),
                                subtitle: Text([fechaBonita(h.fecha), h.centro, h.notas].where((e) => e.isNotEmpty).join(' · ')),
                                trailing: Chapita(etiquetaHba(h.valor), color: h.valor <= p.metaHba ? Tema.ok : Tema.alta),
                              ),
                          ])),
              ],
            ),
          ]);
        }),
      );
}
