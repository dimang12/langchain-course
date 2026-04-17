import 'package:flutter/material.dart';

class WorkspaceNavRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const WorkspaceNavRail(
      {super.key, required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.folder_outlined, Icons.folder, 'Files'),
      (Icons.search_outlined, Icons.search, 'Search'),
      (Icons.chat_bubble_outline, Icons.chat_bubble, 'Chat'),
      (Icons.build_outlined, Icons.build, 'Tools'),
      (Icons.wb_sunny_outlined, Icons.wb_sunny, 'Today'),
      (Icons.flag_outlined, Icons.flag, 'Goals'),
    ];

    return Container(
      width: 88,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6c5ce7), Color(0xFF4834b5)],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          ...items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final isActive = selectedIndex == i;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: _NavItem(
                icon: isActive ? item.$2 : item.$1,
                label: item.$3,
                isActive: isActive,
                onTap: () => onSelected(i),
              ),
            );
          }),
          const Spacer(),
          _NavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            isActive: false,
            onTap: () => onSelected(10),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Colors.white.withValues(alpha: isActive ? 1.0 : 0.6);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      hoverColor: Colors.white.withValues(alpha: 0.15),
      splashColor: Colors.white.withValues(alpha: 0.1),
      child: Container(
        width: 76,
        height: 60,
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
