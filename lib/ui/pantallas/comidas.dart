import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';

import '../../datos/analisis.dart';
import '../../datos/datos.dart';
import '../../datos/modelos.dart';
import '../../services/ia.dart';
import '../../services/imagenes.dart';
import '../comun.dart';
import '../tema.dart';

/// Elige una foto: en Android, cámara o galería; en Windows, un archivo.
Future<Uint8List?> elegirFoto(BuildContext context) async {
  final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  if (android) {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Hacer foto'), onTap: () => Navigator.pop(c, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Elegir de la galería'), onTap: () => Navigator.pop(c, ImageSource.gallery)),
        ]),
      ),
    );
    if (origen == null) return null;
    final f = await ImagePicker().pickImage(source: origen, maxWidth: 2000, maxHeight: 2000);
    return f == null ? null : await f.readAsBytes();
  }
  const tipos = XTypeGroup(label: 'Imágenes', extensions: ['jpg', 'jpeg', 'png', 'webp', 'heic']);
  final f = await openFile(acceptedTypeGroups: [tipos]);
  return f == null ? null : await f.readAsBytes();
}

Future<void> abrirComida(BuildContext context, [Comida? c]) =>
    showDialog(context: context, builder: (_) => _FormComida(c));

class _FormComida extends StatefulWidget {
  final Comida? c;
  const _FormComida(this.c);

  @override
  State<_FormComida> createState() => _FormComidaState();
}

class _FormComidaState extends State<_FormComida> {
  late String fecha, hora, tipo, ig;
  final alimentos = TextEditingController(), kcal = TextEditingController(), hc = TextEditingController();
  final notas = TextEditingController();
  String? error, estadoFoto;
  bool analizando = false;
  Uint8List? miniatura;

  @override
  void initState() {
    super.initState();
    final ahora = DateTime.now();
    final c = widget.c;
    fecha = c?.fecha ?? fechaTexto(ahora);
    hora = c?.hora ?? horaTexto(ahora);
    tipo = c?.tipo ?? TipoComida.sugerido(ahora);
    ig = c?.ig ?? 'medio';
    if (c != null) {
      alimentos.text = c.alimentos;
      if (c.kcal > 0) kcal.text = '${c.kcal}';
      if (c.hc != null) hc.text = '${c.hc}';
      notas.text = c.notas;
    }
  }

  Future<void> _foto() async {
    final bytes = await elegirFoto(context);
    if (bytes == null) return;
    setState(() {
      analizando = true;
      estadoFoto = 'Analizando el plato…';
    });
    try {
      final jpeg = await Imagenes.comprimir(bytes, lado: 1024, calidad: 75);
      setState(() => miniatura = jpeg);
      final r = await IA.analizarPlato(Datos.i.perfil.modeloIA, jpeg);
      setState(() {
        if (r['alimentos'] != null) alimentos.text = r['alimentos'].toString();
        if (r['kcal'] != null) kcal.text = '${(r['kcal'] as num).round()}';
        if (r['hc'] != null) hc.text = '${(r['hc'] as num).round()}';
        if (['bajo', 'medio', 'alto'].contains(r['ig'])) ig = r['ig'];
        estadoFoto = 'Hecho. Revisa y corrige lo que haga falta.';
      });
    } catch (e) {
      setState(() => estadoFoto = 'No se pudo analizar: $e');
    } finally {
      if (mounted) setState(() => analizando = false);
    }
  }

