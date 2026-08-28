Map<String, String> parseCliOptions(List<String> arguments) {
  if (arguments.length.isOdd) {
    throw const FormatException('参数必须使用 --name value');
  }
  final options = <String, String>{};
  for (var index = 0; index < arguments.length; index += 2) {
    final name = arguments[index];
    final value = arguments[index + 1];
    if (!name.startsWith('--') || name.length == 2 || value.startsWith('--')) {
      throw FormatException('无效参数：$name');
    }
    final key = name.substring(2);
    if (options.containsKey(key)) {
      throw FormatException('重复参数：$name');
    }
    options[key] = value;
  }
  return options;
}

String requireCliOption(Map<String, String> options, String name) {
  final value = options[name];
  if (value == null || value.trim().isEmpty) {
    throw FormatException('缺少 --$name');
  }
  return value;
}
