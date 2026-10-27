import 'dart:math';
import 'package:flutter/material.dart';

class Fatia {
  final double valor;
  final Color cor;
  const Fatia(this.valor, this.cor);
}

/// Gráfico de rosca simples, sem bibliotecas externas.
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.fatias, this.size = 140, this.child});
  final List<Fatia> fatias;
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(fatias,
            Theme.of(context).colorScheme.surfaceContainerHighest),
        child: Center(child: child),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.fatias, this.fundo);
  final List<Fatia> fatias;
  final Color fundo;

  @override
  void paint(Canvas canvas, Size size) {
    const largura = 18.0;
    final rect = Rect.fromLTWH(largura / 2, largura / 2,
        size.width - largura, size.height - largura);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = largura;
    final total = fatias.fold<double>(0, (s, f) => s + f.valor);
    if (total <= 0) {
      canvas.drawArc(rect, 0, 2 * pi, false, p..color = fundo);
      return;
    }
    var inicio = -pi / 2;
    final gap = fatias.length > 1 ? 0.03 : 0.0;
    for (final f in fatias) {
      final ang = f.valor / total * 2 * pi;
      if (ang - gap > 0) {
        canvas.drawArc(rect, inicio + gap / 2, ang - gap, false, p..color = f.cor);
      }
      inicio += ang;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => true;
}
