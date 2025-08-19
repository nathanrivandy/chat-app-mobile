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

  // DEDUPE UI (anti bubble dobel dari HTTP + socket)
  List<Message> _dedupeMessages(List<Message> source) {
    final seen = <int>{};
    final out = <Message>[];
    for (final m in source) {
      final id = m.id;
      if (id is int) {
        if (seen.add(id)) out.add(m);
      } else {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
    final colorScheme = Theme.of(context).colorScheme;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Select Image',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  color: colorScheme.primary,
                  onTap: () {
                    Get.back();
                    _takePicture();
                  },
                ),
                _buildImageOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  color: colorScheme.tertiary,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: Obx(() {
              final visibleMessages = _dedupeMessages(_chatController.messages);

              if (_chatController.isLoadingMessages.value &&
                  visibleMessages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator.adaptive(),
                      const SizedBox(height: 16),
                      Text(
                        'Loading messages...',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
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
                      visibleMessages,
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
    final colorScheme = Theme.of(context).colorScheme;
    
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios, color: colorScheme.onSurface),
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
                          ? LinearGradient(
                              colors: [
                                colorScheme.primary,
                                colorScheme.tertiary,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                    ),
                    child: widget.user!.profilePhotoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              'http://103.123.18.29:6969${widget.user!.profilePhotoUrl}',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.person, color: colorScheme.onPrimary),
                            ),
                          )
                        : Icon(Icons.person, color: colorScheme.onPrimary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user!.fullName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.green.shade400,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Online • Credit: ${widget.user!.creditScore}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
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
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.tag, color: colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Text(
                  '#${widget.channel!.name}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
      actions: [
        IconButton(
          icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 60,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.user != null
                  ? 'Start a conversation with ${widget.user!.fullName}'
                  : 'No messages in #${widget.channel!.name} yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Send a message to get the conversation started!',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
        ),
        child: Row(
          children: [
            IconButton.filled(
              onPressed: _showImagePickerDialog,
              icon: const Icon(Icons.add_photo_alternate),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              child: IconButton.filled(
                onPressed: () {
                  final text = _messageController.text.trim();
                  if (text.isEmpty) {
                    _showImagePickerDialog();
                  } else {
                    _sendMessage();
                  }
                },
                icon: const Icon(Icons.send),
                style: IconButton.styleFrom(
                  backgroundColor: (_messageController.text.trim().isNotEmpty)
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHigh,
                  foregroundColor: (_messageController.text.trim().isNotEmpty)
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
      Message message, bool isMe, int index, List<Message> listForContext) {
    final colorScheme = Theme.of(context).colorScheme;
    final showAvatar = !isMe &&
        widget.channel != null &&
        (index == 0 || listForContext[index - 1].senderId != message.senderId);

    return Container(
      key: ValueKey('bubble_${message.id ?? index}'),
      margin: EdgeInsets.only(
        bottom: 8,
        left: isMe ? 64 : 0,
        right: isMe ? 0 : 64,
      ),
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
                      gradient: LinearGradient(
                        colors: [colorScheme.primary, colorScheme.tertiary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.person,
                      color: colorScheme.onPrimary,
                      size: 18,
                    ),
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? LinearGradient(
                            colors: [colorScheme.primary, colorScheme.tertiary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isMe ? null : colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.imageUrl != null)
                        Container(
                          margin: EdgeInsets.only(
                            bottom: (message.text != null && message.text!.isNotEmpty) ? 8 : 0,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              'http://103.123.18.29:6969${message.imageUrl}',
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return SizedBox(
                                  height: 150,
                                  child: Center(
                                    child: CircularProgressIndicator.adaptive(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isMe ? colorScheme.onPrimary : colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.broken_image,
                                          color: colorScheme.onErrorContainer,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Image not available',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onErrorContainer,
                                          ),
                                        ),
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
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isMe ? colorScheme.onPrimary : colorScheme.onSurface,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 12, right: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      // Read indicator untuk pesan yang saya kirim
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead ? Icons.done_all : Icons.done,
                          size: 16,
                          color: message.isRead
                              ? Colors.green.shade400
                              : colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
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