import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../config/api_config.dart';

export '../core/network/api_exceptions.dart' show StaffApiException, ApiException;

/// Facade over [ApiClient] exposing one static method per server operation
/// the app needs. Kept as static methods (rather than an instance) because
/// that's the calling convention already used throughout providers/screens.
///
/// Endpoint paths and response shapes here are matched against the actual
/// hq-server routes/controllers — see the comment above each method.
class StaffApiService {
  StaffApiService._();

  static final ApiClient _client = ApiClient.instance;

  // ─── Token passthrough ──────────────────────────────────────────────
  static Future<void> saveToken(String token) => _client.saveToken(token);
  static Future<String?> getToken() => _client.getToken();
  static Future<void> deleteToken() => _client.deleteToken();

  // POST /auth/logout — for staff/facility_admin/super_admin the server
  // writes an audit-log entry for this (see authController.logout). This
  // used to just clear the local token, so tablet logouts never showed up
  // in the facility/super-admin Audit Log pages. The call is best-effort:
  // if it fails (e.g. no connection), we still clear the local session so
  // the user isn't stuck logged in on the device.
  static Future<void> logout() async {
    try {
      await _client.post('/auth/logout');
    } catch (_) {
      // Ignore — local logout must still proceed.
    } finally {
      await _client.deleteToken();
    }
  }

  // ─── Auth — POST /auth/login, GET /auth/me ─────────────────
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await _client.post(
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
      requiresAuth: false,
    ) as Map<String, dynamic>;

