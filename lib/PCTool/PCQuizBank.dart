import 'dart:convert';

import 'package:flutter/services.dart';

import 'pc_extension_help.dart';

class PCQuizQuestion {
  const PCQuizQuestion({
    required this.question,
    required this.a,
    required this.b,
    required this.answer,
  });

  final String question;
  final String a;
  final String b;
  final String answer;

  factory PCQuizQuestion.fromJson(Map<String, dynamic> json) {
    return PCQuizQuestion(
      question: json['question'] as String,
      a: json['a'] as String,
      b: json['b'] as String,
      answer: json['answer'] as String,
    );
  }
}

class PCQuizBank {
  PCQuizBank._(this.categories);

  static const orderedCategories = <String>[
    'Fruit',
    'DailyLife',
    'Nature',
    'History',
    'Math',
    'Animal',
  ];

  final Map<String, List<PCQuizQuestion>> categories;

  static Future<PCQuizBank> load() async {
    final raw = await rootBundle.loadString('assets/File/pc_quiz_bank.enc');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final codes = (decoded['codes'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value as int),
    );
    final encrypted = decoded['data'] as Map<String, dynamic>;
    final result = <String, List<PCQuizQuestion>>{};
    for (final category in orderedCategories) {
      final plain = BoomUniqueStringUtil.decrypt(
        encrypted[category] as String,
        codes[category]!,
      );
      final values = jsonDecode(plain) as List<dynamic>;
      result[category] = values
          .map(
            (value) => PCQuizQuestion.fromJson(value as Map<String, dynamic>),
          )
          .toList(growable: false);
    }
    return PCQuizBank._(result);
  }

  int get totalLength =>
      categories.values.fold(0, (sum, items) => sum + items.length);

  PCQuizQuestion questionAt(int index) {
    var remaining = index % totalLength;
    for (final category in orderedCategories) {
      final questions = categories[category]!;
      if (remaining < questions.length) return questions[remaining];
      remaining -= questions.length;
    }
    throw StateError('Quiz index out of range');
  }

  String categoryAt(int index) {
    var remaining = index % totalLength;
    for (final category in orderedCategories) {
      final count = categories[category]!.length;
      if (remaining < count) return category;
      remaining -= count;
    }
    throw StateError('Quiz index out of range');
  }
}
