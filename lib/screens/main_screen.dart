import 'package:faber_ticket_pt/screens/photo_screen.dart';
import 'package:flutter/material.dart';
import 'package:faber_ticket_pt/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:faber_ticket_pt/widgets/custom_button.dart';
import 'package:faber_ticket_pt/services/firebase_service.dart';
import 'error_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:html' as html; // For url cleansing


class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  ImageProvider? _mainBackground;

  @override
  void initState() {
    super.initState();
    // 초기 매개변수를 sessionStorage에 저장
    _storeInitialParams();
    _loadMainBackground().then((_) {
      html.window.history.replaceState({}, '', '/');
    });
  }
  void _storeInitialParams() {
    final uri = Uri.parse(html.window.location.href);
    if (uri.queryParameters.isNotEmpty) {
      html.window.sessionStorage['params'] =
          uri.queryParameters.entries.map((e) => '${e.key}=${e.value}').join('&');
    }
  }



  // old version
  // Future<void> _loadMainBackground() async {
  //   try {
  //     // final urlParams = Uri.base.queryParameters;
  //     // final mainBackground = urlParams['cm'];
  //     final storedParams = html.window.sessionStorage['params'];
  //     final urlParams = storedParams != null
  //         ? Uri(query: storedParams).queryParameters
  //         : Uri.base.queryParameters;
  //
  //     final mainBackground = urlParams['cm'];
  //     //이 위까지 수정
  //
  //     if (mainBackground != null) {
  //       final ref = FirebaseStorage.instance.ref("images/$mainBackground");
  //       final url = await ref.getDownloadURL();
  //       print("이미지 URL: $url"); // 성공 로그
  //       setState(() => _mainBackground = NetworkImage(url));
  //     } else {
  //       throw Exception('Custom Image 파라미터 없음');
  //     }
  //   } catch (e) {
  //     print("이미지 로드 실패: $e"); // 실패 로그
  //     setState(() => _mainBackground = AssetImage(Constants.ticketFrontImage));
  //   }
  // } //

  Future<void> _loadMainBackground() async {
    try {
      final storedParams = html.window.sessionStorage['params'];
      final urlParams = storedParams != null
          ? Uri(query: storedParams).queryParameters
          : Uri.base.queryParameters;

      final mainBackground = urlParams['cm'];

      // 1. 매개변수 누락 시 에러 화면으로 이동
      if (mainBackground == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => ErrorScreen()),
          );
        });
        return;
      }

      // 2. 정상 이미지 로드
      final ref = FirebaseStorage.instance.ref("images/$mainBackground");
      final url = await ref.getDownloadURL();
      setState(() => _mainBackground = NetworkImage(url));

    } catch (e) {
      // 3. 예외 발생 시에도 에러 화면 이동
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ErrorScreen()),
        );
      });
    }
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Scaffold 배경 투명화.
      body: _mainBackground == null
          ? Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          // 배경 이미지 (photo_screen.dart와 동일)
          Positioned.fill(
            child: Image(
              image: _mainBackground!,
              fit: BoxFit.fill, // 또는 BoxFit.fill, BoxFit.contain 등 테스트 가능
              // alignment: Alignment.topCenter, // photo_screen.dart와 맞추려면 topCenter
            ),
          ),
          // 나머지 UI
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNavigationButton('📷', PhotoScreen()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButton(String text, Widget screen) {
    return ElevatedButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => screen),
      ),
      style: ElevatedButton.styleFrom(
        minimumSize: Size(120, 50),
        padding: EdgeInsets.symmetric(horizontal: 25, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        elevation: 8,
        shadowColor: Colors.blue.withOpacity(0.3),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ).copyWith(
        overlayColor: MaterialStateProperty.resolveWith<Color>(
              (states) => Colors.blue.withOpacity(0.1),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: LinearGradient(
            colors: [Colors.blueAccent, Colors.blueGrey],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
