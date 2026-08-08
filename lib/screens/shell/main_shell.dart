import 'package:flutter/material.dart';

import '../../services/update_service.dart';
import '../../theme/aquila_theme.dart';
import '../../widgets/common.dart';
import '../analyze/analyze_screen.dart';
import '../chat/chat_screen.dart';
import '../planner/planner_screen.dart';
import '../profile/profile_screen.dart';
import '../quiz/quiz_screen.dart';
import '../referral/referral_screen.dart';
import '../settings/about_screen.dart';
import '../settings/settings_screen.dart';
import '../subscription/subscription_screen.dart';

/// Root logged-in scaffold: bottom navigation switching between the primary
/// tools (Chat, Planner, Quiz, Analyze, Profile) the way the web sidebar does.
class MainShell extends StatefulWidget {
  final String uid;
  const MainShell({super.key, required this.uid});

  static final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    try {
      final info = await UpdateService.instance.check();
      if (!mounted) return;
      if (info.requirement == UpdateRequirement.required) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Update required'),
            content: Text(
              'A newer version of Aquila is required to keep studying.\n\n'
              '${info.notes ?? 'Tap below to download the latest version.'}',
            ),
            actions: [
              TextButton(
                onPressed: () => UpdateService.instance
                    .openDownload(info.downloadUrl),
                child: const Text('Update now'),
              ),
            ],
          ),
        );
      } else if (info.requirement == UpdateRequirement.available) {
        showAquilaSnack(context, 'A new version is available — update in Settings.');
      }
    } catch (_) {
      // Silent: offline / endpoint missing is not an error state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AquilaThemeExt.of(context);
    final screens = [
      ChatScreen(uid: widget.uid),
      PlannerScreen(uid: widget.uid),
      QuizScreen(uid: widget.uid),
      AnalyzeScreen(uid: widget.uid),
      ProfileScreen(uid: widget.uid),
    ];

    return Scaffold(
      key: MainShell.scaffoldKey,
      drawer: _buildDrawer(ext),
      body: IndexedStack(
        index: _index,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: ext.bgSidebar,
          border: Border(top: BorderSide(color: ext.border)),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            backgroundColor: ext.bgSidebar,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AquilaColors.accent,
            unselectedItemColor: ext.textSecondary,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            selectedLabelStyle: const TextStyle(
              fontFamily: AquilaColors.fontMain,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(fontFamily: AquilaColors.fontMain),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline),
                activeIcon: Icon(Icons.chat_bubble),
                label: 'Chat',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month_outlined),
                activeIcon: Icon(Icons.calendar_month),
                label: 'Plan',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.quiz_outlined),
                activeIcon: Icon(Icons.quiz),
                label: 'Quiz',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.insights_outlined),
                activeIcon: Icon(Icons.insights),
                label: 'Analyze',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sidebar drawer (menu), fully implemented with the settings/subscription/
  /// referral/about screens later; kept here for navigation.
  Widget _buildDrawer(AquilaThemeExt ext) {
    return Drawer(
      backgroundColor: ext.bgSidebar,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
            child: Row(
              children: [
                const AquilaLogo(size: 40),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Aquila AI',
                    style: TextStyle(
                      fontFamily: AquilaColors.fontMain,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Chat'),
            onTap: () {
              setState(() => _index = 0);
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Planner'),
            onTap: () {
              setState(() => _index = 1);
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.quiz_outlined),
            title: const Text('Quiz'),
            onTap: () {
              setState(() => _index = 2);
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.insights_outlined),
            title: const Text('Analyze'),
            onTap: () {
              setState(() => _index = 3);
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            onTap: () {
              setState(() => _index = 4);
              Navigator.of(context).pop();
            },
          ),
          const Divider(),
          _drawerMenuTile(Icons.settings_outlined, 'Settings', () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsScreen(uid: widget.uid),
              ),
            );
          }),
          _drawerMenuTile(Icons.workspace_premium, 'Subscription', () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SubscriptionScreen(uid: widget.uid),
              ),
            );
          }),
          _drawerMenuTile(Icons.link, 'Referrals', () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReferralScreen(uid: widget.uid),
              ),
            );
          }),
          _drawerMenuTile(Icons.info_outline, 'About', () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            );
          }),
        ],
      ),
    );
  }

  Widget _drawerMenuTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      onTap: onTap,
    );
  }
}