import 'dart:convert';

class Minute {
  final int? id;
  final String title;
  final String content;
  final String? aiSummary;
  final String? audioPath;
  final DateTime createdAt;

  Minute({
    this.id,
    required this.title,
    required this.content,
    this.aiSummary,
    this.audioPath,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'aiSummary': aiSummary,
      'audioPath': audioPath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Minute.fromMap(Map<String, dynamic> map) {
    return Minute(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      aiSummary: map['aiSummary'],
      audioPath: map['audioPath'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  String toJson() => json.encode(toMap());

  factory Minute.fromJson(String source) => Minute.fromMap(json.decode(source));
}
