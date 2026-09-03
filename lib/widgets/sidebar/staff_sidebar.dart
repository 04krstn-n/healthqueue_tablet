import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inquiry_provider.dart';

class StaffSidebar extends StatelessWidget {
  final String staffName;
  final String staffRole;

  const StaffSidebar({
    super.key,
    required this.staffName,
    required this.staffRole,
  });

  static const double _expandedWidth = 220;
  static const double _collapsedWidth = 72;

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final collapsed = context.watch<AuthProvider>().sidebarCollapsed;
    final unresolvedEscalations =
        context.watch<InquiryProvider>().unresolvedEscalationCount;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: collapsed ? _collapsedWidth : _expandedWidth,

      // Prevents children from painting outside the sidebar
      // while the width is animating.
      clipBehavior: Clip.hardEdge,

      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF073B7A),
            Color(0xFF0E7F9E),
            Color(0xFF0B9B7A),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),

      child: Column(
        children: [
          // ============================================================
          // HEADER
          // ============================================================
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 26, 12, 18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Check ACTUAL width during animation.
                final narrow = constraints.maxWidth < 130;

                return narrow
                    ? Column(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(
                              Icons.monitor_heart_rounded,
                              color: Color(0xFF2563EB),
                              size: 25,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _CollapseToggle(
                            collapsed: collapsed,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(
                              Icons.monitor_heart_rounded,
                              color: Color(0xFF2563EB),
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'HealthQueue+',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Staff Portal',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          _CollapseToggle(
                            collapsed: collapsed,
                          ),
                        ],
                      );
              },
            ),
          ),

          Container(
            height: 1,
            color: Colors.white10,
          ),

          // ============================================================
          // SCROLLABLE SIDEBAR MENU
          // ============================================================
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(
                top: 6,
                bottom: 10,
              ),
              child: Column(
                children: [
                  _SidebarItem(
                    label: 'Dashboard',
                    icon: Icons.dashboard_outlined,
                    route: AppRoutes.dashboard,
                    isActive: currentRoute == AppRoutes.dashboard,
                    collapsed: collapsed,
                  ),
                  _SidebarItem(
                    label: 'Queue Management',
                    icon: Icons.groups_2_outlined,
                    route: AppRoutes.queueManagement,
                    isActive: currentRoute == AppRoutes.queueManagement,
                    collapsed: collapsed,
                  ),
                  _SidebarItem(
                    label: 'Service Schedule',
                    icon: Icons.schedule_rounded,
                    route: AppRoutes.serviceSchedule,
                    isActive: currentRoute == AppRoutes.serviceSchedule,
                    collapsed: collapsed,
                  ),
                  _SidebarItem(
                    label: 'Appointments',
                    icon: Icons.event_note_rounded,
                    route: AppRoutes.appointmentManagement,
                    isActive: currentRoute == AppRoutes.appointmentManagement,
                    collapsed: collapsed,
                  ),
                  _SidebarItem(
                    label: 'Patient Inquiries',
                    icon: Icons.chat_bubble_outline_rounded,
                    route: AppRoutes.patientInquiryManagement,
                    isActive:
                        currentRoute == AppRoutes.patientInquiryManagement,
                    collapsed: collapsed,
                    badgeCount: unresolvedEscalations,
                  ),
                  _SidebarItem(
                    label: 'Waiting Time Update',
                    icon: Icons.timer_outlined,
                    route: AppRoutes.waitingTimeUpdate,
                    isActive: currentRoute == AppRoutes.waitingTimeUpdate,
                    collapsed: collapsed,
                  ),
                ],
              ),
            ),
          ),

          // ============================================================
          // BOTTOM STAFF SECTION
          // ============================================================
          Container(
            height: 1,
            color: Colors.white12,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // IMPORTANT:
                // Use the actual width instead of the collapsed boolean.
                final narrow = constraints.maxWidth < 130;

                return Row(
                  mainAxisAlignment: narrow
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white,
                      child: Text(
                        _initials(staffName),
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (!narrow) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              staffName,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              staffRole,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),

          // ============================================================
          // LOGOUT
          // ============================================================
          Padding(
            padding: const EdgeInsets.fromLTRB(
              8,
              0,
              8,
              10,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Use actual available width during animation.
                final narrow = constraints.maxWidth < 130;

                return SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: narrow
                      ? OutlinedButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(
                              context,
                              AppRoutes.login,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: BorderSide.none,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                            overlayColor: Colors.transparent,
                          ),
                          child: const Icon(
                            Icons.logout_rounded,
                            size: 16,
                            color: Color(0xFFEF4444),
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pushReplacementNamed(
                              context,
                              AppRoutes.login,
                            );
                          },
                          icon: const Icon(
                            Icons.logout_rounded,
                            size: 16,
                            color: Color(0xFFEF4444),
                          ),
                          label: const Text(
                            'Logout',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                            overlayColor: Colors.transparent,
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();

    if (trimmed.isEmpty) {
      return 'NA';
    }

    final parts = trimmed.split(RegExp(r'\s+'));

    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }

    return parts[0][0].toUpperCase();
  }
}

// ============================================================
// COLLAPSE / EXPAND TOGGLE
// ============================================================

class _CollapseToggle extends StatelessWidget {
  final bool collapsed;

  const _CollapseToggle({
    required this.collapsed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          context.read<AuthProvider>().toggleSidebar();
        },
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            collapsed
                ? Icons.chevron_right_rounded
                : Icons.chevron_left_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SIDEBAR ITEM
// ============================================================

class _SidebarItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final String route;
  final bool isActive;
  final bool collapsed;
  final int badgeCount;

  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.route,
    required this.isActive,
    this.collapsed = false,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // IMPORTANT:
        // Check the real available width.
        // This prevents the Row from appearing too early
        // during the AnimatedContainer expansion.
        final narrow = constraints.maxWidth < 130;

        final iconWidget = badgeCount > 0
            ? Badge(
                backgroundColor: const Color(0xFFDC2626),
                label: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: Icon(
                  icon,
                  color: isActive ? Colors.white : Colors.white70,
                  size: 19,
                ),
              )
            : Icon(
                icon,
                color: isActive ? Colors.white : Colors.white70,
                size: 19,
              );

        final item = Container(
          height: 42,
          padding: EdgeInsets.symmetric(
            horizontal: narrow ? 0 : 13,
          ),
          alignment: narrow ? Alignment.center : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: narrow
              ? iconWidget
              : Row(
                  children: [
                    iconWidget,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : Colors.white.withValues(
                                  alpha: 0.82,
                                ),
                          fontSize: 12,
                          fontWeight:
                              isActive ? FontWeight.w900 : FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
        );

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: narrow ? 8 : 12,
            vertical: 3,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final currentRoute = ModalRoute.of(context)?.settings.name;

              if (currentRoute == route) {
                return;
              }

              Navigator.pushReplacementNamed(
                context,
                route,
              );
            },
            child: narrow
                ? Tooltip(
                    message: label,
                    child: item,
                  )
                : item,
          ),
        );
      },
    );
  }
}
