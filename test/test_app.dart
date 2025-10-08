import 'package:flutter/material.dart';

// A minimal app used only for widget tests to avoid importing `lib/main.dart`.
class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test App',
      home: Scaffold(
        appBar: AppBar(title: const Text('Test App')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('0', key: Key('counterText')),
              Icon(Icons.add, key: Key('addIcon')),
            ],
          ),
        ),
      ),
    );
  }
}
