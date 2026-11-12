import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../database/database_helper.dart';
import '../database/tables.dart';
import '../models/sync_queue_item.dart';
import '../services/sqlite_service.dart';
import '../../domain/entities/enums.dart';
import 'remote_apply.dart';

/// What the Settings screen shows about sync.
@immutable
class SyncStatus {
  final int pending;
  final bool online;
  final bool syncing;
  final DateTime? lastSuccess;
  final String? lastError;

  /// True when the same change has failed to upload several times for a
  /// reason that is NOT "no internet" (e.g. permission denied). Everything
  /// queued behind it is waiting too, so the screen must say so.
  final bool stuck;

  const SyncStatus({
    this.pending = 0,
    this.online = false,
    this.syncing = false,
    this.lastSuccess,
    this.lastError,
    this.stuck = false,
  });

  SyncStatus copyWith({
    int? pending,
    bool? online,
    bool? syncing,
    DateTime? lastSuccess,
    String? lastError,
    bool? stuck,
    bool clearError = false,
  }) =>
      SyncStatus(
        pending: pending ?? this.pending,
        online: online ?? this.online,
        syncing: syncing ?? this.syncing,
        lastSuccess: lastSuccess ?? this.lastSuccess,
        lastError: clearError ? null : (lastError ?? this.lastError),
        stuck: clearError ? false : (stuck ?? this.stuck),
      );
}

