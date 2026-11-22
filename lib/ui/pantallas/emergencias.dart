import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../datos/datos.dart';
import '../../datos/modelos.dart';
import '../comun.dart';
import '../tema.dart';

Future<void> abrirContacto(BuildContext context, [Contacto? c]) => showDialog(context: context, builder: (_) => _Form(c));

class _Form extends StatefulWidget {
  final Contacto? c;
  const _Form(this.c);

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final nombre = TextEditingController(), tel = TextEditingController(), rel = TextEditingController();
  String tipo = 'fam';
  String? error;

  @override
  void initState() {
    super.initState();
    final c = widget.c;
    if (c != null) {
      nombre.text = c.nombre;
      tel.text = c.tel;
      rel.text = c.rel;
      tipo = c.tipo;
    }
  }

  void _guardar() {
    if (nombre.text.trim().isEmpty || tel.text.trim().isEmpty) {
      setState(() => error = 'Nombre y teléfono');
      return;
    }
    final c = widget.c ?? Contacto('', nombre: '', tel: '');
    c
      ..nombre = nombre.text.trim()
      ..tel = tel.text.trim()
      ..tipo = tipo
      ..rel = rel.text.trim();
    Datos.i.guardar(Col.contactos, c);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => DialogoForm(
        titulo: widget.c == null ? 'Nuevo contacto' : 'Editar contacto',
        onGuardar: _guardar,
        onBorrar: widget.c == null
            ? null
            : () async {
                if (await confirmar(context, '¿Eliminar ${widget.c!.nombre}?')) {
                  Datos.i.borrar(Col.contactos, widget.c!.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
        campos: [
          TextField(controller: nombre, decoration: InputDecoration(labelText: 'Nombre', errorText: error)),
          TextField(controller: tel, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono', hintText: '600 123 456')),
          Desplegable<String>('Tipo', tipo, Contacto.tipos, (v) => setState(() => tipo = v)),
          TextField(controller: rel, decoration: const InputDecoration(labelText: 'Relación / especialidad', hintText: 'Endocrino, hermana…')),
        ],
      );
}

Future<void> _abrir(BuildContext context, Uri u) async {
  if (!await launchUrl(u, mode: LaunchMode.externalApplication) && context.mounted) {
    avisar(context, 'No se ha podido abrir', error: true);
  }
}

/// Número con prefijo de España si no lo trae (para WhatsApp).
String _paraWhatsapp(String tel) {
  var t = tel.replaceAll(RegExp(r'[^\d+]'), '');
  if (t.startsWith('+')) return t.substring(1);
  if (t.startsWith('00')) return t.substring(2);
  if (t.length == 9) return '34$t';
  return t;
}

class PantallaEmergencias extends StatelessWidget {
  const PantallaEmergencias({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => abrirContacto(context), icon: const Icon(Icons.person_add_alt), label: const Text('Contacto')),
        body: ConDatos(builder: (c, d) {
          final p = d.perfil;
          final ult = d.lecturas.isEmpty ? null : d.lecturas.first;
          final meds = d.medicamentos.map((m) => '${m.nombre} ${m.dosis}'.trim()).join(', ');
          final mensaje = 'Soy ${p.nombre.isEmpty ? 'una persona' : p.nombre} con diabetes ${p.tipo}.'
              '${ult != null ? ' Última glucosa: ${ult.valor} mg/dL (${fechaBonita(ult.fecha)} ${ult.hora}).' : ''}'
              '${meds.isNotEmpty ? ' Medicación: $meds.' : ''}';
          return Pagina([
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Tema.error, padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () => _abrir(context, Uri(scheme: 'tel', path: '112')),
                icon: const Icon(Icons.phone_in_talk),
                label: const Text('Llamar al 112', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            Rotulo('Mis contactos'),
            if (d.contactos.isEmpty) const Tarjeta(child: Vacio('Añade a tu médico y a tus familiares.')),
            for (final x in d.contactos)
              Tarjeta(
                onTap: () => abrirContacto(context, x),
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                child: Row(children: [
                  CircleAvatar(
                    backgroundColor: Tema.acentoSuave,
                    child: Icon(
                        switch (x.tipo) { 'med' => Icons.medical_services_outlined, 'urg' => Icons.local_hospital_outlined, _ => Icons.person_outline },
                        color: Tema.acento),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(x.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text([x.rel, x.tel].where((e) => e.isNotEmpty).join(' · '), style: const TextStyle(color: Tema.gris, fontSize: 12.5)),
                    ]),
                  ),
                  IconButton(
                      tooltip: 'Llamar',
                      onPressed: () => _abrir(context, Uri(scheme: 'tel', path: x.tel.replaceAll(' ', ''))),
                      icon: const Icon(Icons.call, color: Tema.ok)),
                  IconButton(
                      tooltip: 'WhatsApp con mis datos',
                      onPressed: () => _abrir(context, Uri.parse('https://wa.me/${_paraWhatsapp(x.tel)}?text=${Uri.encodeComponent(mensaje)}')),
                      icon: const Icon(Icons.chat_outlined, color: Color(0xFF25D366))),
                ]),
              ),
            Rotulo('Mis datos para urgencias'),
            Tarjeta(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SelectableText(mensaje, style: const TextStyle(height: 1.4)),
                const SizedBox(height: 6),
                const Text('Es el texto que se envía por WhatsApp a tus contactos.', style: TextStyle(fontSize: 11.5, color: Tema.gris)),
              ]),
            ),
            Rotulo('Si hay una hipoglucemia grave'),
            const Nota(
              'Qué deben hacer quienes estén contigo',
              'Si estás consciente y puedes tragar: 15 g de azúcar (zumo, azúcar, caramelos) y medir a los 15 minutos.\n'
                  'Si estás inconsciente o no puedes tragar: no darte nada por la boca, ponerte de lado, usar el glucagón si lo tienes y llamar al 112.',
              color: Tema.error,
              icono: Icons.health_and_safety_outlined,
            ),
          ]);
        }),
      );
}
