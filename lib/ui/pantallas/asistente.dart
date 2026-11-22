import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../datos/datos.dart';
import '../../services/ia.dart';
import '../comun.dart';
import '../marco.dart';
import '../tema.dart';

class PantallaAsistente extends StatefulWidget {
  const PantallaAsistente({super.key});

  @override
  State<PantallaAsistente> createState() => _PantallaAsistenteState();
}

class _PantallaAsistenteState extends State<PantallaAsistente> {
  final _mensajes = <(String, String)>[]; // (rol, texto)
  final _texto = TextEditingController();
  final _scroll = ScrollController();
  bool _pensando = false;
  bool? _hayClave;

  @override
  void initState() {
    super.initState();
    IA.clave().then((k) {
      if (mounted) setState(() => _hayClave = k != null);
    });
  }

  Future<void> _enviar(String pregunta, {String? visible}) async {
    if (pregunta.trim().isEmpty || _pensando) return;
    setState(() {
      _mensajes.add(('user', visible ?? pregunta.trim()));
      _pensando = true;
    });
    _texto.clear();
    _bajar();
    try {
      // El contexto con los datos va en el sistema: así está siempre al día.
      // Sin los errores, con la pregunta completa en vez del texto visible y
      // juntando mensajes seguidos del mismo rol (la API pide alternarlos).
      final previos = _mensajes.sublist(0, _mensajes.length - 1).where((m) => m.$1 != 'error');
      final hist = <(String, String)>[];
      for (final m in [...previos, ('user', pregunta.trim())]) {
        if (hist.isNotEmpty && hist.last.$1 == m.$1) {
          hist[hist.length - 1] = (m.$1, '${hist.last.$2}\n\n${m.$2}');
        } else {
          hist.add(m);
        }
      }
      final r = await IA.preguntar(Datos.i.perfil.modeloIA, hist, sistemaExtra: IA.contexto(Datos.i));
      setState(() => _mensajes.add(('assistant', r)));
    } catch (e) {
      setState(() => _mensajes.add(('error', e.toString())));
    } finally {
      if (mounted) setState(() => _pensando = false);
      _bajar();
    }
  }

  void _bajar() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  @override
  Widget build(BuildContext context) {
    if (_hayClave == false) {
      return Pagina([
        const SizedBox(height: 12),
        const Nota(
          'Falta la clave de la API',
          'El asistente usa Claude con tu propia clave de Anthropic (console.anthropic.com). '
              'Ponla en Ajustes; se guarda cifrada solo en este dispositivo.',
          icono: Icons.key_outlined,
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(onPressed: () => navegar.value = 'ajustes', child: const Text('Ir a Ajustes')),
        ),
      ]);
    }
    return Column(children: [
      Expanded(
        child: ListView(controller: _scroll, padding: const EdgeInsets.fromLTRB(12, 12, 12, 12), children: [
          if (_mensajes.isEmpty) ...[
            const Text('Pregunta lo que quieras sobre tus datos o usa un análisis rápido:',
                style: TextStyle(color: Tema.gris)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in IA.rapidos.entries)
                ActionChip(
                  avatar: const Icon(Icons.auto_awesome, size: 16, color: Tema.acento),
                  label: Text(e.value.$1),
                  onPressed: () => _enviar(e.value.$2, visible: 'Análisis: ${e.value.$1}'),
                ),
            ]),
            const SizedBox(height: 14),
            const Text(
              'Al preguntar se envía a Anthropic un resumen de tus registros. Las respuestas son orientativas: '
              'las decisiones de tratamiento son de tu médico.',
              style: TextStyle(fontSize: 11.5, color: Tema.gris),
            ),
          ],
          for (final (rol, t) in _mensajes) _Burbuja(rol, t),
          if (_pensando)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Row(children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Tema.acento)),
                SizedBox(width: 10),
                Text('Pensando…', style: TextStyle(color: Tema.gris)),
              ]),
            ),
        ]),
      ),
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: SafeArea(
          top: false,
          child: Row(children: [
            if (_mensajes.isNotEmpty)
              IconButton(
                  tooltip: 'Nueva conversación',
                  onPressed: _pensando ? null : () => setState(_mensajes.clear),
                  icon: const Icon(Icons.refresh)),
            Expanded(
              child: TextField(
                controller: _texto,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: _enviar,
                decoration: const InputDecoration(hintText: 'Escribe tu pregunta…'),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(onPressed: _pensando ? null : () => _enviar(_texto.text), icon: const Icon(Icons.send)),
          ]),
        ),
      ),
    ]);
  }
}

class _Burbuja extends StatelessWidget {
  final String rol, texto;
  const _Burbuja(this.rol, this.texto);

  @override
  Widget build(BuildContext context) {
    final yo = rol == 'user';
    final error = rol == 'error';
    return Align(
      alignment: yo ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          decoration: BoxDecoration(
            color: error ? Tema.error.withValues(alpha: 0.08) : (yo ? Tema.acentoSuave : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: error ? Tema.error.withValues(alpha: .3) : Tema.borde),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SelectableText(texto.replaceAll('**', ''), style: TextStyle(height: 1.4, color: error ? Tema.error : Tema.texto)),
            if (rol == 'assistant')
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                IconButton(
                  tooltip: 'Copiar',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: texto));
                    avisar(context, 'Copiado');
                  },
                ),
                IconButton(
                  tooltip: 'Compartir',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.share_outlined, size: 16),
                  onPressed: () => SharePlus.instance.share(ShareParams(text: texto, subject: 'GluControl')),
                ),
              ]),
          ]),
        ),
      ),
    );
  }
}
