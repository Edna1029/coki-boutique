import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/display_names.dart';
import '../../../core/utils/barcode_generator.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/sqlite_service.dart';
import '../../../domain/entities/enums.dart';
import '../../widgets/sync_refresh_mixin.dart';
import '../../widgets/barcode_scanner_screen.dart';
import '../../widgets/product_card.dart';
import 'product_details_screen.dart';

class InventoryScreen extends StatefulWidget {
  final bool isAmharic;
  final UserRole userRole;

  const InventoryScreen({
    super.key,
    required this.isAmharic,
    required this.userRole,
  });

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SyncRefreshMixin {
  final SQLiteService _sqliteService = SQLiteService();
  bool _isLoading = true;
  bool _isCardView = true; // Toggle between Card View and List View per UI/UX spec
  String _searchQuery = '';
  String _selectedCategory = 'All';

  List<ProductModel> _allProducts = [];

  final List<String> _categories = [
    'All',
    'Traditional',
    'Dresses',
    'Formal Wear',
    'Shirts',
    'Jeans',
    'Accessories',
  ];

  @override
  void onSyncedData() => _loadProducts();

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await _sqliteService.getAllProducts();
      if (mounted) {
        setState(() {
          _allProducts = products;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ProductModel> get _filteredProducts {
    return _allProducts.where((p) {
      final matchesSearch = p.productName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.sku.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.brand.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || p.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  void _openProductDetails(ProductModel product) {
    final canEdit = widget.userRole != UserRole.employee;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (detailsCtx) => ProductDetailsScreen(
          product: product,
          isAmharic: widget.isAmharic,
          onProductUpdated: _loadProducts,
          // Close the (now stale) details page, then open the edit dialog.
          onEdit: canEdit
              ? () {
                  Navigator.of(detailsCtx).pop();
                  _showAddEditProductDialog(product);
                }
              : null,
          onDelete: canEdit ? () => _confirmDeleteProduct(detailsCtx, product, closePage: true) : null,
        ),
      ),
    );
  }

  /// Owner/admin only. Removes the product and its sizes on this device and,
  /// through sync, on every other device. Past sales, receipts and credit
  /// records keep their own copy of the product name, so history is intact.
  ///
  /// Called from the details page ([closePage] true: that page is closed
  /// after deleting) and from the bin shown on sold-out products in the list.
  /// Not allowed while a customer still owes money for the product.
  Future<void> _confirmDeleteProduct(BuildContext detailsCtx, ProductModel product, {bool closePage = false}) async {
    final am = widget.isAmharic;
    final units = product.totalStock;

    final owing = await _sqliteService.unpaidCreditCustomersFor(product.productId);
    if (!detailsCtx.mounted) return;
    if (owing.isNotEmpty) {
      await _showOnCreditDialog(detailsCtx, product, owing);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: detailsCtx,
      builder: (ctx) => AlertDialog(
        title: Text(am ? 'ምርቱን ልሰርዝ?' : 'Delete product?'),
        content: Text(
          am
              ? '"${product.productName}" ከሁሉም መሣሪያዎች ይሰረዛል።'
                  '${units > 0 ? ' በክምችት ያሉ $units ዕቃዎችም ይሰረዛሉ።' : ''}'
                  '\n\nያለፉ ሽያጮችና ደረሰኞች አይነኩም። ይህ ሊቀለበስ አይችልም።'
              : '"${product.productName}" will be removed from all devices.'
                  '${units > 0 ? ' Its $units ${units == 1 ? 'unit' : 'units'} in stock will be removed too.' : ''}'
                  '\n\nPast sales and receipts are kept. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(am ? 'ተው' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(am ? 'ሰርዝ' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _sqliteService.deleteProduct(product.productId);
      if (closePage && detailsCtx.mounted) Navigator.of(detailsCtx).pop();
      await _loadProducts();
      messenger.showSnackBar(SnackBar(
        content: Text(am ? '"${product.productName}" ተሰርዟል' : '"${product.productName}" deleted'),
      ));
    } on ProductOnCreditException catch (e) {
      // A credit sale was recorded between the check above and the delete.
      if (detailsCtx.mounted) await _showOnCreditDialog(detailsCtx, product, e.customers);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.error,
        content: Text(am ? 'መሰረዝ አልተሳካም: $e' : 'Could not delete: $e'),
      ));
    }
  }

  /// The bin shown on a SOLD-OUT product in the list (owner/admin only), so
  /// finished items can be cleared without opening each one. Null = no bin.
  VoidCallback? _soldOutDelete(ProductModel p) {
    final canEdit = widget.userRole != UserRole.employee;
    if (!canEdit || p.totalStock > 0) return null;
    return () => _confirmDeleteProduct(context, p);
  }

  /// Explains why a product can't be deleted yet: it was sold on credit and
  /// these customers have not finished paying.
  Future<void> _showOnCreditDialog(BuildContext ctx, ProductModel product, List<String> customers) {
    final am = widget.isAmharic;
    final names = customers.join(am ? '፣ ' : ', ');
    return showDialog<void>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text(am ? 'አሁን መሰረዝ አይቻልም' : "Can't delete yet"),
        content: Text(
          am
              ? '"${product.productName}" በብድር ተሽጧል፣ ክፍያውም አልተጠናቀቀም ($names)።'
                  '\n\nብድሩ ሙሉ በሙሉ ከተከፈለ በኋላ መሰረዝ ይችላሉ።'
              : '"${product.productName}" was sold on credit and is not fully paid yet ($names).'
                  '\n\nYou can delete it once the credit is fully paid.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(am ? 'እሺ' : 'OK'),
          ),
        ],
      ),
    );
  }

  void _showAddEditProductDialog([ProductModel? productToEdit]) {
    final nameController = TextEditingController(text: productToEdit?.productName ?? '');
    final skuController = TextEditingController(text: productToEdit?.sku ?? '');
    final brandController = TextEditingController(text: productToEdit?.brand ?? '');
    final colorController = TextEditingController(text: productToEdit?.color ?? '');
    final priceController = TextEditingController(text: productToEdit != null ? '${productToEdit.price}' : '');
    final barcodeController = TextEditingController(text: productToEdit?.barcode ?? '');
    String? errorText;
    // New products start with NO image (shows a neutral placeholder) — never
    // another product's photo.
    final imageController = TextEditingController(text: productToEdit?.productImage ?? '');

    String category = productToEdit?.category ?? 'Traditional';
    Gender gender = productToEdit?.gender ?? Gender.women;

    // Per-size stock: editing shows current stock; adding starts EMPTY (shown
    // as a "0" hint) so no stock is ever saved that the user didn't type.
    final Map<String, TextEditingController> sizeControllers = {
      for (final size in const ['S', 'M', 'L', 'XL', 'XXL'])
        size: TextEditingController(
          text: productToEdit != null ? '${productToEdit.stockForSize(size)}' : '',
        ),
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final l10n = AppLocalizations.of(context);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusDialog)),
            title: Text(
              productToEdit != null
                  ? (widget.isAmharic ? 'ምርት አሻሽል' : 'Edit Product')
                  : l10n.addProduct,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (errorText != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error),
                        ),
                        child: Text(
                          errorText!,
                          style: const TextStyle(color: AppColors.error, fontSize: 12),
                        ),
                      ),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: widget.isAmharic ? 'የምርት ስም' : 'Product Name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Barcode: scan with the camera (button), type it, or focus the
                    // field and use a USB/Bluetooth scanner (they act as keyboards).
                    // Empty = auto-generate on add / keep current on edit.
                    TextField(
                      controller: barcodeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: widget.isAmharic ? 'ባርኮድ' : 'Barcode',
                        hintText: productToEdit != null
                            ? (widget.isAmharic ? 'ባዶ ከሆነ ነባሩ ይቆያል' : 'Leave empty to keep current')
                            : (widget.isAmharic ? 'ይቃኙ ወይም ይጻፉ — ባዶ ከሆነ በራስ-ሰር ይፈጠራል' : 'Scan or type — leave empty to auto-generate'),
                        prefixIcon: const Icon(Icons.qr_code_2, color: AppColors.secondaryBrown),
                        suffixIcon: IconButton(
                          tooltip: widget.isAmharic ? 'በካሜራ ይቃኙ' : 'Scan with camera',
                          icon: const Icon(Icons.qr_code_scanner, color: AppColors.primaryGreen),
                          onPressed: () async {
                            final code = await BarcodeScannerScreen.scan(context);
                            if (code != null) {
                              setDialogState(() {
                                barcodeController.text = code;
                                errorText = null;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: skuController,
                            decoration: const InputDecoration(labelText: 'SKU'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: brandController,
                            decoration: InputDecoration(
                              labelText: widget.isAmharic ? 'ብራንድ' : 'Brand',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: colorController,
                            decoration: InputDecoration(
                              labelText: widget.isAmharic ? 'ቀለም' : 'Color',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: widget.isAmharic ? 'ዋጋ (ETB)' : 'Price (ETB)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: category,
                            // Fill the half-row instead of sizing to the longest
                            // option, so long names can't overflow on phones.
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: widget.isAmharic ? 'ምድብ' : 'Category',
                            ),
                            items: _categories
                                .where((c) => c != 'All')
                                .map((c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(
                                        DisplayNames.category(c, isAmharic: widget.isAmharic),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => category = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<Gender>(
                            initialValue: gender,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: widget.isAmharic ? 'ፆታ' : 'Gender',
                            ),
                            items: Gender.values
                                .map((g) => DropdownMenuItem(
                                      value: g,
                                      child: Text(
                                        DisplayNames.gender(g, isAmharic: widget.isAmharic),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => gender = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.sizeStock,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: sizeControllers.entries.map((e) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                            child: TextField(
                              controller: e.value,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                labelText: e.key,
                                hintText: '0',
                                floatingLabelBehavior: FloatingLabelBehavior.always,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final price = double.tryParse(priceController.text) ?? 0.0;
                  if (name.isEmpty || price <= 0) return;

                  final Map<String, int> sizeQty = {};
                  for (final e in sizeControllers.entries) {
                    sizeQty[e.key] = int.tryParse(e.value.text) ?? 0;
                  }

                  final brand = brandController.text.trim().isNotEmpty ? brandController.text.trim() : 'Coki';
                  final color = colorController.text.trim().isNotEmpty ? colorController.text.trim() : 'Classic';
                  final typedBarcode = barcodeController.text.trim();

                  // A barcode must identify exactly one product, or scanning breaks.
                  if (typedBarcode.isNotEmpty) {
                    final owner = await _sqliteService.getProductByBarcode(typedBarcode);
                    final bool conflict;
                    if (owner == null) {
                      conflict = false;
                    } else if (productToEdit != null) {
                      conflict = owner.productId != productToEdit.productId;
                    } else {
                      // Adding: allowed only if it's a restock of that same product
                      // (same name/brand/color/gender → PRD merge rule applies).
                      conflict = owner.productName.toLowerCase() != name.toLowerCase() ||
                          owner.brand.toLowerCase() != brand.toLowerCase() ||
                          owner.color.toLowerCase() != color.toLowerCase() ||
                          owner.gender != gender;
                    }
                    if (conflict) {
                      setDialogState(() => errorText = widget.isAmharic
                          ? 'ይህ ባርኮድ አስቀድሞ ለ"${owner!.productName}" ተመዝግቧል።'
                          : 'This barcode is already used by "${owner!.productName}".');
                      return;
                    }
                  }

                  if (productToEdit != null) {
                    // Edit: overwrite details, SET stock to the typed numbers.
                    // Empty barcode field keeps the current barcode.
                    await _sqliteService.updateProduct(
                      productId: productToEdit.productId,
                      barcode: typedBarcode,
                      name: name,
                      sku: skuController.text.trim(),
                      category: category,
                      brand: brand,
                      color: color,
                      gender: gender,
                      price: price,
                      image: imageController.text.trim(),
                      sizeQuantities: sizeQty,
                    );
                  } else {
                    // Add: PRD merge rule — quantities are ADDED to a matching product.
                    final barcode = typedBarcode.isNotEmpty
                        ? typedBarcode
                        : BarcodeGenerator.generateInStoreEan13();
                    await _sqliteService.addOrUpdateProduct(
                      name: name,
                      sku: skuController.text.trim(),
                      barcode: barcode,
                      // Derived from the (unique) barcode so QR codes are unique too.
                      qrCode: 'QR-$barcode',
                      category: category,
                      brand: brand,
                      color: color,
                      gender: gender,
                      price: price,
                      image: imageController.text.trim(),
                      sizeQuantities: sizeQty,
                    );
                  }

                  Navigator.of(ctx).pop();
                  _loadProducts();
                },
                // "Save Changes" only makes sense when editing.
                child: Text(productToEdit != null ? l10n.save : l10n.addProduct),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final products = _filteredProducts;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.navInventory,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // View Switcher (Card View vs List View per design spec)
          IconButton(
            tooltip: _isCardView ? l10n.listView : l10n.cardView,
            icon: Icon(
              _isCardView ? Icons.view_list : Icons.grid_view,
              color: AppColors.primaryGreen,
            ),
            onPressed: () => setState(() => _isCardView = !_isCardView),
          ),
          if (widget.userRole != UserRole.employee)
            IconButton(
              tooltip: l10n.addProduct,
              icon: const Icon(Icons.add_circle, color: AppColors.primaryGreen, size: 28),
              onPressed: () => _showAddEditProductDialog(),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: AppColors.secondaryBrown),
                hintText: l10n.searchPlaceholder,
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Categories Horizontal Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(
                      cat == 'All' ? l10n.allCategories : DisplayNames.category(cat, isAmharic: widget.isAmharic),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primaryGreen,
                    backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppColors.primaryGreen : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                    ),
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Products Display Area (Card View vs List View)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                : products.isEmpty
                    ? Center(
                        child: Text(
                          widget.isAmharic ? 'ምንም የተገኘ ምርት የለም' : 'No products found',
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      )
                    : _isCardView
                        ? GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 0.68,
                            ),
                            itemCount: products.length,
                            itemBuilder: (ctx, idx) {
                              final p = products[idx];
                              return ProductCard(
                                product: p,
                                isAmharic: widget.isAmharic,
                                onTap: () => _openProductDetails(p),
                                onDelete: _soldOutDelete(p),
                              );
                            },
                          )
                        : ListView.builder(
                            itemCount: products.length,
                            itemBuilder: (ctx, idx) {
                              final p = products[idx];
                              return ProductListRow(
                                product: p,
                                isAmharic: widget.isAmharic,
                                onTap: () => _openProductDetails(p),
                                onDelete: _soldOutDelete(p),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
