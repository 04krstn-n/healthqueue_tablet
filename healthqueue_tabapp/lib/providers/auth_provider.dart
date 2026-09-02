import 'package:flutter/material.dart';
import '../models/staff_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _service = AuthService();
  StaffModel? _staff;
  bool _isLoading = false;
  String? _error;

  // Sidebar collapse state — kept here (rather than local State on
  // StaffSidebar) because every screen navigates via
  // pushReplacementNamed, which rebuilds the sidebar fresh each time;
  // local widget state would reset to expanded on every screen switch.
  bool _sidebarCollapsed = false;

  StaffModel? get staff => _staff;
  bool get isAuthenticated => _staff != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get sidebarCollapsed => _sidebarCollapsed;

  void toggleSidebar() {
    _sidebarCollapsed = !_sidebarCollapsed;
    notifyListeners();
  }

  Future<void> login(
    String email,
    String password,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _staff = await _service.login(email, password);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _staff = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void logout() {
    _staff = null;
    notifyListeners();
  }
}
