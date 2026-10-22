import 'dart:typed_data';

import 'freshness_result.dart';

/// A saved manual classification and the image that produced it.
class ScanHistoryEntry {
  const ScanHistoryEntry({
    required this.imageBytes,
    required this.result,
    required this.scannedAt,
  });

  final Uint8List imageBytes;
  final FreshnessResult result;
  final DateTime scannedAt;
}

/// A deleted history entry with its former position for undo.
class DeletedScan {
  const DeletedScan(this.entry, this.index);

  final ScanHistoryEntry entry;
  final int index;
}

/// In-memory bounded scan history with delete and undo operations.
class ScanHistory {
  ScanHistory({this.maxEntries = 20});

  final int maxEntries;
  final List<ScanHistoryEntry> _entries = [];

  List<ScanHistoryEntry> get entries => List.unmodifiable(_entries);

  ScanHistoryEntry add({
    required Uint8List imageBytes,
    required FreshnessResult result,
    DateTime? scannedAt,
  }) {
    final entry = ScanHistoryEntry(
      imageBytes: imageBytes,
      result: result,
      scannedAt: scannedAt ?? DateTime.now(),
    );
    _entries.add(entry);
    while (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
    return entry;
  }

  DeletedScan? delete(ScanHistoryEntry entry) {
    final index = _entries.indexOf(entry);
    if (index < 0) return null;
    return DeletedScan(_entries.removeAt(index), index);
  }

  void undo(DeletedScan deleted) {
    if (_entries.contains(deleted.entry)) return;
    final index = deleted.index.clamp(0, _entries.length);
    _entries.insert(index, deleted.entry);
    if (_entries.length > maxEntries) _entries.removeAt(0);
  }

  void clear() => _entries.clear();
}
