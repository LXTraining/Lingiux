import 'package:flutter/material.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class LingiuxApp extends StatelessWidget {
  const LingiuxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Lingiux',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: AppRouter.router,
    );
  }
}
