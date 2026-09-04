import 'package:flutter/material.dart';
import '../models/inquiry_model.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class InquiryProvider extends ChangeNotifier {
  List<InquiryModel> _inquiries = [];
  // Fetched separately from /chatbot-admin/escalated rather than filtered
  // out of `_inquiries` client-side — `_inquiries` is capped at the last
  // 100 messages of ANY kind, so on a busy clinic an older unresolved
  // escalation could fall off that cap before staff ever saw it. The
  // dedicated endpoint is sorted by escalation time and isn't diluted by
  // regular FAQ/bot chatter, so nothing gets lost.
  List<InquiryModel> _escalated = [];
  bool    _loading = false;
  String? _error;
  String  _query   = '';
  String? _clinicId;
  final ClinicSocketService _socket = ClinicSocketService();

  // Tracks which unresolved escalation ids we've already seen, so a new
  // one can be detected without ever double-firing for the same
  // escalation across repeated socket pushes/reloads. Set on the very
  // first load (so opening the app with existing unresolved escalations
  // doesn't immediately alert for all of them) — only escalations that
  // arrive AFTER that baseline trigger the floating alert.
  Set<String>? _knownUnresolvedIds;

  // One-shot signal for the app-wide floating alert (see main.dart) —
  // set the instant a genuinely new unresolved escalation is detected,
  // cleared by the UI via dismissEscalationAlert() once shown.
  InquiryModel? _pendingAlert;
  InquiryModel? get pendingAlert => _pendingAlert;
  void dismissEscalationAlert() {
    _pendingAlert = null;
    notifyListeners();
  }

  int get unresolvedEscalationCount =>
      _escalated.where((i) => !i.resolvedByStaff).length;

  // ── Live thread (open conversation view) ──────────────────────────────
  // Separate from `_inquiries`/`_escalated` (the inbox lists) — this is
  // the full back-and-forth for whichever patient's dialog is currently
  // open. Loaded on demand rather than kept for every patient at once.
  List<ThreadMessageModel> _thread = [];
  bool _threadLoading = false;
  String? _threadError;
  String? _threadPatientId;

  List<ThreadMessageModel> get thread => _thread;
  bool get threadLoading => _threadLoading;
  String? get threadError => _threadError;

  Future<void> loadThread(String patientId) async {
    _threadPatientId = patientId;
    _threadLoading = true; _threadError = null; notifyListeners();
    try {
      final results = await StaffApiService.getThreadMessages(patientId);
      // Guard against the dialog having been closed/reopened for a
      // different patient while this request was in flight.
      if (_threadPatientId != patientId) return;
      _thread = results
          .map((e) => ThreadMessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on StaffApiException catch (e) {
      _threadError = e.message;
    } catch (_) {
      _threadError = 'Failed to load conversation.';
    } finally {
      _threadLoading = false; notifyListeners();
    }
  }

  // Sends a live reply WITHOUT resolving the escalation — the actual
  // back-and-forth channel (see StaffApiService.replyToThread). Appends
  // optimistically so the dialog updates instantly rather than waiting on
  // a full thread refetch.
  Future<bool> sendThreadReply(String patientId, String text) async {
    try {
      await StaffApiService.replyToThread(patientId, text);
      if (_threadPatientId == patientId) {
        _thread = [
          ..._thread,
          ThreadMessageModel(
            id: 'local-${DateTime.now().microsecondsSinceEpoch}',
            patientText: '',
            replyText: text,
            fromStaff: true,
            createdAt: 'now',
          ),
        ];
        notifyListeners();
      }
      return true;
    } on StaffApiException catch (e) {
      _threadError = e.message; notifyListeners();
      return false;
    } catch (_) {
      _threadError = 'Failed to send reply.'; notifyListeners();
      return false;
    }
  }

  void clearThread() {
    _thread = [];
    _threadPatientId = null;
    _threadError = null;
    notifyListeners();
  }

  List<InquiryModel> get inquiries {
    if (_query.isEmpty) return _inquiries;
    final q = _query.toLowerCase();
    return _inquiries.where((i) =>
      i.message.toLowerCase().contains(q) ||
      i.patientName.toLowerCase().contains(q)
    ).toList();
  }

  List<InquiryModel> get escalatedInquiries {
    if (_query.isEmpty) return _escalated;
    final q = _query.toLowerCase();
    return _escalated.where((i) =>
      i.message.toLowerCase().contains(q) ||
      i.patientName.toLowerCase().contains(q)
    ).toList();
  }

  bool    get isLoading => _loading;
  String? get error     => _error;

  Future<void> loadInquiries({String? clinicId}) async {
    if (clinicId != null && clinicId != _clinicId) {
      _clinicId = clinicId;
      // Chatbot escalations were never pushed live — staff only saw new
      // ones on a manual refresh/re-open of the screen. This subscribes to
      // the same 'chat_escalated' event the server already emits (see
      // chatbotController.js) so the list refreshes as soon as a patient
      // escalates, matching how the queue screens already behave.
      _socket.connect(
        clinicId,
        eventNames: const ['chat_escalated', 'chat_thread_message'],
        onQueueUpdated: (data) {
          loadInquiries(clinicId: _clinicId);
          // If the currently-open thread dialog just got a new message
          // (from either side), refresh it too so staff see it live
          // instead of only after closing and reopening the dialog.
          final patientId = (data is Map ? data['patientId'] : null)?.toString();
          if (patientId != null && patientId == _threadPatientId) {
            loadThread(patientId);
          }
        },
      );
    }
    _loading = true; _error = null; notifyListeners();
    try {
      final targetClinicId = clinicId ?? _clinicId;
      final results = await Future.wait([
        StaffApiService.getChatLogs(clinicId: targetClinicId),
        StaffApiService.getEscalatedLogs(clinicId: targetClinicId),
      ]);
      _inquiries = (results[0])
          .map((e) => InquiryModel.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _escalated = (results[1])
          .map((e) => InquiryModel.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Detect newly-arrived unresolved escalations for the floating alert.
      final unresolvedNow = _escalated.where((i) => !i.resolvedByStaff);
      final currentIds = unresolvedNow.map((i) => i.id).toSet();
      if (_knownUnresolvedIds == null) {
        // First load this session — establish the baseline without
        // alerting for anything that was already sitting there.
        _knownUnresolvedIds = currentIds;
      } else {
        final newIds = currentIds.difference(_knownUnresolvedIds!);
        if (newIds.isNotEmpty) {
          // Most recent of the newly-arrived ones, since _escalated is
          // already sorted newest-first.
          _pendingAlert = unresolvedNow.firstWhere((i) => newIds.contains(i.id));
        }
        _knownUnresolvedIds = currentIds;
      }
    } on StaffApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Failed to load patient inquiries.';
    } finally {
      _loading = false; notifyListeners();
    }
  }

  Future<void> resolveEscalation(String id, {String note = ''}) async {
    try {
      await StaffApiService.resolveEscalation(id, note: note);
      // Update locally in both lists — the entry can appear in `_inquiries`
      // (general log feed) as well as `_escalated` (dedicated feed).
      InquiryModel resolve(InquiryModel old) => InquiryModel(
        id: old.id, message: old.message, reply: old.reply,
        patientName: old.patientName, createdAt: old.createdAt,
        isFallback: old.isFallback, source: old.source,
        isEscalated: old.isEscalated, escalationNote: old.escalationNote,
        resolvedByStaff: true, resolvedNote: note,
      );
      final idx = _inquiries.indexWhere((i) => i.id == id);
      if (idx >= 0) _inquiries[idx] = resolve(_inquiries[idx]);
      final eIdx = _escalated.indexWhere((i) => i.id == id);
      if (eIdx >= 0) _escalated[eIdx] = resolve(_escalated[eIdx]);
      // So a future re-escalation of this same chat log is treated as new
      // rather than being silently suppressed as "already seen".
      _knownUnresolvedIds?.remove(id);
      notifyListeners();
    } on StaffApiException catch (e) {
      _error = e.message; notifyListeners();
    }
  }

  void search(String q) { _query = q; notifyListeners(); }

  // Permanently clears this clinic's chat logs. The confirmation dialog
  // lives in the screen (see patient_inquiry_screen.dart _confirmClearLogs)
  // — this only performs the actual clear once the user has confirmed.
  Future<bool> clearLogs() async {
    try {
      await StaffApiService.clearChatLogs();
      _inquiries = [];
      _escalated = [];
      _knownUnresolvedIds = {};
      notifyListeners();
      return true;
    } on StaffApiException catch (e) {
      _error = e.message; notifyListeners();
      return false;
    } catch (_) {
      _error = 'Failed to clear chat logs.'; notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _socket.dispose();
    super.dispose();
  }
}
