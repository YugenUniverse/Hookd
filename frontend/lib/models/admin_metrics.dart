class GraphDataPoint {
  final int year;
  final int month;
  final int count;

  GraphDataPoint({
    required this.year,
    required this.month,
    required this.count,
  });

  factory GraphDataPoint.fromJson(Map<String, dynamic> json) {
    return GraphDataPoint(
      year: json['_id']['year'],
      month: json['_id']['month'],
      count: json['count'],
    );
  }
}

class AdminGraphs {
  final List<GraphDataPoint> userRegistrations;
  final List<GraphDataPoint> sessionsLogged;
  final List<GraphDataPoint> eventsCreated;
  final List<GraphDataPoint> reviewsAdded;
  final List<GraphDataPoint> groupsCreated;
  final List<GraphDataPoint> wallsAdded;

  AdminGraphs({
    required this.userRegistrations,
    required this.sessionsLogged,
    required this.eventsCreated,
    required this.reviewsAdded,
    required this.groupsCreated,
    required this.wallsAdded,
  });

  factory AdminGraphs.fromJson(Map<String, dynamic> json) {
    return AdminGraphs(
      userRegistrations: (json['userRegistrations'] as List?)?.map((e) => GraphDataPoint.fromJson(e)).toList() ?? [],
      sessionsLogged: (json['sessionsLogged'] as List?)?.map((e) => GraphDataPoint.fromJson(e)).toList() ?? [],
      eventsCreated: (json['eventsCreated'] as List?)
          ?.map((e) => GraphDataPoint.fromJson(e))
          .toList() ?? [],
      reviewsAdded: (json['reviewsAdded'] as List?)
          ?.map((e) => GraphDataPoint.fromJson(e))
          .toList() ?? [],
      groupsCreated: (json['groupsCreated'] as List?)
          ?.map((e) => GraphDataPoint.fromJson(e))
          .toList() ?? [],
      wallsAdded: (json['wallsAdded'] as List?)
          ?.map((e) => GraphDataPoint.fromJson(e))
          .toList() ?? [],
    );
  }
}

class AdminMetrics {
  final int activeUsers;
  final int totalUsers;
  final int totalWalls;
  final int totalReviews;
  final int totalGroups;
  final int totalEvents;
  final int openReports;
  final AdminGraphs graphs;

  AdminMetrics({
    required this.activeUsers,
    required this.totalUsers,
    required this.totalWalls,
    required this.totalReviews,
    required this.totalGroups,
    required this.totalEvents,
    required this.openReports,
    required this.graphs,
  });

  factory AdminMetrics.fromJson(Map<String, dynamic> json) {
    return AdminMetrics(
      activeUsers: json['activeUsers'] ?? 0,
      totalUsers: json['totalUsers'] ?? 0,
      totalWalls: json['totalWalls'] ?? 0,
      totalReviews: json['totalReviews'] ?? 0,
      totalGroups: json['totalGroups'] ?? 0,
      totalEvents: json['totalEvents'] ?? 0,
      openReports: json['openReports'] ?? 0,
      graphs: AdminGraphs.fromJson(json['graphs'] ?? {}),
    );
  }
}
