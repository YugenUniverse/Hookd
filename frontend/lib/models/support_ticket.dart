class SupportTicket {
  final String id;
  final String subject;
  final String body;
  final String category;
  final String status;
  final String? adminReply;
  final DateTime? repliedAt;
  final DateTime? createdAt;
  final Map<String, dynamic>? user;

  const SupportTicket({
    required this.id,
    required this.subject,
    required this.body,
    required this.category,
    required this.status,
    this.adminReply,
    this.repliedAt,
    this.createdAt,
    this.user,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    final userRaw = json['user_id'];
    final user = userRaw is Map ? Map<String, dynamic>.from(userRaw) : null;

    return SupportTicket(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      subject: (json['subject'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      category: (json['category'] ?? 'OTHER').toString(),
      status: (json['status'] ?? 'OPEN').toString(),
      adminReply: json['admin_reply']?.toString(),
      repliedAt: parseDate(json['replied_at']),
      createdAt: parseDate(json['createdAt']),
      user: user,
    );
  }

  bool get isOpen => status == 'OPEN';
  bool get isResolved => status == 'RESOLVED' || status == 'CLOSED';
  bool get hasReply => adminReply != null && adminReply!.isNotEmpty;
}
