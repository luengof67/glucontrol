import 'package:flutter/material.dart';

import '../../datos/analisis.dart';
import '../../datos/datos.dart';
import '../../datos/modelos.dart';
import '../comun.dart';
import '../graficos.dart';
import '../marco.dart';
import '../tema.dart';
import 'comidas.dart';
import 'glucemia.dart';
import 'medicacion.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  int dias = 7;

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => abrirLectura(context),
          icon: const Icon(Icons.water_drop),
          label: const Text('Medir'),
        ),
        body: ConDatos(builder: (c, d) {
          if (!d.listo) return const Center(child: CircularProgressIndicator(color: Tema.acento));
          final p = d.perfil;
          final hoy = hoyTexto();
          final lHoy = d.lecturas.where((x) => x.fecha == hoy).toList();
          final r14 = Resumen.de(ultimosDias(d.lecturas, 14), p);
          final ult = d.lecturas.isEmpty ? null : d.lecturas.first;
          final patrones = buscarPatrones(d);
          final sinMedir = horasSinMedir(d);
          final peso = d.vitales.where((v) => v.peso != null).firstOrNull;
          final fechas = fechasUltimos(dias);
          final citas = d.citas.where((x) => x.fecha.compareTo(hoy) >= 0).take(3).toList();
          final kcalHoy = d.comidas.where((x) => x.fecha == hoy).fold<int>(0, (s, x) => s + x.kcal);

          return Pagina([
            const SizedBox(height: 8),
            if (ult != null && nivelDe(ult.valor, p).index <= Nivel.baja.index && ult.fecha == hoy)
              Nota('Última medida baja: ${ult.valor} mg/dL',
                  'Toma 15 g de hidratos rápidos, espera 15 minutos y vuelve a medir.',
                  color: Tema.baja, icono: Icons.warning_amber_rounded, onTap: () => abrirLectura(context)),
            if (ult != null && ult.valor >= 300 && ult.fecha == hoy)
              Nota('Última medida muy alta: ${ult.valor} mg/dL',
                  'Bebe agua y vuelve a medir. Si se mantiene alta o te encuentras mal, llama a tu médico o al 112.',
                  color: Tema.muyAlta, icono: Icons.error_outline),
            if (sinMedir != null && p.horasAviso > 0 && sinMedir >= p.horasAviso)
              Nota('Llevas $sinMedir h sin medir', 'Toca para apuntar una medición.',
                  color: Tema.aviso, icono: Icons.timer_outlined, onTap: () => abrirLectura(context)),
            Columnas(
              izquierda: [
                Rotulo('Ahora'),
                Tarjeta(
                  onTap: ult == null ? () => abrirLectura(context) : () => abrirLectura(context, ult),
                  child: ult == null
                      ? const Vacio('Aún no hay mediciones. Pulsa «Medir».')
                      : Row(children: [
                          ValorGlucosa(ult.valor, tam: 44),
                          const SizedBox(width: 6),
                          const Padding(
                              padding: EdgeInsets.only(top: 14),
                              child: Text('mg/dL', style: TextStyle(color: Tema.gris))),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Chapita(nombreNivel(nivelDe(ult.valor, p)), color: Tema.nivel(nivelDe(ult.valor, p))),
                              const SizedBox(height: 4),
                              Text(Momento.de(ult.momento).nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('${ult.fecha == hoy ? 'Hoy' : fechaBonita(ult.fecha)} a las ${ult.hora}${_hace(ult.cuando)}',
                                  style: const TextStyle(color: Tema.gris, fontSize: 12.5)),
                            ]),
                          ),
                        ]),
                ),
                Rotulo('Hoy'),
                Tarjeta(
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final m in Momento.lista.where((m) => m.clave != 'otro' && m.clave != 'noche' || lHoy.any((x) => x.momento == m.clave)))
                      _Hueco(m, lHoy.where((x) => x.momento == m.clave).firstOrNull),
                  ]),
                ),
                const SizedBox(height: 6),
                FilaDatos([
                  Dato('Media hoy', lHoy.isEmpty ? '—' : '${media(lHoy.map((x) => x.valor))!.round()}',
                      unidad: lHoy.isEmpty ? '' : 'mg/dL', sub: '${lHoy.length} medidas'),
                  Dato('En rango 14 d', r14.n == 0 ? '—' : '${r14.tir.round()}', unidad: r14.n == 0 ? '' : '%',
                      sub: 'objetivo > 70 %',
                      color: r14.n == 0 ? null : (r14.tir >= 70 ? Tema.ok : r14.tir >= 50 ? Tema.aviso : Tema.alta)),
                  d.hba1c.isNotEmpty
                      ? Dato('HbA1c', num1(d.hba1c.first.valor), unidad: '%', sub: fechaBonita(d.hba1c.first.fecha),
                          color: d.hba1c.first.valor <= p.metaHba ? Tema.ok : Tema.alta)
                      : Dato('HbA1c estimada', num1(r14.gmi), unidad: r14.gmi == null ? '' : '%', sub: 'GMI, 14 días'),
                  Dato('Peso', peso == null ? '—' : num1(peso.peso), unidad: peso == null ? '' : 'kg',
                      sub: peso == null ? '' : (p.imc(peso.peso) != null ? 'IMC ${num1(p.imc(peso.peso))}' : fechaBonita(peso.fecha))),
                ]),
                Rotulo('Media diaria',
                    accion: SegmentedButton<int>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(visualDensity: VisualDensity.compact),
                      segments: const [ButtonSegment(value: 7, label: Text('7 d')), ButtonSegment(value: 30, label: Text('30 d'))],
                      selected: {dias},
                      onSelectionChanged: (s) => setState(() => dias = s.first),
                    )),
                Tarjeta(
                  child: GraficoLinea(
                    valores: mediasDiarias(d.lecturas, fechas),
                    etiquetas: fechas.map(fechaCorta).toList(),
                    bandaMin: p.metaMin.toDouble(),
                    bandaMax: p.metaMax.toDouble(),
                    colorPunto: (v) => Tema.nivel(nivelDe(v.round(), p)),
                  ),
                ),
              ],
              derecha: [
                if (patrones.isNotEmpty) ...[
                  Rotulo('A tener en cuenta',
                      accion: TextButton(onPressed: () => navegar.value = 'estadisticas', child: const Text('Ver más'))),
                  for (final pt in patrones.take(3)) Nota.patron(pt),
                ],
                Rotulo('Medicación de hoy',
                    accion: TextButton(onPressed: () => navegar.value = 'medicacion', child: const Text('Abrir'))),
                Tarjeta(
                  child: d.medicamentos.isEmpty
                      ? const Vacio('Sin medicación')
                      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          for (final m in d.medicamentos)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(child: Text(m.nombre, style: const TextStyle(fontWeight: FontWeight.w600))),
                                  if (m.agotado || m.stockBajo)
                                    Chapita(m.agotado ? 'Agotado' : 'Quedan ${m.stock}', color: m.agotado ? Tema.error : Tema.aviso),
                                ]),
                                if (m.horarios.isNotEmpty) ...[const SizedBox(height: 4), TomasHoy(m)],
                              ]),
                            ),
                        ]),
                ),
                Rotulo('Comidas de hoy', accion: TextButton(onPressed: () => abrirComida(context), child: const Text('Añadir'))),
                Tarjeta(
                  onTap: () => navegar.value = 'comidas',
                  child: Builder(builder: (c) {
                    final cs = d.comidas.where((x) => x.fecha == hoy).toList();
                    if (cs.isEmpty) return const Vacio('Sin comidas apuntadas hoy');
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (final x in cs.reversed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text('${x.hora}  ${TipoComida.nombreDe(x.tipo)}: ${x.alimentos}',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      if (kcalHoy > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('Total: $kcalHoy kcal', style: const TextStyle(fontWeight: FontWeight.w700, color: Tema.acento)),
                        ),
                    ]);
                  }),
                ),
                Rotulo('Próximas citas', accion: TextButton(onPressed: () => navegar.value = 'citas', child: const Text('Abrir'))),
                Tarjeta(
                  child: citas.isEmpty
                      ? const Vacio('Sin citas próximas')
                      : Column(children: [
                          for (final ci in citas)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.event, color: Tema.acento),
                              title: Text(ci.especialista.isEmpty ? (Cita.tipos[ci.tipo] ?? ci.tipo) : ci.especialista),
                              subtitle: Text('${fechaBonita(ci.fecha)} · ${ci.hora}'),
                              trailing: Text(_faltan(ci.fecha), style: const TextStyle(color: Tema.gris, fontSize: 12)),
                            ),
                        ]),
                ),
              ],
            ),
          ]);
        }),
      );
}

