import 'package:flutter/material.dart';

/// Layout breakpoints (logical pixels, widths unless noted).
abstract final class Breakpoints {
  /// Shortest side at which a device counts as a tablet.
  static const double tablet = 600;

  /// Width from which [TwoPane] shows both panes side by side.
  static const double twoPane = 720;

  /// Width from which the shell uses a navigation rail instead of a bottom bar.
  static const double rail = 840;

  /// Maximum width of reading content (passages, lists, cards).
  static const double readingWidth = 680;
}

/// Window size class from the available width.
enum WindowSize {
  /// Phones in portrait (< 600).
  compact,

  /// Large phones in landscape, small tablets (600-839).
  medium,

  /// Tablets in landscape, large tablets (>= 840).
  expanded;

  /// Size class for [width].
  static WindowSize forWidth(double width) => width >= Breakpoints.rail
      ? expanded
      : width >= Breakpoints.tablet
      ? medium
      : compact;
}

/// Screen-level queries (from [MediaQuery]; inside a constrained widget prefer
/// [LayoutBuilder] or the widgets below, which use their own constraints).
extension ResponsiveContext on BuildContext {
  /// Size class of the window.
  WindowSize get windowSize =>
      WindowSize.forWidth(MediaQuery.sizeOf(this).width);

  /// True on tablets (shortest side >= 600), in either orientation.
  bool get isTablet =>
      MediaQuery.sizeOf(this).shortestSide >= Breakpoints.tablet;

  /// True when the window is wide enough for two panes.
  bool get useTwoPane => MediaQuery.sizeOf(this).width >= Breakpoints.twoPane;

  /// Horizontal page padding: 16 on phones, 24 on wider windows.
  EdgeInsets get pagePadding => EdgeInsets.symmetric(
    horizontal: windowSize == WindowSize.compact ? 16 : 24,
  );
}

/// Centres [child] and caps its width at [maxWidth] (~680 dp), so lines stay readable
/// on tablets and in landscape.
class ReadingWidth extends StatelessWidget {
  /// Creates the constraint.
  const ReadingWidth({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.readingWidth,
    this.padding = EdgeInsets.zero,
  });

  /// Content.
  final Widget child;

  /// Maximum content width.
  final double maxWidth;

  /// Padding inside the capped width.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// Two panes side by side when there is room (>= [breakpoint] wide, e.g. Results on a
/// tablet: passage left, word detail right); otherwise [narrow] (or [primary]).
class TwoPane extends StatelessWidget {
  /// Creates the layout.
  const TwoPane({
    super.key,
    required this.primary,
    required this.secondary,
    this.narrow,
    this.primaryFlex = 3,
    this.secondaryFlex = 2,
    this.breakpoint = Breakpoints.twoPane,
  });

  /// Left pane (main content).
  final Widget primary;

  /// Right pane (detail).
  final Widget secondary;

  /// What to show when narrow; defaults to [primary] alone.
  final Widget? narrow;

  /// Flex of [primary].
  final int primaryFlex;

  /// Flex of [secondary].
  final int secondaryFlex;

  /// Minimum width for two panes.
  final double breakpoint;

  /// Whether [width] is wide enough for two panes at [breakpoint].
  static bool isWide(double width, {double breakpoint = Breakpoints.twoPane}) =>
      width >= breakpoint;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!isWide(constraints.maxWidth, breakpoint: breakpoint)) {
        return narrow ?? primary;
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: primaryFlex, child: primary),
          const VerticalDivider(width: 1),
          Expanded(flex: secondaryFlex, child: secondary),
        ],
      );
    },
  );
}
