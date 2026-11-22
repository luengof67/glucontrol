import 'package:flutter/material.dart';

import '../datos/analisis.dart';

/// Lenguaje visual compartido con TRAZA: fondo claro, tarjetas blancas,
/// barra oscura arriba, acento verde azulado y rótulos en versales.
class Tema {
  static const fondo = Color(0xFFF2F4F5);
  static const barra = Color(0xFF1F2A30);
  static const acento = Color(0xFF0F7C7C);
  static const acentoSuave = Color(0xFFE3F1F1);
  static const borde = Color(0xFFE0E5E8);
  static const gris = Color(0xFF6B7780);
  static const texto = Color(0xFF1F2A30);

  // Estados de glucemia
  static const ok = Color(0xFF2E7D32);
  static const baja = Color(0xFFB26A00);
  static const muyBaja = Color(0xFFC62828);
  static const alta = Color(0xFFD9534F);
  static const muyAlta = Color(0xFF8E1B1B);
  static const aviso = Color(0xFFB26A00);
  static const error = Color(0xFFC62828);
  static const morado = Color(0xFF6A4C93);

  static Color nivel(Nivel n) => switch (n) {
        Nivel.muyBaja => muyBaja,
        Nivel.baja => baja,
        Nivel.ok => ok,
        Nivel.alta => alta,
        Nivel.muyAlta => muyAlta,
      };

  static ThemeData get tema {
    final esquema = ColorScheme.fromSeed(
      seedColor: acento,
      primary: acento,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: fondo,
      appBarTheme: const AppBarTheme(
        backgroundColor: barra,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: borde),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borde),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borde),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: acento,
        foregroundColor: Colors.white,
      ),
      dividerTheme: const DividerThemeData(color: borde, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: acentoSuave,
        labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// Rótulo de sección en versales, como en TRAZA.
class Rotulo extends StatelessWidget {
  final String texto;
  final Widget? accion;
  const Rotulo(this.texto, {super.key, this.accion});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              texto.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: Tema.gris,
              ),
            ),
          ),
          if (accion != null) accion!,
        ],
      ),
    );
  }
}

/// Etiqueta pequeña de color.
class Chapita extends StatelessWidget {
  final String texto;
  final Color color;
  const Chapita(this.texto, {super.key, this.color = Tema.acento});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        texto.toUpperCase(),
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: color,
        ),
      ),
    );
  }
}

/// Mensaje rápido abajo.
void avisar(BuildContext context, String texto, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(texto),
    backgroundColor: error ? Tema.error : null,
  ));
}

/// Número con coma decimal.
String num1(double? v, [int dec = 1]) => v == null ? '—' : v.toStringAsFixed(dec).replaceAll('.', ',');

/// Lee un número escrito con coma o con punto.
double? leerNum(String s) {
  final t = s.trim().replaceAll(' ', '');
  if (t.isEmpty) return null;
  return double.tryParse(t.replaceAll(',', '.'));
}
