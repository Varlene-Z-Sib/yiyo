import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/map_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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