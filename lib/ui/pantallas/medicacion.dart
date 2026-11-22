import 'package:flutter/material.dart';

import '../../datos/datos.dart';
import '../../datos/modelos.dart';
import '../comun.dart';
import '../tema.dart';

/// Tomas de hoy de un medicamento: cada horario con su toma (o null si falta).
List<(String, Toma?)> tomasDeHoy(Datos d, Medicamento m) {
  final hoy = hoyTexto();
  final hechas = d.tomas.where((t) => t.medId == m.id && t.fecha == hoy).toList();
  final libres = hechas.where((t) => t.horario.isEmpty).toList();
  return [
    for (final h in m.horarios)
      (
        h,
        hechas.where((t) => t.horario == h).firstOrNull ?? (libres.isNotEmpty ? libres.removeAt(0) : null),
      )
  ];
}

/// Fila de tomas de hoy con casillas (la usan Medicación e Inicio).
class TomasHoy extends StatelessWidget {
  final Medicamento m;
  const TomasHoy(this.m, {super.key});

  @override
  Widget build(BuildContext context) {
    final d = Datos.i;
    final t = tomasDeHoy(d, m);
    if (t.isEmpty) return const SizedBox.shrink();
    final ahora = horaTexto(DateTime.now());
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final (h, toma) in t)
        FilterChip(
          label: Text(toma == null ? h : '$h ✓ ${toma.hora}'),
          selected: toma != null,
          showCheckmark: false,
          avatar: Icon(
              toma != null
                  ? Icons.check_circle
                  : (h.compareTo(ahora) < 0 ? Icons.error_outline : Icons.radio_button_unchecked),
              size: 18,
              color: toma != null ? Tema.ok : (h.compareTo(ahora) < 0 ? Tema.aviso : Tema.gris)),
          selectedColor: Tema.ok.withValues(alpha: 0.12),
          onSelected: (_) async {
            if (toma == null) {
              d.tomar(m, horario: h);
              avisar(context, '${m.nombre}: toma de las $h apuntada');
            } else if (await confirmar(context, '¿Deshacer la toma de las $h?', 'Se devuelve la unidad al stock.')) {
              d.deshacerToma(toma);
            }
          },
        ),
    ]);
  }
}

Future<void> abrirMedicamento(BuildContext context, [Medicamento? m]) =>
    showDialog(context: context, builder: (_) => _FormMed(m));

class _FormMed extends StatefulWidget {
  final Medicamento? m;
  const _FormMed(this.m);

  @override
  State<_FormMed> createState() => _FormMedState();
}

class _FormMedState extends State<_FormMed> {
  final nombre = TextEditingController(), dosis = TextEditingController(), horarios = TextEditingController();
  final stock = TextEditingController(), alerta = TextEditingController(text: '10'), notas = TextEditingController();
  String tipo = 'Comprimido';
  bool avisarHoras = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final m = widget.m;
    if (m != null) {
      nombre.text = m.nombre;
      dosis.text = m.dosis;
      horarios.text = m.horarios.join(', ');
      stock.text = '${m.stock}';
      alerta.text = '${m.alerta}';
      notas.text = m.notas;
      tipo = m.tipo;
      avisarHoras = m.avisar;
    }
  }

  void _guardar() {
    if (nombre.text.trim().isEmpty) {
      setState(() => error = 'Pon el nombre');
      return;
    }
    final hs = horarios.text
        .split(RegExp(r'[,;\s]+'))
        .map((e) => e.trim().replaceAll('.', ':'))
        .where((e) => RegExp(r'^\d{1,2}:\d{2}$').hasMatch(e))
        .map((e) => e.padLeft(5, '0'))
        .toList()
      ..sort();
    final m = widget.m ?? Medicamento('', nombre: '');
    m
      ..nombre = nombre.text.trim()
      ..dosis = dosis.text.trim()
      ..tipo = tipo
      ..horarios = hs
      ..stock = int.tryParse(stock.text.trim()) ?? 0
      ..alerta = int.tryParse(alerta.text.trim()) ?? 10
      ..notas = notas.text.trim()
      ..avisar = avisarHoras;
    Datos.i.guardar(Col.medicamentos, m);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => DialogoForm(
        titulo: widget.m == null ? 'Nuevo medicamento' : 'Editar medicamento',
        onGuardar: _guardar,
        onBorrar: widget.m == null
            ? null
            : () async {
                if (await confirmar(context, '¿Eliminar ${widget.m!.nombre}?', 'Se mantiene el historial de tomas.')) {
                  Datos.i.borrar(Col.medicamentos, widget.m!.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
        campos: [
          TextField(
              controller: nombre,
              decoration: InputDecoration(labelText: 'Nombre', hintText: 'Metformina 850 mg', errorText: error)),
          Row(children: [
            Expanded(child: TextField(controller: dosis, decoration: const InputDecoration(labelText: 'Dosis', hintText: '1 comprimido'))),
            const SizedBox(width: 10),
            Expanded(
              child: Desplegable<String>('Tipo', tipo,
                  {for (final t in ['Comprimido', 'Cápsula', 'Insulina', 'Inyectable', 'Líquido', 'Otro']) t: t},
                  (v) => setState(() => tipo = v)),
            ),
          ]),
          TextField(
              controller: horarios,
              decoration: const InputDecoration(labelText: 'Horarios', hintText: '08:00, 14:00, 22:00')),
          Row(children: [
            Expanded(child: TextField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Unidades que tienes'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: alerta, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Avisar cuando queden'))),
          ]),
          SwitchListTile(
            value: avisarHoras,
            onChanged: (v) => setState(() => avisarHoras = v),
            contentPadding: EdgeInsets.zero,
            title: const Text('Avisarme a cada hora de toma'),
            subtitle: const Text('Notificación en el móvil y en el PC'),
          ),
          TextField(controller: notas, maxLines: 2, decoration: const InputDecoration(labelText: 'Instrucciones', hintText: 'Con la comida…')),
        ],
      );
}

Future<void> _reponer(BuildContext context, Medicamento m) async {
  final c = TextEditingController();
  final n = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Reponer ${m.nombre}'),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: 'Unidades que añades', helperText: 'Ahora tienes ${m.stock}'),
        onSubmitted: (_) => Navigator.pop(ctx, int.tryParse(c.text.trim())),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(c.text.trim())), child: const Text('Añadir')),
      ],
    ),
  );
  if (n == null || n <= 0) return;
  m.stock += n;
  Datos.i.guardar(Col.medicamentos, m);
}

