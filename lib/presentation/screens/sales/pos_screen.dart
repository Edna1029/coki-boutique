import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../widgets/sync_refresh_mixin.dart';
import '../../widgets/barcode_scanner_screen.dart';
import '../../widgets/phone_number_field.dart';
import '../../widgets/product_image.dart';
import '../../../core/utils/phone_number.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/sale_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/pdf_receipt_service.dart';
import '../../../data/services/sqlite_service.dart';

class PosScreen extends StatefulWidget {
  final UserModel currentUser;
  final bool isAmharic;

  /// Switches to the Inventory tab (used by the "no products yet" screen).
  final VoidCallback? onGoToInventory;

  const PosScreen({
    super.key,
    required this.currentUser,
    required this.isAmharic,
    this.onGoToInventory,
  });

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class CartEntry {
  /// Not final: refreshed after every product reload so stock limits stay current.
  ProductModel product;
  String size;
  int quantity;

  CartEntry({
    required this.product,
    required this.size,
    this.quantity = 1,
  });

  double get total => product.price * quantity;
}

class _PosScreenState extends State<PosScreen> with SyncRefreshMixin {
  final SQLiteService _sqliteService = SQLiteService();
  bool _isLoading = true;
  String _searchQuery = '';

  List<ProductModel> _products = [];
  final List<CartEntry> _cart = [];
  String _paymentMethod = 'cash'; // 'cash', 'mobile_transfer', 'credit'
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();

  // Phone layout: the cart is shown in a modal bottom sheet. A modal route is
  // NOT rebuilt by this State's setState, so we keep a handle to the sheet's
  // own setter and its own ScaffoldMessenger (so snackbars show above it).
  StateSetter? _sheetSetState;
  BuildContext? _sheetContext;
  final _sheetMessengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Use instead of setState for anything the cart UI displays, so both the
  /// screen and the open cart sheet (if any) redraw.
  void _updateCart(VoidCallback change) {
    setState(change);
    _sheetSetState?.call(() {});
  }

