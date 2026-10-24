String? normalizeWhatsAppNumber(String value) {
  final input = value.trim();
  if (input.isEmpty || !RegExp(r'^\+?[0-9\s().-]+$').hasMatch(input)) {
    return null;
  }

  var digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.length == 11 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.length == 10) digits = '91$digits';
  if (digits.length < 8 || digits.length > 15) return null;
  return digits;
}

String composeProgressReport({
  required String studentName,
  required int standard,
  required String medium,
  required String activity,
  required int quizCount,
  required int? latestScore,
  required double? averageScore,
  required int studyCompletions,
  required int coins,
  required int habitsCompletedToday,
}) {
  final name = studentName.trim().isEmpty ? 'विद्यार्थी' : studentName.trim();
  final latest = latestScore == null ? 'अद्याप नाही' : '$latestScore/10';
  final average = averageScore == null
      ? 'अद्याप नाही'
      : '${averageScore.toStringAsFixed(1)}/10';
  return 'MahaScholar AI – विद्यार्थी प्रगती अहवाल\n'
      'विद्यार्थी: $name\n'
      'इयत्ता: $standard · माध्यम: $medium\n'
      'अलीकडील कृती: $activity\n'
      'अलीकडील प्रश्नमंजुषा: $quizCount · नवीनतम गुण: $latest · अलीकडील सरासरी: $average\n'
      'पूर्ण अध्ययन घटक: $studyCompletions\n'
      'जीवनकौशल्ये: $coins नाणी · आजच्या स्वच्छता सवयी: $habitsCompletedToday/6';
}
