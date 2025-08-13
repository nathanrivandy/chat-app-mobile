// controllers/auth_controller.dart
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import 'package:flutter/material.dart';

class AuthController extends GetxController {
  final ApiService _apiService = ApiService();
  final GetStorage _storage = GetStorage();
  
  final RxBool isLoggedIn = false.obs;
  final RxBool isLoading = false.obs;
  final Rx<User?> currentUser = Rx<User?>(null);

  @override
  void onInit() {
    super.onInit();
    checkLoginStatus();
  }

  void checkLoginStatus() {
    String? token = _storage.read('token');
    if (token != null && token.isNotEmpty) {
      isLoggedIn.value = true;
      loadUserProfile();
    }
  }

  Future<void> login(String username, List<double> faceEmbedding) async {
    try {
      isLoading.value = true;
      
      final response = await _apiService.login(username, faceEmbedding);
      
      if (response['token'] != null) {
        _storage.write('token', response['token']);
        currentUser.value = User.fromJson(response['user']);
        isLoggedIn.value = true;
        
        Get.snackbar('Success', 'Login successful',
            backgroundColor: Get.theme.primaryColor,
            colorText: Get.theme.colorScheme.onPrimary);
      }
    } catch (e) {
      Get.snackbar('Error', 'Login failed: ${e.toString()}',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> register({
    required String username,
    required String fullName,
    String? phone,
    String? email,
    required List<double> faceEmbedding,
    String? profilePhotoPath,
    String? statusMessage,
  }) async {
    try {
      isLoading.value = true;
      
      await _apiService.register(
        username: username,
        fullName: fullName,
        phone: phone,
        email: email,
        faceEmbedding: faceEmbedding,
        profilePhotoPath: profilePhotoPath,
        statusMessage: statusMessage,
      );
      
      Get.snackbar('Success', 'Registration successful! Please login.',
          backgroundColor: Get.theme.primaryColor,
          colorText: Get.theme.colorScheme.onPrimary);
      
    } catch (e) {
      Get.snackbar('Error', 'Registration failed: ${e.toString()}',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadUserProfile() async {
    try {
      final userData = await _apiService.getUserProfile();
      currentUser.value = User.fromJson(userData['user']);
    } catch (e) {
      print('Failed to load user profile: $e');
      logout();
    }
  }

  void logout() {
    _storage.remove('token');
    currentUser.value = null;
    isLoggedIn.value = false;
  }
}