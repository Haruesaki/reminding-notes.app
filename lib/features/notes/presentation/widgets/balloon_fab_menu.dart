import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

/// Animated Balloon FAB Menu conforming to PRD 4.4 and 7.3.
/// Features:
/// - 45° rotation of plus icon into an 'x'.
/// - 30% black dimmed scrim backdrop.
/// - 3 balloon pills (Folder, List, Page) rising upward with scale, translateY,
///   fade, 40ms stagger, 280ms duration, and light overshoot (easeOutBack).
/// - Dismissible via scrim tap, 'x' tap, or back button, with reverse animation.
class BalloonFabMenu extends StatefulWidget {
  final VoidCallback onSelectFolder;
  final VoidCallback onSelectList;
  final VoidCallback onSelectPage;
  final String heroTag;

  const BalloonFabMenu({
    super.key,
    required this.onSelectFolder,
    required this.onSelectList,
    required this.onSelectPage,
    this.heroTag = 'balloon_fab',
  });

  @override
  State<BalloonFabMenu> createState() => BalloonFabMenuState();
}

class BalloonFabMenuState extends State<BalloonFabMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotationAnimation;
  late final Animation<double> _scrimAnimation;
  late final Animation<double> _folderAnimation;
  late final Animation<double> _listAnimation;
  late final Animation<double> _pageAnimation;

  bool _isOpen = false;
  bool get isOpen => _isOpen;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      reverseDuration: const Duration(milliseconds: 280),
    );

    // FAB plus icon rotates 45 degrees (0.125 turns) to form 'x'
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.78, curve: Curves.easeOutBack),
        reverseCurve: Curves.easeIn,
      ),
    );

    // Scrim fade in
    _scrimAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.70, curve: Curves.easeOut),
        reverseCurve: Curves.easeIn,
      ),
    );

    // Staggered pill animations (40ms stagger, 280ms duration over 360ms total)
    // Folder (top): starts at 0ms -> [0.0, 280/360 ≈ 0.78]
    _folderAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.78, curve: Curves.easeOutBack),
      reverseCurve: Curves.easeIn,
    );

    // List (middle): starts at 40ms -> [40/360 ≈ 0.11, 320/360 ≈ 0.89]
    _listAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.11, 0.89, curve: Curves.easeOutBack),
      reverseCurve: Curves.easeIn,
    );

    // Page (bottom): starts at 80ms -> [80/360 ≈ 0.22, 1.0]
    _pageAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.22, 1.0, curve: Curves.easeOutBack),
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void open() {
    if (!_isOpen) {
      setState(() => _isOpen = true);
      _controller.forward();
    }
  }

  void close() {
    if (_isOpen) {
      setState(() => _isOpen = false);
      _controller.reverse();
    }
  }

  void toggle() {
    if (_isOpen) {
      close();
    } else {
      open();
    }
  }

  Widget _buildPill({
    required Animation<double> animation,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = animation.value;
        if (progress <= 0.0) {
          return const SizedBox.shrink();
        }

        // Float up with translateY and scale with overshoot
        final translateY = (1.0 - progress) * 35.0;
        final scale = 0.6 + (0.4 * progress);
        final opacity = progress.clamp(0.0, 1.0);

        return Transform.translate(
          offset: Offset(0, translateY),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.bottomRight,
            child: Opacity(
              opacity: opacity,
              child: child,
            ),
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            close();
            onTap();
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: AppColors.textPrimary),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: PopScope(
        canPop: !_isOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _isOpen) {
            close();
          }
        },
        child: Stack(
          alignment: Alignment.bottomRight,
          clipBehavior: Clip.none,
          children: [
            // 1. Scrim overlay: 30% black fade, tap to dismiss
            if (_isOpen || _controller.value > 0.0)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _scrimAnimation,
                  builder: (context, child) {
                    final opacity = _scrimAnimation.value;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: close,
                      child: Container(
                        color: Colors.black.withValues(
                          alpha: 0.30 * opacity.clamp(0.0, 1.0),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // 2. FAB and Balloon Pills anchored at bottom-right
            Positioned(
              right: AppConstants.screenMargin,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
              children: [
                // Pill 1: Folder (top)
                _buildPill(
                  animation: _folderAnimation,
                  icon: Icons.folder_rounded,
                  label: 'Folder',
                  onTap: widget.onSelectFolder,
                ),
                const SizedBox(height: 12),

                // Pill 2: List (middle)
                _buildPill(
                  animation: _listAnimation,
                  icon: Icons.check_box_rounded,
                  label: 'List',
                  onTap: widget.onSelectList,
                ),
                const SizedBox(height: 12),

                // Pill 3: Page (bottom)
                _buildPill(
                  animation: _pageAnimation,
                  icon: Icons.description_rounded,
                  label: 'Page',
                  onTap: widget.onSelectPage,
                ),
                const SizedBox(height: 16),

                // Main FAB Button
                SizedBox(
                  width: AppConstants.fabSize,
                  height: AppConstants.fabSize,
                  child: FloatingActionButton(
                    heroTag: widget.heroTag,
                    shape: const CircleBorder(),
                    backgroundColor: AppColors.fabBackground,
                    elevation: 4,
                    onPressed: toggle,
                    child: RotationTransition(
                      turns: _rotationAnimation,
                      child: const Icon(
                        Icons.add_rounded,
                        size: 30,
                        color: AppColors.fabIcon,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}
