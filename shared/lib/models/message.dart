class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final int timestamp;
  final bool isStaff; // true if from dashboard, false if from guest
  
  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isStaff,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp,
      'isStaff': isStaff,
    };
  }

  factory ChatMessage.fromMap(Map<dynamic, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: map['timestamp'] ?? 0,
      isStaff: map['isStaff'] ?? false,
    );
  }
}
