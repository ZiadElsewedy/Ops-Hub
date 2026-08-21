import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:opshub/core/di/injection.dart';
import 'package:opshub/core/extensions/context_extensions.dart';
import 'package:opshub/core/widgets/adaptive_scaffold.dart';
import 'package:opshub/features/cases/presentation/cubit/case_conversation_cubit.dart';
import 'package:opshub/features/cases/presentation/widgets/case_conversation_view.dart';

/// The mobile / deep-link case conversation screen — a single-column
/// conversation (the desktop uses the split-pane workspace in [CasesScreen]).
/// Provides a fresh [CaseConversationCubit] scoped to [caseId].
class CaseConversationScreen extends StatelessWidget {
  const CaseConversationScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context) {
    final user = context.currentUser;
    return BlocProvider<CaseConversationCubit>(
      create: (_) =>
          AppDependencies.createCaseConversationCubit(caseId, user),
      child: AdaptiveScaffold(
        title: 'Case',
        contentMaxWidth: 820,
        body: CaseConversationView(
          onClosedOrDeleted: () {
            if (context.canPop()) context.pop();
          },
        ),
      ),
    );
  }
}
