import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../datos/datos.dart';
import '../../datos/modelos.dart';
import '../../services/imagenes.dart';
import '../comun.dart';
import '../tema.dart';
import 'comidas.dart' show elegirFoto;

Future<void> abrirInforme(BuildContext context, [Informe? i]) => showDialog(context: context, builder: (_) => _Form(i));

void verFoto(BuildContext context, String b64) {
  showDialog(
    context: context,
    builder: (c) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: Stack(children: [
        InteractiveViewer(maxScale: 5, child: Image.memory(base64Decode(b64), fit: BoxFit.contain)),
        Positioned(
          right: 4,
          top: 4,
          child: IconButton.filled(onPressed: () => Navigator.pop(c), icon: const Icon(Icons.close)),
        ),
      ]),
    ),
  );
}

class _Form extends StatefulWidget {
  final Informe? i;
  const _Form(this.i);

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late String fecha, tipo;
  final titulo = TextEditingController(), medico = TextEditingController(), contenido = TextEditingController();
  String? foto, error;
  bool cargando = false;

  @override
  void initState() {
    super.initState();
    final i = widget.i;
    fecha = i?.fecha ?? hoyTexto();
    tipo = i?.tipo ?? 'analisis';
    if (i != null) {
      titulo.text = i.titulo;
      medico.text = i.medico;
      contenido.text = i.contenido;
      foto = i.foto;
    }
  }

  Future<void> _foto() async {
    final b = await elegirFoto(context);
    if (b == null) return;
    setState(() => cargando = true);
    final Uint8List j = await Imagenes.comprimir(b);
    setState(() {
      foto = base64Encode(j);
      cargando = false;
    });
  }

  void _guardar() {
    if (titulo.text.trim().isEmpty) {
      setState(() => error = 'Pon un título');
      return;
    }
    final i = widget.i ?? Informe('', titulo: '', fecha: fecha);
    i
      ..titulo = titulo.text.trim()
      ..fecha = fecha
      ..tipo = tipo
      ..medico = medico.text.trim()
      ..contenido = contenido.text.trim()
      ..foto = foto;
    Datos.i.guardar(Col.informes, i);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => DialogoForm(
        titulo: widget.i == null ? 'Nuevo informe' : 'Editar informe',
        onGuardar: _guardar,
        onBorrar: widget.i == null
            ? null
            : () async {
                if (await confirmar(context, '¿Eliminar este informe?')) {
                  Datos.i.borrar(Col.informes, widget.i!.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
        campos: [
          TextField(controller: titulo, decoration: InputDecoration(labelText: 'Título', hintText: 'Analítica trimestral', errorText: error)),
          Row(children: [
            Expanded(child: CampoFecha('Fecha', fecha, (v) => setState(() => fecha = v))),
            const SizedBox(width: 10),
            Expanded(child: Desplegable<String>('Tipo', tipo, Informe.tipos, (v) => setState(() => tipo = v))),
          ]),
          TextField(controller: medico, decoration: const InputDecoration(labelText: 'Médico / centro')),
          TextField(
              controller: contenido,
              maxLines: 8,
              minLines: 3,
              decoration: const InputDecoration(labelText: 'Resultados / resumen', hintText: 'HbA1c 6,8 %, colesterol LDL 95…')),
          Row(children: [
            OutlinedButton.icon(
              onPressed: cargando ? null : _foto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(foto == null ? 'Añadir foto' : 'Cambiar foto'),
            ),
            if (foto != null) ...[
              const SizedBox(width: 8),
              TextButton(onPressed: () => setState(() => foto = null), child: const Text('Quitar')),
            ],
          ]),
          if (foto != null)
            GestureDetector(
              onTap: () => verFoto(context, foto!),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(base64Decode(foto!), height: 160, fit: BoxFit.cover)),
            ),
        ],
      );
}

class PantallaInformes extends StatefulWidget {
  const PantallaInformes({super.key});

  @override
  State<PantallaInformes> createState() => _PantallaInformesState();
}

class _PantallaInformesState extends State<PantallaInformes> {
  String filtro = 'todos';
  String buscar = '';

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => abrirInforme(context), icon: const Icon(Icons.add), label: const Text('Informe')),
        body: ConDatos(builder: (c, d) {
          final q = buscar.toLowerCase();
          final lista = d.informes
              .where((x) => filtro == 'todos' || x.tipo == filtro)
              .where((x) => q.isEmpty || '${x.titulo} ${x.medico} ${x.contenido}'.toLowerCase().contains(q))
              .toList();
          return Pagina([
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar en informes'),
                onChanged: (v) => setState(() => buscar = v),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
                for (final e in {'todos': 'Todos', ...Informe.tipos}.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(label: Text(e.value), selected: filtro == e.key, onSelected: (_) => setState(() => filtro = e.key)),
                  ),
              ]),
            ),
            if (lista.isEmpty) const Vacio('Sin informes'),
            for (final i in lista)
              Tarjeta(
                onTap: () => abrirInforme(context, i),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Chapita(Informe.tipos[i.tipo] ?? i.tipo),
                        const SizedBox(width: 8),
                        Text(fechaBonita(i.fecha), style: const TextStyle(color: Tema.gris, fontSize: 12)),
                      ]),
                      const SizedBox(height: 4),
                      Text(i.titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      if (i.medico.isNotEmpty) Text(i.medico, style: const TextStyle(color: Tema.gris, fontSize: 12.5)),
                      if (i.contenido.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(i.contenido, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                      ],
                    ]),
                  ),
                  if (i.foto != null) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => verFoto(context, i.foto!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(base64Decode(i.foto!), width: 72, height: 72, fit: BoxFit.cover, gaplessPlayback: true),
                      ),
                    ),
                  ],
                ]),
              ),
          ]);
        }),
      );
}
