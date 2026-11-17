import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shimmer placeholder container that smoothly animates a highlight sweep across surfaces
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final ShapeBorder? shape;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = AppTheme.radiusM,
    this.shape,
  });

  const ShimmerBox.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = size / 2,
        shape = const CircleBorder();

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: ShapeDecoration(
            shape: widget.shape ??
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                ),
            gradient: LinearGradient(
              begin: Alignment(-2.0 + _controller.value * 4, -0.3),
              end: Alignment(-1.0 + _controller.value * 4, 0.3),
              colors: [
                AppTheme.surfaceElevated,
                AppTheme.surfaceBorder.withValues(alpha: 0.6),
                AppTheme.surfaceElevated,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton placeholder for Home Screen while charts are loading
class HomeScreenSkeleton extends StatelessWidget {
  const HomeScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 90, top: 12),
      children: [
        // Quick play 2x3 grid skeleton
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: 6,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 3.2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (_, __) => const ShimmerBox(
              height: 52,
              borderRadius: AppTheme.radiusS,
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Section header skeleton
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: ShimmerBox(width: 140, height: 22, borderRadius: AppTheme.radiusS),
        ),
        const SizedBox(height: 14),

        // Horizontal carousel skeleton
        SizedBox(
          height: 195,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 4,
            itemBuilder: (_, __) => Container(
              width: 135,
              margin: const EdgeInsets.only(right: 14),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 135, height: 135, borderRadius: AppTheme.radiusM),
                  SizedBox(height: 8),
                  ShimmerBox(width: 110, height: 14, borderRadius: AppTheme.radiusS),
                  SizedBox(height: 4),
                  ShimmerBox(width: 70, height: 12, borderRadius: AppTheme.radiusS),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Artists section header skeleton
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: ShimmerBox(width: 120, height: 22, borderRadius: AppTheme.radiusS),
        ),
        const SizedBox(height: 14),

        // Circle artist skeletons
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 4,
            itemBuilder: (_, __) => Container(
              width: 95,
              margin: const EdgeInsets.only(right: 14),
              child: const Column(
                children: [
                  ShimmerBox.circle(size: 90),
                  SizedBox(height: 8),
                  ShimmerBox(width: 65, height: 12, borderRadius: AppTheme.radiusS),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
