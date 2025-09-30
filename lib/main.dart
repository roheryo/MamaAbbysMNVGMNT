import 'package:flutter/material.dart';
import 'package:flutter_applicationtest/pages/add_page.dart';
import 'package:flutter_applicationtest/pages/editprices_page.dart';
import 'package:flutter_applicationtest/pages/inventory_page.dart';
import 'package:flutter_applicationtest/pages/login_page.dart';
import 'package:flutter_applicationtest/pages/notification_page.dart';
import 'package:flutter_applicationtest/pages/sales_page.dart';
import 'package:flutter_applicationtest/pages/settings_page.dart';
import 'pages/register_page.dart';
import 'database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // Also print to console to help diagnose white-screen issues
    // ignore: avoid_print
    print('FlutterError: ${details.exceptionAsString()}');
  };

  try {
    // ✅ Initialize the database
    await DatabaseHelper().database;

    // ✅ Print the database path so you know where app.db is stored
    await DatabaseHelper().printDbPath();

    // ✅ Trigger notifications (low stock + overdue deliveries immediately)
    await DatabaseHelper().triggerAllNotifications();

    runApp(const MyApp());
  } catch (e, st) {
    // ignore: avoid_print
    print('Startup error: $e');
    // ignore: avoid_print
    print(st);
    runApp(ErrorApp(message: e.toString()));
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Startup Error')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(child: Text(message)),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),
        '/inventory': (context) => InventoryPage(),
        '/sales': (context) => SalesPage(),
        '/settings': (context) => SettingsPage(),
        '/editprice': (context) => EditpricesPage(),
        '/addpage': (context) => AddPage(),
        '/notification': (context) => NotificationPage(),
      },
    );
  }
}
