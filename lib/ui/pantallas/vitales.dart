import 'package:flutter/material.dart';

import '../../datos/datos.dart';
import '../../datos/modelos.dart';
import '../comun.dart';
import '../graficos.dart';
import '../tema.dart';

Future<void> abrirVital(BuildContext context, [Vital? v]) => showDialog(context: context, builder: (_) => _Form(v));

class _Form extends StatefulWidget {
  final Vital? v;
  const _Form(this.v);

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late String fecha, hora;
  final peso = TextEditingController(), ts = TextEditingController(), td = TextEditingController(), pulso = TextEditingController();
  String? error;

  @override
  void initState() {
    super.initState();
    final ahora = DateTime.now();
    final v = widget.v;
    fecha = v?.fecha ?? fechaTexto(ahora);
    hora = v?.hora ?? horaTexto(ahora);
    if (v != null) {
      if (v.peso != null) peso.text = num1(v.peso);
      if (v.ts != null) ts.text = '${v.ts}';
      if (v.td != null) td.text = '${v.td}';
      if (v.pulso != null) pulso.text = '${v.pulso}';
    }
  }

  void _guardar() {
    final p = leerNum(peso.text);
    final s = int.tryParse(ts.text.trim()), di = int.tryParse(td.text.trim()), pu = int.tryParse(pulso.text.trim());
    if (p == null && s == null && pu == null) {
      setState(() => error = 'Escribe al menos un valor');
      return;
    }
    if ((s == null) != (di == null)) {
      setState(() => error = 'La tensión lleva alta y baja');
      return;
    }
    final v = widget.v ?? Vital('', fecha: fecha, hora: hora);
    v
      ..fecha = fecha
      ..hora = hora
      ..peso = p
      ..ts = s
      ..td = di
      ..pulso = pu;
    Datos.i.guardar(Col.vitales, v);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => DialogoForm(
        titulo: widget.v == null ? 'Peso y tensión' : 'Editar registro',
        onGuardar: _guardar,
        onBorrar: widget.v == null
            ? null
            : () async {
                if (await confirmar(context, '¿Eliminar este registro?')) {
                  Datos.i.borrar(Col.vitales, widget.v!.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
        campos: [
          FechaHora(fecha, hora, (v) => setState(() => fecha = v), (v) => setState(() => hora = v)),
          TextField(
              controller: peso,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Peso (kg)', errorText: error)),
          Row(children: [
            Expanded(child: TextField(controller: ts, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tensión alta', hintText: '120'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: td, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tensión baja', hintText: '80'))),
          ]),
          TextField(controller: pulso, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pulso (ppm)')),
          if (Datos.i.perfil.altura == null)
            const Text('Pon tu altura en Ajustes para calcular el IMC.', style: TextStyle(fontSize: 12, color: Tema.gris)),
        ],
      );
}

String etiquetaImc(double v) => v < 18.5 ? 'Bajo peso' : v < 25 ? 'Normal' : v < 30 ? 'Sobrepeso' : 'Obesidad';
Color colorImc(double v) => v < 18.5 ? Tema.aviso : v < 25 ? Tema.ok : v < 30 ? Tema.aviso : Tema.alta;
Color colorTension(int s, int d) => (s >= 140 || d >= 90) ? Tema.alta : (s >= 130 || d >= 80) ? Tema.aviso : Tema.ok;

Future<void> _objetivo(BuildContext context) async {
  final p = Datos.i.perfil;
  final c = TextEditingController(text: p.pesoObjetivo == null ? '' : num1(p.pesoObjetivo));
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Peso objetivo'),
      content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'kg', helperText: 'Vacío para quitarlo')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Guardar')),
      ],
    ),
  );
  if (r == null) return;
  p.pesoObjetivo = leerNum(r);
  Datos.i.guardarPerfil();
}

class PantallaVitales extends StatelessWidget {
  const PantallaVitales({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => abrirVital(context), icon: const Icon(Icons.add), label: const Text('Registrar')),
        body: ConDatos(builder: (c, d) {
          final p = d.perfil;
          final conPeso = d.vitales.where((v) => v.peso != null).toList();
          final conTen = d.vitales.where((v) => v.ts != null && v.td != null).toList();
          final ultP = conPeso.firstOrNull, ultT = conTen.firstOrNull;
          final imc = p.imc(ultP?.peso);
          final serieP = conPeso.take(20).toList().reversed.toList();
          final serieT = conTen.take(20).toList().reversed.toList();

          // Progreso hacia el peso objetivo
          Widget? objetivo;
          if (p.pesoObjetivo != null && ultP != null) {
            final primero = conPeso.last.peso!;
            final total = primero - p.pesoObjetivo!;
            final hecho = primero - ultP.peso!;
            final falta = ultP.peso! - p.pesoObjetivo!;
            final frac = total.abs() < 0.05 ? 1.0 : (hecho / total).clamp(0.0, 1.0);
            objetivo = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  falta.abs() < 0.05 || (total > 0 && falta <= 0) || (total < 0 && falta >= 0)
                      ? '¡Objetivo conseguido! (${num1(p.pesoObjetivo)} kg)'
                      : 'Faltan ${num1(falta.abs())} kg para ${num1(p.pesoObjetivo)} kg',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(value: frac.toDouble(), minHeight: 10, backgroundColor: Tema.fondo, color: Tema.acento),
              ),
              const SizedBox(height: 4),
              Text('Desde ${num1(primero)} kg (${fechaBonita(conPeso.last.fecha)}): ${hecho >= 0 ? '−' : '+'}${num1(hecho.abs())} kg',
                  style: const TextStyle(fontSize: 12, color: Tema.gris)),
            ]);
          }

