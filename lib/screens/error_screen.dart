import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({Key? key}) : super(key: key);

  void _launchUrl(String url, BuildContext context, String message) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: Duration(seconds: 1)),
    );
    await Future.delayed(const Duration(seconds: 1));
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _menuItem(String text, IconData icon, VoidCallback onTap, double fontSize) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 18.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.3,
                color: Colors.white,
              ),
            ),
            Icon(icon, size: 18, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomMenu(BuildContext context, double screenWidth) {
    double menuFontSize = screenWidth * 0.036;

    return Column(
      children: [
        const Divider(height: 1, thickness: 0.3, color: Colors.white24),
        _menuItem("FABER STORE", Icons.store, () {
          _launchUrl("https://smartstore.naver.com/faber_ite", context, "스마트스토어로 이동합니다.");
        }, menuFontSize),
        const Divider(height: 1, thickness: 0.3, color: Colors.white24),
        _menuItem("CUSTOM GUIDE", Icons.design_services, () {
          _launchUrl("https://your-custom-guide-link.com", context, "제작 가이드 페이지로 이동합니다.");
        }, menuFontSize),
        const Divider(height: 1, thickness: 0.3, color: Colors.white24),
        _menuItem("INSTAGRAM", FontAwesomeIcons.instagram, () {
          _launchUrl("https://www.instagram.com/faber.ite", context, "@faber.ite으로 이동합니다.");
        }, menuFontSize),
        const Divider(height: 1, thickness: 0.3, color: Colors.white24),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: screenHeight * 0.08),

              // 🔒 자물쇠 이미지
              Center(
                child: SizedBox(
                  width: screenWidth * 0.38,
                  child: Image.asset(
                    'assets/images/locker.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // 안내 문구
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  'faberite 컨텐츠에\n다시 접속하려면\n키링을 태그해주세요!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.055,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 태그 위치 안내 박스
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "• iOS는 휴대폰 후면 상단 또는 카메라 렌즈 우측에 태그",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: screenWidth * 0.032,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "• 안드로이드는 휴대폰 중앙 또는 하단에 태그",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: screenWidth * 0.032,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: screenHeight * 0.12),

              _buildBottomMenu(context, screenWidth),
            ],
          ),
        ),
      ),
    );
  }
}
