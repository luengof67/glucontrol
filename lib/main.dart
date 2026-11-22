import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'datos/datos.dart';
import 'services/avisos.dart';
import 'services/fb.dart';
import 'ui/login.dart';
import 'ui/marco.dart';
import 'ui/tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Fb.iniciar(); // ver services/fb.dart (Windows: nombre propio)
    await initializeDateFormatting('es_ES', null);
  } catch (e, st) {
    runApp(_ErrorArranque('$e\n\n$st'));
    return;
  }
  await Avisos.iniciar();
  runApp(const GluControlApp());
}

/// Pantalla de emergencia si la app no puede arrancar.
class _ErrorArranque extends StatelessWidget {
  final String error;
  const _ErrorArranque(this.error);

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: Tema.tema,
        home: Scaffold(
          appBar: AppBar(title: const Text('GLUCONTROL')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText('La app no ha podido arrancar. Copia este texto y pásaselo a Claude:\n\n$error'),
          ),
        ),
      );
}

class GluControlApp extends StatelessWidget {
  const GluControlApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'GluControl',
        debugShowCheckedModeBanner: false,
        theme: Tema.tema,
        locale: const Locale('es', 'ES'),
        supportedLocales: const [Locale('es', 'ES')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const _Portero(),
      );
}

/// Sin sesión → intenta reconectar con lo guardado; si no, login.
/// Con sesión → la app.
class _Portero extends StatelessWidget {
  const _Portero();

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: Fb.auth.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final u = snap.data;
          if (u != null) {
            Datos.i.iniciar(u.uid);
            return const Marco();
          }
          Datos.i.parar();
          return const ReconectorAutomatico();
        },
      );
}
