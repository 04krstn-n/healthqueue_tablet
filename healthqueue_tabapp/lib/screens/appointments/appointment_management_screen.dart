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
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<ScheduleProvider>();
    final all = provider.schedule;
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
                          Text('Booked appointments for today',
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
                    IconButton(
                      onPressed: provider.loadSchedule,
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
                              s == 'All' ? 'All' : s[0].toUpperCase() + s.substring(1),
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
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                  : provider.error != null
                      ? _errorState(provider.error!)
                      : shown.isEmpty
                          ? _emptyState()
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                              itemCount: shown.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (ctx, i) => _apptCard(shown[i]),
                            ),
            ),
          ]),
        ),
      ]),
    );
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
            s.status[0].toUpperCase() + s.status.substring(1),
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
              .map((st) => PopupMenuItem(value: st, child: Text(st[0].toUpperCase() + st.substring(1))))
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
        Text('No appointments today',
            style: TextStyle(fontSize: 15, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
      ]));

  Widget _errorState(String msg) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 40, color: Colors.red),
        const SizedBox(height: 10),
        Text(msg, style: const TextStyle(fontSize: 14, color: Colors.red)),
        const SizedBox(height: 12),
        ElevatedButton(
            onPressed: context.read<ScheduleProvider>().loadSchedule,
            child: const Text('Retry')),
      ]));
}
