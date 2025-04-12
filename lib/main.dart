import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dangerous Permissions Viewer',
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        dialogTheme: DialogTheme(
          backgroundColor: Colors.grey[900],
          titleTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          contentTextStyle: const TextStyle(color: Colors.white),
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const platform = MethodChannel('permission_channel');
  List<Map<String, dynamic>> userApps = [];
  List<Map<String, dynamic>> systemApps = [];
  List<Map<String, dynamic>> unknownSourceApps = [];

  final List<String> dangerousPermissions = [
    "android.permission.READ_CALENDAR",
    "android.permission.WRITE_CALENDAR",
    "android.permission.CAMERA",
    "android.permission.READ_CONTACTS",
    "android.permission.WRITE_CONTACTS",
    "android.permission.GET_ACCOUNTS",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.RECORD_AUDIO",
    "android.permission.READ_PHONE_STATE",
    "android.permission.READ_PHONE_NUMBERS",
    "android.permission.CALL_PHONE",
    "android.permission.ANSWER_PHONE_CALLS",
    "android.permission.READ_CALL_LOG",
    "android.permission.WRITE_CALL_LOG",
    "android.permission.ADD_VOICEMAIL",
    "android.permission.USE_SIP",
    "android.permission.PROCESS_OUTGOING_CALLS",
    "android.permission.BODY_SENSORS",
    "android.permission.SEND_SMS",
    "android.permission.RECEIVE_SMS",
    "android.permission.READ_SMS",
    "android.permission.RECEIVE_WAP_PUSH",
    "android.permission.RECEIVE_MMS",
    "android.permission.READ_EXTERNAL_STORAGE",
    "android.permission.WRITE_EXTERNAL_STORAGE",
  ];

  @override
  void initState() {
    super.initState();
    _getInstalledApps();
  }

  Future<void> _getInstalledApps() async {
    try {
      final List<dynamic> result = await platform.invokeMethod('getInstalledApps');
      List<Map<String, dynamic>> apps = List<Map<String, dynamic>>.from(result.map((app) => Map<String, dynamic>.from(app)));

      List<Map<String, dynamic>> filteredUserApps = [];
      List<Map<String, dynamic>> filteredSystemApps = [];

      for (var app in apps) {
        String packageName = app['packageName'];
        bool isSystemApp = app['isSystemApp'];
        List<dynamic> permissions = app['permissions'] ?? [];

        bool hasDangerousPermission = permissions.any((perm) => dangerousPermissions.contains(perm));
        if (!hasDangerousPermission) continue;

        if (!isSystemApp && !packageName.startsWith('android.') && !packageName.startsWith('com.google.android.')) {
          filteredUserApps.add(app);
        } else {
          filteredSystemApps.add(app);
        }
      }

      setState(() {
        userApps = filteredUserApps;
        systemApps = filteredSystemApps;
      });
    } on PlatformException catch (e) {
      print("Failed to get installed apps: '${e.message}'");
    }
  }

  Future<void> _checkUnknownSources() async {
    try {
      final List<dynamic> result = await platform.invokeMethod('getInstalledApps');
      List<Map<String, dynamic>> apps = List<Map<String, dynamic>>.from(result.map((app) => Map<String, dynamic>.from(app)));
      List<Map<String, dynamic>> unknownApps = [];

      for (var app in apps) {
        String installer = app['installer'] ?? "";
        bool isSystemApp = app['isSystemApp'] ?? false;

        if (!isSystemApp && (installer.isEmpty || !installer.contains("com.android.vending"))) {
          unknownApps.add(app);
        }
      }

      setState(() {
        unknownSourceApps = unknownApps;
      });

      _showUnknownSourcesDialog();
    } on PlatformException catch (e) {
      print("Error: '${e.message}'");
    }
  }

  void _showUnknownSourcesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Unknown Source Apps"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: unknownSourceApps.isNotEmpty
                  ? unknownSourceApps.map((app) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  "• ${app['appName']} (${app['packageName']})",
                  style: const TextStyle(color: Colors.white),
                ),
              )).toList()
                  : [const Text("No unknown source apps found.")],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close", style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dangerous Permission Apps'),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: _checkUnknownSources,
              icon: const Icon(Icons.warning_amber),
              label: const Text("Check Unknown Source Apps"),
            ),
            const SizedBox(height: 16),
            const Text('User Apps', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            const Divider(),
            ...userApps.map((app) => _buildAppTile(app)),
            const SizedBox(height: 16),
            const Text('System Apps', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            const Divider(),
            ...systemApps.map((app) => _buildAppTile(app)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppTile(Map<String, dynamic> app) {
    List<dynamic> permissions = app['permissions'] ?? [];
    List<String> dangerousPerms = permissions
        .where((perm) => dangerousPermissions.contains(perm))
        .cast<String>()
        .toList();
    int dangerousPermCount = dangerousPerms.length;

    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(app['appName'], style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          '${app['packageName']} • $dangerousPermCount dangerous permissions',
          style: const TextStyle(color: Colors.white70),
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          const Text('Dangerous Permissions:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          ...dangerousPerms.map((perm) => ListTile(
            dense: true,
            title: Text(perm, style: const TextStyle(color: Colors.white70)),
          )),
        ],
      ),
    );
  }
}
