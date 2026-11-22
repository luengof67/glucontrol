import 'package:flutter/material.dart';

import '../datos/analisis.dart';
import '../datos/datos.dart';
import 'tema.dart';

/// Reconstruye cuando cambian los datos.
class ConDatos extends StatelessWidget {
  final Widget Function(BuildContext context, Datos d) builder;
  const ConDatos({super.key, required this.builder});

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: Datos.i, builder: (c, _) => builder(c, Datos.i));
}

/// Tarjeta blanca con margen interior.
class Tarjeta extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const Tarjeta({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

/// Bloque con rótulo en versales y su tarjeta.
class Seccion extends StatelessWidget {
  final String titulo;
  final Widget child;
  final Widget? accion;
  final EdgeInsets padding;
  const Seccion(this.titulo,
      {super.key, required this.child, this.accion, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Rotulo(titulo, accion: accion),
          Tarjeta(padding: padding, child: child),
        ],
      );
}

/// Dato grande (rótulo, valor, unidad, subtítulo).
class Dato extends StatelessWidget {
  final String rotulo, valor;
  final String unidad, sub;
  final Color? color;
  const Dato(this.rotulo, this.valor, {super.key, this.unidad = '', this.sub = '', this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Tema.borde),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(rotulo.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: Tema.gris)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(valor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color ?? Tema.texto)),
                ),
                if (unidad.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(unidad, style: const TextStyle(fontSize: 11, color: Tema.gris)),
                ],
              ],
            ),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Tema.gris)),
            ],
          ],
        ),
      );
}

/// Rejilla de [Dato]: 2 columnas en móvil, hasta 4 en pantalla ancha.
class FilaDatos extends StatelessWidget {
  final List<Widget> hijos;
  const FilaDatos(this.hijos, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: LayoutBuilder(builder: (c, cons) {
          final cols = cons.maxWidth >= 700 ? 4 : 2;
          const sep = 8.0;
          final ancho = (cons.maxWidth - sep * (cols - 1)) / cols;
          return Wrap(
            spacing: sep,
            runSpacing: sep,
            children: [for (final h in hijos) SizedBox(width: ancho, child: h)],
          );
        }),
      );
}

/// Dos columnas en pantalla ancha (Windows), una en móvil.
class Columnas extends StatelessWidget {
  final List<Widget> izquierda, derecha;
  const Columnas({super.key, required this.izquierda, required this.derecha});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (c, cons) {
        if (cons.maxWidth < 900) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...izquierda, ...derecha]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: izquierda)),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: derecha)),
        ]);
      });
}

/// Contenido de una pantalla con scroll y ancho máximo cómodo en Windows.
class Pagina extends StatelessWidget {
  final List<Widget> hijos;
  const Pagina(this.hijos, {super.key});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1300),
          child: ListView(padding: const EdgeInsets.only(bottom: 96), children: hijos),
        ),
      );
}

class Vacio extends StatelessWidget {
  final String texto;
  const Vacio(this.texto, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: Tema.gris, fontSize: 13)),
      );
}

/// Nota de color (consejo, aviso, alerta).
class Nota extends StatelessWidget {
  final String titulo, texto;
  final Color color;
  final IconData icono;
  final VoidCallback? onTap;
  const Nota(this.titulo, this.texto,
      {super.key, this.color = Tema.acento, this.icono = Icons.info_outline, this.onTap});

  factory Nota.patron(Patron p) => Nota(p.titulo, p.texto,
      color: switch (p.gravedad) {
        Gravedad.alerta => Tema.error,
        Gravedad.aviso => Tema.aviso,
        Gravedad.info => Tema.acento,
      },
      icono: switch (p.gravedad) {
        Gravedad.alerta => Icons.error_outline,
        Gravedad.aviso => Icons.warning_amber_rounded,
        Gravedad.info => Icons.lightbulb_outline,
      });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Material(
          color: color.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10), side: BorderSide(color: color.withValues(alpha: 0.35))),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icono, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(titulo, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13.5)),
                    if (texto.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(texto, style: const TextStyle(fontSize: 12.5, color: Tema.texto, height: 1.35)),
                    ],
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
}

/// Valor de glucemia en su color.
class ValorGlucosa extends StatelessWidget {
  final int valor;
  final double tam;
  const ValorGlucosa(this.valor, {super.key, this.tam = 15});

  @override
  Widget build(BuildContext context) {
    final n = nivelDe(valor, Datos.i.perfil);
    return Text('$valor',
        style: TextStyle(fontSize: tam, fontWeight: FontWeight.w800, color: Tema.nivel(n)));
  }
}

