import 'package:flutter/material.dart';
import 'package:testing/map_screen.dart'; 

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Map App',
      home: GoogleMapScreen(),
    );
  }
}
