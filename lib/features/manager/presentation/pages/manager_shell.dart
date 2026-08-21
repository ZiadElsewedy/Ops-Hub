import 'package:flutter/material.dart';
import 'package:opshub/core/widgets/role_scaffold.dart';
import 'manager_home_screen.dart';

/// Role shell for the manager role. Hosts the [ManagerHomeScreen]; the manager
/// experience is built out in Phase 3.
class ManagerShell extends StatelessWidget {
  const ManagerShell({super.key});

  @override
  Widget build(BuildContext context) =>
      const RoleScaffold(title: 'Manager', child: ManagerHomeScreen());
}
