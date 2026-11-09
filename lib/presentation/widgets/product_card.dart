import 'package:flutter/material.dart';
import 'product_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/display_names.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/product_model.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final bool isAmharic;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  const ProductCard({
    super.key,
    required this.product,
    this.isAmharic = false,
    this.onTap,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLowStock = product.totalStock <= 5;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: isDark ? AppDimensions.darkCardShadow : AppDimensions.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image with Category Badge & Stock Alert
              Expanded(
                flex: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ProductImage(url: product.productImage),
                    // Gradient overlay at top
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryBrown.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusBadge),
                        ),
                        child: Text(
                          DisplayNames.category(product.category, isAmharic: isAmharic),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (isLowStock)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isAmharic ? 'አነስተኛ' : 'LOW',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Product Info Area
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'SKU: ${product.sku}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),

                      // Sizes row
                      Wrap(
                        spacing: 3,
                        children: product.variants
                            .where((v) => v.quantity > 0)
                            .map((v) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    v.size,
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ))
                            .toList(),
                      ),

                      // Price and Quick Add Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            CurrencyFormatter.format(product.price, isAmharic: isAmharic),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          if (onAddToCart != null)
                            InkWell(
                              onTap: onAddToCart,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.add_shopping_cart, size: 14, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductListRow extends StatelessWidget {
  final ProductModel product;
  final bool isAmharic;
  final VoidCallback? onTap;

  const ProductListRow({
    super.key,
    required this.product,
    this.isAmharic = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: isDark ? AppDimensions.darkCardShadow : AppDimensions.softShadow,
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ProductImage(url: product.productImage, width: 50, height: 50, iconSize: 24),
        ),
        title: Text(
          product.productName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          '${product.brand} | SKU: ${product.sku} | ${isAmharic ? "ክምችት:" : "Stock:"} ${product.totalStock}',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        trailing: Text(
          CurrencyFormatter.format(product.price, isAmharic: isAmharic),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.primaryGreen,
          ),
        ),
      ),
    );
  }
}
