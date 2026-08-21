import 'package:opshub/features/schedule/domain/today_coverage.dart';

sealed class TodayCoverageState {
  const TodayCoverageState();
}

class TodayCoverageInitial extends TodayCoverageState {
  const TodayCoverageInitial();
}

class TodayCoverageLoading extends TodayCoverageState {
  const TodayCoverageLoading();
}

class TodayCoverageLoaded extends TodayCoverageState {
  const TodayCoverageLoaded(this.coverage);
  final List<TodayCoverage> coverage;
}

class TodayCoverageError extends TodayCoverageState {
  const TodayCoverageError(this.message);
  final String message;
}
