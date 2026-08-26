import 'package:flutter/material.dart';
import '../models/queue_model.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class QueueProvider extends ChangeNotifier {
  List<QueueModel> _entries = [];
  bool    _loading  = false;
  String? _error;
  String? _clinicId;
  final ClinicSocketService _socket = ClinicSocketService();

  List<QueueModel> get entries   => _entries;
  bool             get isLoading => _loading;
  String?          get error     => _error;

  // Server status enums: waiting | called | serving | done | completed | no_show | skipped | cancelled
  List<QueueModel> get waiting   => _entries.where((e) => e.status == 'waiting').toList();
  List<QueueModel> get called    => _entries.where((e) => e.status == 'called').toList();
  List<QueueModel> get serving   => _entries.where((e) => e.status == 'serving').toList();
  List<QueueModel> get completed => _entries.where((e) => ['done','completed'].contains(e.status)).toList();
  List<QueueModel> get noShow    => _entries.where((e) => e.status == 'no_show').toList();
  List<QueueModel> get skipped   => _entries.where((e) => e.status == 'skipped').toList();
  List<QueueModel> get cancelled => _entries.where((e) => e.status == 'cancelled').toList();
  List<QueueModel> get priority  => _entries.where((e) => e.isPriority).toList();
  int get waitingCount   => waiting.length;
  int get servingCount   => serving.length;
  int get completedCount => completed.length;
  int get noShowCount    => noShow.length;
  int get skippedCount   => skipped.length;
  int get cancelledCount => cancelled.length;

  void setClinicId(String id) {
    if (_clinicId != id) {
      _clinicId = id;
      loadEntries();
      // Live sync: server emits `queue_updated` to this clinic's room
      // whenever any staff member mutates the queue (see server.js /
      // queueController). Re-fetch so all tablets stay in sync.
      _socket.connect(id, onQueueUpdated: (_) => loadEntries());
    }
  }

  @override
  void dispose() {
    _socket.dispose();
    super.dispose();
  }

  Future<void> loadEntries() async {
    if (_clinicId == null) return;
    _loading = true; _error = null; notifyListeners();
    try {
      final data = await StaffApiService.getQueueEntries(clinicId: _clinicId);
      _entries = data
          .map((e) => QueueModel.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.joinedAtRaw.compareTo(b.joinedAtRaw));
    } on StaffApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Failed to load queue.';
    } finally {
      _loading = false; notifyListeners();
    }
  }

  // Optimistic status update + server call.
  // NOTE: 'called' and 'serving' are two distinct server states — "Call"
  // moves waiting -> called (starts the 5-min grace period), then "Start"
  // moves called -> serving. Previously the "Call" button requested
  // 'serving' directly (which the server ignored, setting 'called'
  // instead) with no follow-up action wired up, so called/skipped/no_show
  // entries were stuck with no button that could move them forward. This
  // now matches each target status to the correct endpoint, including
  // 'waiting' which requeues a called/skipped/no_show entry.
  //
  // Returns null on success, or the server's error message on failure (e.g.
  // the backend rejects requeuing an entry that isn't called/skipped/
  // no_show). Callers should show this to the user — previously the error
  // was stored in [_error] but immediately wiped by the loadEntries() call
  // below before anyone could read it, so a rejected change silently
  // reverted with no explanation.
  Future<String?> updateStatus(String entryId, String rawStatus) async {
    // Normalize defensively — see the same normalization in
    // QueueModel.fromJson for why the server's casing can't be trusted.
    final status = rawStatus.toLowerCase();
    _optimisticUpdate(entryId, status);
    try {
      switch (status) {
        case 'waiting':   await StaffApiService.requeueEntry(entryId);    break;
        case 'called':    await StaffApiService.callPatient(entryId);     break;
        case 'serving':   await StaffApiService.startService(entryId);    break;
        case 'done':
        case 'completed': await StaffApiService.completePatient(entryId); break;
        case 'skipped':   await StaffApiService.skipPatient(entryId);     break;
        case 'no_show':   await StaffApiService.markNoShow(entryId);      break;
        case 'cancelled': await StaffApiService.cancelQueue(entryId);     break;
      }
      // Refresh to get authoritative state
      await loadEntries();
      return null;
    } on StaffApiException catch (e) {
      await loadEntries(); // revert the optimistic guess to the true server state
      return e.message;
    }
  }

  void _optimisticUpdate(String id, String status) {
    final idx = _entries.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final old = _entries[idx];
    _entries[idx] = QueueModel(
      id: old.id, queueNumber: old.queueNumber,
      patientName: old.patientName, patientPhone: old.patientPhone,
      patientType: old.patientType, serviceName: old.serviceName,
      queueType: old.queueType, status: status,
      joinedAt: old.joinedAt, joinedAtRaw: old.joinedAtRaw,
      isPriority: old.isPriority, notes: old.notes,
      estimatedWaitMinutes: old.estimatedWaitMinutes,
      positionAtJoin: old.positionAtJoin,
    );
    notifyListeners();
  }

  Future<void> addPatient({
    required String patientName,
    required String serviceName,
    // Required (not optional) so the patient can receive queue/turn
    // notifications — server also rejects walk-ins without a phone number.
    required String patientPhone,
    String patientType  = 'Regular',
    String notes        = '',
  }) async {
    if (_clinicId == null) return;
    try {
      await StaffApiService.addWalkIn(
        clinicId: _clinicId!,
        patientName: patientName,
        serviceName: serviceName,
        patientPhone: patientPhone,
        patientType:  patientType,
        notes:        notes.isEmpty ? null : notes,
      );
      await loadEntries();
    } on StaffApiException catch (e) {
      _error = e.message; notifyListeners();
    }
  }
}
