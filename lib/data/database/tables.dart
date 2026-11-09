class DatabaseTables {
  static const String tableUsers = 'users';
  static const String tableProducts = 'products';
  static const String tableProductVariants = 'product_variants';
  static const String tableSales = 'sales';
  static const String tableSaleItems = 'sale_items';
  static const String tableCreditSales = 'credit_sales';
  static const String tablePayments = 'payments';
  static const String tableInventoryLogs = 'inventory_logs';
  static const String tableSyncQueue = 'sync_queue';
  static const String tableSettings = 'settings';

  static const String createUsersTable = '''
    CREATE TABLE $tableUsers (
      user_id TEXT PRIMARY KEY,
      full_name TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      phone_number TEXT,
      role TEXT NOT NULL,
      date_created TEXT NOT NULL,
      last_login TEXT
    );
  ''';

  static const String createProductsTable = '''
    CREATE TABLE $tableProducts (
      product_id TEXT PRIMARY KEY,
      product_name TEXT NOT NULL,
      sku TEXT NOT NULL,
      barcode TEXT,
      qr_code TEXT,
      category TEXT NOT NULL,
      brand TEXT NOT NULL,
      color TEXT NOT NULL,
      gender TEXT NOT NULL,
      price REAL NOT NULL,
      product_image TEXT,
      date_added TEXT NOT NULL,
      last_updated TEXT NOT NULL
    );
  ''';

  static const String createProductVariantsTable = '''
    CREATE TABLE $tableProductVariants (
      variant_id TEXT PRIMARY KEY,
      product_id TEXT NOT NULL,
      size TEXT NOT NULL,
      quantity INTEGER NOT NULL DEFAULT 0,
      last_updated TEXT NOT NULL,
      FOREIGN KEY (product_id) REFERENCES $tableProducts (product_id) ON DELETE CASCADE
    );
  ''';

  static const String createSalesTable = '''
    CREATE TABLE $tableSales (
      sale_id TEXT PRIMARY KEY,
      subtotal REAL NOT NULL,
      tax_amount REAL NOT NULL,
      total_amount REAL NOT NULL,
      employee_id TEXT NOT NULL,
      employee_name TEXT NOT NULL,
      customer_name TEXT,
      customer_phone TEXT,
      date TEXT NOT NULL,
      payment_method TEXT NOT NULL
    );
  ''';

  static const String createSaleItemsTable = '''
    CREATE TABLE $tableSaleItems (
      sale_item_id TEXT PRIMARY KEY,
      sale_id TEXT NOT NULL,
      product_id TEXT NOT NULL,
      product_name TEXT NOT NULL,
      size TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      unit_price REAL NOT NULL,
      total_amount REAL NOT NULL,
      FOREIGN KEY (sale_id) REFERENCES $tableSales (sale_id) ON DELETE CASCADE
    );
  ''';

  static const String createCreditSalesTable = '''
    CREATE TABLE $tableCreditSales (
      credit_id TEXT PRIMARY KEY,
      customer_name TEXT NOT NULL,
      phone_number TEXT NOT NULL,
      products_description TEXT NOT NULL,
      total_quantity INTEGER NOT NULL,
      total_amount_owed REAL NOT NULL,
      amount_paid REAL NOT NULL DEFAULT 0.0,
      remaining_balance REAL NOT NULL,
      due_date TEXT NOT NULL,
      date_created TEXT NOT NULL,
      status TEXT NOT NULL,
      sale_id TEXT
    );
  ''';

  /// v2: links a credit account to the POS sale that took the goods out of
  /// stock. NULL for old free-text credit records.
  static const String addCreditSaleIdColumn =
      'ALTER TABLE $tableCreditSales ADD COLUMN sale_id TEXT';

  static const String createPaymentsTable = '''
    CREATE TABLE $tablePayments (
      payment_id TEXT PRIMARY KEY,
      credit_id TEXT NOT NULL,
      payment_date TEXT NOT NULL,
      amount_paid REAL NOT NULL,
      employee_id TEXT NOT NULL,
      employee_name TEXT NOT NULL,
      note TEXT,
      FOREIGN KEY (credit_id) REFERENCES $tableCreditSales (credit_id) ON DELETE CASCADE
    );
  ''';

  static const String createInventoryLogsTable = '''
    CREATE TABLE $tableInventoryLogs (
      log_id TEXT PRIMARY KEY,
      product_id TEXT NOT NULL,
      change_type TEXT NOT NULL,
      quantity_change INTEGER NOT NULL,
      previous_quantity INTEGER NOT NULL,
      new_quantity INTEGER NOT NULL,
      timestamp TEXT NOT NULL,
      user_id TEXT NOT NULL
    );
  ''';

  static const String createSyncQueueTable = '''
    CREATE TABLE $tableSyncQueue (
      queue_id TEXT PRIMARY KEY,
      table_name TEXT NOT NULL,
      record_id TEXT NOT NULL,
      operation TEXT NOT NULL,
      payload TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      retry_count INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'pending'
    );
  ''';

  static const String createSettingsTable = '''
    CREATE TABLE $tableSettings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
  ''';
}