  void _guardar() {
    if (alimentos.text.trim().isEmpty) {
      setState(() => error = 'Escribe qué has comido');
      return;
    }
    final c = widget.c ?? Comida('', fecha: fecha, hora: hora, tipo: tipo, alimentos: '');
    c
      ..fecha = fecha
      ..hora = hora
      ..tipo = tipo
      ..alimentos = alimentos.text.trim()
      ..kcal = int.tryParse(kcal.text.trim()) ?? 0
      ..hc = int.tryParse(hc.text.trim())
      ..ig = ig
      ..notas = notas.text.trim();
    Datos.i.guardar(Col.comidas, c);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => DialogoForm(
        titulo: widget.c == null ? 'Nueva comida' : 'Editar comida',
        onGuardar: _guardar,
        onBorrar: widget.c == null
            ? null
            : () async {
                if (await confirmar(context, '¿Eliminar esta comida?')) {
                  Datos.i.borrar(Col.comidas, widget.c!.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
        campos: [
          OutlinedButton.icon(
            onPressed: analizando ? null : _foto,
            icon: analizando
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.photo_camera_outlined),
            label: const Text('Foto del plato (la IA lo rellena)'),
          ),
          if (miniatura != null)
            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(miniatura!, height: 140, fit: BoxFit.cover)),
          if (estadoFoto != null) Text(estadoFoto!, style: const TextStyle(fontSize: 12, color: Tema.gris)),
          FechaHora(fecha, hora, (v) => setState(() => fecha = v), (v) => setState(() => hora = v)),
          Desplegable<String>('Comida', tipo, {for (final t in TipoComida.lista) t.clave: t.nombre}, (v) => setState(() => tipo = v)),
          TextField(
              controller: alimentos,
              maxLines: 3,
              minLines: 2,
              decoration: InputDecoration(labelText: 'Qué has comido', errorText: error, hintText: 'Lentejas con verduras, pan, manzana')),
          Row(children: [
            Expanded(child: TextField(controller: hc, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Hidratos (g)'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: kcal, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Calorías'))),
          ]),
          Desplegable<String>('Índice glucémico', ig, const {'bajo': 'Bajo', 'medio': 'Medio', 'alto': 'Alto'}, (v) => setState(() => ig = v)),
          TextField(controller: notas, decoration: const InputDecoration(labelText: 'Notas (opcional)')),
        ],
      );
}

Color colorIg(String ig) => switch (ig) { 'bajo' => Tema.ok, 'alto' => Tema.alta, _ => Tema.aviso };

class PantallaComidas extends StatelessWidget {
  const PantallaComidas({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => abrirComida(context),
          icon: const Icon(Icons.add),
          label: const Text('Comida'),
        ),
        body: ConDatos(builder: (c, d) {
          final pares = {for (final x in emparejarComidas(d, dias: 3650)) x.comida.id: x};
          final fechas = fechasUltimos(7);
          final grupos = <String, List<Comida>>{};
          for (final x in d.comidas.take(150)) {
            grupos.putIfAbsent(x.fecha, () => []).add(x);
          }
          return Pagina([
            Columnas(
              izquierda: [
                Rotulo('Últimos 7 días'),
                Tarjeta(
                  child: Column(children: [
                    for (final f in fechas.reversed)
                      Builder(builder: (c) {
                        final del = d.comidas.where((x) => x.fecha == f).toList();
                        final k = del.fold<int>(0, (s, x) => s + x.kcal);
                        final h = del.fold<int>(0, (s, x) => s + (x.hc ?? 0));
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            SizedBox(width: 60, child: Text(fechaCorta(f), style: const TextStyle(color: Tema.gris))),
                            Expanded(child: Text('${del.length} comidas', style: const TextStyle(fontSize: 12.5))),
                            if (h > 0) SizedBox(width: 70, child: Text('$h g HC', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5))),
                            SizedBox(
                                width: 80,
                                child: Text(k > 0 ? '$k kcal' : '—',
                                    textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, color: Tema.acento))),
                          ]),
                        );
                      }),
                  ]),
                ),
                const Nota('Para ver cómo te sienta cada comida',
                    'Mide antes de comer y a las 2 horas. En «Comida y glucosa» verás qué te sube más.',
                    icono: Icons.tips_and_updates_outlined),
              ],
              derecha: [
                if (d.comidas.isEmpty) ...[Rotulo('Diario'), const Tarjeta(child: Vacio('Sin comidas apuntadas.'))],
                for (final e in grupos.entries) ...[
                  Rotulo(e.key == hoyTexto() ? 'Hoy' : fechaBonita(e.key)),
                  Card(
                    child: Column(children: [
                      for (final x in e.value)
                        ListTile(
                          onTap: () => abrirComida(context, x),
                          title: Text(x.alimentos, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                              Text('${x.hora} · ${TipoComida.nombreDe(x.tipo)}', style: const TextStyle(fontSize: 12)),
                              Chapita('IG ${x.ig}', color: colorIg(x.ig)),
                              if (x.hc != null) Chapita('${x.hc} g HC', color: Tema.gris),
                              if (x.kcal > 0) Chapita('${x.kcal} kcal', color: Tema.gris),
                              if (pares[x.id] != null) _ChapaDespues(pares[x.id]!),
                            ]),
                          ),
                        ),
                    ]),
                  ),
                ],
              ],
            ),
          ]);
        }),
      );
}

class _ChapaDespues extends StatelessWidget {
  final ParComida p;
  const _ChapaDespues(this.p);

  @override
  Widget build(BuildContext context) {
    final n = nivelDe(p.despues.valor, Datos.i.perfil);
    final delta = p.delta;
    return Chapita(
      'Después ${p.despues.valor}${delta != null ? ' (${delta >= 0 ? '+' : ''}$delta)' : ''}',
      color: Tema.nivel(n),
    );
  }
}
