import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Wrap each item of a ListView/Column with this to get a staggered
/// fade+slide-up entrance, e.g.:
///
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) => StaggeredListItem(
///     index: index,
///     child: DocumentCard(...),
///   ),
/// )
/// ```
class StaggeredListItem extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration baseDelay;
  final Duration stepDelay;

  const StaggeredListItem({
    super.key,
    required this.index,
    required this.child,
    this.baseDelay = const Duration(milliseconds: 80),
    this.stepDelay = const Duration(milliseconds: 60),
  });

  @override
  Widget build(BuildContext context) {
    final delay = baseDelay + stepDelay * index;
    return child
        .animate(delay: delay)
        .fadeIn(duration: 300.ms, curve: Curves.easeOut)
        .slideY(begin: 0.15, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}
