enum ErrorType { network, validation, auth, generic, locationService,server }

class AppError {
  final String message;
  final ErrorType type;
  final DateTime timestamp;

  AppError({
    required this.message,
    required this.type,
  }) : timestamp = DateTime.now();

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

  factory AppError.locationService(String message) => AppError(
        message: message,
        type: ErrorType.locationService,
      );

  factory AppError.server(String message) => AppError(
        message: message,
        type: ErrorType.server,
      );
}
