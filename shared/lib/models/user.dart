enum UserRole { guest, security, medical, management, admin }

class AppUser {
  String id;               // Firebase Auth UID
  String name;
  String venueId;
  UserRole role;
  String? roomNumber;      // guests only
  int? floor;              // guests only
  String? fcmToken;        // for push notifications
  bool hasFirstAid;        // staff only — for priority routing

  AppUser({
    required this.id,
    required this.name,
    required this.venueId,
    required this.role,
    this.roomNumber,
    this.floor,
    this.fcmToken,
    this.hasFirstAid = false,
  });
}