class _Hueco extends StatelessWidget {
  final Momento m;
  final Lectura? l;
  const _Hueco(this.m, this.l);

  @override
  Widget build(BuildContext context) {
    final color = l == null ? Tema.borde : Tema.nivel(nivelDe(l!.valor, Datos.i.perfil));
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => abrirLectura(context, l),
      child: Container(
        width: 86,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: l == null ? Tema.borde : color.withValues(alpha: 0.5)),
          color: l == null ? null : color.withValues(alpha: 0.06),
        ),
        child: Column(children: [
          Text(m.corto.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Tema.gris, letterSpacing: .6)),
          const SizedBox(height: 3),
          Text(l == null ? '—' : '${l!.valor}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: l == null ? Tema.borde : color)),
        ]),
      ),
    );
  }
}

String _hace(DateTime t) {
  final m = DateTime.now().difference(t).inMinutes;
  if (m < 0) return '';
  if (m < 60) return ' (hace $m min)';
  if (m < 60 * 24) return ' (hace ${m ~/ 60} h)';
  return '';
}

String _faltan(String fecha) {
  final f = DateTime.tryParse(fecha);
  if (f == null) return '';
  final hoy = DateTime.now();
  final n = DateTime(f.year, f.month, f.day).difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
  if (n == 0) return 'hoy';
  if (n == 1) return 'mañana';
  return 'en $n días';
}
