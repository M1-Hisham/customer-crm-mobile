import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

/// Professional page transitions for the app.
/// Use `AppPageRoute.sharedAxis(page: ...)` when pushing a new screen
/// instead of the default MaterialPageRoute for a much more polished feel.
class AppPageRoute {
  /// Shared-axis (horizontal) transition — best for drilling into a
  /// list item's details (e.g. Case -> Case Details).
  static Route<T> sharedAxis<T>({
    required Widget page,
    SharedAxisTransitionType type = SharedAxisTransitionType.horizontal,
  }) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: type,
          child: child,
        );
      },
    );
  }

  /// Fade-through — best for switching between top-level tabs
  /// (Dashboard, Cases, Documents, Consultation).
  static Route<T> fadeThrough<T>({required Widget page}) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeThroughTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      },
    );
  }
}
