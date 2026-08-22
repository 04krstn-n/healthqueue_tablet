import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/assistance_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/sidebar/staff_sidebar.dart';

class PatientAssistanceScreen extends StatefulWidget {
  const PatientAssistanceScreen({super.key});
  @override
  State<PatientAssistanceScreen> createState() =>
      _PatientAssistanceScreenState();
}

class _PatientAssistanceScreenState extends State<PatientAssistanceScreen> {
  int _tabIndex = 0; // 0 = Queue, 1 = Assistance Requests

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final clinicId = context.read<AuthProvider>().staff?.clinicId;
      if (clinicId != null) {
        context.read<AssistanceProvider>().setClinicId(clinicId);
      }
    });
  }

  void _logRequest() {
    final nameCtrl = TextEditingController();
    final mrnCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    String? selectedQueueId;
    String? selectedServiceType;

    final clinicId = context.read<AuthProvider>().staff?.clinicId;
    // Service types come from the clinic's configured services (added by
    // the Facility Admin) instead of a generic hardcoded list — "Request
    // Type" is meant to be the service the patient needs help with.
    final servicesFuture = clinicId == null
        ? Future.value(<dynamic>[])
        : StaffApiService.getClinicServices(clinicId);
    // Live queue entries — picking one auto-fills name/MRN-lookup/contact so
    // the queue number is never hand-typed and always points at a real
    // patient already in today's queue.
    final queueEntries = context.read<AssistanceProvider>().queue;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: const Text('Log Assistance Request',
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(children: [
                _dialogField(nameCtrl, 'Patient Name'),
                const SizedBox(height: 10),
                _dialogField(mrnCtrl, 'MRN'),
                const SizedBox(height: 10),
                // Queue Number — selected from today's actual queue, not typed.
                DropdownButtonFormField<String>(
                  initialValue: selectedQueueId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Queue Number (optional)',
                      border: OutlineInputBorder()),
                  items: queueEntries
                      .map((q) => DropdownMenuItem(
                            value: q.id,
                            child: Text(
                              '${q.queueNumber} — ${q.patientName}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setDs(() {
                      selectedQueueId = v;
                      final match = queueEntries.where((q) => q.id == v);
                      if (match.isNotEmpty) {
                        final q = match.first;
                        if (nameCtrl.text.trim().isEmpty) nameCtrl.text = q.patientName;
                        if (contactCtrl.text.trim().isEmpty) contactCtrl.text = q.patientPhone;
                      }
                    });
                  },
                ),
                const SizedBox(height: 10),
                // Request Type — the clinic's actual services, not a fixed
                // generic list, so it reflects what was set up under
                // Service Schedule.
                FutureBuilder<List<dynamic>>(
                  future: servicesFuture,
                  builder: (_, snap) {
                    final services = (snap.data ?? [])
                        .whereType<Map>()
                        .map((s) => s['name']?.toString() ?? '')
                        .where((n) => n.isNotEmpty)
                        .toSet()
                        .toList();
                    if (snap.connectionState != ConnectionState.done) {
                      return const SizedBox(
                          height: 46,
                          child: Center(
                              child: SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2))));
                    }
                    if (services.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    selectedServiceType ??= services.first;
                    return DropdownButtonFormField<String>(
                      initialValue: selectedServiceType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Request Type (Service)',
                          border: OutlineInputBorder()),
                      items: services
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setDs(() => selectedServiceType = v),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _dialogField(msgCtrl, 'Message / Concern', maxLines: 3),
                const SizedBox(height: 10),
                _dialogField(contactCtrl, 'Contact Number *'),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty || msgCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Patient name and message are required.'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }
                if (contactCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Contact number is required so the patient can be notified.'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }
                context.read<AssistanceProvider>().addLocalRequest({
                  'name': nameCtrl.text.trim(),
                  'mrn': mrnCtrl.text.trim(),
                  'queueNumber': (() {
                    final match =
                        queueEntries.where((q) => q.id == selectedQueueId);
                    return match.isEmpty ? '' : match.first.queueNumber;
                  })(),
                  'type': selectedServiceType ?? 'General',
                  'message': msgCtrl.text.trim(),
                  'contact': contactCtrl.text.trim(),
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Assistance request logged.'),
                  backgroundColor: Color(0xFF16A34A),
                ));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String label,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'waiting':
        return const Color(0xFFD97706);
      case 'serving':
        return const Color(0xFF7C3AED);
      case 'done':
      case 'completed':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<AssistanceProvider>();

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
              child: Column(
                children: [
                  Row(
                    children: [
                      // Header icon
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF0891B2),
                              Color(0xFF0E7490),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.support_agent_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),

                      const SizedBox(width: 14),

                      // Title and subtitle
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Patient Assistance',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                            ),
                            Text(
                              'Queue overview & assistance requests',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Refresh
                      IconButton(
                        onPressed: provider.loadQueue,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Color(0xFF6B7280),
                        ),
                        tooltip: 'Refresh',
                      ),

                      const SizedBox(width: 8),

                      // Log Request
                      ElevatedButton.icon(
                        onPressed: _logRequest,
                        icon: const Icon(
                          Icons.add,
                          size: 16,
                        ),
                        label: const Text(
                          'Log Request',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0891B2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Same spacing style as Patient Inquiries
                  const SizedBox(height: 10),

                  // Tabs stay inside the header area
                  Row(
                    children: [
                      _tabBtn(
                        0,
                        'Live Queue',
                        Icons.people_outline,
                      ),
                      const SizedBox(width: 6),
                      _tabBtn(
                        1,
                        'Assistance Requests (${provider.localRequests.length})',
                        Icons.assignment_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content
            Expanded(
              child: provider.isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF0891B2)))
                  : _tabIndex == 0
                      ? _queueTab(provider)
                      : _requestsTab(provider),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _tabBtn(int idx, String label, IconData icon) {
    final active = _tabIndex == idx;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = idx),
      child: Container(
        margin: const EdgeInsets.only(bottom: 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  width: 2.5,
                  color:
                      active ? const Color(0xFF0891B2) : Colors.transparent)),
        ),
        child: Row(children: [
          Icon(icon,
              size: 15,
              color:
                  active ? const Color(0xFF0891B2) : const Color(0xFF6B7280)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? const Color(0xFF0891B2)
                      : const Color(0xFF6B7280))),
        ]),
      ),
    );
  }

  Widget _queueTab(AssistanceProvider provider) {
    if (provider.queue.isEmpty) {
      return const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.people_outline, size: 48, color: Color(0xFFD1D5DB)),
        SizedBox(height: 12),
        Text('No patients in queue',
            style: TextStyle(fontSize: 15, color: Color(0xFF9CA3AF))),
      ]));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      itemCount: provider.queue.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final q = provider.queue[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
            ],
          ),
          child: Row(children: [
            // Queue number
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _statusColor(q.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: _statusColor(q.status).withValues(alpha: 0.3)),
              ),
              child: Center(
                  child: Text(q.queueNumber,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _statusColor(q.status)))),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(q.patientName,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827))),
                  Text(q.serviceName,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                  if (q.patientPhone.isNotEmpty)
                    Text(q.patientPhone,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF9CA3AF))),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(q.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(q.status[0].toUpperCase() + q.status.substring(1),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _statusColor(q.status))),
              ),
              const SizedBox(height: 4),
              Text(q.joinedAt,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            ]),
          ]),
        );
      },
    );
  }

  Widget _requestsTab(AssistanceProvider provider) {
    if (provider.localRequests.isEmpty) {
      return const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.assignment_outlined, size: 48, color: Color(0xFFD1D5DB)),
        SizedBox(height: 12),
        Text('No assistance requests logged',
            style: TextStyle(fontSize: 15, color: Color(0xFF9CA3AF))),
        SizedBox(height: 4),
        Text('Tap "Log Request" to add one',
            style: TextStyle(fontSize: 13, color: Color(0xFFD1D5DB))),
      ]));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      itemCount: provider.localRequests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = provider.localRequests[i];
        final isPending = r['status'] == 'Pending';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
            ],
          ),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Text(r['name'] ?? '',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(99)),
                      child: Text(r['type'] ?? '',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  if ((r['mrn'] ?? '').toString().isNotEmpty ||
                      (r['queueNumber'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      [
                        if ((r['mrn'] ?? '').toString().isNotEmpty) 'MRN: ${r['mrn']}',
                        if ((r['queueNumber'] ?? '').toString().isNotEmpty)
                          'Queue #: ${r['queueNumber']}',
                      ].join('   ·   '),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(r['message'] ?? '',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF374151))),
                  const SizedBox(height: 4),
                  Text(r['time'] ?? '',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF))),
                ])),
            const SizedBox(width: 10),
            isPending
                ? ElevatedButton(
                    onPressed: () =>
                        context.read<AssistanceProvider>().resolveRequest(i),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child:
                        const Text('Resolve', style: TextStyle(fontSize: 12)),
                  )
                : const Text('✓ Resolved',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w700)),
          ]),
        );
      },
    );
  }
}
