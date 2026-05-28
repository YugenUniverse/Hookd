class Event {
  final String id;
  final String title;
  final String? description;
  final String facilityId;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? createdAt;
  final String status;
  final List<String> walls;

  const Event({
    required this.id,
    required this.title,
    this.description,
    required this.facilityId,
    required this.startDate,
    this.endDate,
    this.createdAt,
    this.status = 'active',
    this.walls = const [],
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return Event(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      facilityId: (json['facility'] ?? '').toString(),
      startDate: parseDate(json['startDate']) ?? DateTime.now(),
      endDate: parseDate(json['endDate']),
      createdAt: parseDate(json['createdAt']),
      status: json['status']?.toString() ?? 'active',
      walls: (json['walls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
