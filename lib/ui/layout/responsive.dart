import 'package:flutter/widgets.dart';

/// Window-size class buckets aligned with Material 3 breakpoints, named for
/// the form factor they normally represent.
enum FormFactor { compact, medium, expanded }

FormFactor formFactorOf(BuildContext context) {
  final double w = MediaQuery.sizeOf(context).width;
  if (w < 600) return FormFactor.compact;
  if (w < 1000) return FormFactor.medium;
  return FormFactor.expanded;
}

/// Cap content (prose, list items, single-column forms) to a comfortable
/// reading column on wide screens. On phones this is a no-op because the
/// device width is below the cap anyway.
const double kReadableContentMaxWidth = 640;

/// Wraps [child] in a Center + ConstrainedBox so the page's primary column
/// stays readable on iPad/landscape without changing anything on a phone.
///
/// Use this around list scrolling areas and prose-heavy bodies — not around
/// single icons or buttons that are already centered by the layout above.
class ResponsiveColumn extends StatelessWidget {
  const ResponsiveColumn({
    super.key,
    required this.child,
    this.maxWidth = kReadableContentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
