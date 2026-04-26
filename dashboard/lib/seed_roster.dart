import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('--- CrisisNet Staff Roster Seeder ---');

  try {
    // 1. We MUST log in because our new security rules block unauthenticated writes
    print('Authenticating as nah123@gmail.com...');
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'nah123@gmail.com',
      password: 'AdminLogin*123456789', // <--- ENTER YOUR PASSWORD HERE
    );
    
    final String myUid = FirebaseAuth.instance.currentUser!.uid;
    print('Authenticated! UID: $myUid');

    final Map<String, dynamic> roster = {
      myUid: {
        'name': 'Naren (Admin)',
        'role': 'admin',
        'teamId': 'hq',
      },
      'mock_sec_01_uid': {
        'name': 'Security Alpha',
        'role': 'security',
        'teamId': 'sec_01',
      },
      'mock_med_01_uid': {
        'name': 'Medical Unit 1',
        'role': 'medical',
        'teamId': 'med_alpha',
      },
    };

    // 2. Update the Database
    print('Updating staff roster at: venues/mockVenue123/config/staffRoster...');
    await FirebaseDatabase.instance
        .ref('venues/mockVenue123/config/staffRoster')
        .update(roster);
    
    print('✅ SUCCESS! Your profile is now live in the database.');
    print('You can now use the Dashboard with full Admin permissions.');
  } catch (e) {
    print('❌ FAILED: $e');
    if (e.toString().contains('permission-denied')) {
      print('\nNOTE: If you still get Permission Denied, double check that nah123@gmail.com is correct.');
    }
  }

  print('------------------------------------');
}
