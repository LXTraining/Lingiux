sealed class Failure {
  final String message;
  const Failure(this.message);
}

final class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

final class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

final class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

final class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
}
