class Issue {
  final String wall_id;
  final String body;
  final DateTime? submittedAt;

  Issue({required this.wall_id, required this.body, this.submittedAt});

  factory Issue.fromJson(Map<String, dynamic> json) {
    final submittedAtRaw = json['submitted_at'] ?? json['submittedAt'];
    DateTime? submittedAt;
    if (submittedAtRaw != null) {
      submittedAt = DateTime.tryParse(submittedAtRaw.toString());
    }

    return Issue(
      wall_id: (json['wall_id'] ?? 'Unknown Wall').toString(),
      body: (json['body'] ?? '').toString(),
      submittedAt: submittedAt,
    );
  }

  Map<String, dynamic> toJson() {
    final data = {'wall_id': wall_id, 'body': body};

    if (submittedAt != null) {
      data['submitted_at'] = submittedAt!.toIso8601String();
    }

    return data;
  }
}
