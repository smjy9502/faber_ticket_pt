import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:html' as html;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_storage.FirebaseStorage _storage = firebase_storage.FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> getAuthenticatedUID() async {
    final user = _auth.currentUser;
    if (user == null) {
      try {
        final userCredential = await _auth.signInAnonymously();
        print("Anonymous user signed in: ${userCredential.user?.uid}");
        return userCredential.user?.uid;
      } catch (e) {
        print('Error signing in anonymously: $e');
        return null;
      }
    }
    print("Current user UID: ${user.uid}");
    return user.uid;
  }



  Future<String> getOrCreateUID() async {
    final uid = await getAuthenticatedUID();
    if (uid != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_uid', uid);
      await _firestore.collection('users').doc(uid).set({'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      return uid;
    } else {
      throw Exception('Failed to get or create UID');
    }
  }

  Future<bool> verifyAccess(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      print("User document exists: ${userDoc.exists}");
      if (userDoc.exists) {
        final prefs = await SharedPreferences.getInstance();
        bool isFromNFC = prefs.getBool('isFromNFC') ?? false;
        print("Is from NFC: $isFromNFC");
        return isFromNFC;
      }
      return false;
    } catch (e) {
      print('Error verifying access: $e');
      return false;
    }
  }





  Future<String> uploadImage(html.File file, {required String path}) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
      final storageRef = _storage.ref().child(path);
      final uploadTask = storageRef.putBlob(file);
      await uploadTask;
      return await storageRef.getDownloadURL();
    } catch (e) {
      print("이미지 업로드 오류: $e");
      rethrow;
    }
  }

  Future<void> saveCustomData(Map<String, dynamic> data) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .doc('current')
          .set(data, SetOptions(merge: true));
    } catch (e) {
      print("데이터 저장 오류: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCustomData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .doc('current')
          .get();
      return doc.data() ?? {};
    } catch (e) {
      print("데이터 불러오기 오류: $e");
      rethrow;
    }
  }

  Future<String> uploadImageBytes(Uint8List data, {required String path, String? contentType}) async {
    final ref = FirebaseStorage.instance.ref(path);
    final uploadTask = ref.putData(data, SettableMetadata(contentType: contentType));
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }
}

