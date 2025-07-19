import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'dart:ui';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import 'package:faber_ticket_pt/services/firebase_service.dart';
import 'package:faber_ticket_pt/screens/main_screen.dart';


class Member {
  String name;
  String? imageUrl;
  Member({required this.name, this.imageUrl});
  Map<String, dynamic> toMap() => {'name': name, 'imageUrl': imageUrl};
  static Member fromMap(Map<String, dynamic> map) =>
      Member(name: map['name'] ?? '', imageUrl: map['imageUrl']);
}

class PhotoScreen extends StatefulWidget {
  @override
  _PhotoScreenState createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final Uuid _uuid = Uuid();

  final TextEditingController _faberiteController = TextEditingController();
  Timer? _debounceTimer;
  bool _isSaving = false;

  List<Member> members = [];
  List<String?> gridImageUrls = List.generate(9, (_) => null);

  List<bool> isGridUploading = List.filled(9, false);
  List<bool> isMemberUploading = [];

  int _currentIndex = 1;

  final ScrollController _memberScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    html.window.history.replaceState({}, '', '/photo');
    _loadSavedData();
    _faberiteController.addListener(_onFaberiteChanged);
  }

  @override
  void dispose() {
    _faberiteController.removeListener(_onFaberiteChanged);
    _faberiteController.dispose();
    _debounceTimer?.cancel();
    _memberScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    try {
      final data = await _firebaseService.getCustomData();
      if (data['faberite'] != null) {
        _faberiteController.text = data['faberite'];
      }
      if (data['members'] != null && data['members'] is List) {
        members = (data['members'] as List)
            .map((m) => Member.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        if (members.length > 20) members = members.sublist(0, 20);
        isMemberUploading = List.filled(members.length, false);
      }
      if (data['gridImageUrls'] != null && data['gridImageUrls'] is List) {
        List urls = data['gridImageUrls'];
        gridImageUrls = List<String?>.from(urls);
        while (gridImageUrls.length < 9) {
          gridImageUrls.add(null);
        }
        isGridUploading = List.filled(9, false);
      }
      setState(() {});
    } catch (e) {
      print("데이터 불러오기 실패: $e");
    }
  }

  void _onFaberiteChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () {
      _saveAllData();
    });
  }

  Future<void> _saveAllData() async {
    try {
      _isSaving = true;
      await _firebaseService.saveCustomData({
        'faberite': _faberiteController.text,
        'members': members.map((m) => m.toMap()).toList(),
        'gridImageUrls': gridImageUrls,
      });
    } catch (e) {
      print("저장 오류: $e");
    } finally {
      _isSaving = false;
    }
  }

  Future<String?> _uploadImageToStorage(Uint8List bytes) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
      final path = 'users/$userId/photos/${_uuid.v4()}.jpg';
      final img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('이미지 디코딩 실패');
      final img.Image resized = img.copyResize(decoded, width: 600);
      final Uint8List compressed = Uint8List.fromList(img.encodeJpg(resized, quality: 55));
      final downloadUrl = await _firebaseService.uploadImageBytes(
        compressed,
        path: path,
        contentType: 'image/jpeg',
      );
      return downloadUrl;
    } catch (e) {
      print("Storage 업로드 실패: $e");
      return null;
    }
  }

  Future<void> _pickImageForMember(int index) async {
    final input = html.FileUploadInputElement()..accept = "image/*";
    input.click();
    await input.onChange.first;
    if (input.files!.isNotEmpty) {
      setState(() => isMemberUploading[index] = true);
      final file = input.files!.first;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;
      final Uint8List bytes = reader.result as Uint8List;
      final url = await _uploadImageToStorage(bytes);
      if (url != null) {
        setState(() {
          members[index].imageUrl = url;
          isMemberUploading[index] = false;
        });
        _saveAllData();
      } else {
        setState(() => isMemberUploading[index] = false);
      }
    }
  }

  Future<void> _pickImageForGrid(int index) async {
    final input = html.FileUploadInputElement()..accept = "image/*";
    input.click();
    await input.onChange.first;
    if (input.files!.isNotEmpty) {
      setState(() => isGridUploading[index] = true);
      final file = input.files!.first;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;
      final Uint8List bytes = reader.result as Uint8List;
      final url = await _uploadImageToStorage(bytes);
      if (url != null) {
        setState(() {
          gridImageUrls[index] = url;
          isGridUploading[index] = false;
        });
        _saveAllData();
      } else {
        setState(() => isGridUploading[index] = false);
      }
    }
  }

  Future<void> _deleteGridImage(int index) async {
    setState(() => isGridUploading[index] = true);
    final url = gridImageUrls[index];
    if (url != null && url.isNotEmpty) {
      try {
        final ref = FirebaseStorage.instance.refFromURL(url);
        await ref.delete();
      } catch (e) {}
    }
    setState(() {
      gridImageUrls[index] = null;
      isGridUploading[index] = false;
    });
    _saveAllData();
  }

  Future<void> _deleteMember(int index) async {
    if (members[index].imageUrl != null && members[index].imageUrl!.isNotEmpty) {
      try {
        final ref = FirebaseStorage.instance.refFromURL(members[index].imageUrl!);
        await ref.delete();
      } catch (e) {}
    }
    setState(() {
      members.removeAt(index);
      isMemberUploading = List.filled(members.length, false);
    });
    _saveAllData();
  }

  Future<void> _addMember() async {
    if (members.length >= 20) return;
    String name = "";
    String? imageUrl;
    String buttonText = "사진 선택";
    bool isUploading = false;

    await showDialog(
      context: context,
      barrierDismissible: !isUploading,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text("내용 추가"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    cursorColor: Color(0xFF93BBDF),
                    decoration: InputDecoration(
                      hintText: "입력",
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF93BBDF)),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF93BBDF)),
                      ),
                    ),
                    onChanged: (value) {
                      name = value;
                    },
                  ),
                  SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonText == "선택 완료"
                          ? Colors.green[200]
                          : Color(0xFF93BBDF),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isUploading
                        ? null
                        : () async {
                      setStateDialog(() => isUploading = true);
                      final input = html.FileUploadInputElement()..accept = "image/*";
                      input.click();
                      await input.onChange.first;
                      if (input.files!.isNotEmpty) {
                        final file = input.files!.first;
                        final reader = html.FileReader();
                        reader.readAsArrayBuffer(file);
                        await reader.onLoad.first;
                        final Uint8List bytes = reader.result as Uint8List;
                        final url = await _uploadImageToStorage(bytes);
                        if (url != null) {
                          imageUrl = url;
                          buttonText = "선택 완료";
                        }
                      }
                      setStateDialog(() => isUploading = false);
                    },
                    child: isUploading
                        ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : Text(buttonText),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Color(0xFF93BBDF)),
                  onPressed: () {
                    setState(() {
                      members.add(Member(name: name, imageUrl: imageUrl));
                      isMemberUploading.add(false);
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_memberScrollController.hasClients) {
                        _memberScrollController.animateTo(
                          _memberScrollController.position.maxScrollExtent,
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    });
                    Navigator.pop(context);
                    _saveAllData();
                  },
                  child: Text("추가"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMemberImageDialog(int index) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 18),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onTap: () {},
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: members[index].imageUrl != null
                          ? Image.network(
                        members[index].imageUrl!,
                        fit: BoxFit.contain,
                        width: MediaQuery.of(context).size.width * 0.9,
                        height: MediaQuery.of(context).size.height * 0.6,
                      )
                          : Container(
                        width: 200,
                        height: 200,
                        color: Colors.grey[300],
                        child: Center(child: Text('No image')),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[100],
                          foregroundColor: Colors.red[800],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _deleteMember(index);
                        },
                        child: Text("삭제"),
                      ),
                      SizedBox(width: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF93BBDF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text("확인"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showGridImageDialog(int index) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final double maxImageHeight = MediaQuery.of(context).size.height * 0.65;
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: maxImageHeight,
                        minWidth: 200,
                        minHeight: 100,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: gridImageUrls[index] != null
                            ? Image.network(
                          gridImageUrls[index]!,
                          fit: BoxFit.contain,
                        )
                            : Container(
                          color: Colors.grey[300],
                          child: Center(child: Text('No image')),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF93BBDF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () async {
                          final input = html.FileUploadInputElement()..accept = "image/*";
                          input.click();
                          await input.onChange.first;
                          if (input.files!.isNotEmpty) {
                            final file = input.files!.first;
                            final reader = html.FileReader();
                            reader.readAsArrayBuffer(file);
                            await reader.onLoad.first;
                            final Uint8List bytes = reader.result as Uint8List;
                            final url = await _uploadImageToStorage(bytes);
                            if (url != null) {
                              setState(() {
                                gridImageUrls[index] = url;
                              });
                              setStateDialog(() {});
                              _saveAllData();
                            }
                          }
                        },
                        child: Text("수정"),
                      ),
                      SizedBox(width: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[100],
                          foregroundColor: Colors.red[800],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () async {
                          await _deleteGridImage(index);
                          Navigator.pop(context);
                        },
                        child: Text("삭제"),
                      ),
                      SizedBox(width: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Color(0xFF93BBDF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text("확인"),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _onNavTap(int index) async {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    Widget? nextScreen;
    if (index == 0) {
      nextScreen = MainScreen();
    }
    if (nextScreen != null) {
      final isLeft = index < 2;
      await Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => nextScreen!,
          transitionsBuilder: (_, animation, __, child) {
            final begin = Offset(isLeft ? -1.0 : 1.0, 0.0);
            final end = Offset.zero;
            final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.ease));
            return SlideTransition(position: animation.drive(tween), child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double verticalSpacing = MediaQuery.of(context).size.height * 0.03;
    final double gridSide = (MediaQuery.of(context).size.width - 48) / 3;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF93BBDF), Color(0xFF6FAEDC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: verticalSpacing * 1.5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text(
                        "My faberite : ",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _faberiteController,
                          cursorColor: Colors.white,
                          decoration: InputDecoration(
                            hintText: "Type here",
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 0),
                            border: InputBorder.none,
                          ),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textInputAction: TextInputAction.done,
                          onEditingComplete: () {
                            _faberiteController.selection = TextSelection.collapsed(offset: 0);
                            FocusScope.of(context).unfocus();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: verticalSpacing * 1.2),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  key: PageStorageKey('member_list'),
                  controller: _memberScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  itemCount: members.length + 1,
                  itemBuilder: (context, index) {
                    if (index == members.length) {
                      return GestureDetector(
                        onTap: members.length < 20 ? _addMember : null,
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.5),
                                    width: 1.5,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 32,
                                  backgroundColor: Colors.white.withOpacity(0.3),
                                  child: Icon(Icons.add, color: Colors.white, size: 28),
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                "추가",
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return GestureDetector(
                      onTap: () {
                        if (members[index].imageUrl == null) {
                          _pickImageForMember(index);
                        } else {
                          _showMemberImageDialog(index);
                        }
                      },
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 1.5,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 32,
                                backgroundColor: Colors.white.withOpacity(0.3),
                                backgroundImage: members[index].imageUrl != null
                                    ? NetworkImage(members[index].imageUrl!)
                                    : null,
                                child: members[index].imageUrl == null
                                    ? Icon(Icons.add_a_photo, color: Colors.white, size: 20)
                                    : null,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              members[index].name,
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Divider(
                  color: Colors.white.withOpacity(0.4),
                  thickness: 0.5,
                ),
              ),
              SizedBox(height: verticalSpacing * 0.3),
              Expanded(
                child: SingleChildScrollView(
                  key: PageStorageKey('grid_scroll'),
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(9, (i) {
                        return GestureDetector(
                          onTap: () {
                            if (gridImageUrls[i] != null) {
                              _showGridImageDialog(i);
                            } else {
                              _pickImageForGrid(i);
                            }
                          },
                          child: Container(
                            width: gridSide,
                            height: gridSide,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (gridImageUrls[i] != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      gridImageUrls[i]!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: gridImageUrls[i] == null
                                      ? Icon(Icons.add_a_photo, color: Colors.white, size: 30)
                                      : null,
                                ),
                                if (isGridUploading[i])
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
                        );
                      }),
                    ),
                  ),
                ),
              ),
              SizedBox(height: verticalSpacing * 1.2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMinimalIconButton(Icons.home, 0),
                  _buildMinimalIconButton(Icons.camera_alt, 1),
                ],
              ),
              SizedBox(height: verticalSpacing * 1.5),
            ],
          ),
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
            color: isSelected ? Colors.lightBlue : Colors.black.withOpacity(0.3),
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
            ),
        ],
      ),
    );
  }
}
