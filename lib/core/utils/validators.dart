/// Валидация формы создания поста (задание F).
class PostValidators {
  PostValidators._();

  static const int titleMin = 5;
  static const int titleMax = 100;
  static const int bodyMin = 10;
  static const int bodyMax = 1000;

  static String? title(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Введите заголовок';
    if (v.length < titleMin) return 'Минимум $titleMin символов';
    if (v.length > titleMax) return 'Максимум $titleMax символов';
    return null;
  }

  static String? body(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Введите текст поста';
    if (v.length < bodyMin) return 'Минимум $bodyMin символов';
    if (v.length > bodyMax) return 'Максимум $bodyMax символов';
    return null;
  }

  static String? userId(int? value) =>
      value == null ? 'Выберите автора' : null;
}
