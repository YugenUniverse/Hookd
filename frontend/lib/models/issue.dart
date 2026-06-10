import 'package:flutter/material.dart';

class Issue {
  final String? id;
  final String? climberId;
  final String? climberName;
  final String wall_id;
  final String? wallName;
  final double? wallLatitude;
  final double? wallLongitude;
  final String body;
  final String description;
  final String location;
  final String status;
  final String severity;
  final DateTime? submittedAt;

  Issue({
    this.id,
    this.climberId,
    this.climberName,
    required this.wall_id,
    this.wallName,
    this.wallLatitude,
    this.wallLongitude,
    required this.body,
    this.description = '',
    this.location = '',
    this.status = 'OPEN',
    this.severity = 'MEDIUM',
    this.submittedAt,
  });

  factory Issue.fromJson(Map<String, dynamic> json) {
    final submittedAtRaw = json['submitted_at'] ?? json['submittedAt'];
    DateTime? submittedAt;
    if (submittedAtRaw != null) {
      submittedAt = DateTime.tryParse(submittedAtRaw.toString());
    }

    // Extract climber name from populated climber object if available
    String? climberName;
    final climberObj = json['climber_id'];
    if (climberObj is Map) {
      climberName = climberObj['username']?.toString();
    }

    // Extract wall name and coordinates from populated wall object if available
    String? wallName;
    double? wallLatitude;
    double? wallLongitude;
    final wallObj = json['wall_id'];
    if (wallObj is Map) {
      wallName = wallObj['name']?.toString();
      final locationObj = wallObj['location'];
      if (locationObj is Map) {
        final coordsRaw = locationObj['coordinates'];
        if (coordsRaw is List && coordsRaw.length >= 2) {
          wallLongitude = (coordsRaw[0] as num?)?.toDouble();
          wallLatitude = (coordsRaw[1] as num?)?.toDouble();
        }
      }
    }

    return Issue(
      id: (json['id'] ?? json['_id'])?.toString(),
      climberId: (json['climber_id'] is Map
              ? json['climber_id']['_id'] ?? json['climber_id']['id']
              : json['climber_id'])
          ?.toString(),
      climberName: climberName,
      wall_id: (wallObj is Map
              ? (wallObj['_id'] ?? wallObj['id'])
              : json['wall_id'] ?? json['wallId'])
          ?.toString() ?? '',
      wallName: wallName,
      wallLatitude: wallLatitude,
      wallLongitude: wallLongitude,
      body: (json['body'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      status: (json['status'] ?? 'OPEN').toString(),
      severity: (json['severity'] ?? 'MEDIUM').toString(),
      submittedAt: submittedAt,
    );
  }

  Map<String, dynamic> toJson() {
    final data = {'wall_id': wall_id, 'body': body};

    if (description.isNotEmpty) {
      data['description'] = description;
    }
    if (location.isNotEmpty) {
      data['location'] = location;
    }
    if (submittedAt != null) {
      data['submitted_at'] = submittedAt!.toIso8601String();
    }
    if (climberId != null) {
      data['climber_id'] = climberId!;
    }
    if (status.isNotEmpty) {
      data['status'] = status;
    }
    if (severity.isNotEmpty && severity != 'MEDIUM') {
      data['severity'] = severity;
    }
    if (id != null) {
      data['id'] = id!;
    }

    return data;
  }

  Color get severityColor {
    switch (severity) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String get severityLabel {
    switch (severity) {
      case 'HIGH':
        return '🔴 High';
      case 'MEDIUM':
        return '🟠 Medium';
      case 'LOW':
        return '🟡 Low';
      default:
        return 'Unknown';
    }
  }

  String get displayClimberName {
    return climberName?.isNotEmpty == true ? climberName! : 'Anonymous';
  }
}
