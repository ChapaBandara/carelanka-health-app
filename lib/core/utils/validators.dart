class Validators {
  static String? requiredField(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  /// Accepts email or local phone (e.g. 77 123 4567) for login.
  static String? emailOrPhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email or phone is required';
    final v = value.trim();
    if (v.contains('@')) return email(v);
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9 || digits.length > 10) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value)) return 'Enter a valid email';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.isEmpty) return 'Phone is required';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return 'Enter 10-digit phone number';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Minimum 8 characters required';
    if (!RegExp(r'\d').hasMatch(value)) return 'Include at least one number';
    return null;
  }
}
