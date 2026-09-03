import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/queue_provider.dart';
import 'providers/inquiry_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/patient_type_request_provider.dart';
import 'models/inquiry_model.dart';
import 'models/queue_model.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    debugPrint('.env not found — using fallback IP');
  }

  // Lock to landscape for tablet use
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => DashboardProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => QueueProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => InquiryProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ScheduleProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => PatientTypeRequestProvider(),
        ),
      ],
      child: const HealthQueueStaffApp(),
    ),
  );
}

class HealthQueueStaffApp extends StatelessWidget {
  const HealthQueueStaffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealthQueue+ Staff',

      debugShowCheckedModeBanner: false,

      navigatorKey: _navigatorKey,

      // Theme
      theme: AppTheme.light(),

      // Starting page
      initialRoute: AppRoutes.login,

      // App-wide floating alert for newly-escalated concerns (feature: see
      // _EscalationAlertOverlay) — wrapping here via `builder` rather than
      // inside a per-screen widget means it stays live across every screen
      // regardless of navigation, since this app has no persistent shell
      // (each screen is its own full route via pushReplacementNamed).
      builder: (context, child) =>
          _EscalationAlertOverlay(child: child ?? const SizedBox.shrink()),

      // ==========================================================
      // CUSTOM ROUTING
      // Removes the default page transition animation.
      // ==========================================================
      onGenerateRoute: (settings) {
        final builder = AppRoutes.routes[settings.name];

        // Unknown route
        if (builder == null) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) {
              return const Scaffold(
                body: Center(
                  child: Text('Page not found'),
                ),
              );
            },
          );
        }

        // Instant page transition
        return PageRouteBuilder(
          settings: settings,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (
            context,
            animation,
            secondaryAnimation,
          ) {
            return builder(context);
          },
          transitionsBuilder: (
            context,
            animation,
            secondaryAnimation,
            child,
          ) {
            return child;
          },
        );
      },
    );
  }
}

// ============================================================
// ESCALATION ALERT OVERLAY
// ============================================================
// Floating, non-blocking banner shown the instant a new unresolved
// escalation arrives — staff don't have to stop what they're doing or be
// on the Patient Inquiries screen to find out. Driven by InquiryProvider's
// one-shot pendingAlert (see loadInquiries' dedup logic there), which is
// only ever set for a GENUINELY new escalation, never a repeat.
class _EscalationAlertOverlay extends StatefulWidget {
  final Widget child;
  const _EscalationAlertOverlay({required this.child});

  @override
  State<_EscalationAlertOverlay> createState() => _EscalationAlertOverlayState();
}

class _EscalationAlertOverlayState extends State<_EscalationAlertOverlay> {
  InquiryProvider? _inquiryProvider;
  QueueProvider? _queueProvider;
  InquiryModel? _visibleEscalation;
  QueueModel? _visibleOnTheWay;
  Timer? _autoDismissTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final inquiryProvider = context.read<InquiryProvider>();
    if (_inquiryProvider != inquiryProvider) {
      _inquiryProvider?.removeListener(_onInquiryChanged);
      _inquiryProvider = inquiryProvider;
      _inquiryProvider!.addListener(_onInquiryChanged);
    }
    final queueProvider = context.read<QueueProvider>();
    if (_queueProvider != queueProvider) {
      _queueProvider?.removeListener(_onQueueChanged);
      _queueProvider = queueProvider;
      _queueProvider!.addListener(_onQueueChanged);
    }
  }

  @override
  void dispose() {
    _inquiryProvider?.removeListener(_onInquiryChanged);
    _queueProvider?.removeListener(_onQueueChanged);
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  void _onInquiryChanged() {
    final pending = _inquiryProvider?.pendingAlert;
    if (pending == null) return;
    // Consume immediately — dedup is handled entirely in the provider
    // (edge-detection against _knownUnresolvedIds), so once read here this
    // can never re-fire for the same escalation.
    _inquiryProvider!.dismissEscalationAlert();
    if (!mounted) return;
    setState(() {
      _visibleEscalation = pending;
      _visibleOnTheWay = null; // escalation takes priority if both fire
    });
    _restartAutoDismiss();
  }

  void _onQueueChanged() {
    final pending = _queueProvider?.pendingOnTheWayAlert;
    if (pending == null) return;
    _queueProvider!.dismissOnTheWayAlert();
    if (!mounted || _visibleEscalation != null) return;
    setState(() => _visibleOnTheWay = pending);
    _restartAutoDismiss();
  }

  void _restartAutoDismiss() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() {
        _visibleEscalation = null;
        _visibleOnTheWay = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final escalation = _visibleEscalation;
    final onTheWay = _visibleOnTheWay;
    return Stack(
      children: [
        widget.child,
        if (escalation != null)
          _banner(
            color: const Color(0xFFDC2626),
            icon: Icons.priority_high_rounded,
            title: 'Escalated concern needs attention',
            subtitle: escalation.patientName.isNotEmpty ? escalation.patientName : 'A patient',
            onView: () {
              setState(() => _visibleEscalation = null);
              _navigatorKey.currentState
                  ?.pushReplacementNamed(AppRoutes.patientInquiryManagement);
            },
            onDismiss: () => setState(() => _visibleEscalation = null),
          )
        else if (onTheWay != null)
          _banner(
            color: const Color(0xFF0891B2),
            icon: Icons.directions_walk_rounded,
            title: 'Patient is on the way',
            subtitle: 'Queue #${onTheWay.queueNumber} — ${onTheWay.patientName}',
            onView: () {
              setState(() => _visibleOnTheWay = null);
              _navigatorKey.currentState
                  ?.pushReplacementNamed(AppRoutes.queueManagement);
            },
            onDismiss: () => setState(() => _visibleOnTheWay = null),
          ),
      ],
    );
  }

  Widget _banner({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onView,
    required VoidCallback onDismiss,
  }) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              child: Row(children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: onView,
                  child: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
