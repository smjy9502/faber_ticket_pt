import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:faber_ticket_pt/screens/photo_screen.dart';
import 'package:flutter/material.dart';
import 'error_screen.dart';
import 'dart:html' as html; // For url cleansing



class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  ImageProvider? _mainBackground;
  int _currentIndex = 0;

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

      // Firestore에서 backgrounds/main 문서의 imageUrl 필드 사용
      final doc = await FirebaseFirestore.instance.collection('backgrounds').doc(mainBackground).get();
      final url = doc.data()?['imageUrl'];
      if (url == null) throw Exception('No background URL');
      setState(() => _mainBackground = NetworkImage(url));
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ErrorScreen()),
        );
      });
    }
  }




  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
    if (index == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PhotoScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double verticalSpacing = MediaQuery.of(context).size.height * 0.03;

    return Scaffold(
      body: _mainBackground == null
          ? Center(child: CircularProgressIndicator())
          : Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: _mainBackground!,
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            // 아래쪽 gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(0.9),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // ⬅ 왼쪽 정렬
                children: [
                  Spacer(),
                  // 글씨 왼쪽에 딱 붙임
                  Padding(
                    padding: EdgeInsets.only(left: screenWidth * 0.09),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "You are my",
                          style: TextStyle(
                            fontSize: screenWidth * 0.075,
                            fontWeight: FontWeight.w300,
                            color: Colors.black.withOpacity(0.7),
                            height: 1.4,
                          ),
                        ),
                        Text(
                          "faberite",
                          style: TextStyle(
                            fontSize: screenWidth * 0.17,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            height: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.1),
                                offset: Offset(1, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: verticalSpacing * 2.0),

                  // 버튼
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildMinimalIconButton(Icons.home, 0),
                        _buildMinimalIconButton(Icons.camera_alt, 1),
                      ],
                    ),
                  ),

                  SizedBox(height: verticalSpacing * 1.5),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildMinimalIconButton(IconData icon, int index) {
    final bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onNavTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected
                ? Colors.lightBlue
                : Colors.black.withOpacity(0.3),
            size: MediaQuery.of(context).size.width * 0.075,
          ),
          SizedBox(height: 4),
          if (isSelected)
            Container(
              width: 14,
              height: 2,
              decoration: BoxDecoration(
                color: Colors.lightBlue,
                borderRadius: BorderRadius.circular(1),
              ),
            )
        ],
      ),
    );
  }
}
