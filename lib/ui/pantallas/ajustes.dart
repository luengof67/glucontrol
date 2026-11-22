import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../datos/datos.dart';
import '../../datos/modelos.dart';
import '../../services/archivos.dart';
import '../../services/fb.dart';
import '../../services/ia.dart';
import '../../services/informe_pdf.dart';
import '../comun.dart';
import '../login.dart';
import '../tema.dart';

class PantallaAjustes extends StatefulWidget {
  const PantallaAjustes({super.key});

  @override
  State<PantallaAjustes> createState() => _PantallaAjustesState();
}

class _PantallaAjustesState extends State<PantallaAjustes> {
  final nombre = TextEditingController(), medico = TextEditingController(), altura = TextEditingController();
  final metaMin = TextEditingController(), metaMax = TextEditingController(), metaHba = TextEditingController();
  final horasAviso = TextEditingController(), clave = TextEditingController(), modelo = TextEditingController();
  String tipo = 'Tipo 2', fechaNac = '';
  bool verClave = false, ocupado = false;
  int diasInforme = 90;

  @override
  void initState() {
    super.initState();
    _cargar();
    IA.clave().then((k) {
      if (mounted && k != null) setState(() => clave.text = k);
    });
  }

  void _cargar() {
    final p = Datos.i.perfil;
    nombre.text = p.nombre;
    medico.text = p.medico;
    altura.text = p.altura == null ? '' : num1(p.altura, 0);
    metaMin.text = '${p.metaMin}';
    metaMax.text = '${p.metaMax}';
    metaHba.text = num1(p.metaHba);
    horasAviso.text = '${p.horasAviso}';
    modelo.text = p.modeloIA;
    tipo = p.tipo;
    fechaNac = p.fechaNac;
  }

  void _guardarPerfil() {
    final p = Datos.i.perfil;
    final mn = int.tryParse(metaMin.text.trim()) ?? 70, mx = int.tryParse(metaMax.text.trim()) ?? 180;
    if (mn < 50 || mx > 300 || mn >= mx) {
      avisar(context, 'Revisa el rango objetivo (mínimo entre 50 y el máximo)', error: true);
      return;
    }
    p
      ..nombre = nombre.text.trim()
      ..medico = medico.text.trim()
      ..altura = leerNum(altura.text)
      ..tipo = tipo
      ..fechaNac = fechaNac
      ..metaMin = mn
      ..metaMax = mx
      ..metaHba = leerNum(metaHba.text) ?? 7
      ..horasAviso = int.tryParse(horasAviso.text.trim()) ?? 8;
    Datos.i.guardarPerfil();
    avisar(context, 'Guardado');
  }

  Future<void> _guardarIA() async {
    await IA.guardarClave(clave.text);
    Datos.i.perfil.modeloIA = modelo.text.trim().isEmpty ? Perfil.modeloIAPorDefecto : modelo.text.trim();
    Datos.i.guardarPerfil();
    if (mounted) avisar(context, 'Asistente configurado');
  }

