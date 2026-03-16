import 'package:flutter/material.dart';

class DesignSystem {
  static final lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.light(
      primary: Colors.black,
      surface: Colors.white,
      onSurface: Colors.grey[900]!,
      outline: Colors.grey[300],
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.grey[200],
      thickness: 1,
    ),
  );

  static final darkTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Color(0xFF111827), // Gray 900
    colorScheme: ColorScheme.dark(
      primary: Colors.white,
      surface: Color(0xFF1F2937), // Gray 800
      onSurface: Colors.grey[100]!,
      outline: Colors.white10,
    ),
    cardTheme: CardThemeData(
      color: Color(0xFF1F2937), // Gray 800
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.white10),
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Color(0xFF111827),
      foregroundColor: Colors.white,
      elevation: 0,
       iconTheme: IconThemeData(color: Colors.white),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.white10,
      thickness: 1,
    ),
  );
}
