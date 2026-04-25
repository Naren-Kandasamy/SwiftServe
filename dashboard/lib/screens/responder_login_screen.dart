import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'responder_view_screen.dart';
import 'package:shared/models/incident.dart';

class ResponderLoginScreen extends StatefulWidget {
  final String venueId;

  const ResponderLoginScreen({super.key, required this.venueId});

  @override
  State<ResponderLoginScreen> createState() => _ResponderLoginScreenState();
}

class _ResponderLoginScreenState extends State<ResponderLoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  Future<void> _login() async {
    final pin = _pinController.text.trim();
    if (pin.length != 4) {
      setState(() => _errorText = 'PIN must be 4 digits');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      // Ensure anonymous auth
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      final snapshot = await FirebaseDatabase.instance.ref('venues/${widget.venueId}/incidents').get();
      if (!snapshot.exists || snapshot.value == null) {
        setState(() => _errorText = 'Invalid PIN or no active incidents.');
        return;
      }

      final data = snapshot.value as Map;
      Incident? matchedIncident;

      data.forEach((key, value) {
        if (value is Map) {
          final incident = Incident.fromMap(Map<dynamic, dynamic>.from(value));
          if (incident.responderPin == pin) {
            matchedIncident = incident;
          }
        }
      });

      if (matchedIncident != null) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ResponderViewScreen(incident: matchedIncident!)),
        );
      } else {
        setState(() => _errorText = 'Invalid PIN.');
      }
    } catch (e) {
      setState(() => _errorText = 'Error connecting to database.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orangeAccent, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emergency, color: Colors.orangeAccent, size: 64),
              const SizedBox(height: 16),
              const Text(
                'CRISISNET RESPONDER PORTAL',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the 4-digit PIN provided by venue dispatch.',
                style: TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _pinController,
                maxLength: 4,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 12),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Colors.black,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.orangeAccent)),
                  errorText: _errorText,
                ),
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('ACCESS LIVE BRIEFING', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
