import 'package:flutter/material.dart';

import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../theme/aquila_theme.dart';

/// Past conversations list. Tapping a session returns it via `Navigator.pop`
/// so the caller can resume it; swiping/menu deletes it.
class ChatHistoryScreen extends StatefulWidget {
  final String uid;
  const ChatHistoryScreen({super.key, required this.uid});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Chat history')),
      body: StreamBuilder<List<ChatSession>>(
        stream: ChatService.instance.sessionsStream(widget.uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(
                'Could not load your history.',
                style: TextStyle(color: ext.textSecondary),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sessions = snap.data!;
          if (sessions.isEmpty) return _emptyState(ext);
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: sessions.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, indent: 16, endIndent: 16, color: ext.border),
            itemBuilder: (context, i) {
              final s = sessions[i];
              return ListTile(
                leading: Icon(Icons.forum_outlined, color: ext.textSecondary),
                title: Text(
                  s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AquilaColors.fontMain,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _relative(s.updatedAt),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: IconButton(
                  tooltip: 'Delete',
                  icon: Icon(Icons.delete_outline,
                      size: 20, color: ext.textSecondary),
                  onPressed: () => _delete(s),
                ),
                onTap: () => Navigator.of(context).pop(s),
              );
            },
          );
        },
      ),
    );
  }

  Widget _emptyState(AquilaThemeExt ext) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: ext.textMuted),
            const SizedBox(height: 12),
            Text(
              'No past chats yet',
              style: TextStyle(
                fontFamily: AquilaColors.fontMain,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ext.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your conversations will appear here so you can reopen them anytime.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: ext.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  String _relative(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  Future<void> _delete(ChatSession s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this chat?'),
        content: Text(
          '“${s.title}” and all its messages will be permanently removed.',
          style: const TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ChatService.instance.deleteSession(widget.uid, s.id);
    }
  }
}