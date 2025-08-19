import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../controllers/auth_controller.dart';
import '../services/face_recognition_service.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _statusController = TextEditingController();

  final AuthController _authController = Get.find<AuthController>();
  final FaceRecognitionService _faceService = FaceRecognitionService();
  final ImagePicker _imagePicker = ImagePicker();

  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _scanLineController;

  // Animations
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanLineAnimation;

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraReady = false;
  bool _showCamera = false;
  File? _profilePhoto;
  List<double>? _faceEmbedding;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _scanLineController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _scanLineAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scanLineController,
      curve: Curves.linear,
    ));
  }

  Future<void> _initializeCamera() async {
    if (_cameras != null && _cameraController != null) {
      return; // Camera already initialized
    }

    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        // Pilih kamera depan secara robust
        final CameraDescription cam = _cameras!.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras!.first,
        );

        _cameraController = CameraController(
          cam,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        await _cameraController!.setFlashMode(FlashMode.off);

        if (mounted) {
          setState(() => _isCameraReady = true);
        }
      }
    } catch (e) {
      Get.snackbar('Camera error', e.toString());
      setState(() {
        _showCamera = false;
        _isCameraReady = false;
      });
    }
  }

  Future<void> _toggleCamera() async {
    if (_showCamera) {
      // Hide camera
      setState(() {
        _showCamera = false;
        _isCameraReady = false;
      });
      await _cameraController?.dispose();
      _cameraController = null;
      _pulseController.stop();
      _scanLineController.stop();
    } else {
      // Show camera
      setState(() {
        _showCamera = true;
        _isCameraReady = false;
      });
      _pulseController.repeat();
      _scanLineController.repeat();
      await _initializeCamera();
    }
  }

  Future<void> _captureFace() async {
    if (!_showCamera) {
      Get.snackbar('Error', 'Please open camera first');
      return;
    }
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      Get.snackbar('Error', 'Camera not ready');
      return;
    }

    try {
      // beri sedikit jeda agar exposure stabil
      await Future.delayed(const Duration(milliseconds: 250));

      final image = await _cameraController!.takePicture();
      final embedding = await _faceService.extractFaceEmbedding(
        image.path,
        mirror: true, // untuk konsistensi dengan login
      );

      if (embedding != null) {
        setState(() {
          _faceEmbedding = embedding;
        });
        Get.snackbar(
          'Success', 
          'Face captured successfully!',
          backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
          colorText: Theme.of(context).colorScheme.onTertiaryContainer,
        );
      } else {
        Get.snackbar(
          'Error', 
          'No face detected. Please try again.',
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          colorText: Theme.of(context).colorScheme.onErrorContainer,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error', 
        'Failed to capture face: ${e.toString()}',
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        colorText: Theme.of(context).colorScheme.onErrorContainer,
      );
    }
  }

  Future<void> _pickProfilePhoto() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _profilePhoto = File(image.path);
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_faceEmbedding == null) {
      Get.snackbar(
        'Error', 
        'Please capture your face first',
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        colorText: Theme.of(context).colorScheme.onErrorContainer,
      );
      return;
    }

    await _authController.register(
      username: _usernameController.text,
      fullName: _fullNameController.text,
      phone: _phoneController.text.isEmpty ? null : _phoneController.text,
      email: _emailController.text.isEmpty ? null : _emailController.text,
      faceEmbedding: _faceEmbedding!,
      profilePhotoPath: _profilePhoto?.path,
      statusMessage:
          _statusController.text.isEmpty ? null : _statusController.text,
    );
  }

  Widget _buildStatusIndicator() {
    final colorScheme = Theme.of(context).colorScheme;
    Color backgroundColor;
    String text;
    IconData icon;
    Color foregroundColor;
    
    if (_faceEmbedding != null) {
      backgroundColor = colorScheme.tertiaryContainer;
      foregroundColor = colorScheme.onTertiaryContainer;
      text = 'Face captured';
      icon = Icons.verified_rounded;
    } else if (_showCamera && _isCameraReady) {
      backgroundColor = colorScheme.primaryContainer;
      foregroundColor = colorScheme.onPrimaryContainer;
      text = 'Ready to capture';
      icon = Icons.camera_alt_rounded;
    } else if (_showCamera && !_isCameraReady) {
      backgroundColor = colorScheme.secondaryContainer;
      foregroundColor = colorScheme.onSecondaryContainer;
      text = 'Starting camera...';
      icon = Icons.hourglass_empty_rounded;
    } else {
      backgroundColor = colorScheme.surfaceContainerHigh;
      foregroundColor = colorScheme.onSurfaceVariant;
      text = 'Camera inactive';
      icon = Icons.camera_alt_outlined;
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foregroundColor, size: 16),
          SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top padding for status bar
              SizedBox(height: MediaQuery.of(context).padding.top + 10),
              
              // Header with back button
              Row(
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: Icon(Icons.arrow_back_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      foregroundColor: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Spacer(),
                ],
              ),
              
              SizedBox(height: 10),
              
              // Welcome Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.person_add_rounded,
                          size: 40,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Create Account',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Set up your secure biometric profile to get started',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 20),
              
              // Personal Information Card
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal Information',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 20),
                      
                      // Username field
                      TextFormField(
                        controller: _usernameController,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: InputDecoration(
                          labelText: 'Username *',
                          hintText: 'Choose a unique username',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Username is required';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Full name field
                      TextFormField(
                        controller: _fullNameController,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: InputDecoration(
                          labelText: 'Full Name *',
                          hintText: 'Enter your complete name',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Full name is required';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Phone field
                      TextFormField(
                        controller: _phoneController,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          hintText: 'Enter your phone number',
                          prefixIcon: Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      SizedBox(height: 16),

                      // Email field
                      TextFormField(
                        controller: _emailController,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your email address',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      SizedBox(height: 16),

                      // Status message field
                      TextFormField(
                        controller: _statusController,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: InputDecoration(
                          labelText: 'Status Message',
                          hintText: 'Share something about yourself',
                          prefixIcon: Icon(Icons.message_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                        ),
                        maxLength: 140,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 15),

              // Profile Photo Card
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile Photo',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 20),
                      
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: colorScheme.surfaceContainer,
                                border: Border.all(
                                  color: colorScheme.outline,
                                  width: 2,
                                ),
                              ),
                              child: _profilePhoto != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: Image.file(
                                        _profilePhoto!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Icon(
                                      Icons.person_outline_rounded,
                                      size: 60,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                            ),
                            SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _pickProfilePhoto,
                              icon: Icon(Icons.photo_library_outlined),
                              label: Text('Select Photo'),
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 15),

              // Face Recognition Setup Card
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Face Recognition Setup *',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Spacer(),
                          _buildStatusIndicator(),
                        ],
                      ),
                      
                      SizedBox(height: 20),

                      // Camera toggle card
                      InkWell(
                        onTap: _toggleCamera,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _showCamera 
                                ? colorScheme.primaryContainer
                                : colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _showCamera 
                                  ? colorScheme.primary
                                  : colorScheme.outline,
                              width: _showCamera ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _showCamera
                                      ? colorScheme.primary
                                      : colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _showCamera
                                      ? Icons.camera_alt_rounded
                                      : Icons.camera_alt_outlined,
                                  color: _showCamera
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _showCamera ? 'Camera Active' : 'Camera Inactive',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: _showCamera
                                            ? colorScheme.onPrimaryContainer
                                            : colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      _showCamera 
                                          ? 'Tap to close camera' 
                                          : 'Tap to open camera for face capture',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: _showCamera
                                            ? colorScheme.onPrimaryContainer.withOpacity(0.8)
                                            : colorScheme.onSurfaceVariant.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Camera preview
                      AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        height: _showCamera ? null : 0,
                        child: AnimatedOpacity(
                          duration: Duration(milliseconds: 300),
                          opacity: _showCamera ? 1.0 : 0.0,
                          child: Column(
                            children: [
                              SizedBox(height: 20),
                              Container(
                                height: 280,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: colorScheme.surfaceContainer,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (_showCamera &&
                                          _isCameraReady &&
                                          _cameraController != null)
                                        CameraPreview(_cameraController!)
                                      else if (_showCamera && !_isCameraReady)
                                        Container(
                                          color: Colors.black,
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                CircularProgressIndicator.adaptive(
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                      colorScheme.primary),
                                                ),
                                                SizedBox(height: 16),
                                                Text(
                                                  'Starting camera...',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                      // Face captured overlay
                                      if (_faceEmbedding != null)
                                        Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: colorScheme.tertiary,
                                              width: 3,
                                            ),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),

                                      // Scanning line animation
                                      if (_showCamera &&
                                          _isCameraReady &&
                                          _faceEmbedding == null)
                                        AnimatedBuilder(
                                          animation: _scanLineAnimation,
                                          builder: (context, child) {
                                            return Positioned(
                                              top: (1 + _scanLineAnimation.value) * 140,
                                              left: 0,
                                              right: 0,
                                              child: Container(
                                                height: 2,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.transparent,
                                                      colorScheme.primary,
                                                      Colors.transparent,
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),

                                      // Success overlay
                                      if (_faceEmbedding != null)
                                        Container(
                                          decoration: BoxDecoration(
                                            color: colorScheme.tertiaryContainer.withOpacity(0.8),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.verified_rounded,
                                                  size: 60,
                                                  color: colorScheme.onTertiaryContainer,
                                                ),
                                                SizedBox(height: 16),
                                                Text(
                                                  'Face Captured Successfully!',
                                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                    color: colorScheme.onTertiaryContainer,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              SizedBox(height: 16),
                              
                              // Capture button
                              FilledButton.icon(
                                onPressed: (_showCamera && _isCameraReady) ? _captureFace : null,
                                icon: Icon(_faceEmbedding != null 
                                    ? Icons.refresh_rounded 
                                    : Icons.photo_camera_rounded),
                                label: Text(_faceEmbedding != null 
                                    ? 'Recapture Face' 
                                    : 'Capture Face'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _faceEmbedding != null
                                      ? colorScheme.tertiary
                                      : null,
                                  foregroundColor: _faceEmbedding != null
                                      ? colorScheme.onTertiary
                                      : null,
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Register Button
              Card(
                elevation: 0,
                color: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: InkWell(
                  onTap: _authController.isLoading.value ? null : _register,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Obx(() => _authController.isLoading.value
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator.adaptive(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.onPrimary),
                                ),
                              )
                            : Icon(
                                Icons.person_add_rounded,
                                color: colorScheme.onPrimary,
                                size: 24,
                              )),
                        SizedBox(width: 12),
                        Obx(() => Text(
                              _authController.isLoading.value 
                                  ? 'Creating Account...' 
                                  : 'Create Account',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimary,
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: 15),
              
              // Security Notice
              Card(
                elevation: 0,
                color: colorScheme.tertiaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.security_rounded,
                        color: colorScheme.onTertiaryContainer,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your biometric data is processed locally and securely encrypted.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _statusController.dispose();
    _pulseController.dispose();
    _scanLineController.dispose();
    super.dispose();
  }
}