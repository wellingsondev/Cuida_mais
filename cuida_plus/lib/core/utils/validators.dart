class Validators {
  static String? required(String? v, [String field = 'Campo']) =>
      (v == null || v.trim().isEmpty) ? '$field é obrigatório' : null;

  static String? maxLen(String? v, int max) => (v != null && v.length > max) ? 'Máximo de $max caracteres' : null;

  static String? name(String? v) =>
      required(v, 'Nome') ?? ((v!.trim().length < 2) ? 'Informe o nome completo' : maxLen(v, 100));

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'E-mail é obrigatório';
    return _email.hasMatch(v.trim()) ? null : 'E-mail inválido';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Senha é obrigatória';
    if (v.length < 8) return 'Use ao menos 8 caracteres';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) return 'Use letras e números';
    return null;
  }

  static bool isValidTime(int hour, int minute) => hour >= 0 && hour < 24 && minute >= 0 && minute < 60;
}
