import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/queue_provider.dart';
import '../../models/queue_model.dart';
import '../../services/api_service.dart';
import '../../widgets/sidebar/staff_sidebar.dart';

const _kStatuses = [
  'All',
  'waiting',
  'called',
  'serving',
  'done',
  'no_show',
  'skipped',
  'cancelled'
];
const _kPatientTypes = [
  'Regular',
  'Senior Citizen',
  'PWD',
  'Pregnant',
  'Priority'
];

class QueueManagementScreen extends StatefulWidget {
  const QueueManagementScreen({super.key});
  @override
  State<QueueManagementScreen> createState() => _QueueManagementScreenState();
}

class _QueueManagementScreenState extends State<QueueManagementScreen> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'All';

  // Toggles between the editable list view and the read-only Live Queue
  // view (migrated in from the old standalone Queue Monitoring screen).
  bool _liveView = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cid = context.read<AuthProvider>().staff?.clinicId;
      if (cid == null) return;
      final queueProvider = context.read<QueueProvider>();
      // setClinicId() only re-fetches the FIRST time it sees this clinic id
      // (it also opens the socket connection). Since QueueProvider lives for
      // the whole staff session, coming back to this screen after visiting
      // another one wouldn't otherwise re-fetch — force a fresh pull from
      // the backend every time this screen is entered so staff always see
      // the authoritative status, not a possibly-stale in-memory copy.
      queueProvider.setClinicId(cid);
      queueProvider.loadEntries();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Status helpers ─────────────────────────────────────────────────────────
  Color _sc(String s) {
    switch (s) {
      case 'waiting':
        return const Color(0xFFD97706);
      case 'called':
        return const Color(0xFF0891B2);
      case 'serving':
        return const Color(0xFF7C3AED);
      case 'done':
      case 'completed':
        return const Color(0xFF16A34A);
      case 'no_show':
        return const Color(0xFFEF4444);
      case 'skipped':
        return const Color(0xFF6B7280);
      case 'cancelled':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _sl(String s) {
    switch (s) {
      case 'waiting':
        return 'Waiting';
      case 'called':
        return 'Called';
      case 'serving':
        return 'Serving';
      case 'done':
      case 'completed':
        return 'Done';
      case 'no_show':
        return 'No Show';
      case 'skipped':
        return 'Skipped';
      case 'cancelled':
        return 'Cancelled';
      default:
        return s[0].toUpperCase() + s.substring(1);
    }
  }

  // ── Walk-in dialog ─────────────────────────────────────────────────────────
  void _addWalkIn() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String? selectedService;
    String patientType = 'Regular';

    // Service list is fetched once here (not inside the StatefulBuilder) so
    // it isn't re-requested on every setS() rebuild while the sheet is open.
    final clinicId = context.read<AuthProvider>().staff?.clinicId;
    final servicesFuture = clinicId == null
        ? Future.value(<dynamic>[])
        : StaffApiService.getClinicServices(clinicId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(9)),
                            child: const Icon(Icons.person_add_outlined,
                                color: Color(0xFF2563EB), size: 20)),
                        const SizedBox(width: 10),
                        const Text('Add Walk-in Patient',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827))),
                      ]),
                      const SizedBox(height: 20),
                      _lbl('Patient Name *'),
                      const SizedBox(height: 6),
                      TextField(
                          controller: nameCtrl,
                          decoration:
                              _ideco('Full name', Icons.person_outline)),
                      const SizedBox(height: 14),
                      _lbl('Service / Reason for Visit *'),
                      const SizedBox(height: 6),
                      // Pulled from the clinic's configured services (added
                      // by the Facility Admin) instead of free-text entry,
                      // so walk-in reasons always match a real service.
                      FutureBuilder<List<dynamic>>(
                        future: servicesFuture,
                        builder: (_, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return Container(
                              height: 46,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          }

                          final services = (snap.data ?? [])
                              .whereType<Map>()
                              .where((s) => s['isAvailable'] != false)
                              .map((s) => s['name']?.toString() ?? '')
                              .where((n) => n.isNotEmpty)
                              .toSet()
                              .toList();

                          if (services.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFED7AA)),
                              ),
                              child: const Text(
                                'No services configured for this clinic yet. '
                                'Ask your Facility Admin to add one under Service Schedule.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF9A3412)),
                              ),
                            );
                          }

                          selectedService ??= services.first;
                          return DropdownButtonFormField<String>(
                            initialValue: selectedService,
                            decoration: _ideco('Select a service',
                                Icons.medical_services_outlined),
                            items: services
                                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) => setS(() => selectedService = v),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _lbl('Contact Number *'),
                      const SizedBox(height: 6),
                      TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration:
                              _ideco('09XX XXX XXXX', Icons.phone_outlined)),
                      const SizedBox(height: 14),
                      _lbl('Patient Type'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: patientType,
                        decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13)),
                        items: _kPatientTypes
                            .map((t) =>
                                DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) =>
                            setS(() => patientType = v ?? 'Regular'),
                      ),
                      const SizedBox(height: 14),
                      _lbl('Notes (optional)'),
                      const SizedBox(height: 6),
                      TextField(
                          controller: notesCtrl,
                          maxLines: 2,
                          decoration: _ideco(
                              'Additional concerns', Icons.notes_outlined)),
                      const SizedBox(height: 22),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel')),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add to Queue'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10))),
                          onPressed: () {
                            if (nameCtrl.text.trim().isEmpty ||
                                selectedService == null ||
                                selectedService!.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                                  content: Text(
                                      'Patient name and service are required.'),
                                  backgroundColor: Colors.red));
                              return;
                            }
                            if (phoneCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                                  content: Text(
                                      'Contact number is required so the patient can be notified.'),
                                  backgroundColor: Colors.red));
                              return;
                            }
                            context.read<QueueProvider>().addPatient(
                                  patientName: nameCtrl.text.trim(),
                                  serviceName: selectedService!,
                                  patientPhone: phoneCtrl.text.trim(),
                                  patientType: patientType,
                                  notes: notesCtrl.text.trim(),
                                );
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Walk-in patient added to queue.'),
                                    backgroundColor: Color(0xFF16A34A)));
                          },
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<QueueProvider>();

    final search = _searchCtrl.text.toLowerCase();
    final shown = provider.entries.where((q) {
      final ms = search.isEmpty ||
          q.patientName.toLowerCase().contains(search) ||
          q.queueNumber.toLowerCase().contains(search) ||
          q.serviceName.toLowerCase().contains(search);
      final mf = _statusFilter == 'All' ||
          q.status == _statusFilter ||
          (_statusFilter == 'done' && q.status == 'completed');
      return ms && mf;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(children: [
        StaffSidebar(
            staffName: auth.staff?.fullName ?? 'Staff',
            staffRole: auth.staff?.role ?? 'STAFF'),
        Expanded(
            child: Column(children: [
          // ── Header row: title + Add Walk-in button ─────────────────────────
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
                            Color(0xFF2563EB),
                            Color(0xFF1D4ED8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.queue_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),

                    const SizedBox(width: 14),

                    // Title + subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Queue Management',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          Text(
                            'Today · ${provider.entries.length} total',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // List / Live Queue toggle
                    Container(
                      height: 36,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          _viewToggleBtn('List', !_liveView, () {
                            setState(() => _liveView = false);
                          }),
                          _viewToggleBtn('Live Queue', _liveView, () {
                            setState(() => _liveView = true);
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Refresh
                    IconButton(
                      onPressed: provider.loadEntries,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Color(0xFF6B7280),
                      ),
                      tooltip: 'Refresh',
                    ),

                    const SizedBox(width: 8),

                    // Add Walk-in
                    ElevatedButton.icon(
                      onPressed: _addWalkIn,
                      icon: const Icon(
                        Icons.add,
                        size: 16,
                      ),
                      label: const Text(
                        'Add Walk-in',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
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

                // Same small spacing used by Patient Inquiries
                const SizedBox(height: 10),
              ],
            ),
          ),

          // ── Filter + badges + search — all on ONE row ──────────────────────
          // Hidden in Live Queue mode, which shows its own summary row below.
          if (_liveView)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
              child: Row(
                children: [
                  _badge('Waiting', provider.waitingCount, const Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  _badge('Serving', provider.servingCount, const Color(0xFF7C3AED)),
                  const SizedBox(width: 6),
                  _badge('Done', provider.completedCount, const Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  _badge('Total', provider.entries.length, const Color(0xFF2563EB)),
                  const Spacer(),
                  const Text(
                    'Read-only live view · waiting & serving patients',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            )
          else
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
            child: Row(
              children: [
                // Status filter dropdown — colored to match the selected
                // category so it's visually clear at a glance. Previously a
                // separate row of tappable "pills" duplicated this same
                // dropdown's job (both set _statusFilter); the pills have
                // been removed and the dropdown itself now carries the
                // color cue they used to provide.
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _statusFilter == 'All'
                        ? const Color(0xFFF3F4F6)
                        : _sc(_statusFilter).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: _statusFilter == 'All'
                          ? const Color(0xFFE5E7EB)
                          : _sc(_statusFilter).withValues(alpha: 0.4),
                      width: _statusFilter == 'All' ? 1 : 1.3,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _statusFilter,
                      isDense: true,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusFilter == 'All'
                            ? const Color(0xFF374151)
                            : _sc(_statusFilter),
                      ),
                      icon: Icon(
                        Icons.expand_more,
                        size: 16,
                        color: _statusFilter == 'All'
                            ? const Color(0xFF6B7280)
                            : _sc(_statusFilter),
                      ),
                      items: _kStatuses.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(
                            s == 'All' ? 'All Status' : _sl(s),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setState(() {
                          _statusFilter = v ?? 'All';
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Search
                SizedBox(
                  width: 180,
                  height: 36,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search…',
                      hintStyle: const TextStyle(
                        fontSize: 12,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 15,
                        color: Color(0xFF9CA3AF),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── List / Live Queue ────────────────────────────────────────────
          Expanded(
            child: provider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : provider.error != null
                    ? _errView(provider)
                    : _liveView
                        ? _liveQueueList(provider)
                        : shown.isEmpty
                            ? _emptyView()
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(24, 16, 24, 24),
                                itemCount: shown.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, i) => _card(shown[i], provider),
                              ),
          ),
        ])),
      ]),
    );
  }

  Widget _card(QueueModel q, QueueProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: q.isPriority
            ? Border.all(color: const Color(0xFFF59E0B), width: 1.5)
            : Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 5)
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Queue number
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
              color: _sc(q.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: _sc(q.status).withValues(alpha: 0.2))),
          child: Center(
              child: Text(q.queueNumber,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: _sc(q.status)))),
        ),
        const SizedBox(width: 12),
        // Info
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(q.patientName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827)))),
            if (q.isPriority) ...[
              _tag('Priority', const Color(0xFFF59E0B)),
              const SizedBox(width: 8),
            ],
            if (provider.isOnTheWay(q.id)) ...[
              _tag('On the way', const Color(0xFF0891B2)),
              const SizedBox(width: 8),
            ],
            // Status pill + "⋮" menu beside the name — matches
            // Appointment Management's pattern exactly, no separate
            // quick-action button.
            _statusChooser(q, provider),
          ]),
          const SizedBox(height: 2),
          Text(q.serviceName,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 3),
          Row(children: [
            const Icon(Icons.access_time_outlined,
                size: 11, color: Color(0xFF9CA3AF)),
            const SizedBox(width: 3),
            Text(q.joinedAt,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            if (q.patientPhone.isNotEmpty) ...[
              const SizedBox(width: 8),
              const Icon(Icons.phone_outlined,
                  size: 11, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 3),
              Text(q.patientPhone,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            ],
            if (q.patientType != 'Regular') ...[
              const SizedBox(width: 8),
              _tag(q.patientType, const Color(0xFF2563EB)),
            ],
          ]),
          if (q.estimatedWaitMinutes > 0)
            Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('${q.estimatedWaitMinutes} min estimated',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF6B7280)))),
          if (q.notes.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('Note: ${q.notes}',
                    style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF9CA3AF),
                        fontStyle: FontStyle.italic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
        ])),
      ]),
    );
  }

  // Matches Appointment Management's status UI exactly: a plain colored
  // status pill next to a separate "⋮" menu button that lists every
  // selectable status as plain text (see appointment_management_screen.dart
  // _apptCard for the pattern this mirrors).
  // Only offer transitions the server will actually accept — see the
  // matching guards in queueController.js (callPatient/startService/
  // completePatient/markNoShow/requeueEntry). Previously this menu always
  // listed every status regardless of the entry's current one, relying
  // entirely on the server to silently reject invalid picks; the backend
  // guard is still the real enforcement (this list can't be trusted alone —
  // a direct API call bypasses it), but showing only valid next steps here
  // avoids staff hitting a rejection for an action that should never have
  // been offered in the first place.
  List<String> _validNextStatuses(String current) {
    switch (current) {
      case 'waiting':
        return ['called', 'cancelled'];
      case 'called':
        return ['serving', 'no_show', 'cancelled'];
      case 'serving':
        return ['done'];
      case 'skipped':
      case 'no_show':
        return ['waiting'];
      default:
        return const []; // done/completed/cancelled are terminal
    }
  }

  Widget _statusChooser(QueueModel q, QueueProvider provider) {
    final nextOptions = _validNextStatuses(q.status);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _statusPill(q.status),
      if (nextOptions.isNotEmpty) ...[
        const SizedBox(width: 6),
        PopupMenuButton<String>(
          tooltip: 'Change status',
          onSelected: (val) async {
            // updateStatus() reverts to the authoritative server state on
            // failure — surface that clearly instead of letting the pill
            // silently snap back with no explanation.
            final error = await provider.updateStatus(q.id, val);
            if (error != null && mounted) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  backgroundColor: const Color(0xFFDC2626),
                  duration: const Duration(seconds: 5),
                  content: Text(
                    _friendlyStatusError(val, error),
                    style: const TextStyle(color: Colors.white),
                  ),
                ));
            }
          },
          itemBuilder: (_) => nextOptions
              .map((s) => PopupMenuItem<String>(value: s, child: Text(_sl(s))))
              .toList(),
          child: const Icon(Icons.more_vert, color: Color(0xFF6B7280), size: 20),
        ),
      ],
    ]);
  }

  // Turns a raw server error into something a staff member (who has no
  // visibility into the backend) can actually act on. "Done" and
  // "Cancelled" currently ALWAYS fail on this server — a bug in
  // hq-server's QueueEntry status validation (not something the tablet
  // app can fix, since the value that fails validation is written
  // entirely server-side and never comes from the app's request).
  // Everything else (e.g. the requeue restriction) is a real business
  // rule, so that message is shown as-is.
  String _friendlyStatusError(String targetStatus, String serverMessage) {
    if (targetStatus == 'done' || targetStatus == 'completed') {
      return 'Could not mark as Done — the server is rejecting this change '
          '(known backend bug in status validation). This has NOT been '
          'saved. Please notify your system administrator.';
    }
    if (targetStatus == 'cancelled') {
      return 'Could not cancel this patient — the server is rejecting this '
          'change (known backend bug in status validation). This has NOT '
          'been saved. Please notify your system administrator.';
    }
    return serverMessage;
  }

  // Tappable status badge — used as a quick filter shortcut next to the
  // status dropdown. Shows the count beside the label, and highlights with
  // a colored border/background when it's the active filter.
  Widget _badge(String label, int count, Color c,
      {VoidCallback? onTap, bool active = false}) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: active ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(99),
        border: active ? Border.all(color: c, width: 1.3) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$count',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: c)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: c)),
      ]),
    );

    if (onTap == null) return child;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }

  // Matches the status pill styling in appointment_management_screen.dart
  // _apptCard exactly (padding/alpha/radius) for visual consistency.
  Widget _statusPill(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: _sc(s).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: _sc(s).withValues(alpha: 0.3))),
        child: Text(_sl(s),
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: _sc(s))),
      );

  Widget _tag(String t, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99)),
      child: Text(t,
          style:
              TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c)));

  // ── Live Queue view ─────────────────────────────────────────────────────
  // Read-only view of today's waiting + serving patients, migrated in from
  // the old standalone Queue Monitoring screen.
  Widget _liveQueueList(QueueProvider provider) {
    final active = provider.entries
        .where((q) => q.status == 'waiting' || q.status == 'serving')
        .toList();

    if (active.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_outline, size: 52, color: Color(0xFFD1D5DB)),
          SizedBox(height: 12),
          Text('No active patients in queue',
              style: TextStyle(fontSize: 15, color: Color(0xFF9CA3AF))),
        ]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      itemCount: active.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _liveCard(active[i]),
    );
  }

  Widget _liveCard(QueueModel q) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: q.status == 'serving'
            ? Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.4), width: 1.5)
            : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _sc(q.status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(q.queueNumber,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900, color: _sc(q.status))),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(q.patientName,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
            const SizedBox(height: 2),
            Text(q.serviceName, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.access_time_outlined, size: 11, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 3),
              Text('Joined ${q.joinedAt}', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              if (q.estimatedWaitMinutes > 0) ...[
                const SizedBox(width: 8),
                Text('${q.estimatedWaitMinutes} min wait',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              ],
            ]),
          ]),
        ),
        _statusPill(q.status),
      ]),
    );
  }

  Widget _viewToggleBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 3)]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? const Color(0xFF2563EB) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _emptyView() => const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.queue_outlined, size: 44, color: Color(0xFFD1D5DB)),
        SizedBox(height: 10),
        Text('No queue entries',
            style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
      ]));

  Widget _errView(QueueProvider p) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 36, color: Colors.red),
        const SizedBox(height: 8),
        Text(p.error!, style: const TextStyle(fontSize: 13, color: Colors.red)),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: p.loadEntries, child: const Text('Retry')),
      ]));

  Widget _lbl(String t) => Text(t,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151)));

  InputDecoration _ideco(String hint, IconData icon) => InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 17, color: const Color(0xFF9CA3AF)),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)));
}
