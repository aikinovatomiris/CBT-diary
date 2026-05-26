import 'package:flutter/material.dart';

class UserMessagesAction extends StatelessWidget {
  const UserMessagesAction({super.key});

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Сообщения будут доступны позже'),
      ),
    );

    // TODO:
    // Когда появятся ConversationService и routes для сообщений:
    // context.push(AppRoutes.conversations);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Сообщения',
      onPressed: () => _showComingSoon(context),
      icon: const Icon(Icons.chat_bubble_outline_rounded),
    );
  }
}