import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A shimmering placeholder box. Use it to build skeleton versions
/// of real cards (same size/shape) while data is loading.
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.white10 : Colors.black12;
    final highlight = isDark ? Colors.white24 : Colors.black26;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: base,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
    ).animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: highlight);
  }
}

/// Skeleton placeholder shaped like [DocumentCard] / a generic list tile.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const SkeletonBox(width: 40, height: 40, borderRadius: BorderRadius.all(Radius.circular(8))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: double.infinity, height: 14, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 8),
                SkeletonBox(width: 100, height: 10, borderRadius: BorderRadius.circular(4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A vertical list of [count] skeleton tiles — drop this in while
/// the real list ([DocumentCard]s, cases, etc.) is loading.
class SkeletonList extends StatelessWidget {
  final int count;
  const SkeletonList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (_) => const SkeletonListTile()),
    );
  }
}
