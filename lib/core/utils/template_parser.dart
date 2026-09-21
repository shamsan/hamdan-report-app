class TemplateParser {
  /// Replaces placeholders like {{اسم_المشروع}} with actual values from a dictionary
  static String interpolate(String template, Map<String, String> values) {
    String result = template;
    values.forEach((key, val) {
      result = result.replaceAll(key, val);
      // Also match without curly braces if formatted as key
      result = result.replaceAll('{{$key}}', val);
    });
    return result;
  }
}
