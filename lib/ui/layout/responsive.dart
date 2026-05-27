import 'package:flutter/widgets.dart';

enum FormFactor { compact, medium, expanded }

FormFactor formFactorOf(BuildContext context) {
  final double w = MediaQuery.sizeOf(context).width;
  if (w < 600) return FormFactor.compact;
  if (w < 1000) return FormFactor.medium;
  return FormFactor.expanded;
}