class PantallaMedicacion extends StatelessWidget {
  const PantallaMedicacion({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => abrirMedicamento(context),
          icon: const Icon(Icons.add),
          label: const Text('Medicamento'),
        ),
        body: ConDatos(builder: (c, d) {
          final hoy = hoyTexto();
          final tomasHoy = d.tomas.where((t) => t.fecha == hoy).toList();
          return Pagina([
            Columnas(
              izquierda: [
                Rotulo('Mis medicamentos (${d.medicamentos.length})'),
                if (d.medicamentos.isEmpty)
                  const Tarjeta(child: Vacio('Añade tu medicación para llevar las tomas y el stock.')),
                for (final m in d.medicamentos)
                  Tarjeta(
                    onTap: () => abrirMedicamento(context, m),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Tema.acentoSuave,
                          child: Icon(m.tipo == 'Insulina' || m.tipo == 'Inyectable' ? Icons.vaccines_outlined : Icons.medication_outlined,
                              color: Tema.acento, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(m.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            Text([m.dosis, m.tipo, if (m.horarios.isNotEmpty) m.horarios.join(' · ')].where((e) => e.isNotEmpty).join(' — '),
                                style: const TextStyle(color: Tema.gris, fontSize: 12.5)),
                          ]),
                        ),
                        if (m.avisar) const Tooltip(message: 'Con aviso', child: Icon(Icons.notifications_active_outlined, size: 18, color: Tema.acento)),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Chapita(
                          m.agotado
                              ? 'Agotado'
                              : '${m.stock} uds${m.horarios.isNotEmpty ? ' · ${m.diasRestantes} días' : ''}',
                          color: m.agotado ? Tema.error : (m.stockBajo ? Tema.aviso : Tema.ok),
                        ),
                        const Spacer(),
                        TextButton.icon(
                            onPressed: () => _reponer(context, m),
                            icon: const Icon(Icons.add_shopping_cart, size: 18),
                            label: const Text('Reponer')),
                        if (m.horarios.isEmpty)
                          FilledButton.tonal(
                              onPressed: () {
                                d.tomar(m);
                                avisar(context, 'Toma de ${m.nombre} apuntada');
                              },
                              child: const Text('Tomar')),
                      ]),
                      if (m.horarios.isNotEmpty) ...[const SizedBox(height: 6), TomasHoy(m)],
                      if (m.notas.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(m.notas, style: const TextStyle(fontSize: 12, color: Tema.gris)),
                      ],
                    ]),
                  ),
              ],
              derecha: [
                Seccion('Tomas de hoy',
                    child: tomasHoy.isEmpty
                        ? const Vacio('Ninguna toma apuntada hoy')
                        : Column(children: [
                            for (final t in tomasHoy)
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.check_circle, color: Tema.ok, size: 20),
                                title: Text(t.nombre),
                                subtitle: Text(t.dosis),
                                trailing: Text(t.hora, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ),
                          ])),
                Seccion('Historial',
                    child: d.tomas.isEmpty
                        ? const Vacio('Sin tomas')
                        : Column(children: [
                            for (final t in d.tomas.take(40))
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(children: [
                                  SizedBox(width: 90, child: Text(fechaBonita(t.fecha), style: const TextStyle(fontSize: 12.5, color: Tema.gris))),
                                  SizedBox(width: 50, child: Text(t.hora, style: const TextStyle(fontSize: 12.5))),
                                  Expanded(child: Text(t.nombre, style: const TextStyle(fontSize: 12.5))),
                                  IconButton(
                                    tooltip: 'Deshacer',
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.undo, size: 18),
                                    onPressed: () async {
                                      if (await confirmar(context, '¿Deshacer esta toma?', 'Se devuelve la unidad al stock.')) {
                                        d.deshacerToma(t);
                                      }
                                    },
                                  ),
                                ]),
                              ),
                          ])),
              ],
            ),
          ]);
        }),
      );
}
