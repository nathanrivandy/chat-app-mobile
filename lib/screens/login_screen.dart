import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import '../controllers/auth_controller.dart';
import '../services/face_recognition_service.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import 'dart:io' show Platform;

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

enum LivenessState { idle, looking, blinkDetected, processingLogin, failed }

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final AuthController _authController = Get.find<AuthController>();
  final FaceRecognitionService _faceService = FaceRecognitionService();

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

  // ML Kit face detector - SAMA seperti kode kedua yang bekerja
  late final FaceDetector _liveDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableClassification: true,
      enableLandmarks: false,
      enableContours: false,
    ),
  );

  // Stream processing
  bool _streaming = false;
  bool _processing = false;
  int _processIntervalMs = 250;
  DateTime _lastProcess = DateTime.fromMillisecondsSinceEpoch(0);

  // Liveness state
  LivenessState _liveness = LivenessState.idle;
  bool _wasOpen = false;
  bool _closedOnce = false;
  DateTime? _closedAt;
  bool _blinkOk = false;
  bool _isLoggingIn = false; // Flag untuk mencegah multiple login attempts

  // Threshold & timing
  final double _openTh = 0.55;
  final double _closedTh = 0.25;
  final Duration _maxBlinkWindow = const Duration(seconds: 2);

  // Debug info
  String _debugInfo = "";
  int _faceCount = 0;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _scanLineController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
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
    if (_cameras != null && _cameraController != null) return;

    try {
      _cameras = await availableCameras();
      final CameraDescription cam = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420 // Android: prefer YUV420
            : ImageFormatGroup.bgra8888, // iOS: BGRA8888
      );

      await _cameraController!.initialize();
      await _cameraController!.setFlashMode(FlashMode.off);

      if (!mounted) return;
      setState(() {
        _isCameraReady = true;
        _liveness = LivenessState.looking;
        _debugInfo = "Camera ready, starting stream...";
      });

      await _startImageStream();
    } catch (e) {
      setState(() {
        _debugInfo = "Camera error: $e";
      });
      Get.snackbar('Camera error', e.toString());
      setState(() {
        _showCamera = false;
        _isCameraReady = false;
      });
    }
  }

  Future<void> _startImageStream() async {
    if (_streaming || _cameraController == null) return;
    _streaming = true;

    setState(() {
      _debugInfo = "Image stream started";
    });

    _cameraController!.startImageStream((image) async {
      if (!_streaming) return;
      final now = DateTime.now();
      if (_processing ||
          now.difference(_lastProcess).inMilliseconds < _processIntervalMs)
        return;

      _processing = true;
      _lastProcess = now;

      try {
        final input =
            _cameraImageToInputImage(image, _cameraController!.description);
        final faces = await _liveDetector.processImage(input);

        if (!_showCamera) return;

        if (faces.isEmpty) {
          // Reset jika wajah hilang
          _resetBlinkState();
          if (mounted) {
            setState(() {
              _liveness = LivenessState.looking;
              _debugInfo = "No faces detected - position your face";
              _faceCount = 0;
            });
          }
        } else {
          // Update face count
          _faceCount = faces.length;

          // Ambil wajah terbesar
          final face = faces.reduce((a, b) {
            final aa = a.boundingBox.width * a.boundingBox.height;
            final bb = b.boundingBox.width * b.boundingBox.height;
            return aa >= bb ? a : b;
          });

          // Debug face info
          final faceSize =
              (face.boundingBox.width * face.boundingBox.height).toInt();

          // ML Kit bisa null kadang, handle aman
          final le = face.leftEyeOpenProbability;
          final re = face.rightEyeOpenProbability;

          if (le == null || re == null) {
            if (mounted) {
              setState(() {
                _debugInfo = "Face detected (size: $faceSize) but no eye data";
              });
            }
          } else {
            final avg = (le + re) / 2.0;

            setState(() {
              _debugInfo =
                  "Face: $faceSize, Eyes: L=${le.toStringAsFixed(2)} R=${re.toStringAsFixed(2)} Avg=${avg.toStringAsFixed(2)}";
            });

            // State machine blink: open -> close -> open (dalam window)
            if (avg > _openTh) {
              if (_closedOnce && _closedAt != null) {
                if (now.difference(_closedAt!) <= _maxBlinkWindow) {
                  // Blink sukses - langsung login otomatis
                  if (!_blinkOk && !_isLoggingIn) {
                    _blinkOk = true;
                    if (mounted) {
                      setState(() {
                        _liveness = LivenessState.blinkDetected;
                        _debugInfo =
                            "BLINK DETECTED! Logging in automatically...";
                      });
                    }
                    // Auto login setelah blink terdeteksi
                    _autoLoginAfterBlink();
                  }
                } else {
                  // Sudah terlalu lama sejak close
                  _resetBlinkState();
                  setState(() {
                    _debugInfo =
                        "Blink timeout, try again. Eyes avg: ${avg.toStringAsFixed(2)}";
                  });
                }
              } else {
                setState(() {
                  _debugInfo =
                      "Eyes open: ${avg.toStringAsFixed(2)} - Please blink";
                });
              }
              _wasOpen = true;
            } else if (avg < _closedTh) {
              if (_wasOpen) {
                _closedOnce = true;
                _closedAt = now;
                setState(() {
                  _debugInfo =
                      "Eyes closed: ${avg.toStringAsFixed(2)} - detected!";
                });
              }
            } else {
              // di area abu-abu
              setState(() {
                _debugInfo =
                    "Eyes partially open: ${avg.toStringAsFixed(2)} (threshold: $_openTh/$_closedTh)";
              });
            }
          }
        }
      } catch (e) {
        setState(() {
          _debugInfo = "ML Kit error: $e";
        });
        print("Detailed error: $e");
      } finally {
        _processing = false;
      }
    });
  }

  Future<void> _autoLoginAfterBlink() async {
    if (_isLoggingIn) return; // Prevent multiple calls

    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      Get.snackbar('Error', 'Please enter username first');
      _resetBlinkState();
      setState(() {
        _liveness = LivenessState.looking;
      });
      return;
    }

    _isLoggingIn = true;
    setState(() {
      _liveness = LivenessState.processingLogin;
      _debugInfo = "Processing login...";
    });

    try {
      // berhenti stream sebelum takePicture
      await _stopImageStream();
      await Future.delayed(const Duration(milliseconds: 120));

      final XFile image = await _cameraController!.takePicture();

      final embedding = await _faceService.extractFaceEmbedding(
        image.path,
        mirror: true, // konsisten dg kamera depan
      );

      if (embedding != null && embedding.isNotEmpty) {
        await _authController.login(username, embedding);
        // Jika berhasil login, AuthController akan navigate ke home
      } else {
        Get.snackbar('Error', 'No face detected. Please try again.');
        // Reset state dan restart stream untuk coba lagi
        _resetBlinkState();
        setState(() {
          _liveness = LivenessState.looking;
          _debugInfo = "No face detected - try blinking again";
        });
        await _startImageStream();
      }
    } catch (e) {
      Get.snackbar('Error', 'Login failed: ${e.toString()}');
      // Reset state dan restart stream untuk coba lagi
      _resetBlinkState();
      setState(() {
        _liveness = LivenessState.failed;
        _debugInfo = "Login failed - try blinking again";
      });
      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _liveness = LivenessState.looking;
      });
      await _startImageStream();
    } finally {
      _isLoggingIn = false;
    }
  }

  Future<void> _stopImageStream() async {
    if (!_streaming || _cameraController == null) return;
    _streaming = false;
    try {
      await _cameraController!.stopImageStream();
      setState(() {
        _debugInfo = "Image stream stopped";
      });
    } catch (_) {}
  }

  void _resetBlinkState() {
    _wasOpen = false;
    _closedOnce = false;
    _closedAt = null;
    _blinkOk = false;
  }

  // GUNAKAN InputImage conversion yang SAMA dengan kode kedua
  InputImage _cameraImageToInputImage(
      CameraImage image, CameraDescription cam) {
    // iOS: gunakan BGRA langsung
    if (Platform.isIOS) {
      final bytes = _packAllPlanes(image); // BGRA sudah single-plane
      return _asBgraInputImage(bytes, image, cam);
    }

    // ANDROID: coba NV21 dulu → kalau gagal fallback ke BGRA
    try {
      final nv21 = _yuv420ToNv21(image);
      return _asNv21InputImage(nv21, image, cam);
    } catch (_) {
      final bgra = _yuv420ToBgra8888(image);
      return _asBgraInputImage(bgra, image, cam);
    }
  }

