import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Reusable App Logo Widget
/// 
/// Displays the Safe Travel app logo (shield with location pin)
/// with customizable size and color.
/// 
/// Usage:
/// ```dart
/// AppLogo(size: 48, color: Colors.white)
/// ```
class AppLogo extends StatelessWidget {
  /// Size of the logo (width and height)
  final double size;
  
  /// Color to apply to the logo (uses color filter)
  /// If null, displays the original logo colors
  final Color? color;
  
  /// Optional padding around the logo
  final EdgeInsets? padding;

  const AppLogo({
    Key? key,
    this.size = 48,
    this.color = Colors.white,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final logoWidget = SvgPicture.asset(
      'assets/images/app_logo.svg',
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
      semanticsLabel: 'Safe Travel App Logo',
    );

    if (padding != null) {
      return Padding(
        padding: padding!,
        child: logoWidget,
      );
    }

    return logoWidget;
  }
}

/// App Logo with Container Background
/// 
/// Displays the logo inside a styled container with gradient background,
/// border, and shadow effects.
/// 
/// Usage:
/// ```dart
/// AppLogoContainer(
///   size: 80,
///   containerPadding: 16,
///   showShadow: true,
/// )
/// ```
class AppLogoContainer extends StatelessWidget {
  /// Size of the entire container
  final double size;
  
  /// Padding inside the container (affects logo size)
  final double containerPadding;
  
  /// Color of the logo
  final Color logoColor;
  
  /// Gradient colors for the container background
  final List<Color>? gradientColors;
  
  /// Whether to show shadow effect
  final bool showShadow;
  
  /// Border radius of the container
  final double borderRadius;
  
  /// Background opacity (0.0 to 1.0)
  final double backgroundOpacity;

  const AppLogoContainer({
    Key? key,
    this.size = 80,
    this.containerPadding = 16,
    this.logoColor = Colors.white,
    this.gradientColors,
    this.showShadow = true,
    this.borderRadius = 20,
    this.backgroundOpacity = 0.2,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final defaultGradient = [
      const Color(0xFF6366F1),
      const Color(0xFF8B5CF6),
    ];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors ?? defaultGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: (gradientColors?.first ?? defaultGradient.first)
                      .withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(containerPadding),
        child: AppLogo(
          size: size - (containerPadding * 2),
          color: logoColor,
        ),
      ),
    );
  }
}

/// Simple Logo Container for Headers
/// 
/// A simplified version with semi-transparent background and border,
/// perfect for app bar headers.
/// 
/// Usage:
/// ```dart
/// AppLogoHeader(size: 48)
/// ```
class AppLogoHeader extends StatelessWidget {
  final double size;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color logoColor;

  const AppLogoHeader({
    Key? key,
    this.size = 48,
    this.backgroundColor,
    this.borderColor,
    this.logoColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(size * 0.33),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.17),
        child: AppLogo(
          size: size * 0.66,
          color: logoColor,
        ),
      ),
    );
  }
}

/// Animated Logo Widget
/// 
/// Displays the logo with optional pulse or rotation animation.
/// 
/// Usage:
/// ```dart
/// AnimatedAppLogo(
///   size: 100,
///   animate: true,
///   animationType: LogoAnimationType.pulse,
/// )
/// ```
enum LogoAnimationType {
  pulse,
  rotate,
  none,
}

class AnimatedAppLogo extends StatefulWidget {
  final double size;
  final Color? color;
  final bool animate;
  final LogoAnimationType animationType;
  final Duration duration;

  const AnimatedAppLogo({
    Key? key,
    this.size = 48,
    this.color = Colors.white,
    this.animate = true,
    this.animationType = LogoAnimationType.pulse,
    this.duration = const Duration(seconds: 2),
  }) : super(key: key);

  @override
  State<AnimatedAppLogo> createState() => _AnimatedAppLogoState();
}

class _AnimatedAppLogoState extends State<AnimatedAppLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    if (widget.animationType == LogoAnimationType.pulse) {
      _animation = Tween<double>(begin: 1.0, end: 1.1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      );
    } else {
      _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    }

    if (widget.animate) {
      if (widget.animationType == LogoAnimationType.pulse) {
        _controller.repeat(reverse: true);
      } else if (widget.animationType == LogoAnimationType.rotate) {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate || widget.animationType == LogoAnimationType.none) {
      return AppLogo(size: widget.size, color: widget.color);
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        if (widget.animationType == LogoAnimationType.pulse) {
          return Transform.scale(
            scale: _animation.value,
            child: child,
          );
        } else if (widget.animationType == LogoAnimationType.rotate) {
          return Transform.rotate(
            angle: _animation.value * 2 * 3.14159,
            child: child,
          );
        }
        return child!;
      },
      child: AppLogo(size: widget.size, color: widget.color),
    );
  }
}
