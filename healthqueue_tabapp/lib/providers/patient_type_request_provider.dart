import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Staff review queue for patient-submitted Senior Citizen / PWD / Pregnant
/// verification requests (photo of ID/certificate). Not clinic-scoped —
/// see getPatientTypeRequests on the server for why. Loaded lazily (from
/// the "Type Requests" tab in Patient Inquiries) rather than eagerly at
/// login, since this is a lower-frequency review task than escalations.
class PatientTypeRequestProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _requests = [];
  bool    _loading = false;
  String? _error;
  bool    _loadedOnce = false;

  List<Map<String, dynamic>> get requests => _requests;
  List<Map<String, dynamic>> get pending =>
      _requests.where((r) => r['status'] == 'pending').toList();
  bool    get isLoading => _loading;
  String? get error     => _error;
  int     get pendingCount => pending.length;

  Future<void> load({bool force = false}) async {
    if (_loadedOnce && !force) return;
    _loadedOnce = true;
    _loading = true; _error = null; notifyListeners();
    try {
      final data = await StaffApiService.getPatientTypeRequests();
      _requests = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on StaffApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Failed to load requests.';
    } finally {
      _loading = false; notifyListeners();
    }
  }

  Future<String?> approve(String id, {String note = ''}) async {
    try {
      await StaffApiService.approvePatientTypeRequest(id, note: note);
      await load(force: true);
      return null;
    } on StaffApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Failed to approve request.';
    }
  }

  Future<String?> reject(String id, {String note = ''}) async {
    try {
      await StaffApiService.rejectPatientTypeRequest(id, note: note);
      await load(force: true);
      return null;
    } on StaffApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Failed to reject request.';
    }
  }
}
