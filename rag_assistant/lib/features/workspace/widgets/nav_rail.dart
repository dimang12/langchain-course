import 'package:flutter/material.dart';
import '../../../shared/theme/glass_theme.dart';

class WorkspaceNavRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const WorkspaceNavRail({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.folder_outlined, 'Files'),
      (Icons.search_outlined, 'Search'),
      (Icons.chat_bubble_outline, 'Chat'),
      (Icons.build_outlined, 'Tools'),
      (Icons.calendar_today_outlined, 'Today'),
      (Icons.adjust_outlined, 'Goals'),
      (Icons.calendar_view_week_outlined, 'Calendar'),
      (Icons.checklist_outlined, 'Tasks'),
    ];

    return SizedBox(
      width: GlassTheme.railWidth,
      child: Column(
        children: [
          const SizedBox(height: 16),
          const _LogoButton(),
          const SizedBox(height: 14),
          // Separator
          Container(
            width: 28,
            height: 1,
            color: GlassTheme.line,
          ),
          const SizedBox(height: 8),
          // Nav items
          ...items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final isActive = selectedIndex == i;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: _GlassNavItem(
                icon: item.$1,
                label: item.$2,
                isActive: isActive,
                onTap: () => onSelected(i),
              ),
            );
          }),
          const Spacer(),
          // Settings
          _GlassNavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            isActive: false,
            onTap: () => onSelected(10),
          ),
          const SizedBox(height: 10),
          // Avatar with status dot
          const _AvatarWithStatus(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Logo "a" button with hover rotation
class _LogoButton extends StatefulWidget {
  const _LogoButton();

  @override
  State<_LogoButton> createState() => _LogoButtonState();
}

class _LogoButtonState extends State<_LogoButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isHovered = true); }),
      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isHovered = false); }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutBack,
        transform: _isHovered
            ? (Matrix4.identity()
              ..rotateZ(-0.14) // ~-8deg
              ..setEntry(0, 0, 1.05)
              ..setEntry(1, 1, 1.05))
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [GlassTheme.accent, GlassTheme.accentDeep],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            const BoxShadow(
              color: Color(0x66FFFFFF),
              blurRadius: 0,
              spreadRadius: 0,
              offset: Offset(0, 1),
            ),
            BoxShadow(
              color: GlassTheme.accentDeep.withValues(alpha: 0.5),
              blurRadius: 16,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'a',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: Colors.white,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar with green online status dot
class _AvatarWithStatus extends StatefulWidget {
  const _AvatarWithStatus();

  @override
  State<_AvatarWithStatus> createState() => _AvatarWithStatusState();
}

class _AvatarWithStatusState extends State<_AvatarWithStatus> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isHovered = true); }),
      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isHovered = false); }),
      child: AnimatedScale(
        scale: _isHovered ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFD4A574), GlassTheme.accent],
                    ),
                    border: Border.all(
                      color: const Color(0xB3FFFFFF),
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x80FFFFFF),
                        blurRadius: 0,
                        spreadRadius: 0,
                        offset: Offset(0, 1),
                      ),
                      BoxShadow(
                        color: Color(0x30302050),
                        blurRadius: 10,
                        spreadRadius: -2,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'DC',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              // Green status dot
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFCFBFF),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _GlassNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_GlassNavItem> createState() => _GlassNavItemState();
}

class _GlassNavItemState extends State<_GlassNavItem> {
  bool _isHovered = false;
  OverlayEntry? _tooltipEntry;
  final _itemKey = GlobalKey();

  void _showTooltip() {
    _removeTooltip();
    final renderBox = _itemKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _tooltipEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx + size.width + 18,
        top: offset.dy + (size.height - 36) / 2,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size(8, 14),
              painter: _TooltipArrowPainter(),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xF0202020),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_tooltipEntry!);
  }

  void _removeTooltip() {
    _tooltipEntry?.remove();
    _tooltipEntry = null;
  }

  @override
  void dispose() {
    _removeTooltip();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    final isHovered = _isHovered;

    Color iconColor;
    if (isActive) {
      iconColor = GlassTheme.accentDeep;
    } else if (isHovered) {
      iconColor = GlassTheme.ink;
    } else {
      iconColor = GlassTheme.ink2;
    }

    return MouseRegion(
      onEnter: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _isHovered = true);
        });
        _showTooltip();
      },
      onExit: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _isHovered = false);
        });
        _removeTooltip();
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              key: _itemKey,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isActive || isHovered
                    ? const Color(0xFFFFFFFF)
                    : const Color(0x00FFFFFF),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isActive || isHovered
                        ? const Color(0x0C000000)
                        : const Color(0x00000000),
                    blurRadius: isActive || isHovered ? 8 : 0,
                    spreadRadius: 0,
                    offset: isActive || isHovered
                        ? const Offset(0, 2)
                        : Offset.zero,
                  ),
                ],
              ),
              child: Center(
                child: AnimatedScale(
                  scale: isHovered && !isActive ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Icon(widget.icon, size: 22, color: iconColor),
                ),
              ),
            ),
            // Accent bar — inside the nav bar
            if (isActive || isHovered)
              Positioned(
                left: -12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 4,
                    height: isActive ? 20 : 14,
                    decoration: BoxDecoration(
                      color: GlassTheme.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TooltipArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xF0202020)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
