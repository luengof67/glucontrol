import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Fotos de informes y platos: se reducen y se guardan como JPEG en base64
/// dentro del propio registro de Firestore (máximo 1 MB por documento).
class Imagenes {
  /// Lado mayor y calidad para guardar.
  static const _lado = 1400;
  static const _calidad = 70;

  /// Reduce una foto (bytes de cualquier formato) a JPEG ligero.
  static Future<Uint8List> comprimir(Uint8List bytes, {int lado = _lado, int calidad = _calidad}) =>
      Isolate.run(() {
        final im = img.decodeImage(bytes);
        if (im == null) return bytes;
        final r = (im.width > lado || im.height > lado)
            ? img.copyResize(im,
                width: im.width >= im.height ? lado : null,
                height: im.height > im.width ? lado : null,
                interpolation: img.Interpolation.average)
            : im;
        return Uint8List.fromList(img.encodeJpg(r, quality: calidad));
      });

  /// Para fotos que llegan de un backup antiguo: si pesan mucho, se reducen.
  static Future<String> ajustarBase64(String b64) async {
    try {
      final bytes = base64Decode(b64);
      if (bytes.length < 600 * 1024) return b64;
      return base64Encode(await comprimir(bytes));
    } catch (_) {
      return b64;
    }
  }
}
