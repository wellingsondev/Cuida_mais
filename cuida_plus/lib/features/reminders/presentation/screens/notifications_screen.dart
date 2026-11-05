import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/common.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../providers/reminder_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider)!;
    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: AsyncBody(
        value: ref.watch(inboxProvider(uid)),
        onRetry: () => ref.invalidate(inboxProvider(uid)),
        builder: (list) => list.isEmpty
            ? const EmptyState(icon: Icons.notifications_none, title: 'Nenhuma notificação')
            : ListView(padding: const EdgeInsets.all(16), children: [
                for (final n in list)
                  Card(
                    child: ListTile(
                      leading: Icon(n.read ? Icons.notifications_none : Icons.notifications_active, color: n.read ? Colors.grey : Theme.of(context).colorScheme.primary),
                      title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.w700)),
                      subtitle: Text('${n.body}${n.createdAt == null ? '' : '\n${fmtDateTime(n.createdAt!)}'}'),
                      isThreeLine: n.createdAt != null,
                      onTap: n.read ? null : () => ref.read(notificationRepositoryProvider).markRead(n.id),
                    ),
                  ),
              ]),
      ),
    );
  }
}
