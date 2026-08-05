String formatEgp(int piastres, {bool withSuffix = false}) {
  final negative = piastres < 0;
  final value = piastres.abs();
  final whole = value ~/ 100;
  final fraction = value % 100;
  final grouped = whole.toString().replaceAllMapped(
    RegExp(r'(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final amount =
      '${negative ? '-' : ''}$grouped${fraction == 0 ? '' : '.${fraction.toString().padLeft(2, '0')}'}';
  return withSuffix ? '$amount EGP' : amount;
}

int? parseEgpToPiastres(String input) {
  final value = input.trim().replaceAll(',', '');
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(value);
  if (match == null) return null;
  final whole = int.tryParse(match.group(1)!);
  if (whole == null) return null;
  final decimals = (match.group(2) ?? '').padRight(2, '0');
  final fraction = decimals.isEmpty ? 0 : int.parse(decimals);
  return whole * 100 + fraction;
}
