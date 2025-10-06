import 'package:flutter/material.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_applicationtest/pages/add_page.dart';
import 'package:flutter_applicationtest/pages/editprices_page.dart';
import 'package:flutter_applicationtest/pages/inventory_page.dart';
import 'package:flutter_applicationtest/pages/login_page.dart';
import 'package:flutter_applicationtest/pages/notification_page.dart';
import 'package:flutter_applicationtest/pages/sales_page.dart';
import 'package:flutter_applicationtest/pages/settings_page.dart';
import 'package:flutter_applicationtest/pages/register_page.dart';
import 'package:flutter_applicationtest/pages/main_navigation.dart';
import 'database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  
  if (!Platform.isAndroid && !Platform.isIOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print('FlutterError: ${details.exceptionAsString()}');
  };

  try {
    await DatabaseHelper().database;
    await DatabaseHelper().printDbPath();
    await DatabaseHelper().triggerAllNotifications();

    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');

    runApp(const MyApp());
  } catch (e, st) {
    print('Startup error: $e');
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

  Future<bool> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mama Abby’s',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: FutureBuilder<bool>(
        future: _checkSession(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // Always return LoginPage since we clear session on startup
          return const LoginPage();
        },
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/inventory': (context) => const InventoryPage(),
        '/sales': (context) => const SalesPage(),
        '/settings': (context) => const SettingsPage(),
        '/editprice': (context) => const EditpricesPage(),
        '/addpage': (context) => const AddPage(),
        '/notification': (context) => const NotificationPage(),
        '/mainnav': (context) => const MainNavigation(),
      },
    );
  }
}
