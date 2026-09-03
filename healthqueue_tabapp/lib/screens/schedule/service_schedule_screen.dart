import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/sidebar/staff_sidebar.dart';

/// Service Schedule (viewing) — shows the services configured for this
/// clinic by the Facility Admin (name, duration, availability). This is
/// distinct from Appointment Management (booked patient appointments),
/// which used to occupy this same route/sidebar entry and has now been
/// moved to its own module — see appointment_management_screen.dart.
class ServiceScheduleScreen extends StatefulWidget {
  const ServiceScheduleScreen({super.key});
  @override
  State<ServiceScheduleScreen> createState() => _ServiceScheduleScreenState();
}

class _ServiceScheduleScreenState extends State<ServiceScheduleScreen> {
  bool _loading = true;
  String? _error;
  String _clinicName = '';
  List<Map<String, dynamic>> _services = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final clinicId = context.read<AuthProvider>().staff?.clinicId;
    if (clinicId == null) {
      setState(() { _loading = false; _error = 'No clinic assigned to this account.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await StaffApiService.getClinicServices(clinicId);
      setState(() {
        _services = res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
      });
    } on StaffApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Failed to load service schedule.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

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
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF047857)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.schedule_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Service Schedule',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                        Text(
                          _clinicName.isNotEmpty ? _clinicName : 'Services offered by this clinic',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('${_services.length} services',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6B7280)),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF059669)))
                  : _error != null
                      ? _errorState(_error!)
                      : _services.isEmpty
                          ? _emptyState()
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                              itemCount: _services.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) => _serviceCard(_services[i]),
                            ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _serviceCard(Map<String, dynamic> s) {
    final name = s['name']?.toString() ?? 'Unnamed service';
    final desc = s['description']?.toString() ?? '';
    final duration = (s['durationMinutes'] ?? 30) as int;
    final available = s['isAvailable'] != false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.medical_services_outlined, color: Color(0xFF059669), size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ],
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.timer_outlined, size: 13, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 4),
              Text('$duration min per patient',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            ]),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: (available ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF)).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
                color: (available ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF)).withValues(alpha: 0.3)),
          ),
          child: Text(
            available ? 'Available' : 'Unavailable',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: available ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF)),
          ),
        ),
      ]),
    );
  }

  Widget _emptyState() => const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.schedule_outlined, size: 48, color: Color(0xFFD1D5DB)),
        SizedBox(height: 12),
        Text('No services configured yet',
            style: TextStyle(fontSize: 15, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
        SizedBox(height: 4),
        Text('Ask your Facility Admin to add services for this clinic.',
            style: TextStyle(fontSize: 12, color: Color(0xFFD1D5DB))),
      ]));

  Widget _errorState(String msg) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 40, color: Colors.red),
        const SizedBox(height: 10),
        Text(msg, style: const TextStyle(fontSize: 14, color: Colors.red)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _load, child: const Text('Retry')),
      ]));
}
