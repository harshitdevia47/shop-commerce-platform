import 'package:material_ui/material_ui.dart';

/// Grey placeholder block shown while content loads.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({this.width, this.height, this.radius = 8, super.key});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
