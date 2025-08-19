// screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'channels_screen.dart';
import 'package:rive/rive.dart' as rive;

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final ChatController _chatController = Get.put(ChatController());
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    ContactsTab(),
    ChannelsScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
        indicatorColor: Theme.of(context).colorScheme.secondaryContainer,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Channels',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class ContactsTab extends StatelessWidget {
  final ChatController _chatController = Get.find<ChatController>();
  final TextEditingController _searchController = TextEditingController();

  _showRive(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        content: SizedBox(
          width: 300,
          height: 300,
          child: rive.RiveAnimation.network(
            "https://github.com/nathanrivandy/chat-app-mobile/raw/refs/heads/main/assets/animation/face_id_animation.riv",
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        title: Text(
          'Chats',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            margin: EdgeInsets.all(16),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search chats...',
              leading: Icon(Icons.search),
              trailing: [
                IconButton(
                  icon: Icon(Icons.person_add_outlined),
                  onPressed: () => _showAddContactDialog(context),
                  style: IconButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                  ),
                ),
              ],
              backgroundColor: WidgetStatePropertyAll(
                colorScheme.surfaceContainerHigh,
              ),
              elevation: WidgetStatePropertyAll(0),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onChanged: (value) {
                // Implement search functionality
              },
            ),
          ),

          // Chat List
          Expanded(
            child: Obx(() {
              if (_chatController.isLoading.value) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator.adaptive(),
                      SizedBox(height: 16),
                      Text(
                        'Loading chats...',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Get all chat participants (users who have chatted OR contacts without messages)
              final chatParticipants = _getChatParticipants();

              if (chatParticipants.isEmpty) {
                return Center(
                  child: Container(
                    padding: EdgeInsets.all(32),
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
                        SizedBox(height: 24),
                        Text(
                          'No chats yet',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Start a conversation by adding contacts',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 32),
                        FilledButton.icon(
                          onPressed: () => _showAddContactDialog(context),
                          icon: Icon(Icons.person_add),
                          label: Text('Add Contact'),
                          style: FilledButton.styleFrom(
                            minimumSize: Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: chatParticipants.length,
                itemBuilder: (context, index) {
                  final chatData = chatParticipants[index];
                  final user = chatData['user'];
                  final lastMessage = chatData['lastMessage'];
                  final unreadCount = chatData['unreadCount'];
                  final timestamp = chatData['timestamp'];

                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    color: colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(16),
                      leading: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: user.profilePhotoUrl == null
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
                        child: user.profilePhotoUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  'http://103.123.18.29:6969${user.profilePhotoUrl}',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.person,
                                      color: colorScheme.onPrimary,
                                      size: 28,
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.person,
                                color: colorScheme.onPrimary,
                                size: 28,
                              ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.fullName,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (timestamp != null)
                            Text(
                              _formatTimestamp(timestamp),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 4),
                          Text(
                            '@${user.username}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lastMessage ?? 'No messages yet',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (unreadCount > 0) ...[
                                SizedBox(width: 8),
                                Badge(
                                  label: Text('$unreadCount'),
                                  backgroundColor: colorScheme.error,
                                  textColor: colorScheme.onError,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getCreditScoreColor(user.creditScore, colorScheme),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${user.creditScore}',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(height: 4),
                          Icon(
                            Icons.chevron_right,
                            color: colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ],
                      ),
                      onTap: () {
                        Get.to(
                          () => ChatScreen(user: user),
                          transition: Transition.rightToLeft,
                          duration: Duration(milliseconds: 300),
                        );
                      },
                      onLongPress: () {
                        _showReputationDialog(context, user.id, user.fullName);
                      },
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRive(context),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        child: Icon(Icons.person_add),
        tooltip: 'Add Contact',
      ),
    );
  }

  // Method untuk mendapatkan chat participants dengan contacts yang belum pernah chat
  List<Map<String, dynamic>> _getChatParticipants() {
    final currentUserId = Get.find<AuthController>().currentUser.value?.id;
    if (currentUserId == null) {
      print('DEBUG: currentUserId is null');
      return [];
    }

    print('DEBUG: currentUserId = $currentUserId');
    print('DEBUG: messages.length = ${_chatController.messages.length}');
    print('DEBUG: addedContacts.length = ${_chatController.addedContacts.length}');

    Map<int, Map<String, dynamic>> chatMap = {};

    // STEP 1: Tambahkan semua contacts terlebih dahulu
    for (var contact in _chatController.addedContacts) {
      if (contact.id != currentUserId) {
        chatMap[contact.id] = {
          'user': contact,
          'lastMessage': null,
          'timestamp': null,
          'unreadCount': 0,
        };
        print('DEBUG: Added contact ${contact.fullName} without messages');
      }
    }

    // STEP 2: Update dengan data dari messages (jika ada)
    for (var message in _chatController.messages) {
      print('DEBUG: Processing message - id: ${message.id}, senderId: ${message.senderId}, receiverId: ${message.receiverId}, channelId: ${message.channelId}, isRead: ${message.isRead}');

      // Skip channel messages - we only want DM messages
      if (message.channelId != null) {
        print('DEBUG: Skipping channel message');
        continue;
      }

      int? otherUserId;
      dynamic otherUser;

      if (message.senderId == currentUserId && message.receiverId != null) {
        // Current user sent this message to someone
        otherUserId = message.receiverId;
        print('DEBUG: Current user sent message to $otherUserId');
      } else if (message.receiverId == currentUserId && message.senderId != null) {
        // Current user received this message from someone
        otherUserId = message.senderId;
        print('DEBUG: Current user received message from $otherUserId');
      } else {
        print('DEBUG: Message does not involve current user');
        continue; // Message doesn't involve current user
      }

      if (otherUserId == null) {
        print('DEBUG: otherUserId is null, skipping');
        continue;
      }

      // Find the other user - first check if already in chatMap
      if (chatMap.containsKey(otherUserId)) {
        otherUser = chatMap[otherUserId]!['user'];
        print('DEBUG: Found user in chatMap: ${otherUser.fullName} (id: ${otherUser.id})');
      } else {
        // Try to find in allUsers list
        try {
          otherUser = _chatController.allUsers.firstWhere(
            (user) => user.id == otherUserId,
          );
          print('DEBUG: Found user in allUsers: ${otherUser.fullName} (id: ${otherUser.id})');
        } catch (e) {
          print('DEBUG: User with id $otherUserId not found in allUsers list');

          // Try to find in addedContacts as fallback
          try {
            otherUser = _chatController.addedContacts.firstWhere(
              (user) => user.id == otherUserId,
            );
            print('DEBUG: Found user in contacts: ${otherUser.fullName} (id: ${otherUser.id})');
          } catch (e2) {
            print('DEBUG: User with id $otherUserId not found in contacts either, skipping');
            continue;
          }
        }

        // Add to chatMap if not already there
        chatMap[otherUserId] = {
          'user': otherUser,
          'lastMessage': null,
          'timestamp': null,
          'unreadCount': 0,
        };
        print('DEBUG: Added user to chatMap: ${otherUser.fullName}');
      }

      // Update with message data
      final currentTimestamp = chatMap[otherUserId]!['timestamp'] as DateTime?;
      if (currentTimestamp == null || message.timestamp.isAfter(currentTimestamp)) {
        chatMap[otherUserId]!['lastMessage'] = message.content;
        chatMap[otherUserId]!['timestamp'] = message.timestamp;
        print('DEBUG: Updated latest message for user ${otherUser.fullName}: ${message.content}');
      }

      // Count unread messages correctly - only messages received by current user that are not read
      if (message.receiverId == currentUserId && !message.isRead) {
        int currentCount = chatMap[otherUserId]!['unreadCount'] as int;
        chatMap[otherUserId]!['unreadCount'] = currentCount + 1;
        print('DEBUG: Incremented unread count for user ${otherUser.fullName} to ${currentCount + 1}');
      }
    }

    // Convert to list and sort - contacts with messages first (by timestamp), then contacts without messages (by name)
    List<Map<String, dynamic>> chatList = chatMap.values.toList();

    chatList.sort((a, b) {
      final aTimestamp = a['timestamp'] as DateTime?;
      final bTimestamp = b['timestamp'] as DateTime?;

      // Both have messages - sort by timestamp (most recent first)
      if (aTimestamp != null && bTimestamp != null) {
        return bTimestamp.compareTo(aTimestamp);
      }

      // One has messages, one doesn't - messages first
      if (aTimestamp != null && bTimestamp == null) {
        return -1;
      }
      if (aTimestamp == null && bTimestamp != null) {
        return 1;
      }

      // Both don't have messages - sort by name
      final aUser = a['user'];
      final bUser = b['user'];
      return aUser.fullName.compareTo(bUser.fullName);
    });

    print('DEBUG: Final chat list length: ${chatList.length}');
    for (var chat in chatList) {
      print('DEBUG: Chat with ${chat['user'].fullName} - lastMessage: ${chat['lastMessage']} - unreadCount: ${chat['unreadCount']} - timestamp: ${chat['timestamp']}');
    }

    return chatList;
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      // Today - show time
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      // This week - show day name
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[timestamp.weekday - 1];
    } else {
      // Older - show date
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _showAddContactDialog(BuildContext context) {
    final TextEditingController usernameController = TextEditingController();
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.person_add,
                color: colorScheme.onPrimaryContainer,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Text(
              'Add Contact',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter username to add as contact',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 24),
            TextField(
              controller: usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                prefixText: '@',
                prefixStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (usernameController.text.trim().isNotEmpty) {
                _chatController.addContact(usernameController.text.trim());
                Get.back();
              }
            },
            child: Text('Add Contact'),
          ),
        ],
      ),
    );
  }

  Color _getCreditScoreColor(int score, ColorScheme colorScheme) {
    if (score >= 150) return Colors.green.shade600;
    if (score >= 100) return colorScheme.primary;
    if (score >= 50) return Colors.orange.shade600;
    return colorScheme.error;
  }

  void _showReputationDialog(BuildContext context, int userId, String userName) {
    final TextEditingController reasonController = TextEditingController();
    final colorScheme = Theme.of(context).colorScheme;
    int selectedDelta = 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: colorScheme.surfaceTint,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.star_rate,
                  color: colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Rate $userName',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How would you rate this user\'s attitude?',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildRatingChip(
                    context: context,
                    label: 'Toxic',
                    icon: Icons.thumb_down,
                    value: -5,
                    color: colorScheme.error,
                    isSelected: selectedDelta == -5,
                    onTap: () => setState(() => selectedDelta = -5),
                  ),
                  _buildRatingChip(
                    context: context,
                    label: 'Poor',
                    icon: Icons.sentiment_dissatisfied,
                    value: -1,
                    color: Colors.orange.shade600,
                    isSelected: selectedDelta == -1,
                    onTap: () => setState(() => selectedDelta = -1),
                  ),
                  _buildRatingChip(
                    context: context,
                    label: 'Good',
                    icon: Icons.sentiment_satisfied,
                    value: 1,
                    color: colorScheme.primary,
                    isSelected: selectedDelta == 1,
                    onTap: () => setState(() => selectedDelta = 1),
                  ),
                  _buildRatingChip(
                    context: context,
                    label: 'Excellent',
                    icon: Icons.thumb_up,
                    value: 5,
                    color: Colors.green.shade600,
                    isSelected: selectedDelta == 5,
                    onTap: () => setState(() => selectedDelta = 5),
                  ),
                ],
              ),
              SizedBox(height: 20),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                // TODO: Implement reputation submission
                // _chatController.submitReputation(
                //   userId,
                //   selectedDelta,
                //   reasonController.text.isEmpty
                //       ? 'No reason provided'
                //       : reasonController.text,
                // );
                Get.back();
              },
              child: Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingChip({
    required BuildContext context,
    required String label,
    required IconData icon,
    required int value,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? colorScheme.onSecondaryContainer : color,
          ),
          SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isSelected ? colorScheme.onSecondaryContainer : color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: color.withOpacity(0.1),
      selectedColor: colorScheme.secondaryContainer,
      checkmarkColor: colorScheme.onSecondaryContainer,
      side: BorderSide(
        color: isSelected ? Colors.transparent : color,
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}