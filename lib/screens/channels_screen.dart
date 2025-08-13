import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/chat_controller.dart';
import 'chat_screen.dart';

class ChannelsScreen extends StatefulWidget {
  @override
  _ChannelsScreenState createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen>
    with TickerProviderStateMixin {
  final ChatController _chatController = Get.find<ChatController>();
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _chatController.loadChannels();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildJoinedChannels(),
                _buildAllChannels(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      title: Text(
        'Channels',
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
            icon: Icon(Icons.refresh, color: Colors.grey[700]),
            onPressed: () {
              _chatController.loadChannels();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
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
          hintText: 'Search channels...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
        ),
        onChanged: (value) {
          // Implement search functionality
          _chatController.searchChannels(value);
        },
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        labelStyle: TextStyle(fontWeight: FontWeight.w600),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group, size: 18),
                SizedBox(width: 8),
                Text('Joined'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.explore, size: 18),
                SizedBox(width: 8),
                Text('Discover'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinedChannels() {
    return Obx(() {
      final joinedChannels = _chatController.joinedChannels;

      if (_chatController.isLoading.value) {
        return _buildLoadingState();
      }

      if (joinedChannels.isEmpty) {
        return _buildEmptyState(
          icon: Icons.group_outlined,
          title: 'No joined channels',
          subtitle: 'Join channels to start chatting',
          action: 'Discover Channels',
          onAction: () => _tabController.animateTo(1),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: joinedChannels.length,
        itemBuilder: (context, index) {
          final channel = joinedChannels[index];
          return _buildChannelCard(channel, isJoined: true);
        },
      );
    });
  }

  Widget _buildAllChannels() {
    return Obx(() {
      final allChannels = _chatController.allChannels;

      if (_chatController.isLoading.value) {
        return _buildLoadingState();
      }

      if (allChannels.isEmpty) {
        return _buildEmptyState(
          icon: Icons.explore_outlined,
          title: 'No channels available',
          subtitle: 'Create the first channel for your community',
          action: 'Create Channel',
          onAction: () => _showCreateChannelDialog(context),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: allChannels.length,
        itemBuilder: (context, index) {
          final channel = allChannels[index];
          return _buildChannelCard(channel, isJoined: false);
        },
      );
    });
  }

  Widget _buildChannelCard(dynamic channel, {required bool isJoined}) {
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
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isJoined
              ? () {
                  Get.to(
                    () => ChatScreen(channel: channel),
                    transition: Transition.rightToLeft,
                    duration: Duration(milliseconds: 300),
                  );
                }
              : null,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Channel Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _getChannelGradient(channel.name),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _getChannelIcon(channel),
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),

                // Channel Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '#${channel.name}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isJoined) ...[
                            SizedBox(width: 8),
                            _buildRoleBadge(channel.userRole ?? 'member'),
                          ],
                        ],
                      ),
                      if (channel.topic != null &&
                          channel.topic!.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          channel.topic!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${channel.memberCount ?? 0} members',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(width: 12),
                          if (channel.creatorUsername != null) ...[
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'by ${channel.creatorUsername}',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Action Button
                if (isJoined)
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                  )
                else
                  Container(
                    child: ElevatedButton(
                      onPressed: () => _joinChannel(channel),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF6C5CE7),
                        elevation: 0,
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Join',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    String label;
    IconData icon;

    switch (role.toLowerCase()) {
      case 'owner':
        color = Color(0xFFE74C3C);
        label = 'Owner';
        icon = Icons.star;
        break;
      case 'admin':
      case 'mod':
        color = Color(0xFFE17055);
        label = 'Admin';
        icon = Icons.admin_panel_settings;
        break;
      default:
        color = Color(0xFF00D4AA);
        label = 'Member';
        icon = Icons.person;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getChannelGradient(String channelName) {
    final colors = [
      [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
      [Color(0xFF00D4AA), Color(0xFF74B9FF)],
      [Color(0xFFE17055), Color(0xFFFFB8B8)],
      [Color(0xFF0984E3), Color(0xFF81ECEC)],
      [Color(0xFFE84393), Color(0xFFFFCCE5)],
    ];

    final index = channelName.hashCode.abs() % colors.length;
    return colors[index];
  }

  IconData _getChannelIcon(dynamic channel) {
    if (channel.isPublic == false) return Icons.lock;
    return Icons.tag;
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C5CE7)),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Loading channels...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String action,
    required VoidCallback onAction,
  }) {
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
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF6C5CE7).withOpacity(0.1),
                    Color(0xFFA29BFE).withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                icon,
                size: 60,
                color: Color(0xFF6C5CE7),
              ),
            ),
            SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              subtitle,
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
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6C5CE7),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  action,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () => _showCreateChannelDialog(context),
      backgroundColor: Color(0xFF6C5CE7),
      child: Icon(Icons.add, color: Colors.white),
    );
  }

  Future<void> _joinChannel(dynamic channel) async {
    try {
      await _chatController.joinChannel(channel.id);
      Get.snackbar(
        'Success',
        'Joined #${channel.name} successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green[400],
        colorText: Colors.white,
        icon: Icon(Icons.check_circle, color: Colors.white),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to join channel: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[400],
        colorText: Colors.white,
      );
    }
  }

  void _showCreateChannelDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController topicController = TextEditingController();
    bool isPublic = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF6C5CE7).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.add_box,
                  color: Color(0xFF6C5CE7),
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Create Channel',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Channel Name',
                    prefixText: '#',
                    prefixStyle: TextStyle(
                      color: Color(0xFF6C5CE7),
                      fontWeight: FontWeight.bold,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Color(0xFF6C5CE7), width: 2),
                    ),
                  ),
                  textCapitalization: TextCapitalization.none,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: topicController,
                  decoration: InputDecoration(
                    labelText: 'Topic (optional)',
                    hintText: 'What is this channel about?',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Color(0xFF6C5CE7), width: 2),
                    ),
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      isPublic ? Icons.public : Icons.lock,
                      color: Color(0xFF6C5CE7),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isPublic ? 'Public Channel' : 'Private Channel',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    Switch(
                      value: isPublic,
                      onChanged: (value) => setState(() => isPublic = value),
                      activeColor: Color(0xFF6C5CE7),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  isPublic
                      ? 'Anyone can join and see the channel content'
                      : 'Only invited members can join and see the content',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  _createChannel(
                    nameController.text.trim(),
                    topicController.text.trim().isEmpty
                        ? null
                        : topicController.text.trim(),
                    isPublic,
                  );
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
              child: Text('Create', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createChannel(String name, String? topic, bool isPublic) async {
    try {
      await _chatController.createChannel(name,
          topic: topic, isPublic: isPublic);
      Get.snackbar(
        'Success',
        'Channel #$name created successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green[400],
        colorText: Colors.white,
        icon: Icon(Icons.check_circle, color: Colors.white),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to create channel: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[400],
        colorText: Colors.white,
      );
    }
  }
}
