import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../datos/analisis.dart';
import '../datos/datos.dart';
import '../datos/modelos.dart';
import 'tema.dart';

/// Línea de evolución con banda de objetivo (verde) detrás.
/// [valores] puede tener huecos (null): la línea se corta ahí.
class GraficoLinea extends StatelessWidget {
  final List<double?> valores;
  final List<String> etiquetas;
  final double? bandaMin, bandaMax;
  final Color color;
  final double alto;
  final int decimales;

  /// Si se indica, cada punto se pinta del color que devuelva.
  final Color Function(double v)? colorPunto;

  const GraficoLinea({
    super.key,
    required this.valores,
    required this.etiquetas,
    this.bandaMin,
    this.bandaMax,
    this.color = Tema.acento,
    this.alto = 170,
    this.decimales = 0,
    this.colorPunto,
  });

  @override
  Widget build(BuildContext context) {
    if (valores.whereType<double>().isEmpty) {
      return SizedBox(
          height: alto * .5,
          child: const Center(child: Text('Sin datos', style: TextStyle(color: Tema.gris))));
    }
    return SizedBox(
      height: alto,
      width: double.infinity,
      child: CustomPaint(painter: _PintorLinea(this)),
    );
  }
}

class _PintorLinea extends CustomPainter {
  final GraficoLinea g;
  _PintorLinea(this.g);

  @override
  void paint(Canvas canvas, Size size) {
    const izq = 34.0, der = 8.0, arr = 14.0, abj = 20.0;
    final ancho = size.width - izq - der, alto = size.height - arr - abj;
    final vals = g.valores.whereType<double>().toList();
    var minV = vals.reduce(math.min), maxV = vals.reduce(math.max);
    if (g.bandaMin != null) minV = math.min(minV, g.bandaMin!);
    if (g.bandaMax != null) maxV = math.max(maxV, g.bandaMax!);
    final margen = math.max((maxV - minV) * 0.12, maxV.abs() * 0.02 + 1);
    minV -= margen;
    maxV += margen;
    double y(double v) => arr + alto - (v - minV) / (maxV - minV) * alto;
    final n = g.valores.length;
    double x(int i) => izq + (n <= 1 ? ancho / 2 : i * ancho / (n - 1));

    final texto = TextPainter(textDirection: TextDirection.ltr);
    void escribir(String s, Offset o, {Color c = Tema.gris, double tam = 9.5, bool centrar = false, bool derecha = false, FontWeight w = FontWeight.w400}) {
      texto.text = TextSpan(text: s, style: TextStyle(fontSize: tam, color: c, fontWeight: w));
      texto.layout();
      var p = o;
      if (centrar) p = p.translate(-texto.width / 2, 0);
      if (derecha) p = p.translate(-texto.width, 0);
      texto.paint(canvas, p);
    }

    // Banda de objetivo
    if (g.bandaMin != null && g.bandaMax != null) {
      canvas.drawRect(Rect.fromLTRB(izq, y(g.bandaMax!), izq + ancho, y(g.bandaMin!)),
          Paint()..color = Tema.ok.withValues(alpha: 0.08));
      final raya = Paint()
        ..color = Tema.ok.withValues(alpha: 0.45)
        ..strokeWidth = 1;
      for (final b in [g.bandaMin!, g.bandaMax!]) {
        canvas.drawLine(Offset(izq, y(b)), Offset(izq + ancho, y(b)), raya);
        escribir(b.toStringAsFixed(g.decimales), Offset(izq - 4, y(b) - 6), derecha: true, c: Tema.ok);
      }
    } else {
      for (final v in [vals.reduce(math.min), vals.reduce(math.max)]) {
        escribir(v.toStringAsFixed(g.decimales), Offset(izq - 4, y(v) - 6), derecha: true);
      }
    }

    // Línea
    final linea = Paint()
      ..color = g.color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final camino = Path();
    var empezado = false;
    for (var i = 0; i < n; i++) {
      final v = g.valores[i];
      if (v == null) {
        continue; // une por encima de los huecos
      }
      if (!empezado) {
        camino.moveTo(x(i), y(v));
        empezado = true;
      } else {
        camino.lineTo(x(i), y(v));
      }
    }
    canvas.drawPath(camino, linea);

    // Puntos y valores
    final muchos = n > 16;
    for (var i = 0; i < n; i++) {
      final v = g.valores[i];
      if (v == null) continue;
      final c = g.colorPunto?.call(v) ?? g.color;
      canvas.drawCircle(Offset(x(i), y(v)), muchos ? 2.6 : 3.8, Paint()..color = c);
      canvas.drawCircle(
          Offset(x(i), y(v)),
          muchos ? 2.6 : 3.8,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
      if (!muchos) {
        escribir(v.toStringAsFixed(g.decimales), Offset(x(i), y(v) - 15), centrar: true, c: c, w: FontWeight.w700);
      }
    }

    // Etiquetas del eje X (como mucho ~8)
    final paso = math.max(1, (n / 8).ceil());
    for (var i = 0; i < n; i += paso) {
      if (i < g.etiquetas.length) escribir(g.etiquetas[i], Offset(x(i), size.height - 14), centrar: true);
    }
  }

  @override
  bool shouldRepaint(covariant _PintorLinea old) => true;
}

/// Perfil del día: todas las glucemias del periodo según la hora a la que se
/// midieron, con la banda de objetivo. Deja ver de un vistazo a qué horas
/// se sale del rango.
class GraficoDia extends StatelessWidget {
  final List<Lectura> lecturas;
  final Perfil perfil;
  final double alto;
  const GraficoDia({super.key, required this.lecturas, required this.perfil, this.alto = 190});

