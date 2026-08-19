import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';

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
  static Future<void> logout() => _client.deleteToken();

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

  static Future<void> callPatient(String queueId) => _client.put('/queues/$queueId/call');

  // NOTE: the server has a `startService` controller (sets status
  // 'serving') but as of this refactor it is NOT registered in
  // queueRoutes.js — only /call, /complete, /skip, /no-show, /cancel are
  // mounted. Calling this will 404 until that route is added server-side.
  // Included here so the app is ready to use it as soon as it exists.
  static Future<void> startService(String queueId) => _client.put('/queues/$queueId/start-service');

  static Future<void> completePatient(String queueId) => _client.put('/queues/$queueId/complete');
  static Future<void> skipPatient(String queueId) => _client.put('/queues/$queueId/skip');
  static Future<void> markNoShow(String queueId) => _client.put('/queues/$queueId/no-show');
  // Server route is PUT /queues/:id/cancel (controller fn is `cancelEntry`).
  static Future<void> cancelQueue(String queueId) => _client.put('/queues/$queueId/cancel');

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
  static Future<List<dynamic>> getChatLogs() async {
    final res = await _client.get('/chatbot-admin/logs');
    return (ApiClient.unwrap(res) as List<dynamic>?) ?? const [];
  }

  // resolveEscalation -> PUT /chatbot/resolve/:id (note: chatbot, not
  // chatbot-admin — that's where this route actually lives on the server).
  static Future<void> resolveEscalation(String id, {String note = ''}) =>
      _client.put('/chatbot/resolve/$id', body: {'note': note});
}
