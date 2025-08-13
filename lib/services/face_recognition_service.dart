import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceRecognitionService {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableLandmarks: true, // penting untuk eye-based roll
      enableClassification: false,
      enableContours: false,
    ),
  );

  Future<List<double>?> extractFaceEmbedding(
    String imagePath, {
    bool mirror = false,
    bool saveDebug = false,
  }) async {
    try {
      // 1) Load + orientasi + (opsional) mirror
      final bytes = await File(imagePath).readAsBytes();
      img.Image? im = img.decodeImage(bytes);
      if (im == null) return null;
      im = img.bakeOrientation(im);
      if (mirror) {
        im = img.flipHorizontal(im);
      }

      // Helper deteksi via temp file (paling konsisten)
      Future<List<Face>> detect(img.Image src) async {
        final tmpPath =
            '${imagePath}_tmp_${DateTime.now().microsecondsSinceEpoch}.jpg';
        await File(tmpPath)
            .writeAsBytes(img.encodeJpg(src, quality: 95), flush: true);
        final faces = await _detector.processImage(
          InputImage.fromFilePath(tmpPath),
        );
        try {
          File(tmpPath).deleteSync();
        } catch (_) {}
        return faces;
      }

      // 2) Deteksi awal
      var faces = await detect(im);
      if (faces.isEmpty) return null;

      Face _pickLargest(List<Face> fs) => fs.reduce((a, b) {
            final aa = a.boundingBox.width * a.boundingBox.height;
            final bb = b.boundingBox.width * b.boundingBox.height;
            return aa >= bb ? a : b;
          });

      // 3) Estimasi roll dari landmarks (fallback ke Euler Z)
      double _estimateRollDeg(Face f) {
        final left = f.landmarks[FaceLandmarkType.leftEye]?.position;
        final right = f.landmarks[FaceLandmarkType.rightEye]?.position;
        if (left != null && right != null) {
          final dy = right.y - left.y;
          final dx = right.x - left.x;
          return math.atan2(dy, dx) * 180 / math.pi; // derajat
        }
        return (f.headEulerAngleZ ?? 0).toDouble();
      }

      var face = _pickLargest(faces);
      final roll = _estimateRollDeg(face);
      if (roll.abs() > 2) {
        im = img.copyRotate(im, angle: -roll); // tegakkan wajah
        faces = await detect(im);
        if (faces.isEmpty) return null;
        face = _pickLargest(faces);
      }

      // 4) Square crop + margin + clamp
      final rect = face.boundingBox;
      final cx = rect.left + rect.width / 2.0;
      final cy = rect.top + rect.height / 2.0;

      const double scale = 1.4; // ambil dahi & dagu
      double w = rect.width * scale;
      double h = rect.height * scale;
      final side = math.max(w, h);
      w = side;
      h = side;

      int x = (cx - w / 2).round();
      int y = (cy - h / 2).round();
      final iw = im.width;
      final ih = im.height;

      x = x.clamp(0, iw - 1);
      y = y.clamp(0, ih - 1);
      final cw = math.min(iw - x, math.max(1, w.round()));
      final ch = math.min(ih - y, math.max(1, h.round()));

      img.Image crop = img.copyCrop(im, x: x, y: y, width: cw, height: ch);

      if (saveDebug) {
        final debugPath =
            imagePath.replaceFirst(RegExp(r'\.\w+$'), '') + '_crop.jpg';
        await File(debugPath).writeAsBytes(img.encodeJpg(crop, quality: 95));
      }

      // 5) Preprocess: grayscale + contrast normalize + resize tetap
      crop = img.grayscale(crop);
      crop = _contrastNormalize(crop);
      crop = img.copyResize(crop,
          width: 32, height: 16, interpolation: img.Interpolation.linear);

      // 6) 512-dim embedding + L2 normalize
      final emb = _embeddingFromGrayscale(crop);
      _l2Normalize(emb);
      return emb;
    } catch (_) {
      return null;
    }
  }

  // ---- Utilities ----

  img.Image _contrastNormalize(img.Image g) {
    final w = g.width, h = g.height;
    int minV = 255, maxV = 0;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = g.getPixel(x, y);
        final v = img.getLuminance(p);
        if (v < minV) minV = v.toInt();
        if (v > maxV) maxV = v.toInt();
      }
    }
    final range = (maxV - minV).clamp(1, 255);
    final out = img.Image.from(g);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = g.getPixel(x, y);
        final v = img.getLuminance(p);
        final nv = ((v - minV) * 255 / range).round().clamp(0, 255);
        out.setPixelRgba(x, y, nv, nv, nv, 255);
      }
    }
    return out;
  }

  List<double> _embeddingFromGrayscale(img.Image g32x16) {
    final w = g32x16.width, h = g32x16.height; // 32x16 => 512
    final out = List<double>.filled(w * h, 0.0, growable: false);
    int i = 0;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = g32x16.getPixel(x, y);
        final v = img.getLuminance(p); // 0..255
        out[i++] = (v / 255.0) * 2.0 - 1.0; // [-1, 1]
      }
    }
    return out;
  }

  void _l2Normalize(List<double> v) {
    double s = 0;
    for (final x in v) s += x * x;
    final n = s == 0 ? 1e-12 : math.sqrt(s);
    for (int i = 0; i < v.length; i++) v[i] /= n;
  }

  Future<void> close() => _detector.close();
}
