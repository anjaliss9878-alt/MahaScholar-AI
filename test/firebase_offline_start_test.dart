import 'package:flutter_test/flutter_test.dart';
import 'package:shala_saathi/main.dart';

void main() {
  testWidgets('starts in local mode when Firebase options are not configured',
      (tester) async {
    await tester.pumpWidget(const MahaScholarAiApp());

    expect(find.text('विद्यार्थी प्रवेश'), findsOneWidget);
    expect(
      find.textContaining('स्थानिक चाचणी: Firebase जोडलेले नाही'),
      findsOneWidget,
    );
  });
}
