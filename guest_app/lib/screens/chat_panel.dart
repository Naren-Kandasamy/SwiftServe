import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared/models/incident.dart';
import 'package:shared/models/message.dart';
import 'package:uuid/uuid.dart';

class ChatPanel extends StatefulWidget {
  final Incident incident;
  
  const ChatPanel({super.key, required this.incident});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
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
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest_offline';
    final chatMsg = ChatMessage(
      id: msgId,
      senderId: uid,
      text: text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isStaff: false, // from guest
    );

    await FirebaseDatabase.instance
        .ref('venues/${widget.incident.venueId}/messages/${widget.incident.id}/$msgId')
        .set(chatMsg.toMap());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12, width: 2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.black26,
            child: const Row(
              children: [
                Icon(Icons.message, color: Colors.blueAccent, size: 16),
                SizedBox(width: 8),
                Text('Direct Message to Staff', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('Awaiting staff message...', style: TextStyle(color: Colors.white30)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      // Guests messages align right (they sent it), staff left
                      final alignRight = !msg.isStaff;
                      final isResponder = msg.text.startsWith('[RESPONDER]');
                      
                      String displayText = msg.text;
                      if (msg.isStaff && msg.text.startsWith('[')) {
                        final match = RegExp(r'^\[(.*?)\] (.*)').firstMatch(msg.text);
                        if (match != null) {
                          displayText = match.group(2)!;
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isResponder ? Colors.orange[800] : (alignRight ? Colors.blue[900] : Colors.grey[800]),
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomRight: alignRight ? const Radius.circular(0) : null,
                              bottomLeft: !alignRight ? const Radius.circular(0) : null,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (msg.isStaff)
                                Text(isResponder ? 'EMERGENCY SERVICES' : 'STAFF', style: TextStyle(color: isResponder ? Colors.orange[200] : Colors.grey[400], fontSize: 10, fontWeight: FontWeight.bold)),
                              if (msg.isStaff) const SizedBox(height: 2),
                              Text(displayText, style: const TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.grey[900],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  radius: 22,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
