import 'package:flutter/material.dart';

import '../../responsive/breakpoints.dart';

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 220,
    this.spacing = 12,
    this.runSpacing = 12,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final size = AppBreakpoints.fromWidth(width);
        final columns = switch (size) {
          AdaptiveSize.mobile => 1,
          AdaptiveSize.tablet => 2,
          AdaptiveSize.desktop => 3,
          AdaptiveSize.largeDesktop => 4,
        };
        final itemWidth = ((width - (spacing * (columns - 1))) / columns).clamp(
          minItemWidth,
          width,
        );

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}
