import 'package:flutter/material.dart';

import '../../datos/datos.dart';
import '../../datos/modelos.dart';
import '../comun.dart';
import '../tema.dart';

Future<void> abrirCita(BuildContext context, [Cita? c]) => showDialog(context: context, builder: (_) => _Form(c));

class _Form extends StatefulWidget {
  final Cita? c;
  const _Form(this.c);

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late String fecha, hora, tipo;
  final esp = TextEditingController(), notas = TextEditingController();

  @override
  void initState() {
    super.initState();
    final c = widget.c;
    fecha = c?.fecha ?? hoyTexto();
    hora = c?.hora ?? '09:00';
    tipo = c?.tipo ?? 'med';
    if (c != null) {
      esp.text = c.especialista;
      notas.text = c.notas;
    }
  }

  void _guardar() {
    final c = widget.c ?? Cita('', fecha: fecha, hora: hora);
    c
      ..fecha = fecha
      ..hora = hora
      ..tipo = tipo
      ..especialista = esp.text.trim()
      ..notas = notas.text.trim();
    Datos.i.guardar(Col.citas, c);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => DialogoForm(
        titulo: widget.c == null ? 'Nueva cita' : 'Editar cita',
        onGuardar: _guardar,
        onBorrar: widget.c == null
            ? null
            : () async {
                if (await confirmar(context, '¿Eliminar esta cita?')) {
                  Datos.i.borrar(Col.citas, widget.c!.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
        campos: [
          Row(children: [
            Expanded(child: CampoFecha('Fecha', fecha, (v) => setState(() => fecha = v), futuro: true)),
            const SizedBox(width: 10),
            Expanded(child: CampoHora('Hora', hora, (v) => setState(() => hora = v))),
          ]),
          Desplegable<String>('Tipo', tipo, Cita.tipos, (v) => setState(() => tipo = v)),
          TextField(controller: esp, decoration: const InputDecoration(labelText: 'Especialista / centro', hintText: 'Endocrino, Hospital General')),
          TextField(controller: notas, maxLines: 3, minLines: 1, decoration: const InputDecoration(labelText: 'Motivo / qué preguntar')),
        ],
      );
}

class PantallaCitas extends StatelessWidget {
  const PantallaCitas({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => abrirCita(context), icon: const Icon(Icons.add), label: const Text('Cita')),
        body: ConDatos(builder: (c, d) {
          final hoy = hoyTexto();
          final prox = d.citas.where((x) => x.fecha.compareTo(hoy) >= 0).toList();
          final pasadas = d.citas.where((x) => x.fecha.compareTo(hoy) < 0).toList().reversed.toList();
          Widget fila(Cita x, bool pasada) {
            final f = DateTime.tryParse(x.fecha);
            const meses = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];
            return ListTile(
              onTap: () => abrirCita(context, x),
              leading: Container(
                width: 46,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(color: pasada ? Tema.fondo : Tema.acentoSuave, borderRadius: BorderRadius.circular(8)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${f?.day ?? ''}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: pasada ? Tema.gris : Tema.acento)),
                  Text(f == null ? '' : meses[f.month - 1], style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Tema.gris)),
                ]),
              ),
              title: Text(x.especialista.isEmpty ? (Cita.tipos[x.tipo] ?? x.tipo) : x.especialista),
              subtitle: Text([x.hora, Cita.tipos[x.tipo] ?? x.tipo, if (x.notas.isNotEmpty) x.notas].join(' · '),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            );
          }

          return Pagina([
            Columnas(
              izquierda: [
                Seccion('Próximas',
                    padding: EdgeInsets.zero,
                    child: prox.isEmpty ? const Vacio('Sin citas próximas') : Column(children: [for (final x in prox) fila(x, false)])),
              ],
              derecha: [
                Seccion('Anteriores',
                    padding: EdgeInsets.zero,
                    child: pasadas.isEmpty ? const Vacio('Sin historial') : Column(children: [for (final x in pasadas.take(40)) fila(x, true)])),
              ],
            ),
          ]);
        }),
      );
}
