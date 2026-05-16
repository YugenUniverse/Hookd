class Issue {
  final String? id;
  final String? climberId;
  final String wall_id;
  final String body;
  final String status;
  final DateTime? submittedAt;

  Issue({
    this.id,
    this.climberId,
    required this.wall_id,
    required this.body,
    this.status = 'OPEN',
    this.submittedAt,
  });

  factory Issue.fromJson(Map<String, dynamic> json) {
    final submittedAtRaw = json['submitted_at'] ?? json['submittedAt'];
    DateTime? submittedAt;
    if (submittedAtRaw != null) {
      submittedAt = DateTime.tryParse(submittedAtRaw.toString());
    }

    return Issue(
      id: (json['id'] ?? json['_id'])?.toString(),
      climberId: (json['climber_id'] ?? json['climberId'])?.toString(),
      wall_id: (json['wall_id'] ?? json['wallId'] ?? 'Unknown Wall').toString(),
      body: (json['body'] ?? '').toString(),
      status: (json['status'] ?? 'OPEN').toString(),
      submittedAt: submittedAt,
    );
  }

  Map<String, dynamic> toJson() {
    final data = {'wall_id': wall_id, 'body': body};

    if (submittedAt != null) {
      data['submitted_at'] = submittedAt!.toIso8601String();
    }
    if (climberId != null) {
      data['climber_id'] = climberId!;
    }
    if (status.isNotEmpty) {
      data['status'] = status;
    }
    if (id != null) {
      data['id'] = id!;
    }

    return data;
  }
}
