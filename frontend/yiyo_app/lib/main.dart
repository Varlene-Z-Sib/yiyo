import 'package:flutter/material.dart';
import 'screens/map_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(const YiyoApp());
}

class YiyoApp extends StatelessWidget {
  const YiyoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YIYO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const MapScreen(),
    );
  }
}