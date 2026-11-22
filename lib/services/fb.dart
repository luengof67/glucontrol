import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Acceso único a Firebase para toda la app.
///
/// GluControl usa el mismo proyecto Firebase que ComparaPrecios y
/// ConsultaPrecios (misma cuenta de acceso), pero sus datos van aparte, en
/// `glucontrol/{uid}/...`, y solo los puede leer el propio usuario (ver las
/// reglas en el README).
///
/// WINDOWS: igual que en ConsultaPrecios, la app se registra con nombre
/// propio ("glucontrol") para que sus carpetas en %LOCALAPPDATA% no se
/// crucen con las de las otras apps (eso cerraba la app de golpe, APPCRASH
/// c000001d), y va sin copia local de Firestore. Para poder abrirla sin
/// conexión, GluControl guarda su propia copia en un archivo (ver Datos).
class Fb {
  static late FirebaseApp app;

  static bool get windows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static Future<void> iniciar() async {
    if (windows) {
      if (Firebase.apps.every((a) => a.name != '[DEFAULT]')) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      app = await Firebase.initializeApp(
        name: 'glucontrol',
        options: DefaultFirebaseOptions.currentPlatform,
      );
      db.settings = const Settings(persistenceEnabled: false);
    } else {
      app = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  static FirebaseAuth get auth => FirebaseAuth.instanceFor(app: app);
  static FirebaseFirestore get db => FirebaseFirestore.instanceFor(app: app);
}
