import 'package:flutter/material.dart';
import '../../core/routes/app_routes.dart';

class StaffSidebar extends StatelessWidget {
  final String staffName;
  final String staffRole;

  const StaffSidebar({
    super.key,
    required this.staffName,
    required this.staffRole,
  });

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;

    return Container(
      width: 220,
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
            padding: const EdgeInsets.fromLTRB(18, 30, 18, 18),
            child: Row(
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
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Staff Portal',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Container(
            height: 1,
            color: Colors.white10,
          ),

          // ============================================================
          // SCROLLABLE SIDEBAR CONTENT
          // ============================================================
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(
                top: 18,
                bottom: 10,
              ),
              child: Column(
                children: [
                  // DASHBOARD
                  _SidebarItem(
                    label: 'Dashboard',
                    icon: Icons.dashboard_outlined,
                    route: AppRoutes.dashboard,
                    isActive: currentRoute == AppRoutes.dashboard,
                  ),

                  // QUEUE MANAGEMENT
                  _SidebarItem(
                    label: 'Queue Management',
                    icon: Icons.groups_2_outlined,
                    route: AppRoutes.queueManagement,
                    isActive: currentRoute == AppRoutes.queueManagement,
                  ),

                  // SERVICE SCHEDULE
                  _SidebarItem(
                    label: 'Service Schedule',
                    icon: Icons.schedule_rounded,
                    route: AppRoutes.serviceSchedule,
                    isActive: currentRoute == AppRoutes.serviceSchedule,
                  ),

                  // APPOINTMENT MANAGEMENT
                  _SidebarItem(
                    label: 'Appointments',
                    icon: Icons.event_note_rounded,
                    route: AppRoutes.appointmentManagement,
                    isActive: currentRoute == AppRoutes.appointmentManagement,
                  ),

                  // PATIENT INQUIRIES
                  _SidebarItem(
                    label: 'Patient Inquiries',
                    icon: Icons.chat_bubble_outline_rounded,
                    route: AppRoutes.patientInquiryManagement,
                    isActive:
                        currentRoute == AppRoutes.patientInquiryManagement,
                  ),

                  // WAITING TIME UPDATE
                  _SidebarItem(
                    label: 'Waiting Time Update',
                    icon: Icons.timer_outlined,
                    route: AppRoutes.waitingTimeUpdate,
                    isActive: currentRoute == AppRoutes.waitingTimeUpdate,
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
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: Row(
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
            ),
          ),

          // ============================================================
          // LOGOUT
          // ============================================================
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton.icon(
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
// SIDEBAR ITEM
// ============================================================

class _SidebarItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final String route;
  final bool isActive;

  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.route,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
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
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
          ),
          decoration: BoxDecoration(
            color:
                isActive ? Colors.white.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? Colors.white : Colors.white70,
                size: 19,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.82),
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
