import '../../domain/models.dart';

class MotionTokens {
  const MotionTokens({
    required this.fastMs,
    required this.regularMs,
    required this.slowMs,
  });

  final int fastMs;
  final int regularMs;
  final int slowMs;

  static MotionTokens forComplexity(TaskComplexity complexity) {
    return switch (complexity) {
      TaskComplexity.low => const MotionTokens(fastMs: 100, regularMs: 170, slowMs: 220),
      TaskComplexity.medium => const MotionTokens(fastMs: 130, regularMs: 210, slowMs: 280),
      TaskComplexity.high => const MotionTokens(fastMs: 150, regularMs: 250, slowMs: 340),
    };
  }
}
