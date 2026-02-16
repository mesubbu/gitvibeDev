import 'package:theme_preview/integration/diff_detector.dart';

void main() {
  final DiffDetector detector = DiffDetector();
  final String report = detector.toMarkdownReport();
  // ignore: avoid_print
  print(report);
}