    final token = data['token'];
    if (token == null || token.toString().trim().isEmpty) {
      throw StaffApiException('No authentication token returned by server.');
    }
    await saveToken(token.toString());
    return data;
  }

  static Future<Map<String, dynamic>> getMe() async {
    final data = await _client.get('/auth/me') as Map<String, dynamic>;
    // Server nests the profile under "user".
    return (data['user'] as Map<String, dynamic>?) ?? data;
  }

  // ─── Queue — GET/PUT /queues/... ─────────────────────────────────
  // getQueueEntries: server responds { success, count, data: [...] }
  static Future<List<dynamic>> getQueueEntries({String? clinicId, String? status}) async {
    final res = await _client.get('/queues', query: {
      if (clinicId != null) 'clinicId': clinicId,
      if (status != null) 'status': status,
    });
    return (ApiClient.unwrap(res) as List<dynamic>?) ?? const [];
  }

  // getQueueMetrics: server responds a flat object (no data wrapper).
  static Future<Map<String, dynamic>> getQueueMetrics(String clinicId) async {
    final res = await _client.get('/queues/metrics', query: {'clinicId': clinicId});
    return res as Map<String, dynamic>;
  }

  // Marks the patient as "called" — server starts a 5-min grace period.
  static Future<void> callPatient(String queueId) => _client.put('/queues/$queueId/call');

  // Moves a "called" entry into "serving" (now registered server-side).
  static Future<void> startService(String queueId) => _client.put('/queues/$queueId/start-service');

  static Future<void> completePatient(String queueId) => _client.put('/queues/$queueId/complete');
  static Future<void> skipPatient(String queueId) => _client.put('/queues/$queueId/skip');
  static Future<void> markNoShow(String queueId) => _client.put('/queues/$queueId/no-show');
  // Server route is PUT /queues/:id/cancel (controller fn is `cancelEntry`).
  static Future<void> cancelQueue(String queueId) => _client.put('/queues/$queueId/cancel');
  // Brings a called/skipped/no-show entry back to "waiting".
  static Future<void> requeueEntry(String queueId) => _client.put('/queues/$queueId/requeue');

  // ─── Services — GET /services?clinicId=xxx ───────────────────────
  // Returns the list of services configured by the Facility Admin for this
  // clinic — used to populate the walk-in "Service / Reason for Visit"
  // dropdown instead of free-text entry.
  static Future<List<dynamic>> getClinicServices(String clinicId) async {
    final res = await _client.get('/services', query: {'clinicId': clinicId});
    final map = res as Map<String, dynamic>;
    return (map['services'] as List<dynamic>?) ?? const [];
  }

  static Future<Map<String, dynamic>> addWalkIn({
    required String clinicId,
    required String patientName,
    required String serviceName,
    String? patientPhone,
    String? patientType,
    String? notes,
  }) async {
    final res = await _client.post('/queues/add-walkin', body: {
      'clinicId': clinicId,
      'patientName': patientName,
      'serviceName': serviceName,
      // Server field is "phone", not "patientPhone" — see addWalkIn controller.
      if (patientPhone != null) 'phone': patientPhone,
      if (patientType != null) 'patientType': patientType,
      if (notes != null) 'notes': notes,
    });
    return res as Map<String, dynamic>;
  }

  // ─── Dashboard — GET /dashboard/facility ─────────────────────────
  // Flat response (no data wrapper) — matches DashboardModel.fromJson.
  static Future<Map<String, dynamic>> getFacilityStats(String clinicId) async {
    final res = await _client.get('/dashboard/facility', query: {'clinicId': clinicId});
    return res as Map<String, dynamic>;
  }

  // ─── Appointments — GET/PUT /appointments/... ───────────────────
  // getTodayAppointments: server responds { success, data: [...] }
  static Future<List<dynamic>> getTodayAppointments(String clinicId) async {
    final res = await _client.get('/appointments/today', query: {'clinicId': clinicId});
    return (ApiClient.unwrap(res) as List<dynamic>?) ?? const [];
  }

  static Future<List<dynamic>> getAppointments({String? clinicId, String? status}) async {
    final res = await _client.get('/appointments', query: {
      if (clinicId != null) 'clinicId': clinicId,
      if (status != null) 'status': status,
    });
    return (ApiClient.unwrap(res) as List<dynamic>?) ?? const [];
  }

  // getUpcomingAppointments -> GET /appointments?clinicId=&dateFrom=&dateTo=
  // Lets staff see today plus the next few days (not just /appointments/today)
  // so they can confirm/prep upcoming appointments in advance rather than
  // only ever seeing the current day. dateFrom/dateTo are 'YYYY-MM-DD'.
  static Future<List<dynamic>> getUpcomingAppointments({
    required String clinicId,
    required DateTime from,
    required DateTime to,
  }) async {
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final res = await _client.get('/appointments', query: {
      'clinicId': clinicId,
      'dateFrom': fmt(from),
      'dateTo': fmt(to),
    });
    return (ApiClient.unwrap(res) as List<dynamic>?) ?? const [];
  }

  static Future<void> updateAppointmentStatus(String id, String status) =>
      _client.put('/appointments/$id/status', body: {'status': status});

  // ─── Clinics — GET /clinics/:id ───────────────────────────────────
  // { success, data: {...} }
  static Future<Map<String, dynamic>> getClinic(String clinicId) async {
    final res = await _client.get('/clinics/$clinicId');
    return ApiClient.unwrap(res) as Map<String, dynamic>;
  }

  // ─── Services — PUT /services/:clinicId/:serviceId ──────────────
  // Server returns the updated service object directly (no wrapper).
  static Future<Map<String, dynamic>> updateServiceDuration(
    String clinicId,
    String serviceId,
    int durationMinutes,
  ) async {
    final res = await _client.put(
      '/services/$clinicId/$serviceId',
      body: {'durationMinutes': durationMinutes},
    );
    return res as Map<String, dynamic>;
  }

  // ─── Chatbot / Inquiries ──────────────────────────────────────────────
  // getChatLogs -> GET /chatbot-admin/logs: { success, data: [...] }
  // clinicId is passed through so results are scoped to the staff's clinic
  // (the server also enforces this for facility_admin/staff roles).
  static Future<List<dynamic>> getChatLogs({String? clinicId}) async {
    final res = await _client.get('/chatbot-admin/logs',
        query: clinicId == null ? null : {'clinicId': clinicId});
    return (ApiClient.unwrap(res) as List<dynamic>?) ?? const [];
  }

  // getEscalatedLogs -> GET /chatbot-admin/escalated: { success, data: [...] }
  // Purpose-built for the staff inquiries inbox — unlike getChatLogs (which
  // returns the last 100 messages of ANY kind, escalated or not), this only
  // returns escalations, sorted by escalatedAt, and populates the assigned
  // staff member. Using getChatLogs here meant a busy clinic's older
  // unresolved escalations could silently fall off the 100-message cap
  // before staff ever saw them.
  static Future<List<dynamic>> getEscalatedLogs({String? clinicId, bool? resolved}) async {
    final res = await _client.get('/chatbot-admin/escalated', query: {
      if (clinicId != null) 'clinicId': clinicId,
      if (resolved != null) 'resolved': resolved.toString(),
    });
    return (ApiClient.unwrap(res) as List<dynamic>?) ?? const [];
  }

  // resolveEscalation -> PUT /chatbot/resolve/:id (note: chatbot, not
  // chatbot-admin — that's where this route actually lives on the server).
  static Future<void> resolveEscalation(String id, {String note = ''}) =>
      _client.put('/chatbot/resolve/$id', body: {'note': note});

  // getThreadMessages -> GET /chatbot-admin/threads/:patientId/messages
  // Full back-and-forth for one patient (not just the single flagged
  // escalation message getEscalatedLogs returns) — used by the reply
  // dialog so staff have the whole conversation for context.
  static Future<List<dynamic>> getThreadMessages(String patientId) async {
    final res = await _client.get('/chatbot-admin/threads/$patientId/messages');
    return (ApiClient.unwrap(res) as List<dynamic>?) ?? const [];
  }

  // replyToThread -> POST /chatbot-admin/threads/:patientId/reply
  // Sends a live reply WITHOUT closing the escalation — pushes to the
  // patient's app instantly via Socket.io ('staff_chat_reply' on their
  // `user_<id>` room). Only works while the patient has an active
  // ChatSession in 'staff' mode (i.e. actually escalated).
  static Future<void> replyToThread(String patientId, String text) =>
      _client.post('/chatbot-admin/threads/$patientId/reply', body: {'text': text});

  // clearChatLogs -> DELETE /chatbot-admin/logs: { success, deletedCount }
  // Permanently clears this clinic's chat logs. The confirmation dialog
  // lives in the UI (see patient_inquiry_screen.dart) — this call is the
  // actual destructive action, restricted server-side to facility_admin/
  // super_admin.
  static Future<int> clearChatLogs() async {
    final res = await _client.delete('/chatbot-admin/logs');
    final body = res is Map<String, dynamic> ? res : <String, dynamic>{};
    return (body['deletedCount'] as num?)?.toInt() ?? 0;
  }

  // ── Patient Type Requests (Senior/PWD/Pregnant verification) ───────────────
  // Patients submit a photo of their ID/certificate from the mobile app;
  // staff review it here. Not clinic-scoped server-side (patient accounts
  // aren't tied to one clinic), matching PUT /api/patients/:id which
  // actually writes patientType.
  static Future<List<dynamic>> getPatientTypeRequests({String? status}) async {
    final res = await _client.get('/patient-type-requests', query: {
      if (status != null) 'status': status,
    });
    return (ApiClient.unwrap(res) as List<dynamic>?) ?? const [];
  }

  static Future<void> approvePatientTypeRequest(String id, {String note = ''}) =>
      _client.put('/patient-type-requests/$id/approve', body: {'note': note});

  static Future<void> rejectPatientTypeRequest(String id, {String note = ''}) =>
      _client.put('/patient-type-requests/$id/reject', body: {'note': note});

  // Builds the authenticated photo URL + header for Image.network — the
  // endpoint requires a valid staff/admin (or owning-patient) token, so
  // this can't just be a plain public URL.
  static Uri patientTypeRequestPhotoUri(String id) =>
      ApiConfig.buildUri('/patient-type-requests/$id/photo');

  static Future<Map<String, String>> photoAuthHeaders() async {
    final token = await ApiClient.instance.getToken();
    return {'Authorization': 'Bearer $token'};
  }
}