  Future<void> _probarIA() async {
    await _guardarIA();
    setState(() => ocupado = true);
    try {
      final r = await IA.preguntar(Datos.i.perfil.modeloIA, [('user', 'Responde solo: "Conexión correcta".')], maxTokens: 30);
      if (mounted) avisar(context, r);
    } catch (e) {
      if (mounted) avisar(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<void> _conOcupado(Future<void> Function() f) async {
    setState(() => ocupado = true);
    try {
      await f();
    } catch (e) {
      if (mounted) avisar(context, 'Error: $e', error: true);
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<void> _verInforme() => _conOcupado(() async {
        final bytes = await InformePdf.generar(Datos.i, dias: diasInforme);
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'GluControl_informe_${hoyTexto()}.pdf');
      });

  Future<void> _guardarInforme() => _conOcupado(() async {
        final bytes = await InformePdf.generar(Datos.i, dias: diasInforme);
        final m = await Archivos.entregar(bytes, 'GluControl_informe_${hoyTexto()}.pdf', 'application/pdf',
            asunto: 'Informe GluControl');
        if (m != null && mounted) avisar(context, m);
      });

  Future<void> _exportarJson() => _conOcupado(() async {
        final m = await Archivos.entregar(Uint8List.fromList(utf8.encode(Datos.i.exportarJson())),
            'GluControl_copia_${hoyTexto()}.json', 'application/json');
        if (m != null && mounted) avisar(context, m);
      });

  Future<void> _exportarCsv() => _conOcupado(() async {
        final b = StringBuffer('﻿Fecha;Hora;Momento;mg/dL;Notas\r\n');
        for (final l in Datos.i.lecturas) {
          b.write('${fechaBonita(l.fecha)};${l.hora};${Momento.de(l.momento).nombre};${l.valor};"${l.notas.replaceAll('"', "'")}"\r\n');
        }
        final m = await Archivos.entregar(Uint8List.fromList(utf8.encode(b.toString())),
            'GluControl_glucemias_${hoyTexto()}.csv', 'text/csv');
        if (m != null && mounted) avisar(context, m);
      });

  Future<void> _importar() async {
    final bytes = await Archivos.abrir(['json'], 'Copia de GluControl');
    if (bytes == null || !mounted) return;
    Map<String, dynamic> j;
    try {
      j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      avisar(context, 'El archivo no es una copia de GluControl', error: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Importar copia'),
        content: const Text(
            'Se añaden los registros de la copia a los que ya tienes y se sincronizan con todos tus dispositivos. '
            'Si importas dos veces la misma copia no se duplica nada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Importar')),
        ],
      ),
    );
    if (ok != true) return;
    await _conOcupado(() async {
      final r = await Datos.i.importar(j);
      _cargar();
      if (mounted) avisar(context, r);
    });
  }

  Future<void> _salir() async {
    if (!await confirmar(context, '¿Cerrar sesión?', 'Tus datos siguen en la nube; al volver a entrar aparecen.')) return;
    await CredencialesGuardadas.borrar();
    await Datos.i.parar();
    await Fb.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final campos = <Widget>[
      Seccion('Perfil',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: nombre, decoration: const InputDecoration(labelText: 'Nombre')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Desplegable<String>('Diabetes', tipo,
                    {for (final t in ['Tipo 1', 'Tipo 2', 'Gestacional', 'LADA', 'MODY', 'Prediabetes', 'Otro']) t: t},
                    (v) => setState(() => tipo = v)),
              ),
              const SizedBox(width: 10),
              Expanded(child: CampoFecha('Fecha de nacimiento', fechaNac, (v) => setState(() => fechaNac = v), nacimiento: true)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: altura, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Altura (cm)'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: medico, decoration: const InputDecoration(labelText: 'Médico de referencia'))),
            ]),
          ])),
      Seccion('Objetivos',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: TextField(controller: metaMin, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Glucemia mínima'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: metaMax, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Glucemia máxima'))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: metaHba,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'HbA1c objetivo (%)'))),
              const SizedBox(width: 10),
              Expanded(
                  child: TextField(
                      controller: horasAviso,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Avisar tras horas sin medir', helperText: '0 = nunca'))),
            ]),
            const SizedBox(height: 6),
            const Text('Lo habitual es 70–180 mg/dL y HbA1c < 7 %, pero tu médico puede fijarte otros.',
                style: TextStyle(fontSize: 11.5, color: Tema.gris)),
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _guardarPerfil, child: const Text('Guardar perfil y objetivos'))),
          ])),
      Seccion('Informe para el médico',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('PDF con resumen, tiempo en rango, medias por momento, HbA1c, medicación, peso y tensión, '
                'observaciones y el diario de glucemias.'),
            const SizedBox(height: 10),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 14, label: Text('14 días')),
                ButtonSegment(value: 30, label: Text('30 días')),
                ButtonSegment(value: 90, label: Text('90 días')),
              ],
              selected: {diasInforme},
              onSelectionChanged: (s) => setState(() => diasInforme = s.first),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(onPressed: ocupado ? null : _verInforme, icon: const Icon(Icons.print_outlined), label: const Text('Ver / imprimir')),
              OutlinedButton.icon(onPressed: ocupado ? null : _guardarInforme, icon: const Icon(Icons.save_alt), label: const Text('Guardar / enviar')),
            ]),
          ])),
      Seccion('Asistente IA',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Usa Claude con tu clave de la API de Anthropic. La clave se guarda cifrada solo en este '
                'dispositivo (hay que ponerla en el móvil y en el PC).'),
            const SizedBox(height: 10),
            TextField(
              controller: clave,
              obscureText: !verClave,
              decoration: InputDecoration(
                labelText: 'Clave de la API (sk-ant-…)',
                suffixIcon: IconButton(
                    onPressed: () => setState(() => verClave = !verClave),
                    icon: Icon(verClave ? Icons.visibility_off : Icons.visibility)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(controller: modelo, decoration: const InputDecoration(labelText: 'Modelo', helperText: 'Por defecto ${Perfil.modeloIAPorDefecto}')),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton(onPressed: ocupado ? null : _guardarIA, child: const Text('Guardar')),
              OutlinedButton(onPressed: ocupado ? null : _probarIA, child: const Text('Probar conexión')),
              TextButton(
                  onPressed: () => launchUrl(Uri.parse('https://console.anthropic.com/settings/keys'), mode: LaunchMode.externalApplication),
                  child: const Text('Conseguir una clave')),
            ]),
          ])),
      Seccion('Copias y exportación',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Tus datos ya se guardan en la nube y se sincronizan entre el móvil y el PC. '
                'Aquí puedes sacar una copia propia o traer los datos de la versión anterior (HTML).'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(onPressed: ocupado ? null : _exportarJson, icon: const Icon(Icons.backup_outlined), label: const Text('Copia completa (JSON)')),
              OutlinedButton.icon(onPressed: ocupado ? null : _exportarCsv, icon: const Icon(Icons.table_chart_outlined), label: const Text('Glucemias para Excel (CSV)')),
              FilledButton.tonalIcon(onPressed: ocupado ? null : _importar, icon: const Icon(Icons.upload_file), label: const Text('Importar copia')),
            ]),
            const SizedBox(height: 6),
            const Text('Importar admite las copias de GluControl v4 y v9 (las del navegador) y las de esta versión.',
                style: TextStyle(fontSize: 11.5, color: Tema.gris)),
          ])),
      Seccion('Cuenta',
          child: Row(children: [
            Expanded(
              child: Text('Sesión: ${Fb.auth.currentUser?.email ?? '—'}\nGluControl 10.0 · Android y Windows',
                  style: const TextStyle(color: Tema.gris, height: 1.4)),
            ),
            TextButton.icon(
                onPressed: _salir,
                style: TextButton.styleFrom(foregroundColor: Tema.error),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión')),
          ])),
    ];
    return Stack(children: [
      Pagina([
        Columnas(izquierda: campos.sublist(0, 3), derecha: campos.sublist(3)),
      ]),
      if (ocupado) const LinearProgressIndicator(color: Tema.acento),
    ]);
  }
}