Future<bool> confirmar(BuildContext context, String titulo, [String texto = 'No se puede deshacer.']) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
        FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Tema.error),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Eliminar')),
      ],
    ),
  );
  return r ?? false;
}

/// Ventana de formulario común: título, contenido con scroll, Guardar y
/// (si se edita) Eliminar.
class DialogoForm extends StatelessWidget {
  final String titulo;
  final List<Widget> campos;
  final VoidCallback onGuardar;
  final VoidCallback? onBorrar;
  final String textoGuardar;
  const DialogoForm(
      {super.key,
      required this.titulo,
      required this.campos,
      required this.onGuardar,
      this.onBorrar,
      this.textoGuardar = 'Guardar'});

  @override
  Widget build(BuildContext context) {
    final estrecho = MediaQuery.sizeOf(context).width < 600;
    return AlertDialog(
      insetPadding: estrecho ? const EdgeInsets.symmetric(horizontal: 12, vertical: 24) : const EdgeInsets.all(40),
      title: Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final c in campos) Padding(padding: const EdgeInsets.only(bottom: 10), child: c),
            ],
          ),
        ),
      ),
      actions: [
        if (onBorrar != null)
          TextButton(
              onPressed: onBorrar,
              style: TextButton.styleFrom(foregroundColor: Tema.error),
              child: const Text('Eliminar')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: onGuardar, child: Text(textoGuardar)),
      ],
    );
  }
}

/// Campo de fecha ('aaaa-mm-dd').
class CampoFecha extends StatelessWidget {
  final String etiqueta, valor;
  final ValueChanged<String> onChanged;
  final bool futuro;
  const CampoFecha(this.etiqueta, this.valor, this.onChanged, {super.key, this.futuro = false});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () async {
          final ini = DateTime.tryParse(valor) ?? DateTime.now();
          final d = await showDatePicker(
            context: context,
            initialDate: ini,
            firstDate: DateTime(2000),
            lastDate: futuro ? DateTime(2100) : DateTime.now().add(const Duration(days: 1)),
            locale: const Locale('es', 'ES'),
          );
          if (d != null) onChanged(fechaTexto(d));
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: etiqueta, suffixIcon: const Icon(Icons.calendar_today, size: 18)),
          child: Text(valor.isEmpty ? '—' : fechaBonita(valor)),
        ),
      );
}

/// Campo de hora ('hh:mm').
class CampoHora extends StatelessWidget {
  final String etiqueta, valor;
  final ValueChanged<String> onChanged;
  const CampoHora(this.etiqueta, this.valor, this.onChanged, {super.key});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () async {
          final p = valor.split(':');
          final t = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(
                hour: int.tryParse(p.first) ?? TimeOfDay.now().hour,
                minute: p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0),
            builder: (c, child) =>
                MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
          );
          if (t != null) {
            onChanged('${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: etiqueta, suffixIcon: const Icon(Icons.schedule, size: 18)),
          child: Text(valor.isEmpty ? '—' : valor),
        ),
      );
}

/// Fecha y hora en una fila.
class FechaHora extends StatelessWidget {
  final String fecha, hora;
  final ValueChanged<String> onFecha, onHora;
  const FechaHora(this.fecha, this.hora, this.onFecha, this.onHora, {super.key});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: CampoFecha('Fecha', fecha, onFecha)),
        const SizedBox(width: 10),
        Expanded(child: CampoHora('Hora', hora, onHora)),
      ]);
}

/// Desplegable sencillo.
class Desplegable<T> extends StatelessWidget {
  final String etiqueta;
  final T valor;
  final Map<T, String> opciones;
  final ValueChanged<T> onChanged;
  const Desplegable(this.etiqueta, this.valor, this.opciones, this.onChanged, {super.key});

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
        initialValue: opciones.containsKey(valor) ? valor : opciones.keys.first,
        isExpanded: true,
        decoration: InputDecoration(labelText: etiqueta),
        items: [for (final e in opciones.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      );
}

/// Barra horizontal de proporción (para tiempo en rango, momentos...).
class BarraProporcion extends StatelessWidget {
  final String etiqueta, valor;
  final double fraccion;
  final Color color;
  const BarraProporcion(this.etiqueta, this.fraccion, this.valor, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 110, child: Text(etiqueta, style: const TextStyle(fontSize: 12.5))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraccion.clamp(0, 1).toDouble(),
                minHeight: 8,
                backgroundColor: Tema.fondo,
                color: color,
              ),
            ),
          ),
          SizedBox(
              width: 64,
              child: Text(valor,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color))),
        ]),
      );
}
