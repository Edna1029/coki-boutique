import 'package:flutter/material.dart';
import '../../widgets/product_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/display_names.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/product_model.dart';

class ProductDetailsScreen extends StatelessWidget {
  final ProductModel product;
  final bool isAmharic;
  final VoidCallback onProductUpdated;

  /// Opens the edit dialog. Null hides the Edit button (e.g. for employees).
  final VoidCallback? onEdit;

  const ProductDetailsScreen({
    super.key,
    required this.product,
    this.isAmharic = false,
    required this.onProductUpdated,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const allSizes = ['S', 'M', 'L', 'XL', 'XXL'];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAmharic ? 'የምርት ዝርዝር' : 'Product Details',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (onEdit != null)
            IconButton(
              tooltip: isAmharic ? 'ምርት አሻሽል' : 'Edit Product',
              icon: const Icon(Icons.edit_outlined, color: AppColors.primaryGreen),
              onPressed: onEdit,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section: Large Product Image Container
            Container(
              height: 280,
              width: double.infinity,
              color: isDark ? AppColors.darkSurface : Colors.grey[100],
              child: ProductImage(url: product.productImage, iconSize: 64),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand & Category Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryBrown.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isAmharic
                              ? DisplayNames.category(product.category, isAmharic: true)
                              : product.category.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.secondaryBrown,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Text(
                        'SKU: ${product.sku}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Product Title
                  Text(
                    product.productName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // Price
                  Text(
                    CurrencyFormatter.format(product.price, isAmharic: isAmharic),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Information Cards Grid
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      boxShadow: isDark ? AppDimensions.darkCardShadow : AppDimensions.softShadow,
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(isAmharic ? 'ብራንድ' : 'Brand', product.brand, isDark),
                        const Divider(),
                        _buildInfoRow(isAmharic ? 'ቀለም' : 'Color', product.color, isDark),
                        const Divider(),
                        _buildInfoRow(isAmharic ? 'ፆታ' : 'Gender',
                            DisplayNames.gender(product.gender, isAmharic: isAmharic), isDark),
                        const Divider(),
                        _buildInfoRow(isAmharic ? 'ባርኮድ' : 'Barcode', product.barcode, isDark),
                        const Divider(),
                        _buildInfoRow(isAmharic ? 'ጠቅላላ ክምችት' : 'Total Quantity', isAmharic ? '${product.totalStock} ዕቃዎች' : '${product.totalStock} units', isDark),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Size Inventory Section (Prominently displays stock per size)
                  Text(
                    l10n.sizeStock,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: allSizes.map((size) {
                      final qty = product.stockForSize(size);
                      final hasStock = qty > 0;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: hasStock
                                ? AppColors.primaryGreen.withOpacity(0.08)
                                : (isDark ? AppColors.darkSurface : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusInput),
                            border: Border.all(
                              color: hasStock ? AppColors.primaryGreen : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                size,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: hasStock
                                      ? AppColors.primaryGreen
                                      : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$qty',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: hasStock
                                      ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                                      : AppColors.error,
                                ),
                              ),
                              Text(
                                isAmharic ? 'ክምችት' : 'stock',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 30),
                  Text(
                    '${isAmharic ? "የተመዘገበበት ቀን:" : "Added on:"} ${DateFormatter.formatIsoDate(product.dateAdded, isAmharic: isAmharic)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