          return Pagina([
            FilaDatos([
              Dato('Peso', ultP == null ? '—' : num1(ultP.peso), unidad: ultP == null ? '' : 'kg',
                  sub: ultP == null ? '' : fechaBonita(ultP.fecha)),
              Dato('IMC', imc == null ? '—' : num1(imc), sub: imc == null ? (p.altura == null ? 'falta la altura' : '') : etiquetaImc(imc),
                  color: imc == null ? null : colorImc(imc)),
              Dato('Tensión', ultT == null ? '—' : '${ultT.ts}/${ultT.td}', unidad: ultT == null ? '' : 'mmHg',
                  sub: 'objetivo < 130/80', color: ultT == null ? null : colorTension(ultT.ts!, ultT.td!)),
              Dato('Pulso', d.vitales.where((v) => v.pulso != null).firstOrNull?.pulso?.toString() ?? '—', unidad: 'ppm'),
            ]),
            Columnas(
              izquierda: [
                Seccion('Peso objetivo',
                    accion: TextButton(onPressed: () => _objetivo(context), child: const Text('Cambiar')),
                    child: objetivo ?? const Vacio('Pon un peso objetivo para ver tu progreso.')),
                Seccion('Evolución del peso',
                    child: serieP.length < 2
                        ? const Vacio('Hacen falta al menos 2 registros')
                        : GraficoLinea(
                            valores: serieP.map((v) => v.peso).toList(),
                            etiquetas: serieP.map((v) => fechaCorta(v.fecha)).toList(),
                            bandaMin: p.pesoObjetivo,
                            bandaMax: p.pesoObjetivo,
                            decimales: 1,
                            color: Tema.aviso,
                          )),
                Seccion('Evolución de la tensión alta',
                    child: serieT.length < 2
                        ? const Vacio('Hacen falta al menos 2 registros')
                        : GraficoLinea(
                            valores: serieT.map((v) => v.ts!.toDouble()).toList(),
                            etiquetas: serieT.map((v) => fechaCorta(v.fecha)).toList(),
                            bandaMin: 90,
                            bandaMax: 130,
                            color: Tema.alta,
                            colorPunto: (s) => s >= 140 ? Tema.alta : s >= 130 ? Tema.aviso : Tema.ok,
                          )),
              ],
              derecha: [
                Seccion('Historial',
                    padding: EdgeInsets.zero,
                    child: d.vitales.isEmpty
                        ? const Vacio('Sin registros')
                        : Column(children: [
                            for (final v in d.vitales.take(60))
                              ListTile(
                                dense: true,
                                onTap: () => abrirVital(context, v),
                                title: Text([
                                  if (v.peso != null) '${num1(v.peso)} kg',
                                  if (v.ts != null) '${v.ts}/${v.td} mmHg',
                                  if (v.pulso != null) '${v.pulso} ppm',
                                ].join(' · ')),
                                subtitle: Text('${fechaBonita(v.fecha)} · ${v.hora}'),
                                trailing: v.ts != null && v.td != null
                                    ? Icon(Icons.circle, size: 10, color: colorTension(v.ts!, v.td!))
                                    : null,
                              ),
                          ])),
              ],
            ),
          ]);
        }),
      );
}
