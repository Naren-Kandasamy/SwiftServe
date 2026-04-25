import 'alert.dart';

enum IncidentStatus { active, escalated, contained, reviewPending, resolved }

class IncidentUpdate {
  int timestamp;
  String updateText;
  
  IncidentUpdate({
    required this.timestamp,
    required this.updateText,
  });

  factory IncidentUpdate.fromMap(Map<dynamic, dynamic> map) {
    return IncidentUpdate(
      timestamp: map['timestamp'] as int? ?? 0,
      updateText: map['updateText'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp,
      'updateText': updateText,
    };
  }
}

class Incident {
  String id;
  String venueId;
  List<String> alertIds;   // all alerts belonging to this incident
  EmergencyType type;
  int severity;            // 1–5, may upgrade over time
  String affectedZone;     // e.g. "Floor 4 East Wing"
  int guestCount;          // from venue occupancy data
  IncidentStatus status;
  int createdAt;
  int? resolvedAt;
  List<IncidentUpdate> timeline; // chronological log of all updates
  String? responderBriefUrl;
  String? imageUrl; // Optional image evidence
  String? requestedResolutionBy;
  List<String> assignedTeams; // IDs of teams assigned to this incident
  String? responderPin; // 4-digit PIN for emergency services access

  Incident({
    required this.id,
    required this.venueId,
    required this.alertIds,
    required this.type,
    required this.severity,
    required this.affectedZone,
    required this.guestCount,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
    required this.timeline,
    this.responderBriefUrl,
    this.imageUrl,
    this.requestedResolutionBy,
    this.assignedTeams = const [],
    this.responderPin,
  });

  factory Incident.fromMap(Map<dynamic, dynamic> map) {
    return Incident(
      id: map['id'] as String? ?? '',
      venueId: map['venueId'] as String? ?? '',
      alertIds: (map['alertIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      type: EmergencyType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => EmergencyType.other,
      ),
      severity: map['severity'] as int? ?? 1,
      affectedZone: map['affectedZone'] as String? ?? 'Unknown',
      guestCount: map['guestCount'] as int? ?? 0,
      status: IncidentStatus.values.firstWhere(
        (st) => st.name == map['status'],
        orElse: () => IncidentStatus.active,
      ),
      createdAt: map['createdAt'] as int? ?? 0,
      resolvedAt: map['resolvedAt'] as int?,
      timeline: (map['timeline'] as List<dynamic>?)?.map((e) => IncidentUpdate.fromMap(e as Map<dynamic, dynamic>)).toList() ?? [],
      responderBriefUrl: map['responderBriefUrl'] as String?,
      imageUrl: map['imageUrl'] as String?,
      requestedResolutionBy: map['requestedResolutionBy'] as String?,
      assignedTeams: (map['assignedTeams'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      responderPin: map['responderPin'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'venueId': venueId,
      'alertIds': alertIds,
      'type': type.name,
      'severity': severity,
      'affectedZone': affectedZone,
      'guestCount': guestCount,
      'status': status.name,
      'createdAt': createdAt,
      'resolvedAt': resolvedAt,
      'timeline': timeline.map((u) => u.toMap()).toList(),
      'responderBriefUrl': responderBriefUrl,
      'imageUrl': imageUrl,
      'requestedResolutionBy': requestedResolutionBy,
      'assignedTeams': assignedTeams,
      'responderPin': responderPin,
    };
  }
}