/// Two-way sync between this device's SQLite database and Firestore, for a
/// shop running several devices (PRD §23).
///
/// UPLOAD — the local `sync_queue` (written in the same transaction as every
/// local change) is sent in order. Each entry runs as a Firestore transaction,
/// so it either fully succeeds or fails cleanly while offline:
///   * insert / delete: idempotent set (delete = `deleted: true`).
///   * update: "latest updated timestamp wins" against the cloud copy.
///   * increment: adds a signed delta (stock, amount paid). A marker document
///     `sync_ops/{queueId}` is written in the same transaction, so a retry
///     after a dropped connection can never apply the same change twice.
/// Every write stamps `server_updated_at` with the server's clock.
///
/// DOWNLOAD — live listeners per collection, filtered to documents changed
/// since the last applied `server_updated_at`; documents are applied by
/// [RemoteApply] (tested separately). Firestore delivers changes from other
/// devices within seconds while online, and catches up after being offline.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final ValueNotifier<SyncStatus> status = ValueNotifier(const SyncStatus());

  /// Increments whenever downloaded data changed the local database.
  /// Screens listen to this to reload.
  final ValueNotifier<int> dataVersion = ValueNotifier(0);

  final SQLiteService _local = SQLiteService();
  FirebaseFirestore get _fs => FirebaseFirestore.instance;

  final List<StreamSubscription> _subs = [];
  Timer? _periodic;
  Timer? _debounce;
  bool _started = false;
  bool _pushing = false;
  bool _pushAgain = false;
  Future<void> _applyChain = Future.value();

  /// Docs whose parent hasn't arrived yet: key "collection/id".
  final Map<String, (String, String, Map<String, dynamic>, Timestamp?)> _deferred = {};

  static const _opsCollection = 'sync_ops';
  static const _pullKeyPrefix = 'sync_pull_';

  // ---------------------------------------------------------------------------
  // Lifecycle

  /// Call once a user is signed in.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    SQLiteService.onLocalChange = _schedulePush;
    try {
      await _local.purgeCompletedSync();
    } catch (_) {}
    await _refreshPending();
    for (final c in RemoteApply.syncedCollections) {
      await _listen(c);
    }
    _periodic = Timer.periodic(const Duration(minutes: 1), (_) => pushNow());
    unawaited(pushNow());
  }

  /// Call on sign-out.
  Future<void> stop() async {
    _started = false;
    SQLiteService.onLocalChange = null;
    _periodic?.cancel();
    _debounce?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _deferred.clear();
  }

  /// Manual "Sync now".
  Future<void> syncNow() => pushNow();

  void _schedulePush() {
    // Show "N waiting" right away (a push while offline can take a while to fail).
    Future.delayed(const Duration(milliseconds: 300), _refreshPending);
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), () => pushNow());
  }

  Future<void> _refreshPending() async {
    try {
      status.value = status.value.copyWith(pending: await _local.pendingSyncCount());
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Upload

  Future<void> pushNow() async {
    if (!_started) return;
    if (_pushing) {
      _pushAgain = true;
      return;
    }
    _pushing = true;
    status.value = status.value.copyWith(syncing: true);
    try {
      do {
        _pushAgain = false;
        await _pushPending();
      } while (_pushAgain && _started);
    } finally {
      _pushing = false;
      await _refreshPending();
      status.value = status.value.copyWith(syncing: false);
    }
  }

  Future<void> _pushPending() async {
    final items = await _local.getPendingSyncQueue();
    if (items.isEmpty) {
      status.value = status.value.copyWith(lastSuccess: DateTime.now(), clearError: true);
      return;
    }
    for (final item in items) {
      try {
        final cloudWinner = await _upload(item).timeout(const Duration(seconds: 25));
        await _local.markSyncItemCompleted(item.queueId);
        if (cloudWinner != null) {
          // Our edit lost to a newer one from another device. Take the cloud
          // copy now, or this device would keep showing its own old edit.
          final db = await DatabaseHelper.instance.database;
          final r = await db.transaction(
              (txn) => RemoteApply.apply(txn, item.tableName, item.recordId, cloudWinner));
          if (r == ApplyResult.applied) dataVersion.value++;
        }
      } catch (e) {
        // Keep order: stop at the first failure and retry later (offline,
        // permission, timeout…). Safe to retry — see class doc.
        await _local.markSyncItemFailed(item.queueId);
        final offline = _isOffline(e);
        status.value = status.value.copyWith(
          lastError: e.toString(),
          online: offline ? false : null,
          stuck: isStuck(failuresSoFar: item.retryCount + 1, offline: offline),
        );
        debugPrint('Sync upload paused at ${item.tableName}/${item.recordId}: $e');
        return;
      }
    }
    status.value = status.value.copyWith(lastSuccess: DateTime.now(), clearError: true, online: true);
  }

  /// Failures of one change before the Settings screen warns about it.
  static const stuckAfterFailures = 5;

  /// A change counts as stuck once it has failed [stuckAfterFailures] times
  /// for a reason other than being offline (offline just means "wait").
  @visibleForTesting
  static bool isStuck({required int failuresSoFar, required bool offline}) =>
      !offline && failuresSoFar >= stuckAfterFailures;

  bool _isOffline(Object e) =>
      e is TimeoutException || (e is FirebaseException && (e.code == 'unavailable' || e.code == 'deadline-exceeded'));

  /// Uploads one queue entry. Returns the cloud document when an `update`
  /// was dropped because the cloud copy is newer (the caller then applies
  /// that copy locally); otherwise null.
  Future<Map<String, dynamic>?> _upload(SyncQueueItem item) async {
    final data = jsonDecode(item.payload) as Map<String, dynamic>;
    final ref = _fs.collection(item.tableName).doc(item.recordId);
    final stamp = {'server_updated_at': FieldValue.serverTimestamp()};
    Map<String, dynamic>? cloudWinner;

    await _fs.runTransaction((tx) async {
      cloudWinner = null; // Firestore may run this body more than once
      switch (item.operation) {
        case SyncOperation.insert:
          tx.set(ref, {...data, ...stamp, 'deleted': false}, SetOptions(merge: true));
          break;

        case SyncOperation.delete:
          tx.set(ref, {'deleted': true, 'last_updated': data['last_updated'], ...stamp}, SetOptions(merge: true));
          break;

        case SyncOperation.update:
          final snap = await tx.get(ref);
          final cloudTime = DateTime.tryParse((snap.data()?['last_updated'] as String?) ?? '');
          final ourTime = DateTime.tryParse((data['last_updated'] as String?) ?? '');
          if (cloudTime != null && ourTime != null && cloudTime.isAfter(ourTime)) {
            // Conflict: another device changed it later — theirs wins (PRD §23).
            debugPrint('Sync conflict on ${item.tableName}/${item.recordId}: cloud is newer, local edit dropped');
            cloudWinner = snap.data();
            return;
          }
          tx.set(ref, {...data, ...stamp}, SetOptions(merge: true));
          break;

        case SyncOperation.increment:
          final marker = _fs.collection(_opsCollection).doc(item.queueId);
          if ((await tx.get(marker)).exists) return; // already applied once
          tx.set(
            ref,
            {
              data['field'] as String: FieldValue.increment(data['delta'] as num),
              'last_updated': data['last_updated'],
              ...stamp,
            },
            SetOptions(merge: true),
          );
          tx.set(marker, {
            'table': item.tableName,
            'record': item.recordId,
            'at': FieldValue.serverTimestamp(),
          });
          break;
      }
    });
    return cloudWinner;
  }

  // ---------------------------------------------------------------------------
  // Download

  Future<void> _listen(String collection) async {
    final since = await _getPull(collection);
    Query<Map<String, dynamic>> q = _fs.collection(collection);
    if (since != null) q = q.where('server_updated_at', isGreaterThanOrEqualTo: since);

    final sub = q.snapshots(includeMetadataChanges: collection == DatabaseTables.tableProducts).listen(
      (snap) {
        // The products listener also reports whether we're talking to the server.
        if (collection == DatabaseTables.tableProducts) {
          final online = !snap.metadata.isFromCache;
          final wasOnline = status.value.online;
          status.value = status.value.copyWith(online: online);
          if (online && !wasOnline) unawaited(pushNow()); // connection is back
        }
        final docs = [
          for (final ch in snap.docChanges)
            if (ch.type != DocumentChangeType.removed && !ch.doc.metadata.hasPendingWrites)
              (collection, ch.doc.id, ch.doc.data() ?? <String, dynamic>{},
                  ch.doc.data()?['server_updated_at'] as Timestamp?),
        ];
        if (docs.isEmpty) return;
        _applyChain = _applyChain.then((_) => _applyBatch(docs)).catchError((Object e) {
          debugPrint('Sync download error ($collection): $e');
        });
      },
      onError: (Object e) {
        debugPrint('Sync listener error ($collection): $e');
        status.value = status.value.copyWith(lastError: e.toString());
      },
    );
    _subs.add(sub);
  }

  Future<void> _applyBatch(List<(String, String, Map<String, dynamic>, Timestamp?)> docs) async {
    final db = await DatabaseHelper.instance.database;
    var changed = 0;
    final newestApplied = <String, Timestamp>{};

    Future<void> run(List<(String, String, Map<String, dynamic>, Timestamp?)> batch) async {
      await db.transaction((txn) async {
        for (final (collection, id, data, ts) in batch) {
          final r = await RemoteApply.apply(txn, collection, id, data);
          final key = '$collection/$id';
          if (r == ApplyResult.deferred) {
            _deferred[key] = (collection, id, data, ts);
            continue;
          }
          _deferred.remove(key);
          if (r == ApplyResult.applied) changed++;
          if (ts != null) {
            final cur = newestApplied[collection];
            if (cur == null || ts.compareTo(cur) > 0) newestApplied[collection] = ts;
          }
        }
      });
    }

    await run(docs);
    // A parent may have just arrived — retry anything that was waiting.
    if (_deferred.isNotEmpty) await run(_deferred.values.toList());

    for (final e in newestApplied.entries) {
      await _savePull(e.key, e.value);
    }
    if (changed > 0) dataVersion.value++;
  }

  /// Never advance a collection's bookmark past a doc still waiting for its
  /// parent, or it would be skipped after an app restart.
  Future<void> _savePull(String collection, Timestamp newest) async {
    var bookmark = newest;
    for (final (c, _, _, ts) in _deferred.values) {
      if (c == collection && ts != null && ts.compareTo(bookmark) < 0) bookmark = ts;
    }
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      DatabaseTables.tableSettings,
      {'key': '$_pullKeyPrefix$collection', 'value': bookmark.microsecondsSinceEpoch.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Timestamp?> _getPull(String collection) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseTables.tableSettings,
      where: 'key = ?',
      whereArgs: ['$_pullKeyPrefix$collection'],
      limit: 1,
    );
    final v = rows.isEmpty ? null : int.tryParse(rows.first['value'] as String);
    return v == null ? null : Timestamp.fromMicrosecondsSinceEpoch(v);
  }
}
