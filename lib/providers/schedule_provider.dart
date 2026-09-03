import 'package:flutter/material.dart';
import '../models/schedule_model.dart';
import '../services/api_service.dart';

class ScheduleProvider extends ChangeNotifier {
  List<ScheduleModel> _schedule = [];
  // Separate from `_schedule` on purpose: the dashboard's "Today's
  // Appointments"/"Bookings Today" panels rely on `_schedule` staying
  // today-only, so the multi-day view used by Appointment Management lives
  // in its own list instead of repurposing `_schedule`.
  List<ScheduleModel> _upcoming = [];
  // Separate again from `_upcoming` — the List View's "today + next 3
  // days" window is intentionally tight for quick triage, but an actual
  // calendar grid needs a full month's worth of appointments to be useful
  // (otherwise most of the grid would just be empty days). Loaded lazily,
  // only when Calendar View is actually opened.
  List<ScheduleModel> _monthSchedule = [];
  bool    _monthLoading = false;
  bool    _loading  = false;
  bool    _upcomingLoading = false;
  String? _error;
  String? _clinicId;

  List<ScheduleModel> get schedule  => _schedule;
  List<ScheduleModel> get upcoming  => _upcoming;
  List<ScheduleModel> get monthSchedule => _monthSchedule;
  bool                get isLoading => _loading;
  bool                get isUpcomingLoading => _upcomingLoading;
  bool                get isMonthLoading => _monthLoading;
  String?             get error     => _error;

  void setClinicId(String id) {
    if (_clinicId != id) { _clinicId = id; loadSchedule(); }
  }

  Future<void> loadSchedule() async {
    if (_clinicId == null) return;
    _loading = true; _error = null; notifyListeners();
    try {
      // GET /api/appointments/today — scoped to clinic by auth role
      final data = await StaffApiService.getTodayAppointments(_clinicId!);
      _schedule = data
          .map((e) => ScheduleModel.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));
    } on StaffApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Failed to load schedule.';
    } finally {
      _loading = false; notifyListeners();
    }
  }

  // daysAhead=3 -> today plus the next 3 days, so staff can confirm/prep
  // upcoming appointments in advance (Appointment Management screen) instead
  // of only ever seeing the current day.
  Future<void> loadUpcomingSchedule({int daysAhead = 3}) async {
    if (_clinicId == null) return;
    _upcomingLoading = true; _error = null; notifyListeners();
    try {
      final now = DateTime.now();
      final data = await StaffApiService.getUpcomingAppointments(
        clinicId: _clinicId!,
        from: now,
        to: now.add(Duration(days: daysAhead)),
      );
      _upcoming = data
          .map((e) => ScheduleModel.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.timeRaw.compareTo(b.timeRaw));
    } on StaffApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Failed to load upcoming schedule.';
    } finally {
      _upcomingLoading = false; notifyListeners();
    }
  }

  // Loads every appointment in the given month (1st through last day) for
  // the actual calendar grid — see loadUpcomingSchedule above for why this
  // is a separate list/window rather than reusing `upcoming`.
  Future<void> loadMonthSchedule(DateTime month) async {
    if (_clinicId == null) return;
    _monthLoading = true; _error = null; notifyListeners();
    try {
      final from = DateTime(month.year, month.month, 1);
      final to = DateTime(month.year, month.month + 1, 0); // last day of month
      final data = await StaffApiService.getUpcomingAppointments(
        clinicId: _clinicId!,
        from: from,
        to: to,
      );
      _monthSchedule = data
          .map((e) => ScheduleModel.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.timeRaw.compareTo(b.timeRaw));
    } on StaffApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Failed to load calendar.';
    } finally {
      _monthLoading = false; notifyListeners();
    }
  }

  Future<void> updateAppointmentStatus(String id, String status) async {
    try {
      await StaffApiService.updateAppointmentStatus(id, status);
      ScheduleModel withStatus(ScheduleModel old) => ScheduleModel(
        id: old.id, time: old.time, timeRaw: old.timeRaw,
        service: old.service, patientName: old.patientName,
        patientPhone: old.patientPhone,
        status: status, type: old.type, clinicName: old.clinicName,
      );
      final idx = _schedule.indexWhere((s) => s.id == id);
      if (idx >= 0) _schedule[idx] = withStatus(_schedule[idx]);
      final uIdx = _upcoming.indexWhere((s) => s.id == id);
      if (uIdx >= 0) _upcoming[uIdx] = withStatus(_upcoming[uIdx]);
      final mIdx = _monthSchedule.indexWhere((s) => s.id == id);
      if (mIdx >= 0) _monthSchedule[mIdx] = withStatus(_monthSchedule[mIdx]);
      notifyListeners();
    } on StaffApiException catch (e) {
      _error = e.message; notifyListeners();
    }
  }
}
