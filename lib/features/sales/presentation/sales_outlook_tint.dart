import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/features/sales/domain/sales_calculator.dart';

/// The **status** tint for the achievement figures — the ACHIEVED amount, the
/// progress ring and the chart's "today" bar.
///
/// Green when the month is projected **ahead** of target, amber when **behind**,
/// and neutral white before there is anything to project from. This is colour
/// as *status* (ADR-004), the same rule `salesDayPace` follows for Needed per
/// day — it ties the hero numbers to the Pace verdict, and is never brand
/// decoration. `tooEarly` resolves to white, which is both `primary` and
/// `textPrimary`, so it reads as an ordinary neutral figure.
Color salesOutlookTint(SalesTargetOutlook outlook) => switch (outlook) {
  SalesTargetOutlook.ahead => AppColors.success,
  SalesTargetOutlook.behind => AppColors.warning,
  SalesTargetOutlook.tooEarly => AppColors.primary,
};
