import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../navigation/app_routes.dart';

class UserMessagesAction extends StatelessWidget {
  const UserMessagesAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Сообщения',
      onPressed: () {
        context.push(AppRoutes.conversations);
      },
      icon: const Icon(Icons.chat_bubble_outline_rounded),
    );
  }
}