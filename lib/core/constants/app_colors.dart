import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Colores Base de Diseño (Light Mode First)
  static const Color primary = Color(0xFF815BF5);        // Violeta de marca principal
  static const Color accent = Color(0xFF5A45FF);         // Indigo secundario
  static const Color background = Color(0xFFF8F9FD);     // Fondo general claro
  static const Color surface = Color(0xFFFFFFFF);        // Superficies de tarjetas y modales
  static const Color surfaceVariant = Color(0xFFF1F5F9); // Fondo de inputs y secciones secundarias
  static const Color border = Color(0xFFEBEFFA);         // Separación sutil entre elementos
  
  // Colores de Texto
  static const Color onSurface = Color(0xFF0F172A);      // Texto oscuro principal
  static const Color onSurfaceMuted = Color(0xFF64748B); // Texto secundario gris azulado
  static const Color textTerciario = Color(0xFF94A3B8);  // Texto auxiliar

  // Colores de Estado
  static const Color online = Color(0xFF4CD9A3);         // Verde activo/online
  static const Color error = Color(0xFFFF5555);          // Rojo de error suave

  // Colores de Avatares (Pasteles modernos y vibrantes)
  static const List<Color> avatarColors = [
    Color(0xFF815BF5),
    Color(0xFFFF6B8B),
    Color(0xFF4FA4F4),
    Color(0xFF4CD9A3),
    Color(0xFFA258F5),
  ];

  // Colores dedicados para componentes oscuros independientes (ej: Word Cards)
  static const Color darkBackground = Color(0xFF0F0E1A);
  static const Color darkSurface = Color(0xFF1C1B2E);
  static const Color darkSurfaceVariant = Color(0xFF252438);
  static const Color darkOnSurface = Color(0xFFE8E6F0);
  static const Color darkOnSurfaceMuted = Color(0xFF9892B0);
}
