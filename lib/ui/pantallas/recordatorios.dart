import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../datos/datos.dart';
import '../../datos/modelos.dart';
import '../../services/avisos.dart';
import '../comun.dart';
import '../tema.dart';

const _dias = ['Do', 'Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sa'];
const _orden = [1, 2, 3, 4, 5, 6, 0];
const _tipos = {'medicacion': 'Medicación', 'glucemia': 'Medir glucemia', 'cita': 'Cita médica', 'otro': 'Otro'};

IconData _icono(String t) => switch (t) {
      'medicacion' => Icons.medication_outlined,
      'glucemia' => Icons.water_drop_outlined,
      'cita' => Icons.event_outlined,
      _ => Icons.notifications_none,
    };

Future<void> abrirRecordatorio(BuildContext context, [Recordatorio? r]) =>
    showDialog(context: context, builder: (_) => _Form(r));

class _Form extends StatefulWidget {
  final Recordatorio? r;
  const _Form(this.r);

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final nombre = TextEditingController();
  String hora = '09:00', tipo = 'glucemia';
  Set<int> dias = {0, 1, 2, 3, 4, 5, 6};
  String? error;

  @override
  void initState() {
    super.initState();
    final r = widget.r;
    if (r != null) {
      nombre.text = r.nombre;
      hora = r.hora;
      tipo = r.tipo;
      dias = r.dias.toSet();
    }
  }

  void _guardar() {
    if (nombre.text.trim().isEmpty || dias.isEmpty) {
      setState(() => error = nombre.text.trim().isEmpty ? 'Pon un nombre' : 'Elige al menos un día');
      return;
    }
    final r = widget.r ?? Recordatorio('', nombre: '', hora: hora);
    r
      ..nombre = nombre.text.trim()
      ..hora = hora
      ..tipo = tipo
      ..dias = (dias.toList()..sort());
    Datos.i.guardar(Col.recordatorios, r);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => DialogoForm(
        titulo: widget.r == null ? 'Nuevo recordatorio' : 'Editar recordatorio',
        onGuardar: _guardar,
        onBorrar: widget.r == null
            ? null
            : () async {
                if (await confirmar(context, '¿Eliminar este recordatorio?')) {
                  Datos.i.borrar(Col.recordatorios, widget.r!.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
        campos: [
          TextField(
              controller: nombre,
              autofocus: widget.r == null,
              decoration: InputDecoration(labelText: 'Qué hay que hacer', hintText: 'Medir glucosa en ayunas', errorText: error)),
          Row(children: [
            Expanded(child: CampoHora('Hora', hora, (v) => setState(() => hora = v))),
            const SizedBox(width: 10),
            Expanded(child: Desplegable<String>('Tipo', tipo, _tipos, (v) => setState(() => tipo = v))),
          ]),
          Wrap(spacing: 4, children: [
            for (final d in _orden)
              FilterChip(
                label: Text(_dias[d]),
                selected: dias.contains(d),
                onSelected: (s) => setState(() => s ? dias.add(d) : dias.remove(d)),
              ),
            TextButton(onPressed: () => setState(() => dias = {0, 1, 2, 3, 4, 5, 6}), child: const Text('Todos')),
          ]),
        ],
      );
}

class PantallaRecordatorios extends StatelessWidget {
  const PantallaRecordatorios({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => abrirRecordatorio(context), icon: const Icon(Icons.add), label: const Text('Recordatorio')),
        body: ConDatos(builder: (c, d) {
          final windows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
          final meds = d.medicamentos.where((m) => m.avisar && m.horarios.isNotEmpty).toList();
          return Pagina([
            Rotulo('Recordatorios'),
            if (d.recordatorios.isEmpty) const Tarjeta(child: Vacio('Sin recordatorios.')),
            for (final r in d.recordatorios)
              Tarjeta(
                onTap: () => abrirRecordatorio(context, r),
                padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                child: Row(children: [
                  Icon(_icono(r.tipo), color: r.activo ? Tema.acento : Tema.gris),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.nombre, style: TextStyle(fontWeight: FontWeight.w600, color: r.activo ? Tema.texto : Tema.gris)),
                      Text(
                          '${r.hora} · ${r.dias.length == 7 ? 'Todos los días' : _orden.where(r.dias.contains).map((x) => _dias[x]).join(', ')}',
                          style: const TextStyle(fontSize: 12.5, color: Tema.gris)),
                    ]),
                  ),
                  Switch(
                    value: r.activo,
                    onChanged: (v) {
                      r.activo = v;
                      d.guardar(Col.recordatorios, r);
                    },
                  ),
                ]),
              ),
            if (meds.isNotEmpty) ...[
              Rotulo('Avisos de medicación'),
              Tarjeta(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final m in meds)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        const Icon(Icons.medication_outlined, size: 18, color: Tema.acento),
                        const SizedBox(width: 10),
                        Expanded(child: Text(m.nombre)),
                        Text(m.horarios.join(' · '), style: const TextStyle(color: Tema.gris)),
                      ]),
                    ),
                  const SizedBox(height: 4),
                  const Text('Se activan o quitan desde cada medicamento.', style: TextStyle(fontSize: 11.5, color: Tema.gris)),
                ]),
              ),
            ],
            Rotulo('Notificaciones'),
            Nota(
              'Cómo funcionan',
              windows
                  ? 'En Windows los avisos salen aunque la app esté cerrada, durante los 7 días siguientes a la última '
                      'vez que la abriste. Ábrela de vez en cuando para que se renueven.'
                  : 'Los avisos se repiten solos cada día o semana, aunque la app esté cerrada. Si no te llegan, revisa '
                      'que GluControl tenga permiso de notificaciones y que el ahorro de batería no la limite.',
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                    onPressed: () async {
                      await Avisos.probar();
                      if (context.mounted) avisar(context, 'Notificación de prueba enviada');
                    },
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Probar notificación')),
                OutlinedButton.icon(
                    onPressed: () async {
                      await Avisos.reprogramar(d, forzar: true);
                      if (context.mounted) avisar(context, 'Avisos programados de nuevo');
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reprogramar avisos')),
              ]),
            ),
          ]);
        }),
      );
}
