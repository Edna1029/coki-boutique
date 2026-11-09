# Coki Boutique - Store Management System

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)](https://flutter.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20%2B%20BLoC%20%2B%20Repository-10B981)](#architecture)
[![Database](https://img.shields.io/badge/Database-SQLite%20(Offline--First)%20%2B%20Firestore-8B5E3C)](#database-architecture)
[![Bilingual](https://img.shields.io/badge/Localization-English%20%26%20Amharic-blue)](#localization)

A production-ready retail mobile and tablet store management application built for **Coki Boutique** (clothing and fashion accessories retail). Built according to the **Coki Store PRD** and the **UI/UX Design Specification**.

---

## 🎨 Visual Design System

The application design blends a modern professional business POS with a high-end fashion boutique aesthetic:

| Token | Light Mode | Dark Mode | Usage |
|---|---|---|---|
| **Primary Brand** | `#10B981` (Emerald Green) | `#10B981` | Primary buttons, active navigation, positive KPI indicators |
| **Secondary Accent** | `#8B5E3C` (Warm Brown) | `#A47551` | Category tags, decorative highlights, borders |
| **Background** | `#F8FAFC` | `#1E1E1E` | Main scaffold background |
| **Surface** | `#FFFFFF` | `#2A2A2A` | Cards, dialogs, bottom sheets, navigation |
| **Text Primary** | `#1F2937` | `#F3F4F6` | Main headings, labels |
| **Text Secondary** | `#6B7280` | `#B0B0B0` | Subtitles, SKU codes, secondary text |
| **Credit Pending** | `#F59E0B` (Orange) | `#F59E0B` | Unpaid credit status |
| **Credit Partial** | `#3B82F6` (Blue) | `#3B82F6` | Partially paid credit status |
| **Credit Paid** | `#10B981` (Green) | `#10B981` | Fully settled credit accounts |

### Component Radii:
- **Buttons:** 12–16px (`AppDimensions.radiusButton = 14px`)
- **Cards:** 16–20px (`AppDimensions.radiusCard = 18px`)
- **Inputs:** 12px (`AppDimensions.radiusInput = 12px`)
- **Dialogs:** 20px (`AppDimensions.radiusDialog = 20px`)

---

## 🏛️ System Architecture

```text
Flutter UI Layer (Views & Widgets)
          ↓
     BLoC Layer (State Management)
          ↓
  Repository Layer (Single Source of Truth)
          ↓
   SQLite Database (Offline-First Local Source of Truth)
          ↓
  Synchronization Queue (Conflict Resolution: Latest Timestamp Wins)
          ↓
  Firebase Firestore (Cloud Backup & Multi-device Sync)
```

---

## 📂 Project Directory Structure

```text
coki_boutique/
├── android/
│   ├── app/
│   │   ├── build.gradle
│   │   └── src/main/AndroidManifest.xml
│   └── build.gradle
├── web/
│   ├── index.html
│   └── manifest.json
├── web_preview/
│   └── index.html                # Interactive browser testbed & prototype
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart    # Emerald Green & Warm Brown palette
│   │   │   ├── app_dimensions.dart# Spacing, border radii & soft shadows
│   │   │   └── app_typography.dart# Noto Sans & Noto Sans Ethiopic
│   │   ├── localization/
│   │   │   ├── app_localizations.dart
│   │   │   └── ethiopian_calendar.dart # Gregorian <-> Ethiopian converter
│   │   ├── theme/
│   │   │   └── app_theme.dart     # Light & Dark theme definitions
│   │   └── utils/
│   │       ├── currency_formatter.dart # ETB 1,500.00 / 1,500.00 ብር
│   │       └── date_formatter.dart     # Gregorian / Ethiopian formatted
│   ├── data/
│   │   ├── database/
│   │   │   ├── database_helper.dart    # SQLite singleton & seed data
│   │   │   └── tables.dart             # Complete DDL tables
│   │   ├── models/
│   │   │   ├── user_model.dart
│   │   │   ├── product_model.dart
│   │   │   ├── product_variant_model.dart # Size (S, M, L, XL, XXL) & Stock
│   │   │   ├── sale_model.dart
│   │   │   ├── credit_sale_model.dart
│   │   │   ├── payment_model.dart
│   │   │   └── sync_queue_item.dart
│   │   ├── repositories/
│   │   │   ├── auth_repository.dart
│   │   │   ├── inventory_repository.dart
│   │   │   ├── sales_repository.dart
│   │   │   └── credit_repository.dart
│   │   └── services/
│   │       ├── sqlite_service.dart     # Core CRUD & Section 11 inventory rule
│   │       ├── firestore_sync_service.dart # Cloud sync engine
│   │       ├── firebase_auth_service.dart  # Role-based authentication
│   │       ├── excel_export_service.dart   # Inventory, Sales & Credit .xlsx
│   │       ├── pdf_receipt_service.dart    # Bilingual thermal PDF receipts
│   │       └── backup_restore_service.dart # Owner-only JSON backup/restore
│   ├── domain/
│   │   └── entities/
│   │       └── enums.dart              # UserRole, CreditStatus, Gender, etc.
│   ├── presentation/
│   │   ├── screens/
│   │   │   ├── auth/
│   │   │   │   └── login_screen.dart   # Fashion backdrop, glassmorphism card
│   │   │   ├── main_layout_screen.dart # Mobile bottom nav & tablet sidebar
│   │   │   ├── dashboard/
│   │   │   │   └── dashboard_screen.dart # KPIs, charts, low stock alerts
│   │   │   ├── inventory/
│   │   │   │   ├── inventory_screen.dart # Card view & List view switcher
│   │   │   │   └── product_details_screen.dart # Per-size breakdown
│   │   │   ├── sales/
│   │   │   │   └── pos_screen.dart     # Barcode, QR scan, cart, sale flow
│   │   │   ├── credit/
│   │   │   │   └── credit_sales_screen.dart # Status badges, payment tracking
│   │   │   ├── reports/
│   │   │   │   └── reports_screen.dart # Weekly/monthly charts & exports
│   │   │   └── settings/
│   │   │       └── settings_screen.dart# Language, theme, sync, backup
│   │   └── widgets/
│   │       ├── kpi_card.dart
│   │       ├── product_card.dart
│   │       └── customer_credit_card.dart
│   ├── l10n/
│   │   ├── app_en.arb                  # English string catalog
│   │   └── app_am.arb                  # Amharic string catalog
│   ├── l10n.yaml
│   └── main.dart                       # App entrypoint & dynamic locale/theme
├── pubspec.yaml
└── coki_store_PRD.txt
```

---

## 💾 Database Architecture

### SQLite Tables (Local Source of Truth)
- `users`: `user_id`, `full_name`, `email`, `phone_number`, `role`, `date_created`, `last_login`
- `products`: `product_id`, `product_name`, `sku`, `barcode`, `qr_code`, `category`, `brand`, `color`, `gender`, `price`, `product_image`, `date_added`, `last_updated`
- `product_variants`: `variant_id`, `product_id`, `size`, `quantity`, `last_updated`
- `sales`: `sale_id`, `subtotal`, `tax_amount`, `total_amount`, `employee_id`, `employee_name`, `customer_name`, `customer_phone`, `date`, `payment_method`
- `sale_items`: `sale_item_id`, `sale_id`, `product_id`, `product_name`, `size`, `quantity`, `unit_price`, `total_amount`
- `credit_sales`: `credit_id`, `customer_name`, `phone_number`, `products_description`, `total_quantity`, `total_amount_owed`, `amount_paid`, `remaining_balance`, `due_date`, `date_created`, `status`
- `payments`: `payment_id`, `credit_id`, `payment_date`, `amount_paid`, `employee_id`, `employee_name`, `note`
- `inventory_logs`: `log_id`, `product_id`, `change_type`, `quantity_change`, `previous_quantity`, `new_quantity`, `timestamp`, `user_id`
- `sync_queue`: `queue_id`, `table_name`, `record_id`, `operation`, `payload`, `timestamp`, `retry_count`, `status`
- `settings`: `key`, `value`

### PRD Section 11 Inventory Rule:
When new inventory is added: If `Product Name`, `Brand`, `Color`, `Gender`, and `Size` match an existing product variant, the system increases quantity instead of creating a duplicate product entry.

### PRD Section 17 Automatic Completion Logic:
When customer installments reduce remaining balance to `0`, the system automatically transitions the status to **Fully Paid**, logs the payment, and updates reports.

---

## 🌐 Localization & Calendar Support

### Language Selection
Instant toggle between English (`en`) and Amharic (`am`) without restarting the app.

### Currency Formatting
- English: `ETB 1,500.00`
- Amharic: `1,500.00 ብር`

### Ethiopian Calendar Conversion
- Internal storage: `UTC ISO 8601`
- Display in Amharic: Ethiopian Calendar (e.g. `24 ሰኔ 2018`)
- Display in English: Gregorian Calendar (e.g. `June 24, 2026`)

---

## 🚀 Running the Application

### Option 1: Interactive Browser Prototype (Instant)
Open `web_preview/index.html` in any web browser (Chrome, Edge, Firefox).
It includes:
- Instant English / Amharic language switch
- Light Mode / Dark Mode toggle
- Mobile frame / Tablet collapsible sidebar switch
- Live POS checkout with VAT 15% calculation and thermal receipt generation
- Card View vs List View inventory switcher
- Credit payment tracking that automatically marks accounts as Fully Paid
- Excel export simulation

### Option 2: Running via Flutter SDK
```bash
# 1. Fetch Flutter dependencies
flutter pub get

# 2. Run on connected Android device or emulator
flutter run

# 3. Or run on Chrome
flutter run -d chrome
```

---

## 🔐 Default Demo Accounts
- **Owner:** `owner@cokiboutique.com` (Full access, backup/restore, user management)
- **Admin:** `admin@cokiboutique.com` (Inventory, sales, credit management)
- **Employee:** `staff@cokiboutique.com` (POS sales, credit sales, payment recording)
