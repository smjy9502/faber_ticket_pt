import 'dart:html' as html;

import 'package:faber_ticket_pt/screens/main_screen.dart';
import 'package:faber_ticket_pt/services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'error_screen.dart';

class PhotoScreen extends StatefulWidget {
  @override
  _PhotoScreenState createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final Uuid _uuid = Uuid();
  List<String> imageUrls = List.filled(8, '');
  ImageProvider? _photoBackground;
  List<bool> isUploading = List.filled(8, false);

  @override
  void initState() {
    super.initState();
    _loadBackgroundImage().then((_) {
      html.window.history.replaceState({}, '', '/photo');
    });
    loadImages();
  }

  Future<void> _loadBackgroundImage() async {
    try {
      final storedParams = html.window.sessionStorage['params'];
      final urlParams = storedParams != null
          ? Uri(query: storedParams).queryParameters
          : Uri.base.queryParameters;
      final photoBackground = urlParams['cp'];
      if (photoBackground == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => ErrorScreen()),
          );
        });
        return;
      }
      final ref = FirebaseStorage.instance.ref("images/$photoBackground");
      final url = await ref.getDownloadURL();
      setState(() => _photoBackground = NetworkImage(url));
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ErrorScreen()),
        );
      });
    }
  }

  Future<void> loadImages() async {
    try {
      final data = await _firebaseService.getCustomData();
      if (data['imageUrls'] != null) {
        List<String> loadedUrls = List.from(data['imageUrls']);
        while (loadedUrls.length > 8) {
          loadedUrls.removeLast();
        }
        while (loadedUrls.length < 8) {
          loadedUrls.add('');
        }
        setState(() => imageUrls = loadedUrls);
      }
    } catch (e) {
      print("이미지 불러오기 실패: $e");
    }
  }

  Future<void> uploadImageToIndex(int index) async {
    try {
      final input = html.FileUploadInputElement()
        ..accept = "image/*";
      input.click();
      await input.onChange.first;
      if (input.files!.isNotEmpty) {
        setState(() => isUploading[index] = true);
        final file = input.files!.first;
        final userId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
        final path = 'users/$userId/photos/${_uuid.v4()}_${file.name}';
        final downloadUrl = await _firebaseService.uploadImage(
            file, path: path);
        setState(() {
          imageUrls[index] = downloadUrl;
          isUploading[index] = false;
        });
        await saveImages();
      }
    } catch (e) {
      print("이미지 업로드 실패: $e");
      setState(() => isUploading[index] = false);
    }
  }

  // 추가: 이미지 삭제 함수
  Future<void> deleteImageAtIndex(int index) async {
    try {
      setState(() => isUploading[index] = true);
      // Storage에서 파일 삭제 (옵션)
      final url = imageUrls[index];
      if (url.isNotEmpty) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(url);
          await ref.delete();
        } catch (e) {
          // 만약 삭제 실패해도 무시 (이미 삭제된 경우 등)
        }
      }
      setState(() {
        imageUrls[index] = '';
        isUploading[index] = false;
      });
      await saveImages();
    } catch (e) {
      print("이미지 삭제 실패: $e");
      setState(() => isUploading[index] = false);
    }
  }

  Future<void> saveImages() async {
    try {
      await _firebaseService.saveCustomData({'imageUrls': imageUrls});
    } catch (e) {
      print("데이터 저장 실패: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    final double screenHeight = MediaQuery
        .of(context)
        .size
        .height;
    final padding = MediaQuery
        .of(context)
        .padding;

    // 좌우 여백
    final double horizontalPadding = screenWidth * 0.04;
    // 두 그리드 간 간격(좁게)
    final double gridGap = 8;

    // 그리드 가로 크기 (좌우 여백, 그리드 간격 포함)
    final double gridWidth = (screenWidth - 2 * horizontalPadding - gridGap) /
        2;

    // 그리드 내 칸 간격
    final double cellGap = screenHeight * 0.009; // 조금 더 줄임

    // 칸의 세로:가로 비율(직사각형, 더 낮게)
    final double cellAspect = 0.78; // 1:0.78, 세로를 더 줄임

    // 각 칸의 높이
    final double cellHeight = gridWidth * cellAspect;

    // 그리드 전체 높이 (4칸+3간격)
    final double gridHeight = cellHeight * 4 + cellGap * 3;

    // 두 그리드의 top 위치
    final double leftGridTop = padding.top + screenHeight * 0.07;
    final double rightGridTop = padding.top + screenHeight * 0.13; // 더 위로

    return Scaffold(
      body: Stack(
        children: [
          // 배경 이미지
          if (_photoBackground != null)
            Positioned.fill(
              child: Image(
                image: _photoBackground!,
                fit: BoxFit.fill,
                // alignment: Alignment.topCenter,
              ),
            ),
          // Back 버튼 (top=0)
          Positioned(
            top: 0,
            left: 12,
            child: SafeArea(
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () =>
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => MainScreen()),
                    ),
              ),
            ),
          ),
          // 그리드들
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Stack(
                children: [
                  // 좌측 그리드 (위)
                  Positioned(
                    top: leftGridTop,
                    left: 0,
                    child: _buildPhotoStrip(
                      startIndex: 0,
                      gridWidth: gridWidth,
                      cellHeight: cellHeight,
                      cellGap: cellGap,
                    ),
                  ),
                  // 우측 그리드 (더 위로)
                  Positioned(
                    top: rightGridTop,
                    right: 0,
                    child: _buildPhotoStrip(
                      startIndex: 4,
                      gridWidth: gridWidth,
                      cellHeight: cellHeight,
                      cellGap: cellGap,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoStrip({
    required int startIndex,
    required double gridWidth,
    required double cellHeight,
    required double cellGap,
  }) {
    Color gridCellBackground = Colors.white; // 칸 색깔 제어

    return SizedBox(
      width: gridWidth,
      height: cellHeight * 4 + cellGap * 3,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: List.generate(4, (i) {
          int idx = startIndex + i;
          return Padding(
            padding: EdgeInsets.only(bottom: i < 3 ? cellGap : 0),
            child: SizedBox(
              width: gridWidth,
              height: cellHeight,
              child: GestureDetector(
                onTap: () async {
                  if (imageUrls[idx].isEmpty) {
                    await uploadImageToIndex(idx);
                  } else {
                    showDialog(
                      context: context,
                      barrierColor: Colors.black87,
                      builder: (_) =>
                          Dialog(
                            backgroundColor: Colors.transparent,
                            insetPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 32),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.93),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.only(
                                      bottom: 80, top: 16, left: 16, right: 16),
                                  child: Image.network(
                                    imageUrls[idx],
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 70,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.85),
                                      borderRadius: BorderRadius.vertical(
                                          bottom: Radius.circular(12)),
                                    ),
                                    child: Center(
                                      child: IconButton(
                                        icon: Icon(
                                            Icons.delete, color: Colors.white,
                                            size: 40),
                                        onPressed: () async {
                                          Navigator.of(context).pop();
                                          await deleteImageAtIndex(idx);
                                        },
                                        tooltip: "사진 삭제",
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                    );
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: gridCellBackground,
                    border: Border.all(color: Colors.black, width: 2), // 테두리 색 제어
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [
                      imageUrls[idx].isNotEmpty
                          ? Image.network(
                        imageUrls[idx],
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      )
                          : SizedBox.shrink(),
                      if (isUploading[idx])
                        Container(
                          color: Colors.black.withOpacity(0.5),
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                              strokeWidth: 3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}