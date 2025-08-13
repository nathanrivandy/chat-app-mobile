// screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'channels_screen.dart';

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
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF6C5CE7),
          unselectedItemColor: Colors.grey[600],
          selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.group_outlined),
              activeIcon: Icon(Icons.group),
              label: 'Channels',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class ContactsTab extends StatelessWidget {
  final ChatController _chatController = Get.find<ChatController>();
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Chats',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Color(0xFFF1F3F4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.logout_outlined, color: Colors.grey[700]),
              onPressed: () {
                Get.find<AuthController>().logout();
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search chats...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                suffixIcon: IconButton(
                  icon:
                      Icon(Icons.person_add_outlined, color: Color(0xFF6C5CE7)),
                  onPressed: () => _showAddContactDialog(context),
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
                      Container(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF6C5CE7),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading chats...',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
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
                            color: Color(0xFF6C5CE7).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(60),
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline,
                            size: 60,
                            color: Color(0xFF6C5CE7),
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'No chats yet',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Start a conversation by adding contacts',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 32),
                        Container(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () => _showAddContactDialog(context),
                            icon: Icon(Icons.person_add, color: Colors.white),
                            label: Text(
                              'Add Contact',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF6C5CE7),
                              elevation: 0,
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

              return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: chatParticipants.length,
                itemBuilder: (context, index) {
                  final chatData = chatParticipants[index];
                  final user = chatData['user'];
                  final lastMessage = chatData['lastMessage'];
                  final unreadCount = chatData['unreadCount'];
                  final timestamp = chatData['timestamp'];

                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
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
                                    Color(0xFF6C5CE7),
                                    Color(0xFFA29BFE),
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
                                  'http://192.168.74.174:6969${user.profilePhotoUrl}',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 28,
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 28,
                              ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.fullName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          if (timestamp != null)
                            Text(
                              _formatTimestamp(timestamp),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
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
                            style: TextStyle(
                              color: Color(0xFF6C5CE7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lastMessage ?? 'No messages yet',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (unreadCount > 0) ...[
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF6C5CE7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$unreadCount',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
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
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getCreditScoreColor(user.creditScore),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _getCreditScoreColor(user.creditScore)
                                      .withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '${user.creditScore}',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          SizedBox(height: 4),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey[400],
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
    );
  }

  // ⬅️ UPDATED: Method untuk mendapatkan chat participants dengan contacts yang belum pernah chat
  List<Map<String, dynamic>> _getChatParticipants() {
    final currentUserId = Get.find<AuthController>().currentUser.value?.id;
    if (currentUserId == null) {
      print('DEBUG: currentUserId is null');
      return [];
    }

    print('DEBUG: currentUserId = $currentUserId');
    print('DEBUG: messages.length = ${_chatController.messages.length}');
    print(
        'DEBUG: addedContacts.length = ${_chatController.addedContacts.length}');

    Map<int, Map<String, dynamic>> chatMap = {};

    // ⬅️ STEP 1: Tambahkan semua contacts terlebih dahulu
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

    // ⬅️ STEP 2: Update dengan data dari messages (jika ada)
    for (var message in _chatController.messages) {
      print(
          'DEBUG: Processing message - id: ${message.id}, senderId: ${message.senderId}, receiverId: ${message.receiverId}, channelId: ${message.channelId}, isRead: ${message.isRead}');

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
      } else if (message.receiverId == currentUserId &&
          message.senderId != null) {
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
        print(
            'DEBUG: Found user in chatMap: ${otherUser.fullName} (id: ${otherUser.id})');
      } else {
        // Try to find in allUsers list
        try {
          otherUser = _chatController.allUsers.firstWhere(
            (user) => user.id == otherUserId,
          );
          print(
              'DEBUG: Found user in allUsers: ${otherUser.fullName} (id: ${otherUser.id})');
        } catch (e) {
          print('DEBUG: User with id $otherUserId not found in allUsers list');

          // Try to find in addedContacts as fallback
          try {
            otherUser = _chatController.addedContacts.firstWhere(
              (user) => user.id == otherUserId,
            );
            print(
                'DEBUG: Found user in contacts: ${otherUser.fullName} (id: ${otherUser.id})');
          } catch (e2) {
            print(
                'DEBUG: User with id $otherUserId not found in contacts either, skipping');
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
      if (currentTimestamp == null ||
          message.timestamp.isAfter(currentTimestamp)) {
        chatMap[otherUserId]!['lastMessage'] = message.content;
        chatMap[otherUserId]!['timestamp'] = message.timestamp;
        print(
            'DEBUG: Updated latest message for user ${otherUser.fullName}: ${message.content}');
      }

      // ⬅️ FIXED: Count unread messages correctly - only messages received by current user that are not read
      if (message.receiverId == currentUserId && !message.isRead) {
        int currentCount = chatMap[otherUserId]!['unreadCount'] as int;
        chatMap[otherUserId]!['unreadCount'] = currentCount + 1;
        print(
            'DEBUG: Incremented unread count for user ${otherUser.fullName} to ${currentCount + 1}');
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
      print(
          'DEBUG: Chat with ${chat['user'].fullName} - lastMessage: ${chat['lastMessage']} - unreadCount: ${chat['unreadCount']} - timestamp: ${chat['timestamp']}');
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFF6C5CE7).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.person_add,
                color: Color(0xFF6C5CE7),
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Add Contact',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter username to add as contact',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                prefixText: '@',
                prefixStyle: TextStyle(
                  color: Color(0xFF6C5CE7),
                  fontWeight: FontWeight.bold,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Color(0xFF6C5CE7),
                    width: 2,
                  ),
                ),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (usernameController.text.trim().isNotEmpty) {
                _chatController.addContact(usernameController.text.trim());
                Get.back();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6C5CE7),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Add Contact',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCreditScoreColor(int score) {
    if (score >= 150) return Color(0xFF00D4AA);
    if (score >= 100) return Color(0xFF0984E3);
    if (score >= 50) return Color(0xFFE17055);
    return Color(0xFFE74C3C);
  }

  void _showReputationDialog(
      BuildContext context, int userId, String userName) {
    final TextEditingController reasonController = TextEditingController();
    int selectedDelta = 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF6C5CE7).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.star_rate,
                  color: Color(0xFF6C5CE7),
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Rate $userName',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
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
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildRatingChip(
                    label: 'Toxic',
                    icon: Icons.thumb_down,
                    value: -5,
                    color: Color(0xFFE74C3C),
                    isSelected: selectedDelta == -5,
                    onTap: () => setState(() => selectedDelta = -5),
                  ),
                  _buildRatingChip(
                    label: 'Poor',
                    icon: Icons.sentiment_dissatisfied,
                    value: -1,
                    color: Color(0xFFE17055),
                    isSelected: selectedDelta == -1,
                    onTap: () => setState(() => selectedDelta = -1),
                  ),
                  _buildRatingChip(
                    label: 'Good',
                    icon: Icons.sentiment_satisfied,
                    value: 1,
                    color: Color(0xFF0984E3),
                    isSelected: selectedDelta == 1,
                    onTap: () => setState(() => selectedDelta = 1),
                  ),
                  _buildRatingChip(
                    label: 'Excellent',
                    icon: Icons.thumb_up,
                    value: 5,
                    color: Color(0xFF00D4AA),
                    isSelected: selectedDelta == 5,
                    onTap: () => setState(() => selectedDelta = 5),
                  ),
                ],
              ),
              SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Color(0xFF6C5CE7),
                      width: 2,
                    ),
                  ),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6C5CE7),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Submit',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingChip({
    required String label,
    required IconData icon,
    required int value,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color,
            width: isSelected ? 0 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : color,
              size: 16,
            ),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
