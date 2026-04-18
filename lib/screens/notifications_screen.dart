import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final screenWidth = screenSize.width;
    final isSmallPhone = screenWidth < 360;
    final isTablet = screenWidth >= 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Notifications",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 22.0 : (isSmallPhone ? 16.0 : 18.0),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () async {
              await _notificationService.markAllAsRead();
            },
            child: Text(
              "Mark all read",
              style: TextStyle(
                fontSize: isSmallPhone ? 11 : 13,
                color: const Color(0xFFE53935),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _notificationService.getUserNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE53935)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "Error: ${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: isTablet ? 80 : 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No notifications yet",
                    style: TextStyle(
                      fontSize: isTablet ? 20 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "You'll see updates about your requests here",
                    style: TextStyle(
                      fontSize: isTablet ? 15 : 13,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: 12,
            ),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final isRead = data['read'] == true;
              final title = data['title'] ?? 'Notification';
              final body = data['body'] ?? '';
              final type = data['type'] ?? '';
              final createdAt = data['createdAt'] as Timestamp?;

              String timeAgo = '';
              if (createdAt != null) {
                final diff = DateTime.now().difference(createdAt.toDate());
                if (diff.inMinutes < 1) {
                  timeAgo = 'Just now';
                } else if (diff.inMinutes < 60) {
                  timeAgo = '${diff.inMinutes}m ago';
                } else if (diff.inHours < 24) {
                  timeAgo = '${diff.inHours}h ago';
                } else {
                  timeAgo = '${diff.inDays}d ago';
                }
              }

              IconData icon;
              Color iconColor;
              Color iconBg;
              switch (type) {
                case 'request_submitted':
                  icon = Icons.send_rounded;
                  iconColor = Colors.orange;
                  iconBg = Colors.orange.shade50;
                  break;
                case 'mechanic_assigned':
                  icon = Icons.person_pin_rounded;
                  iconColor = Colors.blue;
                  iconBg = Colors.blue.shade50;
                  break;
                case 'request_completed':
                  icon = Icons.check_circle_rounded;
                  iconColor = Colors.green;
                  iconBg = Colors.green.shade50;
                  break;
                default:
                  icon = Icons.notifications_rounded;
                  iconColor = const Color(0xFFE53935);
                  iconBg = Colors.red.shade50;
              }

              return GestureDetector(
                onTap: () {
                  if (!isRead) {
                    _notificationService.markAsRead(doc.id);
                  }
                },
                child: Container(
                  padding: EdgeInsets.all(isTablet ? 18 : 14),
                  decoration: BoxDecoration(
                    color: isRead
                        ? Theme.of(context).cardColor
                        : Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isRead
                          ? Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.1)
                          : Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.2),
                    ),
                    boxShadow: isRead
                        ? null
                        : const [
                            BoxShadow(
                              color: Color.fromRGBO(229, 57, 53, 0.06),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: iconBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: iconColor,
                          size: isTablet ? 24 : 20,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: isTablet ? 16 : 14,
                                      fontWeight: isRead
                                          ? FontWeight.w500
                                          : FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE53935),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              body,
                              style: TextStyle(
                                fontSize: isTablet ? 14 : 12,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              timeAgo,
                              style: TextStyle(
                                fontSize: isTablet ? 13 : 11,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
