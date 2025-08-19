// controllers/auth_controller.dart
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import 'package:flutter/material.dart';
import 'dart:io';

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
    try {
      String? token = _storage.read('token');
      print('DEBUG: Checking login status, token exists: ${token != null}');
      
      if (token != null && token.isNotEmpty) {
        isLoggedIn.value = true;
        loadUserProfile();
      }
    } catch (e) {
      print('DEBUG: Error checking login status: $e');
    }
  }

  Future<void> login(String username, List<double> faceEmbedding) async {
    try {
      print('DEBUG: Starting login for username: $username');
      print('DEBUG: Face embedding length: ${faceEmbedding.length}');
      
      isLoading.value = true;
      
      final response = await _apiService.login(username, faceEmbedding);
      print('DEBUG: Login API response received: ${response.keys}');
      
      if (response['token'] != null) {
        await _storage.write('token', response['token']);
        print('DEBUG: Token saved to storage');
        
        if (response['user'] != null) {
          currentUser.value = User.fromJson(response['user']);
          print('DEBUG: User profile loaded: ${currentUser.value?.username}');
        }
        
        isLoggedIn.value = true;
        
        Get.snackbar(
          'Success', 
          'Login successful! Welcome ${response['user']?['full_name'] ?? username}',
          backgroundColor: Get.theme.primaryColor,
          colorText: Get.theme.colorScheme.onPrimary,
          duration: const Duration(seconds: 3),
        );
        
        // Navigate to home screen
        Get.offAllNamed('/home');
        
      } else {
        throw Exception('No token received from server');
      }
      
    } catch (e) {
      print('DEBUG: Login error: $e');
      print('DEBUG: Error type: ${e.runtimeType}');
      
      String errorMessage = _getErrorMessage(e);
      
      Get.snackbar(
        'Login Failed', 
        errorMessage,
        backgroundColor: Colors.red, 
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
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
      print('DEBUG: Starting registration...');
      print('DEBUG: Username: $username');
      print('DEBUG: Full name: $fullName');
      print('DEBUG: Phone: $phone');
      print('DEBUG: Email: $email');
      print('DEBUG: Face embedding length: ${faceEmbedding.length}');
      print('DEBUG: Profile photo path: $profilePhotoPath');
      print('DEBUG: Status message: $statusMessage');
      
      // Validate inputs
      if (username.trim().isEmpty) {
        throw Exception('Username cannot be empty');
      }
      
      if (fullName.trim().isEmpty) {
        throw Exception('Full name cannot be empty');
      }
      
      if (faceEmbedding.isEmpty) {
        throw Exception('Face embedding is required');
      }
      
      // Validate profile photo if provided
      if (profilePhotoPath != null && profilePhotoPath.isNotEmpty) {
        final photoFile = File(profilePhotoPath);
        if (!await photoFile.exists()) {
          print('DEBUG: Profile photo file does not exist, removing path');
          profilePhotoPath = null;
        } else {
          print('DEBUG: Profile photo file size: ${await photoFile.length()} bytes');
        }
      }
      
      isLoading.value = true;
      
      final response = await _apiService.register(
        username: username.trim(),
        fullName: fullName.trim(),
        phone: phone?.trim().isEmpty == true ? null : phone?.trim(),
        email: email?.trim().isEmpty == true ? null : email?.trim(),
        faceEmbedding: faceEmbedding,
        profilePhotoPath: profilePhotoPath,
        statusMessage: statusMessage?.trim().isEmpty == true ? null : statusMessage?.trim(),
      );
      
      print('DEBUG: Registration API response: ${response.keys}');
      
      Get.snackbar(
        'Success', 
        'Registration successful! Please login to continue.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      
    } catch (e) {
      print('DEBUG: Registration error: $e');
      print('DEBUG: Error type: ${e.runtimeType}');
      
      String errorMessage = _getErrorMessage(e);
      
      Get.snackbar(
        'Registration Failed',
        errorMessage,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
      
      rethrow; // Re-throw to allow UI to handle if needed
      
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadUserProfile() async {
    try {
      print('DEBUG: Loading user profile...');
      
      final userData = await _apiService.getUserProfile();
      print('DEBUG: User profile loaded: ${userData.keys}');
      
      if (userData['user'] != null) {
        currentUser.value = User.fromJson(userData['user']);
        print('DEBUG: Current user set: ${currentUser.value?.username}');
      } else {
        throw Exception('No user data in response');
      }
      
    } catch (e) {
      print('DEBUG: Failed to load user profile: $e');
      
      // If token is invalid, logout
      if (e.toString().contains('401') || 
          e.toString().contains('403') || 
          e.toString().contains('Invalid token')) {
        print('DEBUG: Token appears invalid, logging out');
        logout();
      }
    }
  }

  void logout() {
    try {
      print('DEBUG: Logging out user');
      
      _storage.remove('token');
      currentUser.value = null;
      isLoggedIn.value = false;
      
      Get.snackbar(
        'Logged Out', 
        'You have been logged out successfully',
        backgroundColor: Get.theme.primaryColor,
        colorText: Get.theme.colorScheme.onPrimary,
        duration: const Duration(seconds: 2),
      );
      
    } catch (e) {
      print('DEBUG: Error during logout: $e');
    }
  }

  // Helper method to format error messages
  String _getErrorMessage(dynamic error) {
    String errorString = error.toString().toLowerCase();
    
    // Network errors
    if (errorString.contains('timeout')) {
      return 'Connection timeout. Please check your internet connection and try again.';
    }
    
    if (errorString.contains('socket') || errorString.contains('network')) {
      return 'Network error. Please check your internet connection.';
    }
    
    if (errorString.contains('connection refused') || errorString.contains('connection failed')) {
      return 'Cannot connect to server. Please try again later.';
    }
    
    // Registration specific errors
    if (errorString.contains('username') && errorString.contains('exists')) {
      return 'Username already taken. Please choose a different username.';
    }
    
    if (errorString.contains('email') && errorString.contains('exists')) {
      return 'Email already registered. Please use a different email.';
    }
    
    if (errorString.contains('face') && errorString.contains('recognition')) {
      return 'Face recognition failed. Please try capturing your face again.';
    }
    
    if (errorString.contains('similarity')) {
      return 'Face recognition similarity too low. Please ensure good lighting and try again.';
    }
    
    // Login specific errors
    if (errorString.contains('invalid username')) {
      return 'Username not found. Please check your username or register first.';
    }
    
    if (errorString.contains('invalid') && errorString.contains('token')) {
      return 'Session expired. Please login again.';
    }
    
    // Server errors
    if (errorString.contains('500') || errorString.contains('internal server error')) {
      return 'Server error. Please try again later.';
    }
    
    if (errorString.contains('404') || errorString.contains('not found')) {
      return 'Service not found. Please contact support.';
    }
    
    if (errorString.contains('400') || errorString.contains('bad request')) {
      return 'Invalid request. Please check your input and try again.';
    }
    
    // Format exceptions
    if (errorString.contains('formatexception')) {
      return 'Invalid response from server. Please try again.';
    }
    
    // File errors
    if (errorString.contains('file') && errorString.contains('not found')) {
      return 'Selected file not found. Please try selecting the image again.';
    }
    
    // Generic error message
    if (error.toString().length > 100) {
      print(error.toString());
      return 'An error occurred. Please try again.';
    }
    
    return error.toString().replaceAll('Exception: ', '');
  }

  // Helper method to check if user is authenticated
  bool get isAuthenticated => isLoggedIn.value && currentUser.value != null;
  
  // Helper method to get current user ID
  int? get currentUserId => currentUser.value?.id;
  
  // Helper method to get current username
  String? get currentUsername => currentUser.value?.username;
  
  // Method to refresh user profile
  Future<void> refreshProfile() async {
    if (isAuthenticated) {
      await loadUserProfile();
    }
  }
  
  // Method to update profile locally (after successful API update)
  void updateLocalProfile(User updatedUser) {
    currentUser.value = updatedUser;
    print('DEBUG: Local profile updated for user: ${updatedUser.username}');
  }
}