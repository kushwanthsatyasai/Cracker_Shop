import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool isCompact;

  const AppLogo({
    super.key,
    this.size = 32,
    this.showText = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompactLogo();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIconWithBackground(),
        if (showText) ...[
          const SizedBox(width: 8),
          _buildAppName(),
        ],
      ],
    );
  }

  Widget _buildCompactLogo() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.festiveGold,
            AppTheme.primary,
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.3),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.auto_awesome,
          color: Colors.white,
          size: size * 0.6,
        ),
      ),
    );
  }

  Widget _buildIconWithBackground() {
    return Stack(
      children: [
        // Background circle with gradient
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.festiveGold,
                AppTheme.primary,
              ],
            ),
            borderRadius: BorderRadius.circular(size * 0.2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.3),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        // Main icon
        Positioned.fill(
          child: Center(
            child: Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: size * 0.6,
            ),
          ),
        ),
        // Small sparkle accent
        Positioned(
          top: size * 0.1,
          right: size * 0.1,
          child: Container(
            width: size * 0.2,
            height: size * 0.2,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.star,
                color: AppTheme.festiveGold,
                size: size * 0.12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppName() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              AppTheme.primary,
              AppTheme.accent,
            ],
          ).createShader(bounds),
          child: Text(
            'Cracker Track',
            style: TextStyle(
              fontSize: size * 0.75,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        if (size > 24)
          Text(
            'Vani Fire Crackers',
            style: TextStyle(
              fontSize: size * 0.35,
              color: AppTheme.mutedForeground,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }
}

// Simple icon-only version for app bars
class AppIcon extends StatelessWidget {
  final double size;
  
  const AppIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return AppLogo(size: size, showText: false, isCompact: true);
  }
}