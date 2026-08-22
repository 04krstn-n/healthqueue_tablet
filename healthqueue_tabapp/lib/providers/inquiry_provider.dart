import 'package:flutter/material.dart';
import '../models/inquiry_model.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class InquiryProvider extends ChangeNotifier {
  List<InquiryModel> _inquiries = [];
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
      // Fetch all logs — escalated ones come with isEscalated=true
      final data = await StaffApiService.getChatLogs(clinicId: clinicId ?? _clinicId);
      _inquiries = data
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
      // Update locally
      final idx = _inquiries.indexWhere((i) => i.id == id);
      if (idx >= 0) {
        final old = _inquiries[idx];
        _inquiries[idx] = InquiryModel(
          id: old.id, message: old.message, reply: old.reply,
          patientName: old.patientName, createdAt: old.createdAt,
          isFallback: old.isFallback, source: old.source,
          isEscalated: old.isEscalated, escalationNote: old.escalationNote,
          resolvedByStaff: true, resolvedNote: note,
        );
        notifyListeners();
      }
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
