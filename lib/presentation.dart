import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'domain.dart';

const violet = Color(0xff9562f5);
const ink = Color(0xff17141f);
const palette = [
  violet,
  Color(0xff25a7eb),
  Color(0xff2dc77a),
  Color(0xffff8a24),
  Color(0xffff6e55),
  Color(0xffe7b43c),
];
String monthLabel(DateTime d) =>
    '${const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][d.month - 1]} ${d.year}';
IconData categoryIcon(String name) {
  final s = name.toLowerCase();
  if (s.contains('grocer')) return Icons.shopping_basket_outlined;
  if (s.contains('dining') || s.contains('food')) {
    return Icons.local_cafe_outlined;
  }
  if (s.contains('travel') || s.contains('vacation')) {
    return Icons.beach_access_outlined;
  }
  if (s.contains('educat')) return Icons.school_outlined;
  if (s.contains('home') || s.contains('house') || s.contains('rent')) {
    return Icons.home_outlined;
  }
  if (s.contains('health') || s.contains('emergency')) {
    return Icons.health_and_safety_outlined;
  }
  if (s.contains('salary') || s.contains('income')) {
    return Icons.payments_outlined;
  }
  if (s.contains('shop')) return Icons.shopping_bag_outlined;
  return Icons.account_balance_wallet_outlined;
}

class MoneyRing extends StatelessWidget {
  final Map<String, int> values;
  final String label;
  const MoneyRing({super.key, required this.values, required this.label});
  @override
  Widget build(BuildContext context) {
    final total = values.values.fold(0, (int a, b) => a + b);
    return Semantics(
      label: '$label ${money(total)}',
      child: SizedBox(
        height: 260,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: RingPainter(values.values.toList())),
            ),
            SizedBox(
              width: 170,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    child: Text(
                      money(total),
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RingPainter extends CustomPainter {
  final List<int> values;
  RingPainter(this.values);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: math.min(size.width, size.height) / 2 - 22,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 25
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      paint..color = const Color(0xffeeeaf5),
    );
    final total = values.fold(0, (int a, b) => a + b);
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      final gap = math.min(.045, sweep * .2);
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(.001, sweep - gap),
        false,
        paint..color = palette[i % palette.length],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(RingPainter old) =>
      old.values.toString() != values.toString();
}

class SummaryTile extends StatelessWidget {
  final String label;
  final int amount;
  final IconData icon;
  final Color color;
  const SummaryTile({
    super.key,
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xffeeeaf2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: color.withValues(alpha: .10),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 18),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        FittedBox(
          child: Text(
            money(amount),
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}
