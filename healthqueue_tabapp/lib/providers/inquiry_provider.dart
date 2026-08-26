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
        eventNames: const ['chat_escalated'],
        onQueueUpdated: (_) => loadInquiries(clinicId: _clinicId),
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
      notifyListeners();
    } on StaffApiException catch (e) {
      _error = e.message; notifyListeners();
    }
  }

  void search(String q) { _query = q; notifyListeners(); }

  @override
  void dispose() {
    _socket.dispose();
    super.dispose();
  }
}
