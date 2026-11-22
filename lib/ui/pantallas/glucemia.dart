import 'package:flutter/material.dart';

import '../../datos/analisis.dart';
import '../../datos/datos.dart';
import '../../datos/modelos.dart';
import '../comun.dart';
import '../tema.dart';

/// Alta o edición de una glucemia.
Future<void> abrirLectura(BuildContext context, [Lectura? l]) async {
  final guardada = await showDialog<Lectura>(context: context, builder: (_) => _FormLectura(l));
  if (guardada == null || !context.mounted) return;
  final p = Datos.i.perfil;
  final n = nivelDe(guardada.valor, p);
  if (n == Nivel.baja || n == Nivel.muyBaja) {
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Tema.baja, size: 36),
        title: Text('Glucosa baja: ${guardada.valor} mg/dL'),
        content: const Text(
          'Regla del 15:\n'
          '1. Toma 15 g de hidratos rápidos: un vaso de zumo, 3 sobres de azúcar o 3-4 caramelos.\n'
          '2. Espera 15 minutos y vuelve a medir.\n'
          '3. Si sigue por debajo de 70, repite.\n'
          '4. Cuando se normalice, come algo con hidratos lentos si falta para la comida.\n\n'
          'Si hay confusión o no se puede tragar: 112.',
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Entendido'))],
      ),
    );
  } else if (guardada.valor >= 300) {
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Tema.muyAlta, size: 36),
        title: Text('Glucosa muy alta: ${guardada.valor} mg/dL'),
        content: const Text(
          'Bebe agua, vuelve a medir en un rato y sigue las indicaciones que te haya dado tu médico para '
          'estos casos.\n\nSi se mantiene por encima de 300, o hay vómitos, dolor abdominal, respiración '
          'rápida o somnolencia: llama a tu médico o al 112.',
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Entendido'))],
      ),
    );
  }
}

class _FormLectura extends StatefulWidget {
  final Lectura? l;
  const _FormLectura(this.l);

  @override
  State<_FormLectura> createState() => _FormLecturaState();
}

class _FormLecturaState extends State<_FormLectura> {
  late String fecha, hora, momento;
  final valor = TextEditingController();
  final notas = TextEditingController();
  String? error;

  @override
  void initState() {
    super.initState();
    final ahora = DateTime.now();
    final l = widget.l;
    fecha = l?.fecha ?? fechaTexto(ahora);
    hora = l?.hora ?? horaTexto(ahora);
    momento = l?.momento ?? Momento.sugerido(ahora);
    if (l != null) {
      valor.text = '${l.valor}';
      notas.text = l.notas;
    }
  }

  void _guardar() {
    final v = int.tryParse(valor.text.trim());
    if (v == null || v < 20 || v > 600) {
      setState(() => error = 'Escribe un valor entre 20 y 600');
      return;
    }
    final l = widget.l ?? Lectura('', fecha: fecha, hora: hora, momento: momento, valor: v);
    l
      ..fecha = fecha
      ..hora = hora
      ..momento = momento
      ..valor = v
      ..notas = notas.text.trim();
    Datos.i.guardar(Col.lecturas, l);
    Navigator.pop(context, l);
  }

  @override
  Widget build(BuildContext context) => DialogoForm(
        titulo: widget.l == null ? 'Nueva medición' : 'Editar medición',
        onGuardar: _guardar,
        onBorrar: widget.l == null
            ? null
            : () async {
                if (await confirmar(context, '¿Eliminar esta medición?')) {
                  Datos.i.borrar(Col.lecturas, widget.l!.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
        campos: [
          TextField(
            controller: valor,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            decoration: InputDecoration(labelText: 'Glucosa (mg/dL)', errorText: error),
            onSubmitted: (_) => _guardar(),
          ),
          FechaHora(fecha, hora, (v) => setState(() => fecha = v), (v) => setState(() => hora = v)),
          Desplegable<String>('Momento', momento, {for (final m in Momento.lista) m.clave: m.nombre},
              (v) => setState(() => momento = v)),
          TextField(
            controller: notas,
            decoration: const InputDecoration(labelText: 'Notas (opcional)', hintText: 'Ejercicio, malestar, cambio de dosis…'),
          ),
        ],
      );
}

class PantallaGlucemia extends StatefulWidget {
  const PantallaGlucemia({super.key});

  @override
  State<PantallaGlucemia> createState() => _PantallaGlucemiaState();
}

class _PantallaGlucemiaState extends State<PantallaGlucemia> {
  String filtro = 'todos';
  int limite = 200;

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => abrirLectura(context),
          icon: const Icon(Icons.add),
          label: const Text('Medición'),
        ),
        body: ConDatos(builder: (c, d) {
          final lista = filtro == 'todos' ? d.lecturas : d.lecturas.where((x) => x.momento == filtro).toList();
          final presentes = d.lecturas.map((x) => x.momento).toSet();
          // Agrupar por día
          final grupos = <String, List<Lectura>>{};
          for (final l in lista.take(limite)) {
            grupos.putIfAbsent(l.fecha, () => []).add(l);
          }
          return Pagina([
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                children: [
                  for (final m in [const Momento('todos', 'Todos', 'Todos'), ...Momento.lista.where((m) => presentes.contains(m.clave))])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(m.corto),
                        selected: filtro == m.clave,
                        onSelected: (_) => setState(() => filtro = m.clave),
                      ),
                    ),
                ],
              ),
            ),
            if (lista.isEmpty) const Vacio('Sin mediciones. Pulsa «Medición» para apuntar la primera.'),
            for (final e in grupos.entries) ...[
              Rotulo(
                _tituloDia(e.key),
                accion: Text('media ${media(e.value.map((x) => x.valor))!.round()}',
                    style: const TextStyle(fontSize: 11.5, color: Tema.gris)),
              ),
              Card(
                child: Column(children: [
                  for (final l in e.value) ...[
                    ListTile(
                      dense: true,
                      onTap: () => abrirLectura(context, l),
                      leading: SizedBox(
                          width: 44,
                          child: Text(l.hora, style: const TextStyle(fontWeight: FontWeight.w600, color: Tema.gris))),
                      title: Text(Momento.de(l.momento).nombre),
                      subtitle: l.notas.isEmpty ? null : Text(l.notas, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Chapita(nombreNivel(nivelDe(l.valor, d.perfil)), color: Tema.nivel(nivelDe(l.valor, d.perfil))),
                        const SizedBox(width: 10),
                        SizedBox(width: 40, child: Align(alignment: Alignment.centerRight, child: ValorGlucosa(l.valor, tam: 17))),
                      ]),
                    ),
                    if (l != e.value.last) const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                ]),
              ),
            ],
            if (lista.length > limite)
              Padding(
                padding: const EdgeInsets.all(12),
                child: OutlinedButton(onPressed: () => setState(() => limite += 200), child: const Text('Ver más')),
              ),
          ]);
        }),
      );
}

String _tituloDia(String f) {
  final hoy = hoyTexto();
  final ayer = fechaTexto(DateTime.now().subtract(const Duration(days: 1)));
  if (f == hoy) return 'Hoy';
  if (f == ayer) return 'Ayer';
  final d = DateTime.tryParse(f);
  if (d == null) return f;
  const dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  return '${dias[d.weekday - 1]} ${fechaBonita(f)}';
}
