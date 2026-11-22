import 'package:flutter/material.dart';

import '../datos/datos.dart';
import '../services/avisos.dart';
import 'comun.dart';
import 'pantallas/ajustes.dart';
import 'pantallas/asistente.dart';
import 'pantallas/citas.dart';
import 'pantallas/comidas.dart';
import 'pantallas/consejos.dart';
import 'pantallas/correlacion.dart';
import 'pantallas/emergencias.dart';
import 'pantallas/estadisticas.dart';
import 'pantallas/glucemia.dart';
import 'pantallas/hba1c.dart';
import 'pantallas/informes.dart';
import 'pantallas/inicio.dart';
import 'pantallas/medicacion.dart';
import 'pantallas/recordatorios.dart';
import 'pantallas/vitales.dart';
import 'tema.dart';

class Destino {
  final String clave, nombre, grupo;
  final IconData icono;
  final Widget Function() pantalla;
  const Destino(this.clave, this.nombre, this.icono, this.grupo, this.pantalla);
}

final destinos = <Destino>[
  Destino('inicio', 'Inicio', Icons.home_outlined, 'Principal', () => const PantallaInicio()),
  Destino('glucemia', 'Glucemia', Icons.water_drop_outlined, 'Principal', () => const PantallaGlucemia()),
  Destino('estadisticas', 'Estadísticas', Icons.insights_outlined, 'Principal', () => const PantallaEstadisticas()),
  Destino('hba1c', 'HbA1c', Icons.biotech_outlined, 'Principal', () => const PantallaHba1c()),
  Destino('comidas', 'Alimentación', Icons.restaurant_outlined, 'Salud', () => const PantallaComidas()),
  Destino('correlacion', 'Comida y glucosa', Icons.compare_arrows, 'Salud', () => const PantallaCorrelacion()),
  Destino('vitales', 'Peso y tensión', Icons.monitor_weight_outlined, 'Salud', () => const PantallaVitales()),
  Destino('consejos', 'Consejos', Icons.lightbulb_outline, 'Salud', () => const PantallaConsejos()),
  Destino('asistente', 'Asistente IA', Icons.auto_awesome_outlined, 'Salud', () => const PantallaAsistente()),
  Destino('medicacion', 'Medicación', Icons.medication_outlined, 'Control', () => const PantallaMedicacion()),
  Destino('recordatorios', 'Recordatorios', Icons.notifications_none, 'Control', () => const PantallaRecordatorios()),
  Destino('citas', 'Citas', Icons.event_outlined, 'Control', () => const PantallaCitas()),
  Destino('informes', 'Informes', Icons.description_outlined, 'Control', () => const PantallaInformes()),
  Destino('emergencias', 'Emergencias', Icons.sos_outlined, 'Control', () => const PantallaEmergencias()),
  Destino('ajustes', 'Ajustes', Icons.settings_outlined, 'Opciones', () => const PantallaAjustes()),
];

/// Para saltar de una pantalla a otra (p. ej. desde el inicio).
final navegar = ValueNotifier<String>('inicio');

/// Estructura de la app: menú lateral en pantallas anchas (Windows) y barra
/// inferior con "Más" en el móvil.
class Marco extends StatefulWidget {
  const Marco({super.key});

  @override
  State<Marco> createState() => _MarcoState();
}

class _MarcoState extends State<Marco> {
  static const _inferior = ['inicio', 'glucemia', 'comidas', 'medicacion'];
  bool _avisosHechos = false;

  @override
  void initState() {
    super.initState();
    navegar.addListener(_cambio);
    Datos.i.addListener(_datos);
    Avisos.pedirPermiso();
  }

  @override
  void dispose() {
    navegar.removeListener(_cambio);
    Datos.i.removeListener(_datos);
    super.dispose();
  }

  void _cambio() => setState(() {});

  void _datos() {
    final d = Datos.i;
    if (!d.sincronizado) return;
    Avisos.reprogramar(d);
    if (!_avisosHechos) {
      _avisosHechos = true;
      Avisos.avisoStock(d);
    }
  }

  void _ir(String clave) {
    navegar.value = clave;
  }

