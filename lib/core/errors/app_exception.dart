/// A business-rule or validation failure whose [message] is safe to show
/// directly to the user.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Converts any error into a user-facing message.
String describeError(Object error) {
  if (error is AppException) return error.message;
  return 'Something went wrong. Please try again.';
}
