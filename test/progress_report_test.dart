import 'package:flutter_test/flutter_test.dart';
import 'package:shala_saathi/progress_report.dart';

void main() {
  group('normalizeWhatsAppNumber', () {
    test('adds the Indian country code to a ten-digit number', () {
      expect(normalizeWhatsAppNumber('98765 43210'), '919876543210');
    });

    test('keeps an international number and strips formatting', () {
      expect(normalizeWhatsAppNumber('+1 (415) 555-2671'), '14155552671');
    });

    test('rejects malformed or too-short values', () {
      expect(normalizeWhatsAppNumber('not a number'), isNull);
      expect(normalizeWhatsAppNumber('12345'), isNull);
    });
  });

  test('progress report contains scores and safe life-skills totals', () {
    final report = composeProgressReport(
      studentName: 'Aarav',
      standard: 5,
      medium: 'Semi-English',
      activity: 'Practice quiz completed',
      quizCount: 3,
      latestScore: 8,
      averageScore: 7.5,
      studyCompletions: 4,
      coins: 12,
      habitsCompletedToday: 5,
    );

    expect(report, contains('Aarav'));
    expect(report, contains('8/10'));
    expect(report, contains('7.5/10'));
    expect(report, contains('12 नाणी'));
    expect(report, contains('5/6'));
    expect(report, isNot(contains('mood')));
  });
}
