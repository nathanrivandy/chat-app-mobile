import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/chat_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/user.dart';
import '../models/message.dart';
import '../models/channel.dart';

class ChatScreen extends StatefulWidget {
  final User? user;
  final Channel? channel;

  const ChatScreen({Key? key, this.user, this.channel}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final ChatController _chatController = Get.find<ChatController>();
  final AuthController _authController = Get.find<AuthController>();
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isTyping = false;
  Timer? _readMarkTimer;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );

    // Load messages sesuai tipe chat
    if (widget.user != null) {
      _chatController.setActiveUserChat(widget.user!.id);
      _chatController.loadMessagesForUser(widget.user!.id);
    } else if (widget.channel != null) {
      _chatController.setActiveChannelChat(widget.channel!.id);
      _chatController.loadMessagesForChannel(widget.channel!.id);
    }

    // Auto scroll saat ada pesan baru
    ever(_chatController.messages, (_) {
      _scrollToBottom();
    });

    _messageController.addListener(() {
      final nowTyping = _messageController.text.isNotEmpty;
      if (nowTyping != _isTyping) {
        setState(() => _isTyping = nowTyping);
      }
    });

    _readMarkTimer?.cancel();
    _readMarkTimer = Timer(const Duration(milliseconds: 800), () {
      _chatController.markVisibleMessagesAsRead();
    });
  }

  // ---- DEDUPE UI (anti bubble dobel dari HTTP + socket) ----
  List<Message> _dedupeMessages(List<Message> source) {
    final seen = <int>{};
    final out = <Message>[];
    for (final m in source) {
      final id = m.id; // asumsikan Message.id itu int
      if (id is int) {
        if (seen.add(id)) out.add(m);
      } else {
        // kalau (sangat jarang) id null, tetap tampilkan
        out.add(m);
      }
    }
    return out;
  }

  Future<void> _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 50));
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _sendMessage({String? imagePath}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && imagePath == null) return;

    // animasi klik
    _animationController.forward().then((_) => _animationController.reverse());

    try {
      if (widget.user != null) {
        await _chatController.sendMessageToUser(
          widget.user!.id,
          text.isEmpty ? null : text,
          imagePath: imagePath,
        );
      } else if (widget.channel != null) {
        await _chatController.sendMessageToChannel(
          widget.channel!.id,
          text.isEmpty ? null : text,
          imagePath: imagePath,
        );
      }

      // bersihkan input & scroll
      _messageController.clear();
      setState(() => _isTyping = false);
      await _scrollToBottom();

      // ❌ jangan refresh manual
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to send message: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[400],
        colorText: Colors.white,
      );
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (image != null) {
      await _sendMessage(imagePath: image.path);
    }
  }

  Future<void> _takePicture() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (image != null) {
      await _sendMessage(imagePath: image.path);
    }
  }

  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text('Select Image',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  color: const Color(0xFF6C5CE7),
                  onTap: () {
                    Get.back();
                    _takePicture();
                  },
                ),
                _buildImageOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  color: const Color(0xFF00D4AA),
                  onTap: () {
                    Get.back();
                    _pickImage();
                  },
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildImageOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: Obx(() {
              // gunakan list yang sudah di-dedupe untuk render
              final visibleMessages = _dedupeMessages(_chatController.messages);

              if (_chatController.isLoadingMessages.value &&
                  visibleMessages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(Color(0xFF6C5CE7)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Loading messages...',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 16)),
                    ],
                  ),
                );
              }

              if (visibleMessages.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: visibleMessages.length,
                itemBuilder: (context, index) {
                  final message = visibleMessages[index];
                  final meId = _authController.currentUser.value?.id;
                  final isMe = meId != null && message.senderId == meId;

                  return KeyedSubtree(
                    key: ValueKey(message.id ?? 'i$index'),
                    child: _buildMessageBubble(
                      message,
                      isMe,
                      index,
                      visibleMessages, // <-- pakai list dedupe untuk konteks
                    ),
                  );
                },
              );
            }),
          ),

          // Message input
          _buildMessageInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
        onPressed: () => Get.back(),
      ),
      title: widget.user != null
          ? Row(
              children: [
                Hero(
                  tag: 'avatar_${widget.user!.id}',
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: widget.user!.profilePhotoUrl == null
                          ? const LinearGradient(
                              colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                    ),
                    child: widget.user!.profilePhotoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              'http://192.168.74.174:6969${widget.user!.profilePhotoUrl}',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.person, color: Colors.white),
                            ),
                          )
                        : const Icon(Icons.person, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.user!.fullName,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      Row(
                        children: [
                          Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(4))),
                          const SizedBox(width: 6),
                          Text('Online • Credit: ${widget.user!.creditScore}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.tag, color: Color(0xFF6C5CE7)),
                ),
                const SizedBox(width: 12),
                Text('#${widget.channel!.name}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ],
            ),
      actions: [
        IconButton(
          icon: Icon(Icons.more_vert, color: Colors.grey[700]),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6C5CE7).withOpacity(0.1),
                  const Color(0xFFA29BFE).withOpacity(0.1)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(Icons.chat_bubble_outline,
                size: 60, color: Color(0xFF6C5CE7)),
          ),
          const SizedBox(height: 24),
          Text(
            widget.user != null
                ? 'Start a conversation with ${widget.user!.fullName}'
                : 'No messages in #${widget.channel!.name} yet',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text('Send a message to get the conversation started!',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // --- di dalam _buildMessageInput() ---
  Widget _buildMessageInput() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _showImagePickerDialog,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.add_photo_alternate,
                  color: Color(0xFF6C5CE7),
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F4),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                final text = _messageController.text.trim();
                if (text.isEmpty) {
                  _showImagePickerDialog();
                } else {
                  _sendMessage();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: (_messageController.text.trim().isNotEmpty)
                        ? const [Color(0xFF6C5CE7), Color(0xFFA29BFE)]
                        : [Colors.grey[400]!, Colors.grey[500]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: (_messageController.text.trim().isNotEmpty)
                      ? [
                          BoxShadow(
                            color: const Color(0xFF6C5CE7).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ⬇️ tambahkan parameter 'listForContext' agar hitung showAvatar konsisten dengan list dedupe
  Widget _buildMessageBubble(
      Message message, bool isMe, int index, List<Message> listForContext) {
    final showAvatar = !isMe &&
        widget.channel != null &&
        (index == 0 || listForContext[index - 1].senderId != message.senderId);

    return Container(
      key: ValueKey('bubble_${message.id ?? index}'),
      margin:
          EdgeInsets.only(bottom: 8, left: isMe ? 50 : 0, right: isMe ? 0 : 50),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe && widget.channel != null) ...[
            showAvatar
                ? Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child:
                        const Icon(Icons.person, color: Colors.white, size: 18),
                  )
                : const SizedBox(width: 40),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && widget.channel != null && showAvatar)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 4),
                    child: Text(
                      message.senderFullName,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6C5CE7),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? const LinearGradient(
                            colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isMe ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isMe
                            ? const Color(0xFF6C5CE7).withOpacity(0.3)
                            : Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.imageUrl != null)
                        Container(
                          margin: EdgeInsets.only(
                              bottom: (message.text != null &&
                                      message.text!.isNotEmpty)
                                  ? 8
                                  : 0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              'http://192.168.74.174:6969${message.imageUrl}',
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return SizedBox(
                                  height: 150,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          isMe
                                              ? Colors.white
                                              : const Color(0xFF6C5CE7)),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 150,
                                  decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.broken_image,
                                            color: Colors.grey[400], size: 32),
                                        const SizedBox(height: 8),
                                        Text('Image not available',
                                            style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      if (message.text != null && message.text!.isNotEmpty)
                        Text(
                          message.text!,
                          style: TextStyle(
                              color: isMe ? Colors.white : Colors.black87,
                              fontSize: 15,
                              height: 1.4),
                        ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.only(top: 4, left: 12, right: 8),
                      child: Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ),
                    // Read indicator untuk pesan yang saya kirim
                    if (isMe)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(
                          message.isRead ? Icons.done_all : Icons.done,
                          size: 14,
                          color: message.isRead
                              ? const Color(
                                  0xFF00D4AA) // hijau untuk sudah dibaca
                              : Colors.grey[400], // abu-abu untuk terkirim
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  void dispose() {
    _readMarkTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    _chatController.clearActiveChat();
    super.dispose();
  }
}
