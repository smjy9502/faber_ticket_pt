import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:faber_ticket_pt/screens/main_screen.dart';
import 'package:faber_ticket_pt/screens/error_screen.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:html' as html;

// main.dart 수정
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // FirebaseOptions 명시적 전달
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAuth.instance.signInAnonymously();
    runApp(MyApp());
  } catch (e) {
    print("Firebase 초기화 실패: $e");
    runApp(MaterialApp(home: ErrorScreen()));
  }
}



class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Faber Ticket',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'CustomFont',
      ),
      home: FutureBuilder(
        future: checkInitialAccess(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CircularProgressIndicator();
          } else if (snapshot.data == true) {
            return MainScreen();
          } else {
            return ErrorScreen();
          }
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

Future<bool> checkInitialAccess() async {
  if (foundation.kIsWeb) {
    final userAgent = html.window.navigator.userAgent?.toLowerCase() ?? '';
    print('User Agent: $userAgent');
    final isMobile = userAgent.contains('mobile') ||
        userAgent.contains('android') ||
        userAgent.contains('iphone')
        // || userAgent.contains('macintosh')
    ;
    return isMobile;
  }
  return true;
}

