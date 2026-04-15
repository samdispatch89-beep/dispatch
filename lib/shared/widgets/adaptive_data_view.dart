import 'package:flutter/material.dart';

import '../../responsive/breakpoints.dart';

class AdaptiveDataView extends StatelessWidget {
  const AdaptiveDataView({
    super.key,
    required this.itemCount,
    required this.cardBuilder,
    required this.tableBuilder,
    this.empty,
  });

  final int itemCount;
  final WidgetBuilder tableBuilder;
  final IndexedWidgetBuilder cardBuilder;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) {
      return empty ?? const SizedBox.shrink();
    }

    if (AppBreakpoints.isDesktop(context)) {
      return tableBuilder(context);
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: cardBuilder,
    );
  }
}
