enum ErrorType { network, validation, auth, generic }

class AppError {
  final String message;
  final ErrorType type;
  final DateTime timestamp;

  AppError({
    required this.message,
    required this.type,
  }) : timestamp = DateTime.now();

  // Factory constructors for common errors
  factory AppError.network(String message) => AppError(
        message: message,
        type: ErrorType.network,
      );

  factory AppError.validation(String message) => AppError(
        message: message,
        type: ErrorType.validation,
      );

  factory AppError.auth(String message) => AppError(
        message: message,
        type: ErrorType.auth,
      );
}
