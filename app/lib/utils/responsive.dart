/// Shared viewport breakpoints and responsive width helpers.
abstract final class Responsive {
  static const mobileBreakpoint = 600.0;
  static const desktopBreakpoint = 900.0;

  static bool isMobile(double width) => width < mobileBreakpoint;
  static bool isTablet(double width) =>
      width >= mobileBreakpoint && width < desktopBreakpoint;
  static bool isDesktop(double width) => width >= desktopBreakpoint;
}
