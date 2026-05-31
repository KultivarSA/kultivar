class NoteTemplate {
  final String id;
  final String title;
  final String content;
  final String category; // matches NoteCategory.name
  final DateTime createdAt;

  const NoteTemplate({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'category': category,
        'createdAt': createdAt.toIso8601String(),
      };

  factory NoteTemplate.fromJson(Map<String, dynamic> json) => NoteTemplate(
        id: json['id'],
        title: json['title'],
        content: json['content'],
        category: json['category'] ?? 'observation',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : DateTime.now(),
      );
}
