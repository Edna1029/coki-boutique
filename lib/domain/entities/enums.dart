enum UserRole {
  owner,
  admin,
  employee;

  /// Shop-wide money figures: the Reports tab (revenue, credit totals, stock
  /// value, Excel export with customer phone numbers) and the dashboard's
  /// Total Sales card, weekly revenue chart and recent transactions.
  /// PRD §5 gives reports/exports to owners and admins only; employees still
  /// see stock, low-stock alerts and credit accounts.
  bool get canViewFinancials => this != UserRole.employee;

  static UserRole fromString(String val) {
    return UserRole.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => UserRole.employee,
    );
  }
}

enum CreditStatus {
  pending,
  partiallyPaid,
  fullyPaid;

  static CreditStatus fromString(String val) {
    return CreditStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => CreditStatus.pending,
    );
  }
}

enum Gender {
  men,
  women,
  unisex;

  static Gender fromString(String val) {
    return Gender.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => Gender.unisex,
    );
  }
}

enum ProductSize {
  S,
  M,
  L,
  XL,
  XXL;

  static ProductSize fromString(String val) {
    return ProductSize.values.firstWhere(
      (e) => e.name.toUpperCase() == val.toUpperCase(),
      orElse: () => ProductSize.M,
    );
  }
}

enum SyncOperation {
  /// Create the record (full payload).
  insert,

  /// Overwrite fields — "latest updated timestamp wins" (PRD §23).
  update,

  /// Soft-delete the record in the cloud.
  delete,

  /// Add a signed amount to one numeric field (payload: field, delta).
  /// Used for stock and credit amount_paid so that changes made on several
  /// devices at the same time all count, instead of overwriting each other.
  increment;
}
