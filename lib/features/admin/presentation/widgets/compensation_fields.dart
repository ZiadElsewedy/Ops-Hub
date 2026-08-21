import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/utils/validators.dart';
import 'package:opshub/features/auth/presentation/widgets/app_dropdown_field.dart';
import 'package:opshub/features/auth/presentation/widgets/app_text_field.dart';

/// Canonical compensation option values (stored lowercase on `users/{uid}`)
/// and their display labels — the single source for the Create Account form,
/// the admin Edit Info sheet, and the read-only Details dialog.
const salaryTypeOptions = <String, String>{
  'monthly': 'Monthly',
  'weekly': 'Weekly',
  'daily': 'Daily',
};

const paymentMethodOptions = <String, String>{
  'cash': 'Cash',
  'bank': 'Bank transfer',
  'wallet': 'Mobile wallet',
  'instapay': 'InstaPay',
};

/// Human label for a stored salary-type / payment-method value; falls back to
/// the raw value so an unknown legacy string still renders.
String salaryTypeLabel(String value) => salaryTypeOptions[value] ?? value;
String paymentMethodLabel(String value) => paymentMethodOptions[value] ?? value;

/// One-line salary summary for the read-only Details dialog, e.g.
/// "4500 · Monthly". Returns null when no amount is recorded.
String? salarySummary(double? amount, String? type) {
  if (amount == null) return null;
  final amountText = amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toString();
  return type == null ? amountText : '$amountText · ${salaryTypeLabel(type)}';
}

/// Digits + a single decimal point — keeps the salary amount numeric at the
/// keystroke level (mirrors how phone fields use [Validators.phoneInput]).
final salaryAmountInput =
    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'));

/// Optional-field validator: empty is fine, otherwise must parse to a
/// non-negative number.
String? validateSalaryAmount(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return null;
  final parsed = double.tryParse(t);
  if (parsed == null || parsed < 0) return 'Enter a valid amount';
  return null;
}

/// The four compensation inputs, shared by the Create Account form and the
/// admin Edit Info sheet so the two surfaces can never drift. All fields are
/// optional — pay data can be recorded now or any time later.
class CompensationFields extends StatelessWidget {
  const CompensationFields({
    super.key,
    required this.amount,
    required this.paymentNumber,
    required this.salaryType,
    required this.paymentMethod,
    required this.onSalaryType,
    required this.onPaymentMethod,
  });

  final TextEditingController amount;
  final TextEditingController paymentNumber;
  final String? salaryType;
  final String? paymentMethod;
  final ValueChanged<String?> onSalaryType;
  final ValueChanged<String?> onPaymentMethod;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          controller: amount,
          label: 'Salary amount',
          hint: 'e.g. 4500',
          prefixIcon: Icons.payments_outlined,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [salaryAmountInput],
          validator: validateSalaryAmount,
        ),
        const SizedBox(height: AppSpacing.md),
        AppDropdownField<String?>(
          value: salaryType,
          hint: 'Salary type',
          prefixIcon: Icons.event_repeat_outlined,
          items: [
            const DropdownMenuItem<String?>(
                value: null, child: Text('Not set')),
            for (final e in salaryTypeOptions.entries)
              DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
          ],
          onChanged: onSalaryType,
        ),
        const SizedBox(height: AppSpacing.md),
        AppDropdownField<String?>(
          value: paymentMethod,
          hint: 'Payment method',
          prefixIcon: Icons.account_balance_wallet_outlined,
          items: [
            const DropdownMenuItem<String?>(
                value: null, child: Text('Not set')),
            for (final e in paymentMethodOptions.entries)
              DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
          ],
          onChanged: onPaymentMethod,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: paymentNumber,
          label: 'Payment number',
          hint: 'Wallet / account number salary is sent to',
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.tag_rounded,
          inputFormatters: [Validators.phoneInput],
          validator: (v) => Validators.phone(v, required: false),
        ),
      ],
    );
  }
}
