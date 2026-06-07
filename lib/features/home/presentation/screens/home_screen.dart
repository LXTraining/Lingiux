import 'package:flutter/material.dart';
import '../../../feed/presentation/screens/feed_screen.dart';
import '../../../chat/presentation/screens/chats_list_screen.dart';
import '../../../create_card/presentation/screens/create_card_screen.dart';
import '../../../community/presentation/screens/community_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const FeedScreen(),
      const ChatsListScreen(),
      CreateCardScreen(isActive: _selectedIndex == 2),
      const CommunityScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        height: 72 + MediaQuery.of(context).padding.bottom,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 10,
          bottom: MediaQuery.of(context).padding.bottom + 10,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, AppStrings.navInicio),
            _buildNavItem(1, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, AppStrings.navChats),
            _buildNavItem(2, Icons.add_circle_outline_rounded, Icons.add_circle_rounded, AppStrings.navCrear),
            _buildNavItem(3, Icons.people_outline_rounded, Icons.people_rounded, AppStrings.navComunidad),
            _buildNavItem(4, Icons.person_outline_rounded, Icons.person_rounded, AppStrings.navPerfil),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlineIcon, IconData solidIcon, String label) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? solidIcon : outlineIcon,
              color: isSelected ? Colors.white : AppColors.onSurfaceMuted,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
