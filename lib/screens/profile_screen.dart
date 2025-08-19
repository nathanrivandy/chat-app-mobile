import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthController _authController = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Obx(() {
          final user = _authController.currentUser.value;
          
          if (user == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator.adaptive(
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading profile...',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              // Custom App Bar with Profile Header
              SliverAppBar(
                expandedHeight: 300,
                floating: false,
                pinned: true,
                backgroundColor: colorScheme.surface,
                foregroundColor: colorScheme.onSurface,
                elevation: 0,
                actions: [
                  Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Card(
                      elevation: 0,
                      color: colorScheme.errorContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          _showLogoutDialog(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.logout_rounded,
                            color: colorScheme.onErrorContainer,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colorScheme.primaryContainer,
                          colorScheme.surface,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 80),
                        
                        // Profile Avatar with Status Ring
                        Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primary,
                                    colorScheme.tertiary,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withOpacity(0.3),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(4),
                              child: CircleAvatar(
                                radius: 48,
                                backgroundImage: user.profilePhotoUrl != null
                                    ? NetworkImage('http://localhost:3000${user.profilePhotoUrl}')
                                    : null,
                                backgroundColor: colorScheme.surfaceContainerHighest,
                                child: user.profilePhotoUrl == null
                                    ? Icon(
                                        Icons.person_rounded,
                                        size: 42,
                                        color: colorScheme.onSurfaceVariant,
                                      )
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colorScheme.surface,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        SizedBox(height: 12),
                        
                        // Name and Username
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            user.fullName,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        
                        SizedBox(height: 4),
                        
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '@${user.username}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Profile Content
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Credit Score Card
                    _buildCreditScoreCard(context, user.creditScore),
                    
                    SizedBox(height: 16),
                    
                    // Contact Information Card
                    if (user.phone != null || user.email != null)
                      _buildContactCard(context, user),
                    
                    if (user.phone != null || user.email != null)
                      SizedBox(height: 16),
                    
                    // Settings and Actions
                    _buildSettingsCard(context),
                    
                    SizedBox(height: 16),
                    
                    // Security Card
                    _buildSecurityCard(context),
                  ]),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCreditScoreCard(BuildContext context, int creditScore) {
    final colorScheme = Theme.of(context).colorScheme;
    final scoreColor = _getCreditScoreColor(creditScore);
    final scoreLabel = _getCreditScoreLabel(creditScore);
    final progressValue = (creditScore / 200).clamp(0.0, 1.0);
    
    return Card(
      elevation: 0,
      color: colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.star_rounded,
                    color: scoreColor,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Credit Score',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                      Text(
                        scoreLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scoreColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$creditScore',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                    Text(
                      '/ 200',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSecondaryContainer.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Progress bar
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: colorScheme.onSecondaryContainer.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                widthFactor: progressValue,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [scoreColor.withOpacity(0.7), scoreColor],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(BuildContext context, user) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.contacts_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Contact Information',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            if (user.phone != null)
              _buildContactRow(
                context,
                Icons.phone_rounded,
                'Phone Number',
                user.phone!,
                colorScheme.secondaryContainer,
                colorScheme.onSecondaryContainer,
              ),
            
            if (user.phone != null && user.email != null)
              SizedBox(height: 12),
            
            if (user.email != null)
              _buildContactRow(
                context,
                Icons.email_rounded,
                'Email Address',
                user.email!,
                colorScheme.secondaryContainer,
                colorScheme.onSecondaryContainer,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color bgColor,
    Color textColor,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: textColor.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.copy_rounded,
            color: textColor.withOpacity(0.5),
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.settings_rounded,
                    color: colorScheme.onSecondaryContainer,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Account Settings',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            _buildSettingItem(
              context,
              Icons.edit_rounded,
              'Edit Profile',
              'Update your personal information',
              () {},
            ),
            
            SizedBox(height: 12),
            
            _buildSettingItem(
              context,
              Icons.notifications_rounded,
              'Notifications',
              'Manage notification preferences',
              () {},
            ),
            
            SizedBox(height: 12),
            
            _buildSettingItem(
              context,
              Icons.privacy_tip_rounded,
              'Privacy Settings',
              'Control your privacy and data',
              () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      elevation: 0,
      color: colorScheme.tertiaryContainer,
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
                color: colorScheme.tertiary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.security_rounded,
                color: colorScheme.onTertiary,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Security',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your account is secured with advanced biometric authentication and end-to-end encryption.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onTertiaryContainer.withOpacity(0.8),
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

  void _showLogoutDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.logout_rounded,
              color: colorScheme.error,
              size: 24,
            ),
            SizedBox(width: 12),
            Text(
              'Sign Out',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out of your account?',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _authController.logout();
            },
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            child: Text(
              'Sign Out',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCreditScoreColor(int score) {
    if (score >= 150) return Colors.green;
    if (score >= 100) return Colors.blue;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  String _getCreditScoreLabel(int score) {
    if (score >= 150) return 'Excellent';
    if (score >= 100) return 'Good';
    if (score >= 50) return 'Fair';
    return 'Poor';
  }

  @override
  void dispose() {
    super.dispose();
  }
}