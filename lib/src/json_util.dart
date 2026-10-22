/// Runs [parse] and reports malformed input (wrong types, missing keys,
/// invalid values) as a [FormatException], so callers only need one `catch`.
T parseJson<T>(String what, T Function() parse) {
  try {
    return parse();
  } on FormatException {
    rethrow;
  } on TypeError catch (e) {
    throw FormatException('Invalid $what JSON: $e');
  } on ArgumentError catch (e) {
    throw FormatException('Invalid $what JSON: ${e.message}');
  }
}
