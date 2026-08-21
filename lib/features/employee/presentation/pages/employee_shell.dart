import 'package:flutter/material.dart';
import 'package:opshub/core/widgets/role_scaffold.dart';
import 'employee_home_screen.dart';

/// Role shell for the employee role. Hosts the [EmployeeHomeScreen]; the
/// employee experience (shifts, tasks) is built out in Phase 3.
class EmployeeShell extends StatelessWidget {
  const EmployeeShell({super.key});

  @override
  Widget build(BuildContext context) =>
      const RoleScaffold(title: 'Home', child: EmployeeHomeScreen());
}
