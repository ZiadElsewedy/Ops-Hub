import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/widgets/adaptive_scaffold.dart';
import 'package:opshub/core/widgets/app_snackbar.dart';
import 'package:opshub/core/widgets/glass_container.dart';
import 'package:opshub/core/widgets/premium_button.dart';
import 'package:opshub/features/auth/presentation/widgets/app_text_field.dart';
import 'package:opshub/features/branch/domain/branch_geofence.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/branch/presentation/cubit/branch_cubit.dart';

/// The admin **attendance-area editor** — sets a branch's GPS geofence (location ·
/// allowed radius · minimum GPS accuracy) that the employee clock-in is verified
/// against. Until an admin saves this, GPS clock-in is inert on the branch (the
/// employee screen shows "GPS not set up here").
///
/// Coordinates are captured with **Use current location** (the admin stands at the
/// branch — reuses the `geolocator` dependency, no maps SDK), with editable fields
/// as a fallback. Saved through the dedicated `BranchCubit.setGeofence` path.
class BranchGeofenceEditorScreen extends StatefulWidget {
  const BranchGeofenceEditorScreen({super.key, required this.branch});

  final BranchEntity branch;

  @override
  State<BranchGeofenceEditorScreen> createState() =>
      _BranchGeofenceEditorScreenState();
}

class _BranchGeofenceEditorScreenState
    extends State<BranchGeofenceEditorScreen> {
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late final TextEditingController _radius;
  late final TextEditingController _minAcc;

  double? _capturedAccuracy;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    final g = widget.branch.geofence;
    _lat = TextEditingController(
        text: g == null ? '' : g.latitude.toStringAsFixed(6));
    _lng = TextEditingController(
        text: g == null ? '' : g.longitude.toStringAsFixed(6));
    _radius =
        TextEditingController(text: (g?.radiusMeters ?? 150).round().toString());
    _minAcc = TextEditingController(
        text: (g?.minAccuracyMeters ?? 50).round().toString());
  }

  @override
  void dispose() {
    _lat.dispose();
    _lng.dispose();
    _radius.dispose();
    _minAcc.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _capturing = true);
    String? error;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        error = 'Turn on location services to capture the branch location.';
      } else {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          error = 'Allow location access to capture the branch location.';
        } else {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              timeLimit: Duration(seconds: 15),
            ),
          );
          if (!mounted) return;
          _lat.text = pos.latitude.toStringAsFixed(6);
          _lng.text = pos.longitude.toStringAsFixed(6);
          _capturedAccuracy = pos.accuracy;
        }
      }
    } catch (_) {
      error = 'Couldn\'t get your location. Try again in the open.';
    }
    if (!mounted) return;
    setState(() => _capturing = false);
    if (error != null) AppSnackbar.error(context, error);
  }

  void _save() {
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    final radius = double.tryParse(_radius.text.trim());
    final minAcc = double.tryParse(_minAcc.text.trim());
    final error = BranchGeofence.validateInput(
      latitude: lat,
      longitude: lng,
      radiusMeters: radius,
      minAccuracyMeters: minAcc,
    );
    if (error != null) {
      AppSnackbar.error(context, error);
      return;
    }
    context.read<BranchCubit>().setGeofence(
          widget.branch.id,
          BranchGeofence(
            latitude: lat!,
            longitude: lng!,
            radiusMeters: radius!,
            minAccuracyMeters: minAcc!,
          ),
        );
    AppSnackbar.success(
        context, 'Attendance area saved for ${widget.branch.name}.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.branch.geofence;
    return AdaptiveScaffold(
      title: 'Attendance area',
      subtitle: widget.branch.name,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          _IntroCard(configured: g != null),
          const SizedBox(height: AppSpacing.lg),
          // ── Capture ──
          PremiumButton(
            label: _capturing ? 'Getting location…' : 'Use current location',
            icon: Icons.my_location_rounded,
            onPressed: _capturing ? null : _useCurrentLocation,
            style: PremiumButtonStyle.filled,
          ),
          if (_capturedAccuracy != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _CaptureReadout(accuracy: _capturedAccuracy!),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _lat,
                  label: 'Latitude',
                  hint: '30.0444',
                  prefixIcon: Icons.place_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                      signed: true, decimal: true),
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppTextField(
                  controller: _lng,
                  label: 'Longitude',
                  hint: '31.2357',
                  keyboardType: const TextInputType.numberWithOptions(
                      signed: true, decimal: true),
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _radius,
            label: 'Allowed radius (metres)',
            hint: '150',
            prefixIcon: Icons.adjust_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.xs),
          const _FieldHint(
              'How close to the branch a clock-in counts as "at work".'),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _minAcc,
            label: 'Minimum GPS accuracy (metres)',
            hint: '50',
            prefixIcon: Icons.gps_fixed_rounded,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpacing.xs),
          const _FieldHint(
              'A clock-in is rejected if the phone\'s GPS fix is less precise '
              'than this (a weak signal can\'t be trusted).'),
          const SizedBox(height: AppSpacing.xl),
          PremiumButton(
            label: 'Save attendance area',
            icon: Icons.check_rounded,
            onPressed: _save,
            style: PremiumButtonStyle.filled,
          ),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.configured});
  final bool configured;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            configured ? Icons.where_to_vote_rounded : Icons.wrong_location_outlined,
            color: configured ? AppColors.success : AppColors.warning,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              configured
                  ? 'This branch has an attendance area. Employees can clock in '
                      'within the radius below.'
                  : 'No attendance area yet — employees can\'t GPS clock in here '
                      'until you set one. Stand at the branch and tap "Use '
                      'current location".',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureReadout extends StatelessWidget {
  const _CaptureReadout({required this.accuracy});
  final double accuracy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          const Icon(Icons.my_location_rounded,
              size: 18, color: AppColors.success),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Captured this spot · ±${accuracy.round()} m accuracy',
              style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldHint extends StatelessWidget {
  const _FieldHint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
      ),
    );
  }
}