  @override
  Widget build(BuildContext context) {
    if (lecturas.isEmpty) {
      return const SizedBox(height: 80, child: Center(child: Text('Sin datos', style: TextStyle(color: Tema.gris))));
    }
    return SizedBox(height: alto, width: double.infinity, child: CustomPaint(painter: _PintorDia(lecturas, perfil)));
  }
}

class _PintorDia extends CustomPainter {
  final List<Lectura> l;
  final Perfil p;
  _PintorDia(this.l, this.p);

  @override
  void paint(Canvas canvas, Size size) {
    const izq = 34.0, der = 8.0, arr = 8.0, abj = 20.0;
    final ancho = size.width - izq - der, alto = size.height - arr - abj;
    final maxV = math.max(300.0, l.map((x) => x.valor).reduce(math.max) + 10.0);
    const minV = 40.0;
    double y(num v) => arr + alto - ((v.clamp(minV, maxV)) - minV) / (maxV - minV) * alto;
    double x(int min) => izq + min / 1440 * ancho;
    final texto = TextPainter(textDirection: TextDirection.ltr);
    void escribir(String s, Offset o, Color c, {bool derecha = false, bool centrar = false}) {
      texto.text = TextSpan(text: s, style: TextStyle(fontSize: 9.5, color: c));
      texto.layout();
      var q = o;
      if (derecha) q = q.translate(-texto.width, 0);
      if (centrar) q = q.translate(-texto.width / 2, 0);
      texto.paint(canvas, q);
    }

    canvas.drawRect(Rect.fromLTRB(izq, y(p.metaMax), izq + ancho, y(p.metaMin)),
        Paint()..color = Tema.ok.withValues(alpha: 0.09));
    for (final (v, c) in [(54, Tema.muyBaja), (p.metaMin, Tema.ok), (p.metaMax, Tema.ok), (250, Tema.muyAlta)]) {
      canvas.drawLine(
          Offset(izq, y(v)),
          Offset(izq + ancho, y(v)),
          Paint()
            ..color = c.withValues(alpha: 0.35)
            ..strokeWidth = 1);
      escribir('$v', Offset(izq - 4, y(v) - 6), c, derecha: true);
    }
    for (var h = 0; h <= 24; h += 3) {
      final xx = x(h * 60);
      canvas.drawLine(Offset(xx, arr), Offset(xx, arr + alto), Paint()..color = Tema.borde);
      escribir('${h}h', Offset(xx, size.height - 14), Tema.gris, centrar: true);
    }
    for (final lec in l) {
      final t = lec.cuando;
      canvas.drawCircle(Offset(x(t.hour * 60 + t.minute), y(lec.valor)), 3.6,
          Paint()..color = Tema.nivel(nivelDe(lec.valor, p)).withValues(alpha: 0.85));
    }
  }

  @override
  bool shouldRepaint(covariant _PintorDia old) => true;
}

/// Barra apilada de tiempo en rango (5 bandas) con su leyenda.
class BarraTiempoEnRango extends StatelessWidget {
  final Resumen r;
  const BarraTiempoEnRango(this.r, {super.key});

  @override
  Widget build(BuildContext context) {
    final orden = [Nivel.muyAlta, Nivel.alta, Nivel.ok, Nivel.baja, Nivel.muyBaja];
    final p = Datos.i.perfil;
    String rango(Nivel n) => switch (n) {
          Nivel.muyAlta => '> 250',
          Nivel.alta => '${p.metaMax + 1}–250',
          Nivel.ok => '${p.metaMin}–${p.metaMax}',
          Nivel.baja => '54–${p.metaMin - 1}',
          Nivel.muyBaja => '< 54',
        };
    String objetivo(Nivel n) => switch (n) {
          Nivel.muyAlta => 'obj. < 5 %',
          Nivel.alta => 'obj. < 25 % (con la anterior)',
          Nivel.ok => 'obj. > 70 %',
          Nivel.baja => 'obj. < 4 % (con la siguiente)',
          Nivel.muyBaja => 'obj. < 1 %',
        };
    if (r.n == 0) return const Text('Sin datos', style: TextStyle(color: Tema.gris));
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 34,
        height: 150,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Column(children: [
            for (final n in orden)
              if (r.bandas[n]! > 0) Expanded(flex: r.bandas[n]!, child: Container(color: Tema.nivel(n))),
          ]),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final n in orden)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: Tema.nivel(n), borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '${nombreNivel(n)} ', style: const TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(text: rango(n), style: const TextStyle(color: Tema.gris)),
                    TextSpan(text: '\n${objetivo(n)}', style: const TextStyle(color: Tema.gris, fontSize: 10.5)),
                  ]), style: const TextStyle(fontSize: 12.5)),
                ),
                Text('${r.pct(n).round()} %',
                    style: TextStyle(fontWeight: FontWeight.w800, color: Tema.nivel(n), fontSize: 14)),
              ]),
            ),
        ]),
      ),
    ]);
  }
}
