import 'package:flutter/material.dart';
import 'package:opshub/core/widgets/role_scaffold.dart';
import 'admin_dashboard_screen.dart';

/// Role shell for the admin role. Hosts the [AdminDashboardScreen]; the admin
/// console is built out in Phase 5.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context) =>
      const RoleScaffold(title: 'Admin', child: AdminDashboardScreen());
}
