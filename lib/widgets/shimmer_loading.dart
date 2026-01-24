import 'package:flutter/material.dart';

/// Shimmer loading effect widget for perceived performance improvement.
/// Shows an animated gradient instead of spinners while content loads.
class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoading({
    super.key,
    this.width = double.infinity,
    this.height = 60,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2 * _controller.value, 0),
              end: Alignment(1.0 + 2 * _controller.value, 0),
              colors: isDark
                  ? [Colors.grey[800]!, Colors.grey[700]!, Colors.grey[800]!]
                  : [Colors.grey[300]!, Colors.grey[100]!, Colors.grey[300]!],
            ),
          ),
        );
      },
    );
  }
}

/// Shimmer placeholder for a list of resources/files
class ResourceListShimmer extends StatelessWidget {
  final int itemCount;
  const ResourceListShimmer({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: [
            const ShimmerLoading(width: 48, height: 48, borderRadius: 8),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerLoading(height: 16, width: 200),
                  SizedBox(height: 8),
                  ShimmerLoading(height: 12, width: 120),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer placeholder for a grid of cards
class CardGridShimmer extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;
  final double childAspectRatio;

  const CardGridShimmer({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.2,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const ShimmerLoading(
        borderRadius: 12,
      ),
    );
  }
}

/// Shimmer placeholder for chat messages
class ChatMessageShimmer extends StatelessWidget {
  final bool isUser;
  const ChatMessageShimmer({super.key, this.isUser = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const ShimmerLoading(width: 36, height: 36, borderRadius: 18),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              ShimmerLoading(
                width: MediaQuery.of(context).size.width * 0.6,
                height: 60,
                borderRadius: 16,
              ),
              const SizedBox(height: 4),
              const ShimmerLoading(width: 60, height: 10, borderRadius: 4),
            ],
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const ShimmerLoading(width: 36, height: 36, borderRadius: 18),
          ],
        ],
      ),
    );
  }
}

/// Shimmer placeholder for the home hero card
class HeroCardShimmer extends StatelessWidget {
  const HeroCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: ShimmerLoading(
        height: 180,
        borderRadius: 20,
      ),
    );
  }
}

/// Shimmer for feature cards horizontal list
class FeatureCardsShimmer extends StatelessWidget {
  final int itemCount;
  const FeatureCardsShimmer({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.only(right: 12),
          child: ShimmerLoading(
            width: 140,
            height: 120,
            borderRadius: 16,
          ),
        ),
      ),
    );
  }
}