  /// Snackbars go to the cart sheet while it's open, otherwise to the screen.
  ScaffoldMessengerState get _messenger =>
      _sheetMessengerKey.currentState ?? ScaffoldMessenger.of(context);

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
      final items = await _sqliteService.getAllProducts();
      if (mounted) {
        final byId = {for (final p in items) p.productId: p};
        _updateCart(() {
          _products = items;
          // Point cart lines at the fresh data so +/- limits use current stock.
          for (final entry in _cart) {
            final fresh = byId[entry.product.productId];
            if (fresh != null) entry.product = fresh;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addToCart(ProductModel product, [String? preferredSize]) {
    final availableSizes = product.variants.where((v) => v.quantity > 0).toList();
    if (availableSizes.isEmpty) {
      _messenger.showSnackBar(
        SnackBar(
          content: Text(widget.isAmharic ? 'በክምችት ላይ የለም!' : 'Out of stock!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final selectedSize = preferredSize ?? availableSizes.first.size;

    final existingIndex = _cart.indexWhere(
      (c) => c.product.productId == product.productId && c.size == selectedSize,
    );

    if (existingIndex >= 0) {
      _incrementCartEntry(_cart[existingIndex]);
    } else {
      _updateCart(() => _cart.add(CartEntry(product: product, size: selectedSize)));
    }
  }

  /// Adds one more unit of [entry], unless that would exceed the stock for
  /// its size. Stock is re-checked inside the sale transaction as well.
  void _incrementCartEntry(CartEntry entry) {
    final available = entry.product.stockForSize(entry.size);
    if (entry.quantity >= available) {
      _showStockLimitMessage(entry.product.productName, entry.size, available);
      return;
    }
    _updateCart(() => entry.quantity += 1);
  }

  void _showStockLimitMessage(String productName, String size, int available) {
    _messenger.hideCurrentSnackBar();
    _messenger.showSnackBar(
      SnackBar(
        content: Text(
          widget.isAmharic
              ? '$productName (መጠን $size): በክምችት ያሉት $available ብቻ ናቸው'
              : 'Only $available left of $productName in size $size',
        ),
        backgroundColor: AppColors.error,
      ),
    );
  }

  /// PRD §14 workflow: scan code → find product → show it (size picker) →
  /// proceed to sale. Matches barcode, QR code or SKU.
  Future<void> _scanProduct() async {
    final code = await BarcodeScannerScreen.scan(context);
    if (code == null || !mounted) return;

    final found = await _sqliteService.getProductByCode(code);
    if (!mounted) return;
    if (found == null) {
      _messenger.showSnackBar(
        SnackBar(
          content: Text(widget.isAmharic
              ? 'ለ "$code" የሚዛመድ ምርት አልተገኘም'
              : 'No product found for "$code"'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    // Prefer the copy already on screen (same data the cart uses).
    final product = _products.firstWhere(
      (p) => p.productId == found.productId,
      orElse: () => found,
    );
    if (product.totalStock <= 0) {
      _showSoldOutMessage(product);
      return;
    }
    _showSizePickerSheet(product);
  }

  void _showSoldOutMessage(ProductModel product) {
    _messenger.hideCurrentSnackBar();
    _messenger.showSnackBar(
      SnackBar(
        content: Text(widget.isAmharic
            ? '${product.productName} ተሽጦ አልቋል'
            : '${product.productName} is sold out'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  double get _subtotal => _cart.fold(0.0, (sum, c) => sum + c.total);
  /// Shelf prices are the final prices: no VAT is added at the till
  /// (owner's decision, 2026-11-12). Sales are stored with tax 0.
  double get _tax => 0;
  double get _total => _subtotal;

  List<SaleItemModel> _cartAsSaleItems() {
    return _cart.map((entry) {
      return SaleItemModel(
        saleItemId: const Uuid().v4(),
        saleId: '',
        productId: entry.product.productId,
        productName: entry.product.productName,
        size: entry.size,
        quantity: entry.quantity,
        unitPrice: entry.product.price,
        totalAmount: entry.total,
      );
    }).toList();
  }

  /// After a successful sale: close the phone cart sheet (so the old cart
  /// isn't left behind the dialog), empty the cart and reload stock.
  void _resetAfterSale() {
    final sheetCtx = _sheetContext;
    if (sheetCtx != null && sheetCtx.mounted) {
      Navigator.of(sheetCtx).pop();
    }
    _updateCart(() {
      _cart.clear();
      _customerNameCtrl.clear();
      _customerPhoneCtrl.clear();
      _paymentMethod = 'cash';
    });
    _loadProducts();
  }

  /// True while a sale is being written. A second tap on "Complete Sale"
  /// during that time must not record the same cart again.
  bool _savingSale = false;

  Future<void> _completeSale() async {
    if (_cart.isEmpty || _savingSale) return;
    if (_paymentMethod == 'credit') {
      _showCreditDetailsDialog();
      return;
    }

    _updateCart(() => _savingSale = true);
    try {
      final sale = await _sqliteService.processSale(
        items: _cartAsSaleItems(),
        subtotal: _subtotal,
        taxAmount: _tax,
        totalAmount: _total,
        employeeId: widget.currentUser.userId,
        employeeName: widget.currentUser.fullName,
        customerName: _customerNameCtrl.text.isNotEmpty ? _customerNameCtrl.text : null,
        customerPhone: _customerPhoneCtrl.text.isNotEmpty ? _customerPhoneCtrl.text : null,
        paymentMethod: _paymentMethod,
      );

      _resetAfterSale();
      _showSaleCompleteDialog(sale);
    } on InsufficientStockException catch (e) {
      // Stock changed since the cart was filled. Nothing was saved; refresh the
      // product list so the grid shows real numbers, and keep the cart so the
      // cashier can lower the quantity and try again.
      _loadProducts();
      if (mounted) _showStockLimitMessage(e.productName, e.size, e.available);
    } catch (e) {
      if (mounted) {
        _messenger.showSnackBar(
          SnackBar(
            content: Text(widget.isAmharic ? 'ስህተት: $e' : 'Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) _updateCart(() => _savingSale = false);
    }
  }

  /// Credit checkout: who is taking the goods, any down payment, and when the
  /// rest is due. The goods leave stock now; the balance is tracked on the
  /// Credit screen.
  void _showCreditDetailsDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final depositCtrl = TextEditingController();
    var dueDate = DateTime.now().add(const Duration(days: 30));
    var country = PhoneNumbers.ethiopia;
    String? phoneError;
    String? errorText;
    var saving = false;
    final am = widget.isAmharic;
    final total = _total;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(builder: (dialogCtx, setDialogState) {
        final l10n = AppLocalizations.of(context);

        Future<void> save() async {
          final name = nameCtrl.text.trim();
          final digits = phoneCtrl.text.trim();
          final deposit = double.tryParse(depositCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
          if (name.isEmpty) {
            setDialogState(() => errorText = am ? 'እባክዎ የደንበኛውን ስም ያስገቡ።' : 'Please enter the customer\'s name.');
            return;
          }
          final badPhone = PhoneNumberField.validate(country, digits, isAmharic: am);
          if (badPhone != null) {
            setDialogState(() {
              phoneError = badPhone;
              errorText = null;
            });
            return;
          }
          final phone = PhoneNumbers.toE164(country, digits);
          setDialogState(() {
            saving = true;
            errorText = null;
            phoneError = null;
          });
          try {
            final result = await _sqliteService.processCreditSale(
              items: _cartAsSaleItems(),
              subtotal: _subtotal,
              taxAmount: _tax,
              totalAmount: total,
              employeeId: widget.currentUser.userId,
              employeeName: widget.currentUser.fullName,
              customerName: name,
              customerPhone: phone,
              initialDeposit: deposit,
              dueDate: DateTime(dueDate.year, dueDate.month, dueDate.day, 23, 59).toUtc().toIso8601String(),
            );
            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
            _resetAfterSale();
            _showSaleCompleteDialog(result.sale, owed: result.credit.remainingBalance, customer: name);
          } on InvalidPaymentException catch (e) {
            final max = CurrencyFormatter.format(e.maxAllowed, isAmharic: am);
            setDialogState(() {
              saving = false;
              errorText = e.reason == PaymentRejection.depositExceedsTotal
                  ? (am ? 'ቅድመ ክፍያው ከጠቅላላው በላይ ሊሆን አይችልም። ከፍተኛው: $max' : 'Down payment cannot be more than the total. Maximum: $max')
                  : (am ? 'ቅድመ ክፍያው ትክክል አይደለም።' : 'The down payment is not valid.');
            });
          } on InsufficientStockException catch (e) {
            // Stock changed meanwhile: nothing was saved. Back to the cart.
            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
            _loadProducts();
            if (mounted) _showStockLimitMessage(e.productName, e.size, e.available);
          } catch (e) {
            setDialogState(() {
              saving = false;
              errorText = am ? 'ስህተት: $e' : 'Error: $e';
            });
          }
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusDialog)),
          title: Text(l10n.newCreditSale, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
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
                    child: Text(errorText!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                  ),
                Text(
                  '${am ? "ጠቅላላ:" : "Total:"} ${CurrencyFormatter.format(total, isAmharic: am)}'
                  '  ·  ${am ? "$_cartUnits ዕቃዎች" : "$_cartUnits ${_cartUnits == 1 ? 'item' : 'items'}"}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: l10n.customerName, prefixIcon: const Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 10),
                PhoneNumberField(
                  controller: phoneCtrl,
                  country: country,
                  isAmharic: am,
                  enabled: !saving,
                  labelText: '${l10n.customerPhone} *',
                  errorText: phoneError,
                  onCountryChanged: (c) => setDialogState(() {
                    country = c;
                    phoneError = null;
                  }),
                  onChanged: (_) {
                    if (phoneError != null) setDialogState(() => phoneError = null);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: depositCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: am ? 'ቅድመ ክፍያ (ካለ)' : 'Down payment (optional)',
                    hintText: '0',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: saving
                      ? null
                      : () async {
                          final today = DateTime.now();
                          final picked = await showDatePicker(
                            context: dialogCtx,
                            initialDate: dueDate,
                            firstDate: DateTime(today.year, today.month, today.day),
                            lastDate: today.add(const Duration(days: 365)),
                          );
                          if (picked != null) setDialogState(() => dueDate = picked);
                        },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.dueDate,
                      prefixIcon: const Icon(Icons.event_outlined),
                    ),
                    child: Text(DateFormatter.formatDate(dueDate, isAmharic: am)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(dialogCtx).pop(),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: saving ? null : save,
              child: Text(am ? 'የብድር ሽያጭ መዝግብ' : 'Record credit sale'),
            ),
          ],
        );
      }),
    );
  }

  /// [owed] / [customer] are set for a credit sale: the dialog then shows
  /// what the customer still owes instead of "Total Paid".
  void _showSaleCompleteDialog(SaleModel sale, {double? owed, String? customer}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusDialog)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                owed == null
                    ? (widget.isAmharic ? 'ሽያጩ በተሳካ ሁኔታ ተጠናቋል!' : 'Sale Completed Successfully!')
                    : (widget.isAmharic ? 'የብድር ሽያጭ ተመዝግቧል!' : 'Credit Sale Recorded!'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                owed == null
                    ? '${widget.isAmharic ? "ጠቅላላ:" : "Total Paid:"} ${CurrencyFormatter.format(sale.totalAmount, isAmharic: widget.isAmharic)}'
                    : '${widget.isAmharic ? "ጠቅላላ:" : "Total:"} ${CurrencyFormatter.format(sale.totalAmount, isAmharic: widget.isAmharic)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              if (owed != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.isAmharic
                      ? '$customer ቀሪ ዕዳ: ${CurrencyFormatter.format(owed, isAmharic: true)}'
                      : '$customer owes: ${CurrencyFormatter.format(owed)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.error),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                '${widget.isAmharic ? "የደረሰኝ ቁጥር:" : "Receipt ID:"} ${sale.saleId.substring(0, 8).toUpperCase()}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                PdfReceiptService.printReceipt(sale, isAmharic: widget.isAmharic);
              },
              icon: const Icon(Icons.print),
              label: Text(widget.isAmharic ? 'ደረሰኝ አትም' : 'Print Receipt'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(widget.isAmharic ? 'ቀጣይ ሽያጭ' : 'New Sale'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = _products.where((p) {
      return p.productName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.sku.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.barcode.contains(_searchQuery);
    }).toList()
      // Sellable products first; sold-out ones stay visible (greyed) at the end.
      ..sort((a, b) => (a.totalStock > 0 ? 0 : 1).compareTo(b.totalStock > 0 ? 0 : 1));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.posTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Camera scanner: reads both barcodes and QR codes.
          IconButton(
            tooltip: widget.isAmharic ? 'ባርኮድ / QR ይቃኙ' : 'Scan barcode / QR',
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.primaryGreen, size: 28),
            onPressed: _scanProduct,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 850;

          if (isWide) {
            // Split Tablet / Desktop view: Product Grid on Left (60%), Cart on Right (40%)
            return Row(
              children: [
                Expanded(
                  flex: 6,
                  child: _buildProductSection(filtered, l10n, isDark),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 4,
                  child: _buildCartSection(l10n, isDark),
                ),
              ],
            );
          } else {
            // Mobile Tab View with floating or bottom sheet cart summary
            return Column(
              children: [
                Expanded(child: _buildProductSection(filtered, l10n, isDark)),
                _buildMobileCartBottomBar(l10n, isDark),
              ],
            );
          }
        },
      ),
    );
  }

  /// Shown when there is nothing to sell: either no products at all yet, or
  /// the search matched nothing.
  Widget _buildEmptyProducts(bool isDark) {
    final muted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final noProductsAtAll = _products.isEmpty;
    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 60),
          Icon(noProductsAtAll ? Icons.checkroom_outlined : Icons.search_off, size: 64, color: muted),
          const SizedBox(height: 16),
          Text(
            noProductsAtAll
                ? (widget.isAmharic ? 'እስካሁን ምንም ምርት የለም' : 'No products yet')
                : (widget.isAmharic ? 'ምንም የሚዛመድ ምርት የለም' : 'No matching products'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            noProductsAtAll
                ? (widget.isAmharic
                    ? 'ለመሸጥ መጀመሪያ በ"ዕቃዎች ዝርዝር" ውስጥ ምርቶችን ይመዝግቡ።'
                    : 'Add products in Inventory first, then they will appear here to sell.')
                : (widget.isAmharic ? 'የተለየ ስም፣ SKU ወይም ባርኮድ ይሞክሩ።' : 'Try a different name, SKU or barcode.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: muted),
          ),
          if (noProductsAtAll && widget.onGoToInventory != null) ...[
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: widget.onGoToInventory,
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text(widget.isAmharic ? 'ወደ ዕቃዎች ዝርዝር ሂድ' : 'Go to Inventory'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductSection(List<ProductModel> filtered, AppLocalizations l10n, bool isDark) {
    return Column(
      children: [
        // Search Area
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: AppColors.secondaryBrown),
              hintText: l10n.searchPlaceholder,
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),

        // Product Grid Area
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
              : filtered.isEmpty
                  ? _buildEmptyProducts(isDark)
                  : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final prod = filtered[idx];
                    return _buildPosProductCard(prod, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPosProductCard(ProductModel prod, bool isDark) {
    final soldOut = prod.totalStock <= 0;
    return Opacity(
      // Sold out: greyed, red "Sold out" badge, disabled + button.
      opacity: soldOut ? 0.55 : 1,
      child: Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: isDark ? AppDimensions.darkCardShadow : AppDimensions.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ProductImage(url: prod.productImage),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: soldOut ? AppColors.error : Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      soldOut
                          ? (widget.isAmharic ? 'ተሽጦ አልቋል' : 'Sold out')
                          : (widget.isAmharic ? '${prod.totalStock} በክምችት' : '${prod.totalStock} in stock'),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    prod.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        CurrencyFormatter.format(prod.price, isAmharic: widget.isAmharic),
                        style: const TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      InkWell(
                        onTap: soldOut ? () => _showSoldOutMessage(prod) : () => _showSizePickerSheet(prod),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: soldOut ? Colors.grey : AppColors.primaryGreen,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(soldOut ? Icons.block : Icons.add, color: Colors.white, size: 14),
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
    );
  }

  void _showSizePickerSheet(ProductModel prod) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.isAmharic ? "መጠን ይምረጡ -" : "Select Size -"} ${prod.productName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                children: prod.variants.map((v) {
                  final inStock = v.quantity > 0;
                  return ActionChip(
                    // Solid green + white text for sizes in stock: readable in
                    // light and dark mode (was light text on pale green).
                    label: Text(
                      '${v.size} (${v.quantity})',
                      style: TextStyle(
                        color: inStock ? Colors.white : null,
                        fontWeight: inStock ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    backgroundColor: inStock ? AppColors.primaryGreen : null,
                    side: inStock ? BorderSide.none : null,
                    onPressed: inStock
                        ? () {
                            Navigator.of(ctx).pop();
                            _addToCart(prod, v.size);
                          }
                        : null,
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Payment method option. Selected = solid green with white text, so the
  /// choice is clearly readable in both light and dark mode.
  Widget _buildPaymentChip({required String label, required String value}) {
    final selected = _paymentMethod == value;
    return ChoiceChip(
      label: Center(child: Text(label)),
      selected: selected,
      showCheckmark: true,
      checkmarkColor: Colors.white,
      selectedColor: AppColors.primaryGreen,
      labelStyle: TextStyle(
        color: selected ? Colors.white : null,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => _updateCart(() => _paymentMethod = value),
    );
  }

  int get _cartUnits => _cart.fold(0, (sum, c) => sum + c.quantity);

  Widget _buildCartSection(AppLocalizations l10n, bool isDark) {
    return Container(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: AppColors.primaryGreen),
                  const SizedBox(width: 8),
                  Text(
                    l10n.cart,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              if (_cart.isNotEmpty)
                TextButton(
                  onPressed: () => _updateCart(() => _cart.clear()),
                  child: Text(widget.isAmharic ? 'አጽዳ' : 'Clear', style: const TextStyle(color: AppColors.error)),
                ),
            ],
          ),
          const Divider(),

          // Cart Items List
          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Text(
                      l10n.emptyCart,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _cart.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final item = _cart[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.productName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  Text(
                                    '${widget.isAmharic ? "መጠን:" : "Size:"} ${item.size} | ${CurrencyFormatter.format(item.product.price, isAmharic: widget.isAmharic)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Qty controls (- / +)
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                                  onPressed: () {
                                    _updateCart(() {
                                      if (item.quantity > 1) {
                                        item.quantity -= 1;
                                      } else {
                                        _cart.removeAt(idx);
                                      }
                                    });
                                  },
                                ),
                                Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 18),
                                  onPressed: () => _incrementCartEntry(item),
                                ),
                              ],
                            ),
                            Text(
                              CurrencyFormatter.format(item.total, isAmharic: widget.isAmharic),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          const Divider(),

          // Totals Area
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.total, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                CurrencyFormatter.format(_total, isAmharic: widget.isAmharic),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Payment Mode Selector
          Row(
            children: [
              Expanded(
                child: _buildPaymentChip(
                  label: widget.isAmharic ? 'ጥሬ ገንዘብ' : 'Cash',
                  value: 'cash',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: _buildPaymentChip(
                  label: 'CBE / Telebirr',
                  value: 'mobile_transfer',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildPaymentChip(
                  label: widget.isAmharic ? 'ብድር' : 'Credit',
                  value: 'credit',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Complete Sale Button (Emerald Green per spec)
          ElevatedButton(
            onPressed: _cart.isEmpty || _savingSale ? null : _completeSale,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusButton)),
            ),
            child: Text(
              l10n.completeSale,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCartBottomBar(AppLocalizations l10n, bool isDark) {
    if (_cart.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
        boxShadow: isDark ? AppDimensions.darkCardShadow : AppDimensions.softShadow,
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.isAmharic
                      ? '$_cartUnits ዕቃዎች በጋሪ'
                      : '$_cartUnits ${_cartUnits == 1 ? 'item' : 'items'} in cart',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                Text(
                  CurrencyFormatter.format(_total, isAmharic: widget.isAmharic),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  clipBehavior: Clip.antiAlias,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (sheetCtx) {
                    _sheetContext = sheetCtx;
                    return StatefulBuilder(
                      builder: (ctx, setSheetState) {
                        _sheetSetState = setSheetState;
                        return SizedBox(
                          height: MediaQuery.of(context).size.height * 0.8,
                          // Own messenger + scaffold so snackbars appear above the sheet.
                          child: ScaffoldMessenger(
                            key: _sheetMessengerKey,
                            child: Scaffold(
                              backgroundColor: Colors.transparent,
                              body: _buildCartSection(l10n, isDark),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ).whenComplete(() {
                  _sheetSetState = null;
                  _sheetContext = null;
                });
              },
              child: Text(l10n.completeSale),
            ),
          ],
        ),
      ),
    );
  }
}
