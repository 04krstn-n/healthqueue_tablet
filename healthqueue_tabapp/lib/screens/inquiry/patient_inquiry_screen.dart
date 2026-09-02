import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inquiry_provider.dart';
import '../../providers/patient_type_request_provider.dart';
import '../../models/inquiry_model.dart';
import '../../services/api_service.dart';
import '../../widgets/sidebar/staff_sidebar.dart';

class PatientInquiryScreen extends StatefulWidget {
  const PatientInquiryScreen({super.key});
  @override
  State<PatientInquiryScreen> createState() => _PatientInquiryScreenState();
}

class _PatientInquiryScreenState extends State<PatientInquiryScreen> {
  final _searchCtrl = TextEditingController();
  int _tabIndex = 0; // 0 = All Logs, 1 = Escalated (needs attention), 2 = Type Requests

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final clinicId = context.read<AuthProvider>().staff?.clinicId;
      context.read<InquiryProvider>().loadInquiries(clinicId: clinicId);
      // Loaded eagerly (not just when the tab is clicked) so the tab's
      // pending-count badge is accurate the moment this screen opens.
      context.read<PatientTypeRequestProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Color _sourceColor(String s) {
    switch (s) {
      case 'rasa':
        return const Color(0xFF16A34A);
      case 'openai':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFFD97706);
    }
  }

  String _sourceLabel(String s) {
    switch (s) {
      case 'rasa':
        return 'Rasa NLU';
      case 'openai':
        return 'OpenAI';
      default:
        return 'FAQ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<InquiryProvider>();

    final escalated = provider.escalatedInquiries;
    final unresolved = escalated.where((i) => !i.resolvedByStaff).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(children: [
        StaffSidebar(
            staffName: auth.staff?.fullName ?? 'Staff',
            staffRole: auth.staff?.role ?? 'STAFF'),
        Expanded(
            child: Column(children: [
          // ── Header ────────────────────────────────────────────────────────
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
                            Color(0xFF7C3AED),
                            Color(0xFF5B21B6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
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
                            'Patient Inquiries',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          Text(
                            'Chatbot logs & escalated concerns',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Search
                    SizedBox(
                      width: 200,
                      height: 36,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: context.read<InquiryProvider>().search,
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

                    const SizedBox(width: 8),

                    // Refresh
                    IconButton(
                      onPressed: () => provider.loadInquiries(
                        clinicId: auth.staff?.clinicId,
                      ),
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Color(0xFF6B7280),
                      ),
                      tooltip: 'Refresh',
                    ),

                    // Clear chat logs — restricted server-side to
                    // facility_admin/super_admin (this is a permanent bulk
                    // delete), so it's hidden for plain staff rather than
                    // shown and then rejected with a confusing error.
                    if (auth.staff?.role == 'facility_admin' ||
                        auth.staff?.role == 'super_admin')
                      IconButton(
                        onPressed: () => _confirmClearLogs(provider),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFDC2626),
                        ),
                        tooltip: 'Clear chat logs',
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                // Tabs
                Row(
                  children: [
                    _tabBtn(
                      0,
                      'All Logs (${provider.inquiries.length})',
                      Icons.history_rounded,
                    ),
                    const SizedBox(width: 6),
                    _tabBtn(
                      1,
                      'Needs Attention ($unresolved)',
                      Icons.priority_high_rounded,
                      urgent: unresolved > 0,
                    ),
                    const SizedBox(width: 6),
                    Consumer<PatientTypeRequestProvider>(
                      builder: (_, typeReqProvider, __) => _tabBtn(
                        2,
                        'Type Requests (${typeReqProvider.pendingCount})',
                        Icons.badge_outlined,
                        urgent: typeReqProvider.pendingCount > 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          Expanded(
            child: _tabIndex == 2
                ? _typeRequestsTab()
                : provider.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
                    : provider.error != null
                        ? _errorState(provider)
                        : _tabIndex == 0
                            ? _logsList(provider.inquiries)
                            : _escalatedList(escalated, provider),
          ),
        ])),
      ]),
    );
  }

  Widget _logsList(List<InquiryModel> logs) {
    if (logs.isEmpty) {
      return const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.chat_bubble_outline_rounded,
            size: 44, color: Color(0xFFD1D5DB)),
        SizedBox(height: 10),
        Text('No chatbot conversations yet',
            style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
      ]));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _logCard(logs[i]),
    );
  }

  Widget _logCard(InquiryModel inq) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: inq.isEscalated && !inq.resolvedByStaff
            ? Border.all(color: const Color(0xFFFB923C), width: 1.5)
            : Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 5)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(inq.patientName,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827)))),
          // Source badge
          _pill(_sourceLabel(inq.source), _sourceColor(inq.source)),
          if (inq.isEscalated) ...[
            const SizedBox(width: 6),
            _pill(
                inq.resolvedByStaff ? '✓ Resolved' : '⚠ Escalated',
                inq.resolvedByStaff
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFEF4444)),
          ],
          const SizedBox(width: 8),
          Text(inq.createdAt,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ]),
        const SizedBox(height: 8),
        // Patient message
        _bubble(inq.message, const Color(0xFFF3F4F6), Icons.person_outline,
            const Color(0xFF6B7280)),
        // Bot reply
        if (inq.reply.isNotEmpty) ...[
          const SizedBox(height: 6),
          _bubble(inq.reply, const Color(0xFFEFF6FF), Icons.smart_toy_outlined,
              const Color(0xFF2563EB)),
        ],
        // Escalation note
        if (inq.isEscalated && inq.escalationNote.isNotEmpty) ...[
          const SizedBox(height: 6),
          _bubble('Staff note: ${inq.escalationNote}', const Color(0xFFFFF7ED),
              Icons.warning_amber_outlined, const Color(0xFFF97316)),
        ],
      ]),
    );
  }

  Widget _escalatedList(
      List<InquiryModel> escalated, InquiryProvider provider) {
    final unresolved = escalated.where((i) => !i.resolvedByStaff).toList();
    final resolved = escalated.where((i) => i.resolvedByStaff).toList();
    final all = [...unresolved, ...resolved];

    if (all.isEmpty) {
      return const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_outline, size: 44, color: Color(0xFF16A34A)),
        SizedBox(height: 10),
        Text('No escalated inquiries',
            style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
        SizedBox(height: 4),
        Text('All patient concerns are resolved',
            style: TextStyle(fontSize: 12, color: Color(0xFFD1D5DB))),
      ]));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      itemCount: all.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final inq = all[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: inq.resolvedByStaff
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFFED7AA),
                  width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 5)
              ]),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(
                  inq.resolvedByStaff
                      ? Icons.check_circle_rounded
                      : Icons.priority_high_rounded,
                  size: 16,
                  color: inq.resolvedByStaff
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFF97316)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(inq.patientName,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827)))),
              Text(inq.createdAt,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            ]),
            const SizedBox(height: 8),
            _bubble(inq.message, const Color(0xFFF3F4F6), Icons.person_outline,
                const Color(0xFF6B7280)),
            if (inq.reply.isNotEmpty) ...[
              const SizedBox(height: 6),
              _bubble(inq.reply, const Color(0xFFEFF6FF),
                  Icons.smart_toy_outlined, const Color(0xFF2563EB)),
            ],
            if (inq.escalationNote.isNotEmpty) ...[
              const SizedBox(height: 6),
              _bubble('Concern: ${inq.escalationNote}', const Color(0xFFFFF7ED),
                  Icons.warning_amber_outlined, const Color(0xFFF97316)),
            ],
            if (inq.resolvedNote.isNotEmpty) ...[
              const SizedBox(height: 6),
              _bubble('Resolved: ${inq.resolvedNote}', const Color(0xFFF0FDF4),
                  Icons.check_circle_outline, const Color(0xFF16A34A)),
            ],
            if (!inq.resolvedByStaff) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                    onPressed: () => _replyDialog(inq, provider),
                    icon: const Icon(Icons.reply_rounded, size: 15),
                    label: const Text('Reply to Patient'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9)))),
              ),
            ],
          ]),
        );
      },
    );
  }

  // ── Type Requests tab ────────────────────────────────────────────────────
  // Staff review of patient-submitted Senior Citizen/PWD/Pregnant
  // verification requests (see PatientTypeRequestProvider). Separate
  // provider/data domain from chat inquiries — this screen just hosts both
  // as tabs per the agreed placement.
  Widget _typeRequestsTab() {
    return Consumer<PatientTypeRequestProvider>(
      builder: (_, provider, __) {
        if (provider.isLoading && provider.requests.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
        }
        if (provider.error != null && provider.requests.isEmpty) {
          return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 10),
            Text(provider.error!, style: const TextStyle(fontSize: 14, color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: () => provider.load(force: true), child: const Text('Retry')),
          ]));
        }

        final pending = provider.requests.where((r) => r['status'] == 'pending').toList();
        final resolved = provider.requests.where((r) => r['status'] != 'pending').toList();
        final all = [...pending, ...resolved];

        if (all.isEmpty) {
          return const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.badge_outlined, size: 44, color: Color(0xFFD1D5DB)),
            SizedBox(height: 10),
            Text('No account type requests',
                style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
          ]));
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          itemCount: all.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _typeRequestCard(all[i], provider),
        );
      },
    );
  }

  Widget _typeRequestCard(Map<String, dynamic> req, PatientTypeRequestProvider provider) {
    final id = req['_id']?.toString() ?? '';
    final status = req['status']?.toString() ?? 'pending';
    final requestedType = req['requestedType']?.toString() ?? '';
    final patient = req['patient'];
    final patientName = (patient is Map ? patient['fullName'] : null)?.toString() ?? 'Patient';
    final createdAt = req['createdAt']?.toString() ?? '';
    final reviewNote = req['reviewNote']?.toString() ?? '';
    final isPending = status == 'pending';

    final statusColor = status == 'approved'
        ? const Color(0xFF16A34A)
        : status == 'rejected'
            ? const Color(0xFFDC2626)
            : const Color(0xFFF97316);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 5)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
              status == 'approved'
                  ? Icons.check_circle_rounded
                  : status == 'rejected'
                      ? Icons.cancel_rounded
                      : Icons.hourglass_top_rounded,
              size: 16,
              color: statusColor),
          const SizedBox(width: 8),
          Expanded(
              child: Text(patientName,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827)))),
          Text(createdAt.isNotEmpty ? createdAt.split('T').first : '',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text('Requesting: $requestedType',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor)),
        ),
        if (reviewNote.isNotEmpty) ...[
          const SizedBox(height: 8),
          _bubble('Note: $reviewNote', const Color(0xFFF3F4F6), Icons.notes_rounded,
              const Color(0xFF6B7280)),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _viewIdPhoto(id),
              icon: const Icon(Icons.image_outlined, size: 15),
              label: const Text('View Photo'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
            ),
          ),
          if (isPending) ...[
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _reviewTypeRequest(id, provider, approve: true),
                icon: const Icon(Icons.check_rounded, size: 15),
                label: const Text('Approve'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _reviewTypeRequest(id, provider, approve: false),
                icon: const Icon(Icons.close_rounded, size: 15),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFDC2626)),
                    padding: const EdgeInsets.symmetric(vertical: 10)),
              ),
            ),
          ],
        ]),
      ]),
    );
  }

  void _viewIdPhoto(String requestId) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: FutureBuilder<Map<String, String>>(
          future: StaffApiService.photoAuthHeaders(),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              );
            }
            return Column(mainAxisSize: MainAxisSize.min, children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 500, maxWidth: 500),
                child: Image.network(
                  StaffApiService.patientTypeRequestPhotoUri(requestId).toString(),
                  headers: snap.data,
                  fit: BoxFit.contain,
                  loadingBuilder: (c, child, progress) => progress == null
                      ? child
                      : const Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                  errorBuilder: (c, e, s) => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('Could not load photo.'),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Future<void> _reviewTypeRequest(
      String id, PatientTypeRequestProvider provider,
      {required bool approve}) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(approve ? 'Approve Request?' : 'Reject Request?',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(approve
              ? 'This will update the patient\'s account type.'
              : 'The patient will see your note explaining why.'),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            decoration: InputDecoration(
              hintText: approve ? 'Note (optional)' : 'Reason for rejection',
              border: const OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: approve ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final error = approve
        ? await provider.approve(id, note: noteCtrl.text.trim())
        : await provider.reject(id, note: noteCtrl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: error == null ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
        content: Text(error ?? (approve ? 'Request approved.' : 'Request rejected.')),
      ));
  }

  // The only channel the backend exposes for staff to respond to an
  // escalated conversation is PUT /chatbot/resolve/:id, which saves a
  // "resolvedNote" and marks the inquiry resolved in the same call — there
  // is no separate "send a reply without closing" endpoint. So this dialog
  // shows the full thread like a real conversation and sends the staff's
  // reply through that note field, which is the actual channel that
  // reaches the patient's side; it's presented as "Reply" since that's
  // what it does, but note it always resolves the inquiry at the same time.
  // Clear chat logs — confirms before calling the permanent, irreversible
  // backend delete (see InquiryProvider.clearLogs / DELETE
  // /chatbot-admin/logs). The confirmation happens here in the UI; the
  // actual restriction (facility_admin/super_admin only) is enforced by
  // the server, not by this dialog or the button's visibility alone.
  Future<void> _confirmClearLogs(InquiryProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Chat Logs?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'This will permanently delete all chatbot conversation logs for '
          'this clinic, including escalated concerns. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear Logs'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await provider.clearLogs();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
        content: Text(ok
            ? 'Chat logs cleared.'
            : (provider.error ?? 'Failed to clear chat logs.')),
      ));
  }

  void _replyDialog(InquiryModel inq, InquiryProvider provider) {
    final replyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Reply to ${inq.patientName}',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        // The dialog's own vertical space shrinks once the on-screen
        // keyboard opens (autofocus below triggers it immediately), and a
        // fixed-size Column doesn't shrink with it — that's what caused
        // the earlier "bottom overflowed" error. Capping content height to
        // the available screen height and making it scrollable means it
        // resizes/scrolls instead of overflowing, on any screen size.
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: MediaQuery.of(dialogCtx).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Full conversation thread so staff have context before replying
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _bubble(inq.message, const Color(0xFFF3F4F6),
                      Icons.person_outline, const Color(0xFF6B7280)),
                  if (inq.reply.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _bubble(inq.reply, const Color(0xFFEFF6FF),
                        Icons.smart_toy_outlined, const Color(0xFF2563EB)),
                  ],
                  if (inq.escalationNote.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _bubble('Concern: ${inq.escalationNote}',
                        const Color(0xFFFFF7ED), Icons.warning_amber_outlined,
                        const Color(0xFFF97316)),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: replyCtrl,
              autofocus: true,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: 'Your reply to the patient',
                  hintText: 'Type your response…',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Sending this will also mark the conversation as resolved.',
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel')),
          ElevatedButton.icon(
              icon: const Icon(Icons.send_rounded, size: 15),
              onPressed: () {
                final text = replyCtrl.text.trim();
                if (text.isEmpty) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(const SnackBar(
                      content: Text('Please type a reply first.'),
                      backgroundColor: Colors.red));
                  return;
                }
                provider.resolveEscalation(inq.id, note: text);
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Reply sent to patient.'),
                    backgroundColor: Color(0xFF16A34A)));
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white),
              label: const Text('Send Reply')),
        ],
      ),
    );
  }

  Widget _tabBtn(int idx, String label, IconData icon, {bool urgent = false}) {
    final active = _tabIndex == idx;
    return GestureDetector(
      onTap: () {
        setState(() => _tabIndex = idx);
        if (idx == 2) context.read<PatientTypeRequestProvider>().load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    width: 2.5,
                    color: active
                        ? (urgent
                            ? const Color(0xFFF97316)
                            : const Color(0xFF7C3AED))
                        : Colors.transparent))),
        child: Row(children: [
          Icon(icon,
              size: 14,
              color: active
                  ? (urgent ? const Color(0xFFF97316) : const Color(0xFF7C3AED))
                  : const Color(0xFF6B7280)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active
                      ? (urgent
                          ? const Color(0xFFF97316)
                          : const Color(0xFF7C3AED))
                      : const Color(0xFF6B7280))),
        ]),
      ),
    );
  }

  Widget _pill(String t, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: c.withValues(alpha: 0.25))),
      child: Text(t,
          style:
              TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c)));

  Widget _bubble(String text, Color bg, IconData icon, Color iconColor) =>
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 7),
            Expanded(
                child: Text(text,
                    style: TextStyle(
                        fontSize: 12, color: iconColor.withValues(alpha: 0.9)),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis)),
          ]));

  Widget _errorState(InquiryProvider p) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 36, color: Colors.red),
        const SizedBox(height: 8),
        Text(p.error!, style: const TextStyle(fontSize: 13, color: Colors.red)),
        const SizedBox(height: 10),
        ElevatedButton(
            onPressed: () => p.loadInquiries(
                clinicId: context.read<AuthProvider>().staff?.clinicId),
            child: const Text('Retry')),
      ]));
}
