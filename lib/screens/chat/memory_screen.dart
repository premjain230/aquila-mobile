import 'package:flutter/material.dart';

import '../../services/memory_service.dart';
import '../../theme/aquila_theme.dart';
import '../../widgets/common.dart';

/// Manages Aquila's long-term memory. These entries are shared with the web
/// app and injected into every chat so Aquila remembers you across sessions.
class MemoryScreen extends StatefulWidget {
  final String uid;
  const MemoryScreen({super.key, required this.uid});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  List<MemoryItem>? _items;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await MemoryService.instance.load(widget.uid);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a memory'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          maxLength: 2000,
          decoration: const InputDecoration(
            hintText: 'e.g. I\'m preparing for JEE 2027 and find Chemistry hardest.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.isEmpty || !mounted) return;
    final ok = await MemoryService.instance.add(widget.uid, text);
    if (!mounted) return;
    showAquilaSnack(
      context,
      ok ? 'Saved to memory — Aquila will remember this.' : 'Could not save. Try again.',
      error: !ok,
    );
    await _load();
  }

  Future<void> _delete(MemoryItem item) async {
    await MemoryService.instance.remove(widget.uid, item.id);
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('AI Memory')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add memory',
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items == null || _items!.isEmpty
              ? _empty(ext)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: _items!.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final m = _items![i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ext.bgCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ext.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.bookmark_outline,
                              size: 18, color: ext.textSecondary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.text,
                                  style: TextStyle(
                                    fontFamily: AquilaColors.fontMain,
                                    fontSize: 13.5,
                                    height: 1.5,
                                    color: ext.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _relative(m.createdAt),
                                  style: TextStyle(
                                    fontFamily: AquilaColors.fontMono,
                                    fontSize: 10,
                                    color: ext.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Forget',
                            icon: Icon(Icons.close,
                                size: 18, color: ext.textSecondary),
                            onPressed: () => _delete(m),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _empty(AquilaThemeExt ext) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmarks_outlined, size: 48, color: ext.textMuted),
            const SizedBox(height: 12),
            Text(
              'No memories yet',
              style: TextStyle(
                fontFamily: AquilaColors.fontMain,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ext.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap + to save a fact or preference, or use "Remember this"\nunder an Aquila answer in Chat.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5, color: ext.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  String _relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}