// ---------- Builders (tanpa planeData) ----------

  InputImage _asNv21InputImage(
    Uint8List nv21,
    CameraImage image,
    CameraDescription cam,
  ) {
    final rotation =
        InputImageRotationValue.fromRawValue(cam.sensorOrientation) ??
            InputImageRotation.rotation0deg;

    final md = InputImageMetadata(
      size: ui.Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: InputImageFormat.nv21, // <= cukup metadata ini
      bytesPerRow: image.width, // baris Y utk NV21
    );
    return InputImage.fromBytes(bytes: nv21, metadata: md);
  }

  InputImage _asBgraInputImage(
    Uint8List bgra,
    CameraImage image,
    CameraDescription cam,
  ) {
    final rotation =
        InputImageRotationValue.fromRawValue(cam.sensorOrientation) ??
            InputImageRotation.rotation0deg;

    final md = InputImageMetadata(
      size: ui.Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: InputImageFormat.bgra8888,
      bytesPerRow: image.width * 4, // 4 byte/pixel
    );
    return InputImage.fromBytes(bytes: bgra, metadata: md);
  }

// ---------- Helpers: packing & convert ----------

  Uint8List _packAllPlanes(CameraImage image) {
    final WriteBuffer wb = WriteBuffer();
    for (final Plane p in image.planes) {
      wb.putUint8List(p.bytes);
    }
    return wb.done().buffer.asUint8List();
  }

  /// Convert 3-plane YUV420 → NV21 (Y + interleaved VU)
  Uint8List _yuv420ToNv21(CameraImage image) {
    final int w = image.width;
    final int h = image.height;

    final Plane yP = image.planes[0];
    final Plane uP = image.planes[1]; // Cb
    final Plane vP = image.planes[2]; // Cr

    final Uint8List out = Uint8List(w * h + (w * h ~/ 2));

    // Copy Y row-by-row (respect row stride)
    int o = 0;
    for (int row = 0; row < h; row++) {
      final int start = row * yP.bytesPerRow;
      out.setRange(o, o + w, yP.bytes.sublist(start, start + w));
      o += w;
    }

    // Hitung parameter chroma
    final int cw = (w + 1) >> 1;
    final int ch = (h + 1) >> 1;

    // Estimasi pixelStride (beberapa device = 2)
    final int uPixStride = (uP.bytesPerRow ~/ cw).clamp(1, 4);
    final int vPixStride = (vP.bytesPerRow ~/ cw).clamp(1, 4);

    // Interleave VU
    for (int row = 0; row < ch; row++) {
      final int uRow = row * uP.bytesPerRow;
      final int vRow = row * vP.bytesPerRow;
      for (int col = 0; col < cw; col++) {
        final int uIdx = uRow + col * uPixStride;
        final int vIdx = vRow + col * vPixStride;
        out[o++] = vP.bytes[vIdx]; // V
        out[o++] = uP.bytes[uIdx]; // U
      }
    }

    return out;
  }

  /// Convert YUV420 → BGRA8888 (universal fallback)
  Uint8List _yuv420ToBgra8888(CameraImage image) {
    final int w = image.width;
    final int h = image.height;

    final Plane yP = image.planes[0];
    final Plane uP = image.planes[1];
    final Plane vP = image.planes[2];

    final Uint8List out = Uint8List(w * h * 4);

    final int cw = (w + 1) >> 1;
    final int ch = (h + 1) >> 1;

    // Estimasi pixelStride utk UV
    final int uPixStride = (uP.bytesPerRow ~/ cw).clamp(1, 4);
    final int vPixStride = (vP.bytesPerRow ~/ cw).clamp(1, 4);

    int o = 0;
    for (int y = 0; y < h; y++) {
      final int yRow = y * yP.bytesPerRow;
      final int uvRow = (y >> 1) * uP.bytesPerRow;
      for (int x = 0; x < w; x++) {
        final int Y = yP.bytes[yRow + x];

        final int uCol = (x >> 1) * uPixStride;
        final int vCol = (x >> 1) * vPixStride;
        final int U = uP.bytes[uvRow + uCol];
        final int V = vP.bytes[uvRow + vCol];

        // BT.601
        final double c = (Y - 16).clamp(0, 255).toDouble();
        final double d = (U - 128).toDouble();
        final double e = (V - 128).toDouble();

        int r = (1.164 * c + 1.596 * e).round();
        int g = (1.164 * c - 0.392 * d - 0.813 * e).round();
        int b = (1.164 * c + 2.017 * d).round();

        if (r < 0)
          r = 0;
        else if (r > 255) r = 255;
        if (g < 0)
          g = 0;
        else if (g > 255) g = 255;
        if (b < 0)
          b = 0;
        else if (b > 255) b = 255;

        out[o++] = b;
        out[o++] = g;
        out[o++] = r;
        out[o++] = 255;
      }
    }

    return out;
  }

  Future<void> _toggleCamera() async {
    if (_showCamera) {
      // Hide camera + stop stream
      await _stopImageStream();
      setState(() {
        _showCamera = false;
        _isCameraReady = false;
        _liveness = LivenessState.idle;
        _debugInfo = "Camera stopped";
        _faceCount = 0;
      });
      await _cameraController?.dispose();
      _cameraController = null;
      _resetBlinkState();
      _isLoggingIn = false;
      _pulseController.stop();
      _scanLineController.stop();
    } else {
      // Show camera + start stream
      setState(() {
        _showCamera = true;
        _liveness = LivenessState.looking;
        _debugInfo = "Starting camera...";
      });
      _pulseController.repeat();
      _scanLineController.repeat();
      await _initializeCamera();
    }
  }

  Widget _buildLivenessIndicator() {
    Color bg;
    String text;
    IconData icon;
    switch (_liveness) {
      case LivenessState.blinkDetected:
        bg = Colors.green;
        text = 'Blink detected';
        icon = Icons.verified;
        break;
      case LivenessState.processingLogin:
        bg = Colors.orange;
        text = 'Logging in...';
        icon = Icons.hourglass_empty;
        break;
      case LivenessState.looking:
        bg = Colors.blueGrey;
        text = 'Blink to login';
        icon = Icons.remove_red_eye;
        break;
      case LivenessState.failed:
        bg = Colors.red;
        text = 'Try again';
        icon = Icons.error_outline;
        break;
      default:
        bg = Colors.grey;
        text = 'Idle';
        icon = Icons.hourglass_empty;
    }
    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 18),
      label: Text(text, style: const TextStyle(color: Colors.white)),
      backgroundColor: bg,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Auto Face Recognition Login',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Username
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter your username',
                  prefixIcon:
                      Icon(Icons.person_outline, color: Colors.blue.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),

            // Instructions Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'How to Login:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Enter your username\n2. Open camera\n3. Position your face\n4. Blink once to login automatically',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Debug Info Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Debug Info:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Faces: $_faceCount',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  Text(
                    _debugInfo.isEmpty ? 'Waiting...' : _debugInfo,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Camera + liveness
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text('Auto Face Recognition',
                            style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        _buildLivenessIndicator(),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 280,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
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
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.blue.shade50,
                                      Colors.blue.shade100,
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AnimatedBuilder(
                                        animation: _pulseAnimation,
                                        builder: (context, child) {
                                          return Transform.scale(
                                            scale: _pulseAnimation.value,
                                            child: Container(
                                              padding: const EdgeInsets.all(20),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade100,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.blue.shade300,
                                                  width: 2,
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.camera_alt,
                                                size: 40,
                                                color: Colors.blue.shade600,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Press button below to open camera',
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Face detection overlay
                            if (_showCamera && _isCameraReady && _faceCount > 0)
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _liveness ==
                                                LivenessState.blinkDetected ||
                                            _liveness ==
                                                LivenessState.processingLogin
                                        ? Colors.green
                                        : Colors.orange,
                                    width: 3,
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),

                            // Scanning line animation
                            if (_showCamera &&
                                _isCameraReady &&
                                _liveness != LivenessState.blinkDetected &&
                                _liveness != LivenessState.processingLogin)
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
                                            Colors.orange,
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),

                            // Processing overlay
                            if (_liveness == LivenessState.processingLogin)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Processing login...',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
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
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _toggleCamera,
                      icon: Icon(
                          _showCamera ? Icons.videocam_off : Icons.videocam),
                      label: Text(_showCamera ? 'Close Camera' : 'Open Camera'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _showCamera
                            ? Colors.red.shade500
                            : Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Status Card (replaces login button)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _showCamera && _isCameraReady && !_isLoggingIn
                      ? [Colors.green.shade50, Colors.green.shade100]
                      : [Colors.grey.shade50, Colors.grey.shade100],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _showCamera && _isCameraReady && !_isLoggingIn
                      ? Colors.green.shade200
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _showCamera && _isCameraReady && !_isLoggingIn
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: _showCamera && _isCameraReady && !_isLoggingIn
                        ? Colors.green.shade600
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _showCamera && _isCameraReady && !_isLoggingIn
                              ? 'Ready to Login'
                              : _isLoggingIn
                                  ? 'Processing...'
                                  : 'Camera Inactive',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                _showCamera && _isCameraReady && !_isLoggingIn
                                    ? Colors.green.shade800
                                    : Colors.grey.shade800,
                          ),
                        ),
                        Text(
                          _showCamera && _isCameraReady && !_isLoggingIn
                              ? 'Blink once when your face is detected to login'
                              : _isLoggingIn
                                  ? 'Authenticating your face...'
                                  : 'Open camera and position your face',
                          style: TextStyle(
                            color:
                                _showCamera && _isCameraReady && !_isLoggingIn
                                    ? Colors.green.shade700
                                    : Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isLoggingIn)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.grey.shade600),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Register
            TextButton.icon(
              onPressed: () => Get.to(() => RegisterScreen()),
              icon: Icon(Icons.person_add, color: Colors.blue.shade600),
              label: Text(
                "Don't have an account? Register",
                style: TextStyle(
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Security Notice
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your biometric data is processed locally and securely encrypted.',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopImageStream();
    _liveDetector.close();
    _cameraController?.dispose();
    _usernameController.dispose();
    _pulseController.dispose();
    _scanLineController.dispose();
    super.dispose();
  }
}
