import 'dart:html' as html;
import 'package:faber_ticket_pt/screens/main_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:faber_ticket_pt/services/firebase_service.dart';
import 'package:faber_ticket_pt/utils/constants.dart';
import 'package:uuid/uuid.dart';

class PhotoScreen extends StatefulWidget {
  @override
  _PhotoScreenState createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final Uuid _uuid = Uuid();
  List<String> imageUrls = List.filled(9, '');
  ImageProvider? _photoBackground;

  @override
  void initState() {
    super.initState();
    _loadBackgroundImage();
    loadImages();
  }

  Future<void> _loadBackgroundImage() async {
    try {
      final urlParams = Uri.base.queryParameters;
      final photoBackground = urlParams['cp'];

      if (photoBackground != null) {
        final ref = FirebaseStorage.instance.ref("images/$photoBackground");
        final url = await ref.getDownloadURL();
        setState(() => _photoBackground = NetworkImage(url));
      } else {
        throw Exception('Custom Image 파라미터 없음');
      }
    } catch (e) {
      print("배경 이미지 로드 실패: $e");
      setState(() => _photoBackground = AssetImage(Constants.photoBackgroundImage));
    }
  }

  Future<void> loadImages() async {
    try {
      final data = await _firebaseService.getCustomData();
      if (data['imageUrls'] != null) {
        setState(() => imageUrls = List.from(data['imageUrls']));
      }
    } catch (e) {
      print("이미지 불러오기 실패: $e");
    }
  }

  Future<void> uploadImages() async {
    try {
      final input = html.FileUploadInputElement()..accept = "image/*";
      input.multiple = true;
      input.click();

      await input.onChange.first;
      if (input.files!.isNotEmpty) {
        for (var i = 0; i < input.files!.length && i < imageUrls.length; i++) {
          final file = input.files![i];
          final userId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
          final path = 'users/$userId/photos/${_uuid.v4()}_${file.name}';

          final downloadUrl = await _firebaseService.uploadImage(file, path: path);
          setState(() => imageUrls[i] = downloadUrl);
        }
        await saveImages();
      }
    } catch (e) {
      print("이미지 업로드 실패: $e");
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
    return Scaffold(
      body: Stack(
        children: [
          if (_photoBackground != null)
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: _photoBackground!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Positioned(
            top: 15,
            left: 20,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => MainScreen()),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(child: SizedBox(height: 30)),
                Expanded(
                  flex: 3,
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: imageUrls.length,
                    itemBuilder: (context, index) => GestureDetector(
                      onTap: () => imageUrls[index].isNotEmpty
                          ? showDialog(
                        context: context,
                        builder: (_) => Dialog(child: Image.network(imageUrls[index])),
                      )
                          : null,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        child: imageUrls[index].isNotEmpty
                            ? Image.network(imageUrls[index], fit: BoxFit.cover)
                            : Icon(Icons.add_photo_alternate),
                      ),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: uploadImages,
                  child: Text('Upload'),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
