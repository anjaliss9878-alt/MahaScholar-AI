import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shala_saathi/life_skills_modules.dart';

void main() {
  testWidgets('shows and opens all four life-skills modules', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LifeSkillsModulesPage(medium: 'English'),
      ),
    );

    expect(find.text('Time Management'), findsOneWidget);
    expect(find.text('Financial Literacy'), findsOneWidget);
    expect(find.text('Self-Care & Hygiene'), findsOneWidget);
    expect(find.text('Emotional Intelligence'), findsOneWidget);

    await tester.ensureVisible(find.text('Time Management'));
    await tester.tap(find.text('Time Management'));
    await tester.pumpAndSettle();
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('Pomodoro focus and break timer'), findsOneWidget);
  });

  testWidgets('shows the module names in Marathi', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LifeSkillsModulesPage(medium: 'Marathi'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('वेळेचे नियोजन'), findsOneWidget);
    expect(find.text('आर्थिक साक्षरता'), findsOneWidget);
    expect(find.text('स्वतःची काळजी आणि स्वच्छता'), findsOneWidget);
    expect(find.text('भावनिक बुद्धिमत्ता'), findsOneWidget);
  });

  testWidgets('tracks savings, daily hygiene, and mood entries locally',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: LifeSkillsModulesPage(medium: 'English'),
      ),
    );

    await tester.ensureVisible(find.text('Financial Literacy'));
    await tester.tap(find.text('Financial Literacy'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save transaction'));
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(find.text('1 coins'), findsOneWidget);

    await tester.ensureVisible(find.text('Self-Care & Hygiene'));
    await tester.tap(find.text('Self-Care & Hygiene'));
    await tester.pumpAndSettle();
    final habits = find.byType(CheckboxListTile);
    expect(habits, findsNWidgets(6));
    for (var index = 0; index < 6; index++) {
      await tester.ensureVisible(habits.at(index));
      await tester.tap(habits.at(index));
      await tester.pumpAndSettle();
    }
    expect(find.text('2 coins'), findsOneWidget);

    await tester.ensureVisible(find.text('Emotional Intelligence'));
    await tester.tap(find.text('Emotional Intelligence'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Happy'));
    await tester.tap(find.text('Happy'));
    final moodNote = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Note (optional)',
    );
    await tester.enterText(moodNote, 'Good day');
    expect(tester.widget<TextField>(moodNote).controller?.text, 'Good day');
    await tester.tap(find.text('Log mood'));
    await tester.pumpAndSettle();
    expect(find.text('Recent mood entries'), findsOneWidget);
    expect(find.text('Happy'), findsNWidgets(2));
    expect(find.textContaining('Good day'), findsOneWidget);
  });
}
