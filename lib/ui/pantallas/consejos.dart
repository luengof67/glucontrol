import 'package:flutter/material.dart';

import '../../datos/analisis.dart';
import '../comun.dart';
import '../tema.dart';

class PantallaConsejos extends StatelessWidget {
  const PantallaConsejos({super.key});

  @override
  Widget build(BuildContext context) => ConDatos(builder: (c, d) {
        final p = d.perfil;
        final ult = d.lecturas.isEmpty ? null : d.lecturas.first;
        final n = ult == null ? null : nivelDe(ult.valor, p);
        Widget ahora;
        if (ult == null) {
          ahora = const Nota('Sin datos', 'Apunta una medición para ver consejos según tu nivel.');
        } else {
          ahora = switch (n!) {
            Nivel.muyBaja || Nivel.baja => Nota('Baja (${ult.valor} mg/dL): actúa ya',
                'Toma 15 g de hidratos rápidos (zumo, azúcar, caramelos), espera 15 minutos y vuelve a medir. Repite si sigue por debajo de ${p.metaMin}.',
                color: Tema.baja, icono: Icons.warning_amber_rounded),
            Nivel.ok => Nota('En rango (${ult.valor} mg/dL)', 'Buen control. Mantén tus horarios de comida, medicación y actividad.',
                color: Tema.ok, icono: Icons.check_circle_outline),
            Nivel.alta => Nota('Elevada (${ult.valor} mg/dL)',
                'Bebe agua, evita hidratos rápidos en la próxima comida y, si puedes, camina 15-20 minutos. Revisa si te has saltado alguna toma.',
                color: Tema.aviso, icono: Icons.trending_up),
            Nivel.muyAlta => Nota('Muy alta (${ult.valor} mg/dL)',
                'Vuelve a medir en un rato y sigue las pautas de tu médico. Si pasa de 300 de forma mantenida, o hay vómitos, dolor abdominal o somnolencia: llama a tu médico o al 112.',
                color: Tema.muyAlta, icono: Icons.error_outline),
          };
        }
        return Pagina([
          Rotulo('Según tu última medida'),
          ahora,
          Rotulo('Alimentación'),
          const Nota('Plato equilibrado',
              'Medio plato de verdura, un cuarto de proteína y un cuarto de hidratos, mejor integrales o legumbres. El método del plato es una forma sencilla de repartir.',
              icono: Icons.restaurant_outlined),
          const Nota('Orden de los alimentos',
              'Empezar por la verdura y la proteína y dejar los hidratos para el final suaviza la subida de después de comer.',
              icono: Icons.format_list_numbered),
          const Nota('Bebidas', 'Agua como bebida habitual. Fuera zumos y refrescos con azúcar (salvo para corregir una bajada).',
              icono: Icons.local_drink_outlined),
          Rotulo('Actividad y descanso'),
          const Nota('Caminar después de comer',
              'Un paseo de 10-20 minutos después de las comidas ayuda a bajar el pico de glucosa.',
              icono: Icons.directions_walk),
          const Nota('Sueño y estrés', 'Dormir 7-8 horas y cuidar el estrés: los dos influyen en la glucemia.',
              icono: Icons.bedtime_outlined),
          Rotulo('Revisiones'),
          const Nota('Pies', 'Revísalos a diario (heridas, rozaduras, cambios de color) y usa calzado cómodo.',
              icono: Icons.visibility_outlined),
          const Nota('Controles periódicos',
              'HbA1c cada 3-6 meses, revisión de ojos, riñón y tensión según te indique tu médico.',
              icono: Icons.event_available_outlined),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Consejos generales: tu médico o tu enfermera educadora son quienes ajustan las pautas a tu caso.',
                style: TextStyle(fontSize: 11.5, color: Tema.gris)),
          ),
        ]);
      });
}
