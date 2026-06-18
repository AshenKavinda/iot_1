import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/history_provider.dart';
import 'providers/status_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[FIREBASE] Initializing with platform: ${DefaultFirebaseOptions.currentPlatform.projectId}');
  debugPrint('[FIREBASE] Database URL: ${DefaultFirebaseOptions.currentPlatform.databaseURL}');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[FIREBASE] Initialized successfully');
  } catch (e, stack) {
    debugPrint('[FIREBASE] Initialization FAILED: $e');
    debugPrint('[FIREBASE] Stack: $stack');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StatusProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
      ],
      child: const WaterFillApp(),
    ),
  );
}

class WaterFillApp extends StatelessWidget {
  const WaterFillApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Water Tank Monitor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    DashboardScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
