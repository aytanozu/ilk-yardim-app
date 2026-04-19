/// TC Kimlik No (Turkish national ID) validator.
///
/// Specification:
/// - 11 digits
/// - Leading digit not zero
/// - d10 = ((d1+d3+d5+d7+d9) * 7 - (d2+d4+d6+d8)) mod 10
/// - d11 = (d1+d2+d3+d4+d5+d6+d7+d8+d9+d10) mod 10
///
/// Rejects typos with high probability; does NOT prove the ID belongs to
/// the submitter or exists in MERNİS. Source of truth stays with the
/// dispatcher reviewing the registration request.
bool isValidTcKimlik(String raw) {
  final input = raw.trim();
  if (input.length != 11) return false;
  if (!RegExp(r'^\d{11}$').hasMatch(input)) return false;
  if (input[0] == '0') return false;

  final d = input.split('').map(int.parse).toList();
  final sumOdd = d[0] + d[2] + d[4] + d[6] + d[8];
  final sumEven = d[1] + d[3] + d[5] + d[7];
  final d10 = ((sumOdd * 7) - sumEven) % 10;
  final d11 = (sumOdd + sumEven + d[9]) % 10;
  return d[9] == d10 && d[10] == d11;
}

/// Convenience: returns null if valid, otherwise a user-facing Turkish
/// validation message suitable for TextFormField.validator.
String? validateTcKimlik(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'TC Kimlik No gerekli';
  if (v.length != 11) return '11 haneli olmalı';
  if (!RegExp(r'^\d+$').hasMatch(v)) return 'Sadece rakam';
  if (!isValidTcKimlik(v)) return 'Geçersiz TC Kimlik No';
  return null;
}
