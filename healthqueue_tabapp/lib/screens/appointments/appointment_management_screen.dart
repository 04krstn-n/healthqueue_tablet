import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../models/schedule_model.dart';
import '../../widgets/sidebar/staff_sidebar.dart';

/// Appointment Management — booked appointments for the clinic, with status
/// actions (confirm, mark arrived, start serving, complete, cancel, no-show).
///
/// This used to live under the "Service Schedule" sidebar entry/route, which
/// was confusing since Service Schedule is meant to show the clinic's
/// configured services/hours, not booked appointments. It has been migrated
/// to its own module — see service_schedule_screen.dart for the real
/// service-schedule viewer.
class AppointmentManagementScreen extends StatefulWidget {
  const AppointmentManagementScreen({super.key});
  @override
  State<AppointmentManagementScreen> createState() => _AppointmentManagementScreenState();
}

class _AppointmentManagementScreenState extends State<AppointmentManagementScreen> {
  String _filter = 'All';
  // Detailed/List View (existing, unchanged) vs Calendar View (new) — see
  // _calendarBody. Both read from the same ScheduleProvider.upcoming data;
  // this only changes how it's presented.
  bool _calendarView = false;
  String? _selectedDayKey;
  final _statuses = [
    'All',
    'pending',
    'confirmed',
    'arrived',
    'serving',
    'completed',
    'cancelled',
    'no_show',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final clinicId = context.read<AuthProvider>().staff?.clinicId;
      if (clinicId != null) {
        context.read<ScheduleProvider>().setClinicId(clinicId);
        // Today + next 3 days, so staff can confirm/prep upcoming
        // appointments instead of only ever seeing the current day.
        context.read<ScheduleProvider>().loadUpcomingSchedule();
      }
    });
  }

  String _dayKey(String isoStr) {
    final dt = DateTime.tryParse(isoStr)?.toUtc().add(const Duration(hours: 8));
    if (dt == null) return '';
    return '${dt.year}-${dt.month}-${dt.day}';
  }

  String _dayLabel(String isoStr) {
    final dt = DateTime.tryParse(isoStr)?.toUtc().add(const Duration(hours: 8));
    if (dt == null) return 'Unknown date';
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(dt.year, dt.month, dt.day);
    final diff = that.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${wd[dt.weekday - 1]}, ${mo[dt.month - 1]} ${dt.day}';
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'confirmed':
        return const Color(0xFF16A34A);
      case 'pending':
        return const Color(0xFFD97706);
      case 'arrived':
        return const Color(0xFF2563EB);
      case 'serving':
        return const Color(0xFF7C3AED);
      case 'completed':
        return const Color(0xFF6B7280);
      case 'cancelled':
        return const Color(0xFFDC2626);
      case 'no_show':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  // Naive `s[0].toUpperCase() + s.substring(1)` capitalization (used at all
  // three display sites below) turned 'no_show' into the literal string
  // "No_show" instead of "No Show" — this replaces underscores with spaces
  // before capitalizing each word, so it works for every status without
  // needing a status-specific case.
  String _statusLabel(String s) {
    if (s.isEmpty) return s;
    if (s == 'All') return 'All';
    return s
        .split('_')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<ScheduleProvider>();
    final all = provider.upcoming;
    final shown = _filter == 'All'
        ? all
        : all.where((s) => s.status.toLowerCase() == _filter.toLowerCase()).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(children: [
        StaffSidebar(
            staffName: auth.staff?.fullName ?? 'Staff',
            staffRole: auth.staff?.role ?? 'STAFF'),
        Expanded(
          child: Column(children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.event_note_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Appointment Management',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827))),
                          Text('Booked appointments — today + next 3 days',
                              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text('${all.length} total',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2563EB))),
                    ),
                    const SizedBox(width: 10),
                    // Calendar / List view toggle — both render the same
                    // ScheduleProvider.upcoming data, just presented
                    // differently. Existing list functionality (status
                    // filter chips, per-card actions) is unchanged; this
                    // only adds an alternative way to browse the same data.
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        _viewToggleBtn(Icons.view_agenda_rounded, 'List', !_calendarView,
                            () => setState(() => _calendarView = false)),
                        _viewToggleBtn(Icons.calendar_month_rounded, 'Calendar', _calendarView,
                            () => setState(() => _calendarView = true)),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      onPressed: provider.loadUpcomingSchedule,
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6B7280)),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Status filter — this was declared `final` before and had
                // no control wired to it, so it silently never filtered.
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _statuses.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final s = _statuses[i];
                        final active = _filter == s;
                        return GestureDetector(
                          onTap: () => setState(() => _filter = s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: active ? const Color(0xFF2563EB) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              s == 'All' ? 'All' : _statusLabel(s),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: active ? Colors.white : const Color(0xFF374151),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ]),
            ),

            // Content
            Expanded(
              child: provider.isUpcomingLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                  : provider.error != null
                      ? _errorState(provider.error!)
                      : shown.isEmpty
                          ? _emptyState()
                          : (_calendarView
                              ? _calendarBody(shown)
                              : ListView(
                                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                                  children: _buildDayGroupedList(shown),
                                )),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _viewToggleBtn(IconData icon, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)]
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: active ? const Color(0xFF2563EB) : const Color(0xFF6B7280)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? const Color(0xFF2563EB) : const Color(0xFF6B7280))),
        ]),
      ),
    );
  }

  /// Calendar View — a day strip (each day in the loaded window, with its
  /// appointment count) that filters the same list below to just the
  /// selected day. Keeps the underlying data and per-appointment actions
  /// identical to List View; only the browsing structure differs.
  Widget _calendarBody(List<ScheduleModel> shown) {
    // Group by day key while preserving chronological order.
    final byDay = <String, List<ScheduleModel>>{};
    for (final s in shown) {
      byDay.putIfAbsent(_dayKey(s.timeRaw), () => []).add(s);
    }
    final dayKeys = byDay.keys.toList();
    final activeKey = (_selectedDayKey != null && byDay.containsKey(_selectedDayKey))
        ? _selectedDayKey!
        : dayKeys.first;
    final dayItems = byDay[activeKey] ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 76,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            scrollDirection: Axis.horizontal,
            itemCount: dayKeys.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final key = dayKeys[i];
              final dayList = byDay[key]!;
              final active = key == activeKey;
              return GestureDetector(
                onTap: () => setState(() => _selectedDayKey = key),
                child: Container(
                  width: 88,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF2563EB) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(_dayLabel(dayList.first.timeRaw),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: active ? Colors.white : const Color(0xFF111827))),
                    const SizedBox(height: 6),
                    Text('${dayList.length} appt${dayList.length == 1 ? '' : 's'}',
                        style: TextStyle(
                            fontSize: 11,
                            color: active ? Colors.white70 : const Color(0xFF9CA3AF))),
                  ]),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            itemCount: dayItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _apptCard(dayItems[i]),
          ),
        ),
      ],
    );
  }

  /// Inserts a "Today" / "Tomorrow" / "Wed, Aug 28" header wherever the day
  /// changes in the (already chronologically-sorted) list, so staff can see
  /// which day each appointment belongs to instead of a flat undated list.
  List<Widget> _buildDayGroupedList(List<ScheduleModel> shown) {
    final items = <Widget>[];
    String? lastKey;
    for (final s in shown) {
      final key = _dayKey(s.timeRaw);
      if (key != lastKey) {
        if (lastKey != null) items.add(const SizedBox(height: 12));
        items.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            _dayLabel(s.timeRaw),
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF374151)),
          ),
        ));
        lastKey = key;
      }
      items.add(_apptCard(s));
      items.add(const SizedBox(height: 8));
    }
    return items;
  }

  Widget _apptCard(ScheduleModel s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Row(children: [
        Container(
          width: 70,
          height: 56,
          decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(s.time,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.patientName,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
            const SizedBox(height: 3),
            Text(s.service, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            if (s.patientPhone.isNotEmpty)
              Text(s.patientPhone, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _statusColor(s.status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: _statusColor(s.status).withValues(alpha: 0.3)),
          ),
          child: Text(
            _statusLabel(s.status),
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor(s.status)),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          onSelected: (val) =>
              context.read<ScheduleProvider>().updateAppointmentStatus(s.id, val),
          itemBuilder: (_) => [
            'confirmed',
            'arrived',
            'serving',
            'completed',
            'cancelled',
            'no_show',
          ]
              .map((st) => PopupMenuItem(value: st, child: Text(_statusLabel(st))))
              .toList(),
          child: const Icon(Icons.more_vert, color: Color(0xFF6B7280)),
        ),
      ]),
    );
  }

  Widget _emptyState() => const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.event_busy_rounded, size: 48, color: Color(0xFFD1D5DB)),
        SizedBox(height: 12),
        Text('No appointments in the next few days',
            style: TextStyle(fontSize: 15, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
      ]));

  Widget _errorState(String msg) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 40, color: Colors.red),
        const SizedBox(height: 10),
        Text(msg, style: const TextStyle(fontSize: 14, color: Colors.red)),
        const SizedBox(height: 12),
        ElevatedButton(
            onPressed: context.read<ScheduleProvider>().loadUpcomingSchedule,
            child: const Text('Retry')),
      ]));
}
