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

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _statusController = TextEditingController();

  final AuthController _authController = Get.find<AuthController>();
  final FaceRecognitionService _faceService = FaceRecognitionService();
  final ImagePicker _imagePicker = ImagePicker();

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraReady = false;
  bool _showCamera = false;
  File? _profilePhoto;
  List<double>? _faceEmbedding;

  @override
  void initState() {
    super.initState();
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
    } else {
      // Show camera
      setState(() {
        _showCamera = true;
        _isCameraReady = false;
      });
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
        Get.snackbar('Success', 'Face captured successfully!');
      } else {
        Get.snackbar('Error', 'No face detected. Please try again.');
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to capture face: ${e.toString()}');
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
      Get.snackbar('Error', 'Please capture your face first');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Register'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Username field
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username*',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
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
                decoration: InputDecoration(
                  labelText: 'Full Name*',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
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
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 16),

              // Email field
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),

              // Status message field
              TextFormField(
                controller: _statusController,
                decoration: InputDecoration(
                  labelText: 'Status Message',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.message),
                ),
                maxLength: 140,
              ),
              SizedBox(height: 16),

              // Profile photo section
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text('Profile Photo',
                          style: Theme.of(context).textTheme.titleMedium),
                      SizedBox(height: 10),
                      _profilePhoto != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(_profilePhoto!,
                                  height: 100, width: 100, fit: BoxFit.cover),
                            )
                          : Container(
                              height: 100,
                              width: 100,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.person,
                                  size: 50, color: Colors.grey),
                            ),
                      SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _pickProfilePhoto,
                        icon: Icon(Icons.photo_library),
                        label: Text('Select Photo'),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Face recognition section
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Face Recognition Setup*',
                              style: Theme.of(context).textTheme.titleMedium),
                          Icon(
                            _faceEmbedding != null
                                ? Icons.check_circle
                                : Icons.circle,
                            color: _faceEmbedding != null
                                ? Colors.green
                                : Colors.grey,
                            size: 24,
                          ),
                        ],
                      ),
                      SizedBox(height: 10),

                      // Camera preview or placeholder
                      Container(
                        height: 250,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _showCamera
                            ? (_isCameraReady && _cameraController != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: CameraPreview(_cameraController!),
                                  )
                                : const Center(
                                    child: CircularProgressIndicator()))
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt,
                                      size: 60,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Press button below to open camera',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      SizedBox(height: 10),

                      // Camera controls
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _toggleCamera,
                              icon: Icon(_showCamera
                                  ? Icons.camera_alt_outlined
                                  : Icons.camera_alt),
                              label: Text(
                                  _showCamera ? 'Close Camera' : 'Open Camera'),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (_showCamera && _isCameraReady)
                                  ? _captureFace
                                  : null,
                              icon: Icon(Icons.photo_camera),
                              label: Text('Capture Face'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _faceEmbedding != null
                                    ? Colors.green
                                    : null,
                                foregroundColor: _faceEmbedding != null
                                    ? Colors.white
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Register button
              Obx(() => ElevatedButton(
                    onPressed:
                        _authController.isLoading.value ? null : _register,
                    child: _authController.isLoading.value
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text('Register'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                  )),
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
    super.dispose();
  }
}
