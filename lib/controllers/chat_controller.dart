import 'dart:convert';
import 'dart:math';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:cryptography/cryptography.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../models/user.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../controllers/auth_controller.dart';

class ChatController extends GetxController {
  final ApiService _apiService = ApiService();
  final AuthController _authController = Get.find<AuthController>();

  // Users & contacts
  RxList<User> users = <User>[].obs;
  RxList<User> allUsers = <User>[].obs; // ⬅️ Added: For storing all users data
  RxBool isLoading = false.obs;

  RxList<User> addedContacts = <User>[].obs;
  RxBool isAddingContact = false.obs;
  RxList<User> searchResults = <User>[].obs;
  RxBool isSearching = false.obs;

  // Messages
  RxList<Message> messages = <Message>[].obs;
  RxBool isLoadingMessages = false.obs;

  // Channels (pakai dynamic)
  RxList<dynamic> channels = <dynamic>[].obs;
  RxList<dynamic> joinedChannels = <dynamic>[].obs;
  RxList<dynamic> allChannels = <dynamic>[].obs;

  // === Realtime
  IO.Socket? _socket;
  RxInt currentOpenUserId = (-1).obs;
  RxInt currentOpenChannelId = (-1).obs;

  // === E2EE
  final GetStorage _box = GetStorage();
  final X25519 _x25519 = X25519();
  final AesGcm _aes = AesGcm.with256bits();
  final Random _rng = Random.secure();

  SimpleKeyPair? _myKeyPair; // private+public (local)
  final Map<int, SimplePublicKey> _peerPublicKeys = {}; // cache pubkey lawan
  final Map<int, SecretKey> _dmKeys = {}; // ⬅️ cache session key per user

