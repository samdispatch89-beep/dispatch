import 'package:flutter/widgets.dart';

enum AdaptiveSize { mobile, tablet, desktop, largeDesktop }

class AppBreakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1280;

  static AdaptiveSize fromWidth(double width) {
    if (width < mobile) return AdaptiveSize.mobile;
    if (width < tablet) return AdaptiveSize.tablet;
    if (width < desktop) return AdaptiveSize.desktop;
    return AdaptiveSize.largeDesktop;
  }

  static AdaptiveSize of(BuildContext context) {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }

  static bool isMobile(BuildContext context) =>
      of(context) == AdaptiveSize.mobile;
  static bool isTablet(BuildContext context) =>
      of(context) == AdaptiveSize.tablet;
  static bool isDesktop(BuildContext context) {
    final size = of(context);
    return size == AdaptiveSize.desktop || size == AdaptiveSize.largeDesktop;
  }

  static bool isLargeDesktop(BuildContext context) =>
      of(context) == AdaptiveSize.largeDesktop;

  static double contentMaxWidth(BuildContext context) {
    switch (of(context)) {
      case AdaptiveSize.mobile:
        return double.infinity;
      case AdaptiveSize.tablet:
        return 920;
      case AdaptiveSize.desktop:
        return 1180;
      case AdaptiveSize.largeDesktop:
        return 1440;
    }
  }

  static double pagePadding(BuildContext context) {
    switch (of(context)) {
      case AdaptiveSize.mobile:
        return 12;
      case AdaptiveSize.tablet:
        return 18;
      case AdaptiveSize.desktop:
        return 24;
      case AdaptiveSize.largeDesktop:
        return 28;
    }
  }
}
