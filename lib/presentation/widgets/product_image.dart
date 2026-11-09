import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Shows a product's photo, or a neutral "no photo" placeholder when the
/// product has no image URL or the image can't be loaded (e.g. offline).
///
/// Never substitutes another product's photo, so a product without an image
/// can't be mistaken for something it isn't.
class ProductImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final double iconSize;

  const ProductImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.iconSize = 40,
  });

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return _placeholder(context);
    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (ctx, _, __) => _placeholder(ctx),
    );
  }

  Widget _placeholder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      color: isDark ? Colors.grey[800] : Colors.grey[200],
      alignment: Alignment.center,
      child: Icon(Icons.checkroom_outlined, size: iconSize, color: AppColors.secondaryBrown),
    );
  }
}
