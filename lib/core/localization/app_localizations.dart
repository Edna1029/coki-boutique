import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_am.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'localization/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('am'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Coki Boutique'**
  String get appTitle;

  /// No description provided for @storeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clothing & Accessories Store Management'**
  String get storeSubtitle;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get login;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember Me'**
  String get rememberMe;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get selectLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @amharic.
  ///
  /// In en, this message translates to:
  /// **'አማርኛ'**
  String get amharic;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @owner.
  ///
  /// In en, this message translates to:
  /// **'Store Owner'**
  String get owner;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get admin;

  /// No description provided for @employee.
  ///
  /// In en, this message translates to:
  /// **'Staff / Cashier'**
  String get employee;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get navInventory;

  /// No description provided for @navSales.
  ///
  /// In en, this message translates to:
  /// **'Sales POS'**
  String get navSales;

  /// No description provided for @navCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit Sales'**
  String get navCredit;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navUsers.
  ///
  /// In en, this message translates to:
  /// **'User Management'**
  String get navUsers;

  /// No description provided for @navBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup & Sync'**
  String get navBackup;

  /// No description provided for @totalProducts.
  ///
  /// In en, this message translates to:
  /// **'Total Products'**
  String get totalProducts;

  /// No description provided for @inventoryCount.
  ///
  /// In en, this message translates to:
  /// **'Inventory Stock'**
  String get inventoryCount;

  /// No description provided for @totalSales.
  ///
  /// In en, this message translates to:
  /// **'Total Sales'**
  String get totalSales;

  /// No description provided for @creditBalance.
  ///
  /// In en, this message translates to:
  /// **'Credit Balance'**
  String get creditBalance;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get addProduct;

  /// No description provided for @newSale.
  ///
  /// In en, this message translates to:
  /// **'New Sale'**
  String get newSale;

  /// No description provided for @newCreditSale.
  ///
  /// In en, this message translates to:
  /// **'Credit Sale'**
  String get newCreditSale;

  /// No description provided for @addInventory.
  ///
  /// In en, this message translates to:
  /// **'Restock Items'**
  String get addInventory;

  /// No description provided for @generateReport.
  ///
  /// In en, this message translates to:
  /// **'Generate Report'**
  String get generateReport;

  /// No description provided for @weeklySales.
  ///
  /// In en, this message translates to:
  /// **'Weekly Sales Overview'**
  String get weeklySales;

  /// No description provided for @monthlyRevenue.
  ///
  /// In en, this message translates to:
  /// **'Monthly Revenue Trend'**
  String get monthlyRevenue;

  /// No description provided for @bestSelling.
  ///
  /// In en, this message translates to:
  /// **'Best Selling Products'**
  String get bestSelling;

  /// No description provided for @recentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get recentTransactions;

  /// No description provided for @lowStockAlerts.
  ///
  /// In en, this message translates to:
  /// **'Low Stock Alerts'**
  String get lowStockAlerts;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search products, SKU, barcode...'**
  String get searchPlaceholder;

  /// No description provided for @cardView.
  ///
  /// In en, this message translates to:
  /// **'Card View'**
  String get cardView;

  /// No description provided for @listView.
  ///
  /// In en, this message translates to:
  /// **'List View'**
  String get listView;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get allCategories;

  /// No description provided for @brand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get brand;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @men.
  ///
  /// In en, this message translates to:
  /// **'Men'**
  String get men;

  /// No description provided for @women.
  ///
  /// In en, this message translates to:
  /// **'Women'**
  String get women;

  /// No description provided for @unisex.
  ///
  /// In en, this message translates to:
  /// **'Unisex'**
  String get unisex;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @stock.
  ///
  /// In en, this message translates to:
  /// **'In Stock'**
  String get stock;

  /// No description provided for @sku.
  ///
  /// In en, this message translates to:
  /// **'SKU'**
  String get sku;

  /// No description provided for @barcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get barcode;

  /// No description provided for @qrCode.
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get qrCode;

  /// No description provided for @sizeStock.
  ///
  /// In en, this message translates to:
  /// **'Stock Per Size'**
  String get sizeStock;

  /// No description provided for @small.
  ///
  /// In en, this message translates to:
  /// **'Small (S)'**
  String get small;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium (M)'**
  String get medium;

  /// No description provided for @large.
  ///
  /// In en, this message translates to:
  /// **'Large (L)'**
  String get large;

  /// No description provided for @xl.
  ///
  /// In en, this message translates to:
  /// **'Extra Large (XL)'**
  String get xl;

  /// No description provided for @xxl.
  ///
  /// In en, this message translates to:
  /// **'Double XL (XXL)'**
  String get xxl;

  /// No description provided for @posTitle.
  ///
  /// In en, this message translates to:
  /// **'Point of Sale'**
  String get posTitle;

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Shopping Cart'**
  String get cart;

  /// No description provided for @emptyCart.
  ///
  /// In en, this message translates to:
  /// **'Cart is empty. Select items to begin sale.'**
  String get emptyCart;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @tax.
  ///
  /// In en, this message translates to:
  /// **'Tax (VAT 15%)'**
  String get tax;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get total;

  /// No description provided for @completeSale.
  ///
  /// In en, this message translates to:
  /// **'Complete Sale'**
  String get completeSale;

  /// No description provided for @customerName.
  ///
  /// In en, this message translates to:
  /// **'Customer Name'**
  String get customerName;

  /// No description provided for @customerPhone.
  ///
  /// In en, this message translates to:
  /// **'Customer Phone Number'**
  String get customerPhone;

  /// No description provided for @dueDate.
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get dueDate;

  /// No description provided for @amountPaid.
  ///
  /// In en, this message translates to:
  /// **'Amount Paid'**
  String get amountPaid;

  /// No description provided for @remainingBalance.
  ///
  /// In en, this message translates to:
  /// **'Remaining Balance'**
  String get remainingBalance;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @partiallyPaid.
  ///
  /// In en, this message translates to:
  /// **'Partially Paid'**
  String get partiallyPaid;

  /// No description provided for @fullyPaid.
  ///
  /// In en, this message translates to:
  /// **'Fully Paid'**
  String get fullyPaid;

  /// No description provided for @recordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record Payment'**
  String get recordPayment;

  /// No description provided for @paymentHistory.
  ///
  /// In en, this message translates to:
  /// **'Payment History'**
  String get paymentHistory;

  /// No description provided for @exportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get exportPdf;

  /// No description provided for @exportExcel.
  ///
  /// In en, this message translates to:
  /// **'Export Excel (.xlsx)'**
  String get exportExcel;

  /// No description provided for @syncStatus.
  ///
  /// In en, this message translates to:
  /// **'Cloud Synchronization'**
  String get syncStatus;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now with Firestore'**
  String get syncNow;

  /// No description provided for @lastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced'**
  String get lastSynced;

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'Operating Offline (SQLite Local)'**
  String get offlineMode;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get themeMode;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logout;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @items.
  ///
  /// In en, this message translates to:
  /// **'items'**
  String get items;

  /// No description provided for @receipt.
  ///
  /// In en, this message translates to:
  /// **'Official Store Receipt'**
  String get receipt;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['am', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'am':
      return AppLocalizationsAm();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
