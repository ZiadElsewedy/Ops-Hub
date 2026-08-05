import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/features/sales/domain/entities/sales_month_snapshot.dart';
import 'package:drop/features/sales/domain/repositories/sales_repository.dart';
import 'package:drop/features/sales/domain/sales_business_time.dart';

sealed class SalesAdminOverviewState {
  const SalesAdminOverviewState();
}

class SalesAdminOverviewLoading extends SalesAdminOverviewState {
  const SalesAdminOverviewLoading();
}

class SalesAdminOverviewError extends SalesAdminOverviewState {
  const SalesAdminOverviewError(this.message);

  final String message;
}

class SalesAdminOverviewLoaded extends SalesAdminOverviewState {
  const SalesAdminOverviewLoaded(this.snapshotsByBranchId);

  final Map<String, SalesMonthSnapshot> snapshotsByBranchId;
}

class SalesAdminOverviewCubit extends Cubit<SalesAdminOverviewState> {
  SalesAdminOverviewCubit({
    required this._repository,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const SalesAdminOverviewLoading());

  final SalesRepository _repository;
  final DateTime Function() _now;
  StreamSubscription<List<SalesMonthSnapshot>>? _subscription;

  Future<void> load({String? monthKey, DateTime? now}) async {
    await _subscription?.cancel();
    emit(const SalesAdminOverviewLoading());
    final key = monthKey ?? businessMonthKey(now ?? _now());
    _subscription = _repository.watchBranchMonthSummaries(key).listen(
      (snapshots) => emit(
        SalesAdminOverviewLoaded({
          for (final snapshot in snapshots)
            if (snapshot.target != null) snapshot.target!.branchId: snapshot,
        }),
      ),
      onError: (Object error, StackTrace _) => emit(
        SalesAdminOverviewError(
          error is Failure ? error.message : 'Failed to load branch sales.',
        ),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
