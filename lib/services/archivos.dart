import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Sacar un archivo de la app: en Windows, ventana de "Guardar como"; en
/// Android, menú de compartir (Drive, WhatsApp, correo, Archivos…).
/// Devuelve un texto para avisar al usuario, o null si se canceló.
class Archivos {
  static bool get _windows => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static Future<String?> entregar(Uint8List bytes, String nombre, String mime, {String? asunto}) async {
    if (_windows) {
      final ext = nombre.split('.').last;
      final destino = await getSaveLocation(
        suggestedName: nombre,
        acceptedTypeGroups: [XTypeGroup(label: ext.toUpperCase(), extensions: [ext])],
      );
      if (destino == null) return null;
      var ruta = destino.path;
      if (!ruta.toLowerCase().endsWith('.$ext')) ruta = '$ruta.$ext';
      await File(ruta).writeAsBytes(bytes);
      return 'Guardado en $ruta';
    }
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$nombre');
    await f.writeAsBytes(bytes);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(f.path, mimeType: mime)],
      subject: asunto ?? nombre,
    ));
    return null;
  }

  /// Elegir un archivo para importar.
  static Future<Uint8List?> abrir(List<String> extensiones, String etiqueta) async {
    final f = await openFile(acceptedTypeGroups: [XTypeGroup(label: etiqueta, extensions: extensiones)]);
    return f == null ? null : await f.readAsBytes();
  }
}
