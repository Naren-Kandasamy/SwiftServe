import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared/models/incident.dart';
import 'package:shared/models/message.dart';
import 'package:shared/models/user.dart';
import 'package:uuid/uuid.dart';

class IncidentChatDialog extends StatefulWidget {
  final Incident incident;
  final UserRole currentRole;
  final String? teamId;
  
  const IncidentChatDialog({
    super.key, 
    required this.incident,
    required this.currentRole,
    this.teamId,
  });

  @override
  State<IncidentChatDialog> createState() => _IncidentChatDialogState();
}

class _IncidentChatDialogState extends State<IncidentChatDialog> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _subscribeToMessages();
  }

  void _subscribeToMessages() {
    FirebaseDatabase.instance
        .ref('venues/${widget.incident.venueId}/messages/${widget.incident.id}')
        .onValue
        .listen((event) {
      if (!mounted) return;
      if (event.snapshot.value == null) {
        setState(() => _messages = []);
        return;
      }

      final data = event.snapshot.value;
      if (data is! Map) return;

      final List<ChatMessage> loaded = [];
      data.forEach((key, value) {
        if (value is Map) {
          loaded.add(ChatMessage.fromMap(Map<dynamic, dynamic>.from(value)));
        }
      });
      loaded.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      setState(() {
        _messages = loaded;
      });

      // Simple auto-scroll
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    final msgId = const Uuid().v4();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'staff_mock';
    final String label = widget.currentRole == UserRole.admin ? 'ADMIN' : (widget.teamId ?? widget.currentRole.name.toUpperCase());
    final String prefixedText = '[$label] $text';

    final chatMsg = ChatMessage(
      id: msgId,
      senderId: uid,
      text: prefixedText,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isStaff: true, // we are on the dashboard
    );

    await FirebaseDatabase.instance
        .ref('venues/${widget.incident.venueId}/messages/${widget.incident.id}/$msgId')
        .set(chatMsg.toMap());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 400,
        height: 600,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red[900],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.forum, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chat w/ Guest (Room ${widget.incident.affectedZone})',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? const Center(child: Text('No messages yet. Send one to open communication.', style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final label = widget.currentRole == UserRole.admin ? 'ADMIN' : (widget.teamId ?? widget.currentRole.name.toUpperCase());
                        final alignRight = msg.isStaff; // Staff always on right for dashboard users
                        final isMe = msg.isStaff && msg.text.startsWith('[$label]');
                        final timeString = DateTime.fromMillisecondsSinceEpoch(msg.timestamp).toString().substring(11, 16);
                        
                        String roleLabel = alignRight ? 'Staff' : 'Guest';
                        String displayMsg = msg.text;
                        
                        if (alignRight) {
                          final match = RegExp(r'^\[(.*?)\] (.*)').firstMatch(msg.text);
                          if (match != null) {
                            roleLabel = match.group(1)!;
                            displayMsg = match.group(2)!;
                          }
                        }
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 300),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: alignRight ? Colors.blue[800] : Colors.grey[800],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(roleLabel, style: TextStyle(color: alignRight ? Colors.blue[200] : Colors.grey[400], fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(displayMsg, style: const TextStyle(color: Colors.white)),
                                const SizedBox(height: 4),
                                Text(timeString, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Type guidance...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.black45,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 18),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
