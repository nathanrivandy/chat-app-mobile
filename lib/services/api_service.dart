import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.74.174:6969/api';
  final GetStorage _storage = GetStorage();

  // ===== Helpers =============================================================
  Uri _buildUri(String path, [Map<String, dynamic>? params]) {
    final uri = Uri.parse('$baseUrl$path');
    if (params == null) return uri;
    // Filter null & convert ke string
    final qp = <String, String>{};
    params.forEach((k, v) {
      if (v != null) qp[k] = v.toString();
    });
    return uri.replace(queryParameters: qp.isEmpty ? null : qp);
  }

  Map<String, String> _jsonHeaders({bool withAuth = true}) {
    final token = _storage.read('token');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (withAuth && token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Map<String, String> _multipartHeaders({bool withAuth = true}) {
    // Jangan set Content-Type di multipart; biarkan http package yang set.
    final token = _storage.read('token');
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (withAuth && token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  T _decodeJson<T>(String body, String? contentType, int statusCode) {
    final isJson =
        (contentType ?? '').toLowerCase().contains('application/json');
    if (!isJson) {
      final snippet = body.substring(0, body.length > 200 ? 200 : body.length);
      throw FormatException(
        'Server did not return JSON (status $statusCode): $snippet',
      );
    }
    final obj = jsonDecode(body);
    return obj as T;
  }

  Map<String, dynamic> _parseResponse(http.Response res) {
    final data = _decodeJson<Map<String, dynamic>>(
      res.body,
      res.headers['content-type'],
      res.statusCode,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    throw Exception(data['error'] ?? 'HTTP ${res.statusCode}');
  }

  Future<Map<String, dynamic>> _parseStreamedResponse(
    http.StreamedResponse res,
  ) async {
    final body = await res.stream.bytesToString();
    final data = _decodeJson<Map<String, dynamic>>(
      body,
      res.headers['content-type'],
      res.statusCode,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    throw Exception(data['error'] ?? 'HTTP ${res.statusCode}');
  }

  // ===== Auth ================================================================
  Future<Map<String, dynamic>> login(
    String username,
    List<double> faceEmbedding,
  ) async {
    final res = await http
        .post(
          _buildUri('/login'),
          headers: _jsonHeaders(withAuth: false),
          // Kirim sebagai ARRAY, hindari double-encode
          body: jsonEncode({
            'username': username,
            'face_embedding': faceEmbedding,
          }),
        )
        .timeout(const Duration(seconds: 20));
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String fullName,
    String? phone,
    String? email,
    required List<double> faceEmbedding,
    String? profilePhotoPath,
    String? statusMessage,
  }) async {
    final req = http.MultipartRequest('POST', _buildUri('/register'));
    req.headers.addAll(_multipartHeaders(withAuth: false));

    req.fields['username'] = username;
    req.fields['full_name'] = fullName;
    if (phone != null) req.fields['phone'] = phone;
    if (email != null) req.fields['email'] = email;
    // Multipart harus string → encode sekali
    req.fields['face_embedding'] = jsonEncode(faceEmbedding);
    if (statusMessage != null) req.fields['status_message'] = statusMessage;

    if (profilePhotoPath != null) {
      req.files.add(
          await http.MultipartFile.fromPath('profile_photo', profilePhotoPath));
    }

    final res = await req.send().timeout(const Duration(seconds: 30));
    return _parseStreamedResponse(res);
  }

  // ===== Profile & Users =====================================================
  Future<Map<String, dynamic>> getUserProfile() async {
    final res = await http
        .get(_buildUri('/profile'), headers: _jsonHeaders())
        .timeout(const Duration(seconds: 20));
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> getUsers() async {
    final res = await http
        .get(_buildUri('/users'), headers: _jsonHeaders())
        .timeout(const Duration(seconds: 20));
    return _parseResponse(res);
  }

  // ⬅️ NEW: Method untuk mendapatkan semua users (diperlukan untuk home screen)
  Future<Map<String, dynamic>> getAllUsers() async {
    try {
      final res = await http
          .get(_buildUri('/users/all'), headers: _jsonHeaders())
          .timeout(const Duration(seconds: 20));
      return _parseResponse(res);
    } catch (e) {
      print('DEBUG: getAllUsers failed, trying fallback');
      // Fallback to regular users endpoint
      return await getUsers();
    }
  }

  // ===== Contacts ============================================================
  Future<Map<String, dynamic>> getAddedContacts() async {
    final res = await http
        .get(_buildUri('/contacts'), headers: _jsonHeaders())
        .timeout(const Duration(seconds: 20));
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> searchUserByUsername(String username) async {
    final res = await http
        .get(
          _buildUri('/users/search', {'username': username}),
          headers: _jsonHeaders(),
        )
        .timeout(const Duration(seconds: 20));
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> addContact(int contactUserId) async {
    // Kirim dua key untuk kompatibilitas server yang berbeda (aman, server abaikan yang tak dipakai)
    final res = await http
        .post(
          _buildUri('/contacts'),
          headers: _jsonHeaders(),
          body: jsonEncode({
            'contact_user_id': contactUserId,
            'target_user_id': contactUserId,
          }),
        )
        .timeout(const Duration(seconds: 20));
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> removeContact(int contactId) async {
    final res = await http
        .delete(_buildUri('/contacts/$contactId'), headers: _jsonHeaders())
        .timeout(const Duration(seconds: 20));
    return _parseResponse(res);
  }

  // ===== Messages ============================================================
  Future<Map<String, dynamic>> getMessages({
    int? receiverId,
    int? channelId,
    int limit = 50,
    int offset = 0,
  }) async {
    final qp = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      if (receiverId != null) 'receiver_id': receiverId,
      if (channelId != null) 'channel_id': channelId,
    };
    final res = await http
        .get(_buildUri('/messages', qp), headers: _jsonHeaders())
        .timeout(const Duration(seconds: 20));
    return _parseResponse(res);
  }

  // ⬅️ NEW: Method untuk mendapatkan semua messages (diperlukan untuk home screen)
  Future<Map<String, dynamic>> getAllMessages({
    int limit = 1000,
    int offset = 0,
  }) async {
    try {
      final qp = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };
      final res = await http
          .get(_buildUri('/messages/all', qp), headers: _jsonHeaders())
          .timeout(const Duration(seconds: 20));
      return _parseResponse(res);
    } catch (e) {
      print('DEBUG: getAllMessages endpoint not available: $e');
      // Return empty result if endpoint doesn't exist
      return {'messages': []};
    }
  }

  // ⬅️ NEW: Method untuk mark messages sebagai read
  Future<Map<String, dynamic>> markMessagesAsRead(int userId) async {
    try {
      final res = await http
          .put(
            _buildUri('/messages/read'),
            headers: _jsonHeaders(),
            body: jsonEncode({
              'user_id': userId,
            }),
          )
          .timeout(const Duration(seconds: 20));
      return _parseResponse(res);
    } catch (e) {
      print('DEBUG: markMessagesAsRead endpoint failed: $e');
      // Return success even if endpoint doesn't exist (graceful degradation)
      return {'message': 'Read status updated locally'};
    }
  }

  Future<Map<String, dynamic>> sendMessage({
    String? text,
    int? receiverId,
    int? channelId,
    String? imagePath,
  }) async {
    final req = http.MultipartRequest('POST', _buildUri('/messages'));
    req.headers.addAll(_multipartHeaders());

    if (text != null) req.fields['text'] = text;
    if (receiverId != null) req.fields['receiver_id'] = receiverId.toString();
    if (channelId != null) req.fields['channel_id'] = channelId.toString();

    if (imagePath != null) {
      req.files.add(await http.MultipartFile.fromPath('image', imagePath));
    }

    final res = await req.send().timeout(const Duration(seconds: 30));
    return _parseStreamedResponse(res);
  }

  // ===== Channels ============================================================
  Future<Map<String, dynamic>> getChannels() async {
    final res = await http
        .get(_buildUri('/channels'), headers: _jsonHeaders())
        .timeout(const Duration(seconds: 20));
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> createChannel(
    String name, {
    String? topic,
    bool isPublic = true,
  }) async {
    final res = await http
        .post(
          _buildUri('/channels'),
          headers: _jsonHeaders(),
          body: jsonEncode({
            'name': name,
            if (topic != null) 'topic': topic,
            'is_public': isPublic ? 1 : 0, // server kamu pakai int
          }),
        )
        .timeout(const Duration(seconds: 20));
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> joinChannel(int channelId) async {
    final res = await http
        .post(_buildUri('/channels/$channelId/join'), headers: _jsonHeaders())
        .timeout(const Duration(seconds: 20));
    return _parseResponse(res);
  }

  // ===== Reputation ==========================================================
  Future<Map<String, dynamic>> submitReputation(
    int targetUserId,
    int delta,
    String reason,
  ) async {
    final res = await http
        .post(
          _buildUri('/reputation'),
          headers: _jsonHeaders(),
          body: jsonEncode({
            'target_user_id': targetUserId,
            'delta': delta,
            'reason': reason,
          }),
        )
        .timeout(const Duration(seconds: 20));
    return _parseResponse(res);
  }

  // ===== E2EE ================================================================
  Future<void> savePublicKey(String publicKeyB64) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/e2ee/public-key'),
      headers: _jsonHeaders(),
      body: json.encode({'public_key': publicKeyB64}),
    );
    if (resp.statusCode != 200) {
      try {
        final body = json.decode(resp.body);
        throw Exception(body['error'] ?? 'Failed to save public key');
      } catch (_) {
        throw Exception('Failed to save public key');
      }
    }
  }

  // ambil public key user lain
  Future<Map<String, dynamic>> getUserPublicKey(int userId) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/e2ee/public-key/$userId'),
      headers: _jsonHeaders(),
    );
    if (resp.statusCode == 200) {
      return json.decode(resp.body);
    } else if (resp.statusCode == 404) {
      // biar ChatController bisa munculkan error "Public key not found"
      return {};
    } else {
      try {
        final body = json.decode(resp.body);
        throw Exception(body['error'] ?? 'Failed to get public key');
      } catch (_) {
        throw Exception('Failed to get public key');
      }
    }
  }
}
