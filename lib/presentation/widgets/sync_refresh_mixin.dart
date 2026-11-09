import 'package:flutter/widgets.dart';
import '../../data/sync/sync_service.dart';

/// Reloads a screen when data from another device arrives via sync.
///
/// ```dart
/// class _MyScreenState extends State<MyScreen> with SyncRefreshMixin {
///   @override
///   void onSyncedData() => _loadData();
/// }
/// ```
mixin SyncRefreshMixin<T extends StatefulWidget> on State<T> {
  /// Called (at most once per sync batch) after downloaded data changed the
  /// local database. Reload what the screen shows.
  void onSyncedData();

  void _listener() {
    if (mounted) onSyncedData();
  }

  @override
  void initState() {
    super.initState();
    SyncService.instance.dataVersion.addListener(_listener);
  }

  @override
  void dispose() {
    SyncService.instance.dataVersion.removeListener(_listener);
    super.dispose();
  }
}