  // --------- E2EE helpers ----------
  Future<void> _ensureMyKeyPair() async {
    if (_myKeyPair != null) return;

    final privB64 = _box.read('e2ee_priv') as String?;
    final pubB64 = _box.read('e2ee_pub') as String?;

    if (privB64 != null && pubB64 != null) {
      final priv = base64Decode(privB64);
      final pub = base64Decode(pubB64);
      _myKeyPair = SimpleKeyPairData(
        priv,
        publicKey: SimplePublicKey(pub, type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );
    } else {
      final kp = await _x25519.newKeyPair();
      final priv = await kp.extractPrivateKeyBytes();
      final pub = await kp.extractPublicKey();
      _box.write('e2ee_priv', base64Encode(priv));
      _box.write('e2ee_pub', base64Encode(pub.bytes));
      _myKeyPair = SimpleKeyPairData(
        priv,
        publicKey: SimplePublicKey(pub.bytes, type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );
      // upload public key ke server (idempotent)
      try {
        await _apiService.savePublicKey(base64Encode(pub.bytes));
      } catch (_) {}
    }
  }

  /// Pastikan keypair ada & public key selalu ter-upload (kalau server hilang data).
  Future<void> ensureE2EEReady() async {
    await _ensureMyKeyPair();
    final pubB64 = _box.read('e2ee_pub') as String?;
    if (pubB64 != null) {
      try {
        await _apiService.savePublicKey(pubB64);
      } catch (_) {}
    }
  }

  Future<SimplePublicKey> _ensurePeerPublicKey(int userId) async {
    final cached = _peerPublicKeys[userId];
    if (cached != null) return cached;

    final res = await _apiService.getUserPublicKey(userId);
    final b64 = res['public_key'] as String?;
    if (b64 == null) {
      throw Exception('Public key user $userId belum tersedia');
    }
    final pk = SimplePublicKey(base64Decode(b64), type: KeyPairType.x25519);
    _peerPublicKeys[userId] = pk;
    return pk;
  }

  List<int> _randBytes(int n) =>
      List<int>.generate(n, (_) => _rng.nextInt(256));

  /// Derive & cache session key untuk DM dgn user tertentu (hemat CPU).
  Future<SecretKey> _getDmKey(int peerUserId) async {
    final existing = _dmKeys[peerUserId];
    if (existing != null) return existing;

    await _ensureMyKeyPair();
    final peer = await _ensurePeerPublicKey(peerUserId);

    final shared = await _x25519.sharedSecretKey(
      keyPair: _myKeyPair!,
      remotePublicKey: peer,
    );

    final sharedBytes = await shared.extractBytes();
    final info = utf8.encode('chatapp:e2ee:v1');
    final digest = await Sha256().hash([...sharedBytes, ...info]);
    final key = SecretKey(digest.bytes); // 32 bytes AES-256

    _dmKeys[peerUserId] = key;
    return key;
  }

  Future<String> _encryptForUser(String plaintext, int peerUserId) async {
    final key = await _getDmKey(peerUserId);
    final nonce = _randBytes(12); // 96-bit nonce AES-GCM
    final box = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );
    return 'enc:v1:aesgcm:${base64Encode(nonce)}:${base64Encode(box.cipherText)}:${base64Encode(box.mac.bytes)}';
  }

  Future<String?> _decryptWithKey(String? enc, SecretKey key) async {
    if (enc == null) return null;
    if (!enc.startsWith('enc:v1:')) return enc;

    final parts = enc.split(':'); // enc:v1:aesgcm:nonce:ct:mac
    if (parts.length != 6 || parts[2] != 'aesgcm') return enc;

    final nonce = base64Decode(parts[3]);
    final ct = base64Decode(parts[4]);
    final mac = base64Decode(parts[5]);

    try {
      final clear = await _aes.decrypt(
        SecretBox(ct, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
      return utf8.decode(clear);
    } catch (_) {
      return '[Encrypted]';
    }
  }

  Future<String?> _decryptFromUser(String? enc, int peerUserId) async {
    final key = await _getDmKey(peerUserId);
    return _decryptWithKey(enc, key);
  }

  // =========================
  // ⬅️ NEW: Home Screen Support Methods
  // =========================

  /// Load all users to populate allUsers list (needed for home screen)
  Future<void> loadAllUsers() async {
    try {
      print('DEBUG: Loading all users...');

      // Try the new endpoint first
      try {
        final response = await _apiService.getAllUsers();
        if (response['users'] != null) {
          allUsers.value =
              (response['users'] as List).map((u) => User.fromJson(u)).toList();
          print('DEBUG: Loaded ${allUsers.length} users from /api/users/all');
          return;
        }
      } catch (e) {
        print('DEBUG: /api/users/all endpoint failed: $e');
      }

      // Fallback to regular users endpoint
      try {
        final response = await _apiService.getUsers();
        if (response['users'] != null) {
          allUsers.value =
              (response['users'] as List).map((u) => User.fromJson(u)).toList();
          print(
              'DEBUG: Loaded ${allUsers.length} users from /api/users fallback');
          return;
        }
      } catch (e) {
        print('DEBUG: /api/users fallback failed: $e');
      }

      // Last resort: use contacts
      await loadAddedContacts();
      allUsers.value = addedContacts.toList();
      print('DEBUG: Using ${allUsers.length} users from contacts as fallback');
    } catch (e) {
      print('DEBUG: Error in loadAllUsers: $e');
      // Make sure we have some users for the UI
      allUsers.value = addedContacts.toList();
    }
  }

  /// Load all messages for home screen (to show chat history)
  Future<void> loadAllMessages() async {
    try {
      print('DEBUG: Loading all messages...');
      isLoading.value = true;

      final currentUserId = _authController.currentUser.value?.id;
      if (currentUserId == null) {
        print('DEBUG: currentUserId is null, cannot load messages');
        isLoading.value = false;
        return;
      }

      // Try the new endpoint first
      try {
        final response = await _apiService.getAllMessages();
        if (response['messages'] != null) {
          final rawMessages = response['messages'] as List;
          print(
              'DEBUG: Got ${rawMessages.length} messages from /api/messages/all');

          // Process and decrypt messages
          final processedMessages =
              await _processMessages(rawMessages, currentUserId);
          messages.value = processedMessages;
          print('DEBUG: Processed ${messages.length} messages successfully');
          return;
        }
      } catch (e) {
        print('DEBUG: /api/messages/all endpoint failed: $e');
      }

      // Fallback: load messages for each contact individually
      print('DEBUG: Trying fallback method - loading messages per contact');
      List<Message> allMessages = [];

      for (var contact in addedContacts) {
        try {
          final response =
              await _apiService.getMessages(receiverId: contact.id);
          if (response['messages'] != null) {
            final contactMessages = response['messages'] as List;
            final processed =
                await _processMessages(contactMessages, currentUserId);
            allMessages.addAll(processed);
            print(
                'DEBUG: Loaded ${processed.length} messages for contact ${contact.fullName}');
          }
        } catch (e) {
          print(
              'DEBUG: Failed to load messages for contact ${contact.fullName}: $e');
        }
      }

      // Sort by timestamp
      allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      messages.value = allMessages;
      print('DEBUG: Fallback method loaded ${messages.length} total messages');
    } catch (e) {
      print('DEBUG: Error in loadAllMessages: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Process and decrypt messages
  Future<List<Message>> _processMessages(
      List<dynamic> rawMessages, int currentUserId) async {
    final futures = rawMessages.map((m) async {
      try {
        final raw = Map<String, dynamic>.from(m);
        final senderId = raw['sender_id'] as int?;
        final receiverId = raw['receiver_id'] as int?;
        final channelId = raw['channel_id'] as int?;

        // Only decrypt DM messages (not channel messages)
        if (channelId == null && senderId != null && receiverId != null) {
          final peerId = senderId == currentUserId ? receiverId : senderId;
          try {
            final key = await _getDmKey(peerId);
            raw['text'] = await _decryptWithKey(raw['text'] as String?, key);
          } catch (e) {
            print('DEBUG: Failed to decrypt message ${raw['id']}: $e');
            raw['text'] = '[Encrypted]';
          }
        }

        return Message.fromJson(raw);
      } catch (e) {
        print('DEBUG: Failed to process message: $e');
        // Return a dummy message to prevent crashes
        return Message(
          id: 0,
          senderId: 0,
          senderFullName: 'Unknown',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
    }).toList();

    final processedMessages = await Future.wait(futures);

    // Filter out dummy messages
    return processedMessages.where((msg) => msg.id != 0).toList();
  }

  /// Mark messages as read with better error handling
  Future<void> markMessagesAsRead(int userId) async {
    try {
      // Try the new endpoint first
      try {
        await _apiService.markMessagesAsRead(userId);
        print('DEBUG: Marked messages as read for user $userId');
      } catch (e) {
        print('DEBUG: markMessagesAsRead endpoint failed: $e');
        // Continue with local update anyway
      }

      // Update local messages to mark as read
      bool hasUpdates = false;
      for (var i = 0; i < messages.length; i++) {
        final msg = messages[i];
        if (msg.senderId == userId &&
            msg.receiverId == _authController.currentUser.value?.id &&
            !msg.isRead) {
          messages[i] = msg.copyWith(isRead: true);
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        messages.refresh();
        print(
            'DEBUG: Updated local read status for messages from user $userId');
      }
    } catch (e) {
      print('DEBUG: Error in markMessagesAsRead: $e');
    }
  }

  // =========================
  // ⬅️ UPDATED: Lifecycle
  // =========================
  @override
  void onInit() {
    super.onInit();
    print('DEBUG: ChatController onInit called');

    // Load initial data
    loadAddedContacts();

    // Connect socket and load data when user is available
    ever(_authController.currentUser, (u) async {
      if (u != null) {
        print('DEBUG: User available, setting up E2EE and loading data');
        await ensureE2EEReady();
        _connectSocket(u.id);

        // Load data in sequence
        await loadAllUsers();
        await loadAllMessages();
        print('DEBUG: Initial data loading complete');
      }
    });

    // If user is already available, set up immediately
    final me = _authController.currentUser.value;
    if (me != null) {
      print('DEBUG: User already available, setting up immediately');
      ensureE2EEReady();
      _connectSocket(me.id);

      // Load data
      Future.delayed(Duration(milliseconds: 500), () async {
        await loadAllUsers();
        await loadAllMessages();
        print('DEBUG: Delayed data loading complete');
      });
    }
  }

  // =========================
  // ⬅️ UPDATED: Add contact method with better integration
  // =========================
  Future<void> addContact(String username) async {
    if (username.trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Please enter a username',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[400],
        colorText: Colors.white,
      );
      return;
    }
    try {
      isAddingContact.value = true;
      final searchResponse = await _apiService.searchUserByUsername(username);
      if (searchResponse['user'] == null) {
        Get.snackbar(
          'Error',
          'User not found',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[400],
          colorText: Colors.white,
        );
        return;
      }
      final user = User.fromJson(searchResponse['user']);
      if (addedContacts.any((c) => c.id == user.id)) {
        Get.snackbar(
          'Info',
          'Contact already exists',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange[400],
          colorText: Colors.white,
        );
        return;
      }
      final addResponse = await _apiService.addContact(user.id);
      if (addResponse['message'] != null) {
        addedContacts.add(user);

        // Also add to allUsers if not already there
        if (!allUsers.any((u) => u.id == user.id)) {
          allUsers.add(user);
        }

        print('DEBUG: Added contact ${user.fullName} (id: ${user.id})');

        Get.snackbar(
          'Success',
          'Contact added successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green[400],
          colorText: Colors.white,
          icon: const Icon(Icons.check_circle, color: Colors.white),
        );
      }
    } catch (e) {
      print('DEBUG: Error adding contact: $e');
      Get.snackbar(
        'Error',
        'Failed to add contact: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[400],
        colorText: Colors.white,
      );
    } finally {
      isAddingContact.value = false;
    }
  }

  // =========================
  // ⬅️ UPDATED: Socket connection with better error handling
  // =========================
  void _connectSocket(int myUserId) {
    if (_socket != null && _socket!.connected) {
      print('DEBUG: Socket already connected');
      return;
    }

    final socketHost = ApiService.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    print('DEBUG: Connecting to socket at $socketHost');

    _socket = IO.io(
      socketHost,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      print('DEBUG: Socket connected');
      _socket!.emit('join_user_room', myUserId);
    });

    _socket!.on('new_message', (data) {
      try {
        print('DEBUG: Received new_message via socket');
        final Map<String, dynamic> raw = Map<String, dynamic>.from(data);
        final int me = _authController.currentUser.value!.id;

        final int? senderId = raw['sender_id'] as int?;
        final int? receiverId = raw['receiver_id'] as int?;
        final int? channelId = raw['channel_id'] as int?;

        if (channelId == null && senderId != null && receiverId != null) {
          final peerId = senderId == me ? receiverId : senderId;
          _getDmKey(peerId!).then((key) async {
            raw['text'] = await _decryptWithKey(raw['text'] as String?, key);
            messages.add(Message.fromJson(raw));
            print('DEBUG: Added decrypted DM message');
          }).catchError((e) {
            print('DEBUG: Failed to decrypt socket message: $e');
            raw['text'] = '[Encrypted]';
            messages.add(Message.fromJson(raw));
          });
        } else {
          messages.add(Message.fromJson(raw));
          print('DEBUG: Added channel message');
        }
      } catch (e) {
        print('DEBUG: Error processing socket new_message: $e');
      }
    });

    _socket!.on('messages_read', (data) {
      try {
        print('DEBUG: Received messages_read notification');
        final Map<String, dynamic> readData = Map<String, dynamic>.from(data);
        final int readerId = readData['reader_id'];

        // Find and update messages that were read
        bool hasUpdates = false;
        for (var i = 0; i < messages.length; i++) {
          final msg = messages[i];
          if (msg.receiverId == readerId &&
              msg.senderId == _authController.currentUser.value?.id &&
              !msg.isRead) {
            messages[i] = msg.copyWith(isRead: true);
            hasUpdates = true;
          }
        }

        if (hasUpdates) {
          messages.refresh();
          print('DEBUG: Updated read status for messages to user $readerId');
        }
      } catch (e) {
        print('DEBUG: Error processing messages_read: $e');
      }
    });

    _socket!.onDisconnect((_) => print('DEBUG: Socket disconnected'));

    _socket!.onConnectError(
        (error) => print('DEBUG: Socket connection error: $error'));

    _socket!.connect();
  }

  // panggil dari ChatScreen saat buka DM
  void setActiveUserChat(int userId) {
    if (currentOpenChannelId.value != -1) {
      _socket?.emit('leave_channel_room', currentOpenChannelId.value);
    }
    currentOpenChannelId.value = -1;
    currentOpenUserId.value = userId;
    // pre-warm session key supaya kirim pertama tidak lag
    _getDmKey(userId);
    // Mark messages as read when opening chat
    markMessagesAsRead(userId);
  }

  // panggil dari ChatScreen saat buka Channel
  void setActiveChannelChat(int channelId) {
    currentOpenUserId.value = -1;
    if (currentOpenChannelId.value != -1 &&
        currentOpenChannelId.value != channelId) {
      _socket?.emit('leave_channel_room', currentOpenChannelId.value);
    }
    currentOpenChannelId.value = channelId;
    _socket?.emit('join_channel_room', channelId);
  }

  // panggil dari ChatScreen.dispose()
  void clearActiveChat() {
    if (currentOpenChannelId.value != -1) {
      _socket?.emit('leave_channel_room', currentOpenChannelId.value);
    }
    currentOpenUserId.value = -1;
    currentOpenChannelId.value = -1;
  }

  // =========================
  // Messages
  // =========================
  Future<void> loadMessagesForUser(int userId) async {
    final useSpinner = messages.isEmpty; // spinner cuma saat awal
    try {
      if (useSpinner) isLoadingMessages.value = true;

      // ❌ jangan clear agar UI gak flicker saat refresh berkala
      final response = await _apiService.getMessages(receiverId: userId);
      if (response['messages'] != null) {
        final key = await _getDmKey(userId); // derive sekali
        final futures = (response['messages'] as List).map((m) async {
          final raw = Map<String, dynamic>.from(m);
          raw['text'] = await _decryptWithKey(raw['text'] as String?, key);
          return Message.fromJson(raw);
        }).toList();

        final list = await Future.wait(futures);
        messages.value = list; // replace tanpa spinner flicker
      }
    } catch (e) {
      debugPrint('Error loading messages for user: $e');
      Get.snackbar(
        'Error',
        'Failed to load messages: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[400],
        colorText: Colors.white,
      );
    } finally {
      if (useSpinner) isLoadingMessages.value = false;
    }
  }

  Future<void> loadMessagesForChannel(int channelId) async {
    final useSpinner = messages.isEmpty; // spinner cuma saat awal
    try {
      if (useSpinner) isLoadingMessages.value = true;

      // ❌ jangan clear agar UI gak flicker saat refresh berkala
      final response = await _apiService.getMessages(channelId: channelId);
      if (response['messages'] != null) {
        messages.value = (response['messages'] as List)
            .map((m) => Message.fromJson(m))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading messages for channel: $e');
      Get.snackbar(
        'Error',
        'Failed to load messages: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[400],
        colorText: Colors.white,
      );
    } finally {
      if (useSpinner) isLoadingMessages.value = false;
    }
  }

  Future<void> sendMessageToUser(int userId, String? text,
      {String? imagePath}) async {
    try {
      String? payload = text;
      if (payload != null && payload.isNotEmpty) {
        // Pakai key yang sudah dicache (cepat)
        payload = await _encryptForUser(payload, userId);
      }

      final response = await _apiService.sendMessage(
        text: payload,
        receiverId: userId,
        imagePath: imagePath,
      );

      if (response['data'] != null) {
        final raw = Map<String, dynamic>.from(response['data']);
        // decrypt dgn key cache utk render cepat
        final key = await _getDmKey(userId);
        raw['text'] = await _decryptWithKey(raw['text'] as String?, key);
        messages.add(Message.fromJson(raw));
      }
    } catch (e) {
      debugPrint('Error sending message to user: $e');
      Get.snackbar(
        'Error',
        'Failed to send message: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[400],
        colorText: Colors.white,
      );
    }
  }

  Future<void> sendMessageToChannel(int channelId, String? text,
      {String? imagePath}) async {
    try {
      final response = await _apiService.sendMessage(
        text: text,
        channelId: channelId,
        imagePath: imagePath,
      );
      if (response['data'] != null) {
        messages.add(Message.fromJson(response['data']));
      }
    } catch (e) {
      debugPrint('Error sending message to channel: $e');
      Get.snackbar(
        'Error',
        'Failed to send message: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[400],
        colorText: Colors.white,
      );
    }
  }

  // =========================
  // Channels
  // =========================
  Future<void> loadChannels() async {
    try {
      isLoading.value = true;
      final response = await _apiService.getChannels();
      if (response['channels'] != null) {
        final channelsList = response['channels'] as List;
        channels.value = channelsList;
        allChannels.value = channelsList;
        joinedChannels.value =
            channelsList.where((ch) => ch['user_role'] != null).toList();
      }
    } catch (e) {
      debugPrint('Error loading channels: $e');
      Get.snackbar(
        'Error',
        'Failed to load channels: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[400],
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> createChannel(String name,
      {String? topic, bool isPublic = true}) async {
    try {
      final response = await _apiService.createChannel(name,
          topic: topic, isPublic: isPublic);
      if (response['channel_id'] != null) {
        await loadChannels();
        Get.snackbar(
          'Success',
          'Channel created',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green[400],
          colorText: Colors.white,
        );
      }
    } catch (e) {
      debugPrint('Error creating channel: $e');
      rethrow;
    }
  }

  Future<void> joinChannel(int channelId) async {
    try {
      final response = await _apiService.joinChannel(channelId);
      if (response['message'] != null) {
        final idxAll = allChannels.indexWhere((c) => c['id'] == channelId);
        if (idxAll != -1) {
          allChannels[idxAll]['user_role'] = 'member';
          if (!joinedChannels.any((c) => c['id'] == channelId)) {
            joinedChannels.add(allChannels[idxAll]);
          }
        }
        final idxMain = channels.indexWhere((c) => c['id'] == channelId);
        if (idxMain != -1) channels[idxMain]['user_role'] = 'member';
        channels.refresh();
        joinedChannels.refresh();
        allChannels.refresh();
      }
    } catch (e) {
      debugPrint('Error joining channel: $e');
      rethrow;
    }
  }

  void searchChannels(String query) {
    if (query.trim().isEmpty) {
      allChannels.value = channels;
      joinedChannels.value =
          channels.where((ch) => ch['user_role'] != null).toList();
      return;
    }
    final q = query.toLowerCase();
    final filtered = channels.where((ch) {
      final name = ch['name']?.toString().toLowerCase() ?? '';
      final topic = ch['topic']?.toString().toLowerCase() ?? '';
      return name.contains(q) || topic.contains(q);
    }).toList();
    allChannels.value = filtered;
    joinedChannels.value =
        filtered.where((ch) => ch['user_role'] != null).toList();
  }

  // =========================
  // Contacts
  // =========================
  Future<void> loadAddedContacts() async {
    try {
      isLoading.value = true;
      final response = await _apiService.getAddedContacts();
      if (response['contacts'] != null) {
        addedContacts.value = (response['contacts'] as List)
            .map((c) => User.fromJson(c))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading added contacts: $e');
      Get.snackbar(
        'Error',
        'Failed to load contacts: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[400],
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> searchUserByUsername(String username) async {
    if (username.trim().isEmpty) return;
    try {
      isSearching.value = true;
      searchResults.clear();
      final response = await _apiService.searchUserByUsername(username);
      if (response['user'] != null) {
        searchResults.add(User.fromJson(response['user']));
      }
    } catch (e) {
      debugPrint('Error searching user: $e');
      Get.snackbar(
        'Error',
        'User not found',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[400],
      );
    } finally {
      isSearching.value = false;
    }
  }

  void markVisibleMessagesAsRead() {
    final currentUserId = Get.find<AuthController>().currentUser.value?.id;
    if (currentUserId == null) return;

    final unreadMessages = messages
        .where((m) =>
            m.senderId != currentUserId && // not my message
            !m.isRead && // not read yet
            m.id != null) // has valid id
        .map((m) => m.id)
        .toList();

    // Mark messages as read for each sender (userId)
    final senderIds = messages
        .where((m) => m.senderId != currentUserId && !m.isRead && m.id != null)
        .map((m) => m.senderId)
        .toSet();

    for (var userId in senderIds) {
      markMessagesAsRead(userId);
    }
  }

  // Handle incoming read status updates from socket
  void handleMessageRead(Map<String, dynamic> data) {
    final messageId = data['message_id'];
    final readerId = data['reader_id'];

    // Find and update the message
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      messages[index] = messages[index].copyWith(isRead: true);
      messages.refresh();
    }
  }
}

  // Future<void> addContact(String username) async {
  //   if (username.trim().isEmpty) {
  //     Get.snackbar(
  //       'Error',
  //       'Please enter a username',
  //       snackPosition: SnackPosition.BOTTOM,
  //       backgroundColor: Colors.red[400],
  //       colorText: Colors.white,
  //     );
  //     return;
  //   }
  //   try {
  //     isAddingContact.value = true;
  //     final searchResponse = await _apiService.searchUserByUsername(username);
  //     if (searchResponse['user'] == null) {
  //       Get.snackbar(
  //         'Error',
  //         'User not found',
  //         snackPosition: SnackPosition.BOTTOM,
  //         backgroundColor: Colors.red[400],
  //         colorText: Colors.white,
  //       );
  //       return;
  //     }
  //     final user = User.fromJson(searchResponse['user']);
  //     if (addedContacts.any((c) => c.id == user.id)) {
  //       Get.snackbar(
  //         'Info',
  //         'Contact already exists',
  //         snackPosition: SnackPosition.BOTTOM,
  //         backgroundColor: Colors.orange[400],
  //         colorText: Colors.white,
  //       );
  //       return;
  //     }
  //     final addResponse = await _apiService.addContact(user.id);
  //     if (addResponse['message'] != null) {
  //       addedContacts.add(user);
  //       // Also add to allUsers if not already there
  //       if (!allUsers.any((u) => u.id == user.id)) {
  //         allUsers.add(user);
  //       }
  //       Get.snackbar(
  //         'Success',
  //         'Contact added successfully',
  //         snackPosition: SnackPosition.BOTTOM,
  //         backgroundColor: Colors.green[400],
  //         colorText: Colors.white,
  //         icon: const Icon(Icons.check_circle, color: Colors.white),
  //       );
  //     }
  //   } catch (e) {
  //     debugPrint('Error adding contact: $e');
  //     Get.snackbar(
  //       'Error',
  //       'Failed to add contact: ${e.toString()}',
  //       snackPosition: SnackPosition.BOTTOM,
  //       backgroundColor: Colors.red[400],
  //       colorText: Colors.white,
  //     );
  //   } finally {
  //     isAddingContact.value = false;
  //   }
  // }