  Destino get _actual => destinos.firstWhere((x) => x.clave == navegar.value, orElse: () => destinos.first);

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width >= 900;
    final cuerpo = Column(children: [
      ConDatos(builder: (c, d) {
        if (d.error == null) return const SizedBox.shrink();
        return Nota('Sin sincronizar', d.error!, color: Tema.error, icono: Icons.cloud_off);
      }),
      Expanded(child: KeyedSubtree(key: ValueKey(_actual.clave), child: _actual.pantalla())),
    ]);
    final barra = AppBar(
      title: Text(_actual.nombre.toUpperCase()),
      actions: [
        ConDatos(
          builder: (c, d) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: d.error != null
                  ? 'Sin sincronizar'
                  : d.sincronizado
                      ? 'Sincronizado'
                      : 'Conectando…',
              child: Icon(
                d.error != null
                    ? Icons.cloud_off
                    : d.sincronizado
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_sync_outlined,
                size: 20,
                color: d.error != null ? Colors.orangeAccent : Colors.white70,
              ),
            ),
          ),
        ),
      ],
    );

    if (ancho) {
      return Scaffold(
        body: Row(children: [
          _Lateral(actual: _actual.clave, onTap: _ir),
          Expanded(child: Scaffold(appBar: barra, body: cuerpo)),
        ]),
      );
    }

    final idx = _inferior.indexOf(_actual.clave);
    return Scaffold(
      appBar: barra,
      body: cuerpo,
      bottomNavigationBar: NavigationBar(
        height: 64,
        selectedIndex: idx < 0 ? 4 : idx,
        onDestinationSelected: (i) {
          if (i < 4) {
            _ir(_inferior[i]);
          } else {
            _mas(context);
          }
        },
        destinations: [
          for (final k in _inferior)
            NavigationDestination(
                icon: Icon(destinos.firstWhere((x) => x.clave == k).icono),
                label: destinos.firstWhere((x) => x.clave == k).nombre),
          const NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Más'),
        ],
      ),
    );
  }

  void _mas(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          childAspectRatio: 1.35,
          children: [
            for (final dd in destinos.where((x) => !_inferior.contains(x.clave)))
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Navigator.pop(c);
                  _ir(dd.clave);
                },
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(dd.icono, color: Tema.acento),
                  const SizedBox(height: 6),
                  Text(dd.nombre, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _Lateral extends StatelessWidget {
  final String actual;
  final ValueChanged<String> onTap;
  const _Lateral({required this.actual, required this.onTap});

  @override
  Widget build(BuildContext context) {
    String? grupo;
    final hijos = <Widget>[];
    for (final d in destinos) {
      if (d.grupo != grupo) {
        grupo = d.grupo;
        hijos.add(Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 4),
          child: Text(grupo.toUpperCase(),
              style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
        ));
      }
      final on = d.clave == actual;
      hijos.add(Material(
        color: on ? Colors.white.withValues(alpha: 0.10) : Colors.transparent,
        child: InkWell(
          onTap: () => onTap(d.clave),
          child: Container(
            decoration: BoxDecoration(
                border: Border(left: BorderSide(color: on ? const Color(0xFF4FC3B5) : Colors.transparent, width: 3))),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Icon(d.icono, size: 19, color: on ? Colors.white : Colors.white60),
              const SizedBox(width: 12),
              Text(d.nombre,
                  style: TextStyle(color: on ? Colors.white : Colors.white70, fontSize: 13.5, fontWeight: on ? FontWeight.w600 : FontWeight.w400)),
            ]),
          ),
        ),
      ));
    }
    return Container(
      width: 230,
      color: Tema.barra,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
          child: ConDatos(
            builder: (c, d) => Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/icono.png', width: 34, height: 34)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('GLUCONTROL',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.6, fontSize: 14)),
                  Text(d.perfil.nombre.isNotEmpty ? d.perfil.nombre : 'Diabetes ${d.perfil.tipo}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
                ]),
              ),
            ]),
          ),
        ),
        Expanded(child: ListView(padding: EdgeInsets.zero, children: hijos)),
      ]),
    );
  }
}
