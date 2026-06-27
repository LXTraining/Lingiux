import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../feed/presentation/screens/feed_screen.dart';
import '../../../chat/presentation/screens/chats_list_screen.dart';
import '../../../create_card/presentation/screens/create_card_screen.dart';
import '../../../community/presentation/screens/community_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../providers/navigation_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(activeTabProvider);

    final screens = [
      const FeedScreen(),
      const ChatsListScreen(),
      CreateCardScreen(isActive: selectedIndex == 2),
      const CommunityScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
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
            _buildNavItem(context, ref, 0, Icons.home_outlined, Icons.home_rounded, AppStrings.navInicio, selectedIndex),
            _buildNavItem(context, ref, 1, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, AppStrings.navChats, selectedIndex),
            _buildNavItem(context, ref, 2, Icons.add_circle_outline_rounded, Icons.add_circle_rounded, AppStrings.navCrear, selectedIndex),
            _buildNavItem(context, ref, 3, Icons.people_outline_rounded, Icons.people_rounded, AppStrings.navComunidad, selectedIndex),
            _buildNavItem(context, ref, 4, Icons.person_outline_rounded, Icons.person_rounded, AppStrings.navPerfil, selectedIndex),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, WidgetRef ref, int index, IconData outlineIcon, IconData solidIcon, String label, int selectedIndex) {
    final isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () {
        ref.read(activeTabProvider.notifier).state = index;
      },
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
