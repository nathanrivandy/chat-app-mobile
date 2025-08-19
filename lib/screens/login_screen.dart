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
import 'package:rive/rive.dart' as rive;
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
  late AnimationController _shimmerController;

  // Animations
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanLineAnimation;
  late Animation<double> _shimmerAnimation;

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

    _shimmerController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

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

    _shimmerAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
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
    final colorScheme = Theme.of(context).colorScheme;
    Color backgroundColor;
    String text;
    IconData icon;
    Color foregroundColor = colorScheme.onSecondaryContainer;
    
    switch (_liveness) {
      case LivenessState.blinkDetected:
        backgroundColor = colorScheme.tertiaryContainer;
        foregroundColor = colorScheme.onTertiaryContainer;
        text = 'Blink detected!';
        icon = Icons.verified_rounded;
        break;
      case LivenessState.processingLogin:
        backgroundColor = colorScheme.secondaryContainer;
        foregroundColor = colorScheme.onSecondaryContainer;
        text = 'Authenticating...';
        icon = Icons.hourglass_empty_rounded;
        break;
      case LivenessState.looking:
        backgroundColor = colorScheme.primaryContainer;
        foregroundColor = colorScheme.onPrimaryContainer;
        text = 'Blink to login';
        icon = Icons.visibility_rounded;
        break;
      case LivenessState.failed:
        backgroundColor = colorScheme.errorContainer;
        foregroundColor = colorScheme.onErrorContainer;
        text = 'Try again';
        icon = Icons.error_outline_rounded;
        break;
      default:
        backgroundColor = colorScheme.surfaceContainerHigh;
        foregroundColor = colorScheme.onSurfaceVariant;
        text = 'Idle';
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top padding for status bar
            SizedBox(height: MediaQuery.of(context).padding.top + 20),
            
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
                        Icons.face_retouching_natural_rounded,
                        size: 40,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Secure Face Login',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Login with just a blink using advanced biometric technology',
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
            
            // Username Field
            TextField(
              controller: _usernameController,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                labelText: 'Username',
                hintText: 'Enter your username',
                prefixIcon: Icon(Icons.person_outline_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
              ),
            ),

            SizedBox(height: 15),

            InkWell(
              onTap: _toggleCamera, // Pindahkan fungsi toggle camera ke sini
              borderRadius: BorderRadius.circular(20),
              child: Card(
                elevation: 0,
                color: _getStatusCardColor(colorScheme),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getStatusIconBackground(colorScheme),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getStatusIcon(),
                          color: _getStatusIconColor(colorScheme),
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getStatusTitle(),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _getStatusTextColor(colorScheme),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _getStatusDescription(),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: _getStatusTextColor(colorScheme).withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      if (_isLoggingIn)
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: rive.RiveAnimation.asset(
                            "assets/animation/face_id_animation.riv",
                            fit: BoxFit.fitHeight,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            
            // SizedBox(height: 15),
            
            // // Instructions Card
            // Card(
            //   elevation: 0,
            //   color: colorScheme.secondaryContainer,
            //   shape: RoundedRectangleBorder(
            //     borderRadius: BorderRadius.circular(20),
            //   ),
            //   child: Padding(
            //     padding: EdgeInsets.all(20),
            //     child: Column(
            //       crossAxisAlignment: CrossAxisAlignment.start,
            //       children: [
            //         Row(
            //           children: [
            //             Icon(
            //               Icons.lightbulb_outline_rounded,
            //               color: colorScheme.onSecondaryContainer,
            //               size: 20,
            //             ),
            //             SizedBox(width: 8),
            //             Text(
            //               'How it works',
            //               style: Theme.of(context).textTheme.titleMedium?.copyWith(
            //                 fontWeight: FontWeight.bold,
            //                 color: colorScheme.onSecondaryContainer,
            //               ),
            //             ),
            //           ],
            //         ),
            //         SizedBox(height: 16),
            //         _buildInstructionStep(
            //           context,
            //           '1',
            //           'Enter your username above',
            //           Icons.edit_rounded,
            //         ),
            //         SizedBox(height: 12),
            //         _buildInstructionStep(
            //           context,
            //           '2',
            //           'Open camera and position your face',
            //           Icons.camera_alt_rounded,
            //         ),
            //         SizedBox(height: 12),
            //         _buildInstructionStep(
            //           context,
            //           '3',
            //           'Blink once to authenticate',
            //           Icons.visibility_rounded,
            //         ),
            //       ],
            //     ),
            //   ),
            // ),
            
            SizedBox(height: 15),
            
            // Camera Preview Card
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: _showCamera ? null : 0,
              child: AnimatedOpacity(
                duration: Duration(milliseconds: 300),
                opacity: _showCamera ? 1.0 : 0.0,
                child: Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Header with status
                        Row(
                          children: [
                            Text(
                              'Camera Preview',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            Spacer(),
                            _buildLivenessIndicator(),
                          ],
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Camera Preview
                        Container(
                          height: 320,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: colorScheme.surfaceContainer,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
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

                                // Face detection overlay
                                if (_showCamera && _isCameraReady && _faceCount > 0)
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: _liveness == LivenessState.blinkDetected ||
                                                _liveness == LivenessState.processingLogin
                                            ? colorScheme.tertiary
                                            : colorScheme.primary,
                                        width: 3,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
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
                                        top: (1 + _scanLineAnimation.value) * 160,
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

                                // Processing overlay
                                if (_liveness == LivenessState.processingLogin)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: colorScheme.scrim.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                        ],
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
              ),
            ),

            // Tambahkan spacing conditional setelah camera preview
            if (_showCamera) SizedBox(height: 20),
            
            
            // Register Button
            // OutlinedButton.icon(
            //   onPressed: () => Get.to(() => RegisterScreen()),
            //   icon: Icon(Icons.person_add_rounded),
            //   label: Text(
            //     "Don't have an account? Register",
            //     style: TextStyle(fontWeight: FontWeight.w600),
            //   ),
            // ),
            Card(
              elevation: 0, // Sama dengan card lain
              color: colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20), // Sama dengan card lain
              ),
              child: InkWell(
                onTap: () => Get.to(() => RegisterScreen()),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: EdgeInsets.all(20), // Sama dengan padding card lain
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_add_rounded,
                        color: colorScheme.onPrimary,
                        size: 24, // Konsisten dengan icon size di card lain
                      ),
                      SizedBox(width: 12), // Konsisten dengan spacing di card lain
                      Text(
                        'Create New Account',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold, // Konsisten dengan title style
                          color: colorScheme.onPrimary,
                        ),
                      ),
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
    );
  }

  Widget _buildInstructionStep(
    BuildContext context,
    String number,
    String instruction,
    IconData icon,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              number,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        Icon(
          icon,
          size: 18,
          color: colorScheme.onSecondaryContainer.withOpacity(0.7),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            instruction,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusCardColor(ColorScheme colorScheme) {
    if (_showCamera && _isCameraReady && !_isLoggingIn) {
      return colorScheme.tertiaryContainer;
    } else if (_isLoggingIn) {
      return colorScheme.secondaryContainer;
    } else {
      return colorScheme.surfaceContainerHigh;
    }
  }

  Color _getStatusIconBackground(ColorScheme colorScheme) {
    if (_showCamera && _isCameraReady && !_isLoggingIn) {
      return colorScheme.tertiary;
    } else if (_isLoggingIn) {
      return colorScheme.secondary;
    } else {
      return colorScheme.surfaceContainerHighest;
    }
  }

  IconData _getStatusIcon() {
    if (_showCamera && _isCameraReady && !_isLoggingIn) {
      return Icons.visibility_rounded;
    } else if (_isLoggingIn) {
      return Icons.hourglass_empty_rounded;
    } else {
      return Icons.visibility_off_rounded;
    }
  }

  Color _getStatusIconColor(ColorScheme colorScheme) {
    if (_showCamera && _isCameraReady && !_isLoggingIn) {
      return colorScheme.onTertiary;
    } else if (_isLoggingIn) {
      return colorScheme.onSecondary;
    } else {
      return colorScheme.onSurfaceVariant;
    }
  }

  Color _getStatusTextColor(ColorScheme colorScheme) {
    if (_showCamera && _isCameraReady && !_isLoggingIn) {
      return colorScheme.onTertiaryContainer;
    } else if (_isLoggingIn) {
      return colorScheme.onSecondaryContainer;
    } else {
      return colorScheme.onSurfaceVariant;
    }
  }

  String _getStatusTitle() {
    if (_showCamera && _isCameraReady && !_isLoggingIn) {
      return 'Ready to Authenticate';
    } else if (_isLoggingIn) {
      return 'Processing Authentication';
    } else {
      return 'Camera Inactive';
    }
  }

  String _getStatusDescription() {
    if (_showCamera && _isCameraReady && !_isLoggingIn) {
      return 'Position your face in the camera and blink once to login securely. Tap to close camera.';
    } else if (_isLoggingIn) {
      return 'Verifying your identity using advanced biometric analysis';
    } else {
      return 'Tap here to open camera and begin face authentication';
    }
  }

  @override
  void dispose() {
    _stopImageStream();
    _liveDetector.close();
    _cameraController?.dispose();
    _usernameController.dispose();
    _pulseController.dispose();
    _scanLineController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }
}