import '../../domain/entities/enums.dart';

class SyncQueueItem {
  final String queueId;
  final String tableName;
  final String recordId;
  final SyncOperation operation;
  final String payload; // JSON serialized
  final String timestamp; // UTC ISO 8601
  final int retryCount;
  final String status; // 'pending', 'in_progress', 'completed', 'failed'

  SyncQueueItem({
    required this.queueId,
    required this.tableName,
    required this.recordId,
    required this.operation,
    required this.payload,
    required this.timestamp,
    this.retryCount = 0,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'queue_id': queueId,
      'table_name': tableName,
      'record_id': recordId,
      'operation': operation.name,
      'payload': payload,
      'timestamp': timestamp,
      'retry_count': retryCount,
      'status': status,
    };
  }

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    return SyncQueueItem(
      queueId: map['queue_id'] ?? '',
      tableName: map['table_name'] ?? '',
      recordId: map['record_id'] ?? '',
      operation: SyncOperation.values.firstWhere(
        (e) => e.name == map['operation'],
        orElse: () => SyncOperation.insert,
      ),
      payload: map['payload'] ?? '{}',
      timestamp: map['timestamp'] ?? DateTime.now().toUtc().toIso8601String(),
      retryCount: (map['retry_count'] as num?)?.toInt() ?? 0,
      status: map['status'] ?? 'pending',
    );
  }
}
