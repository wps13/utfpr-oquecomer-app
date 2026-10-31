import 'package:dio/dio.dart';

import '../../../domain/errors/app_failure.dart';

/// Converte falhas do Dio em [AppFailure].
AppFailure mapDioException(DioException e) {
  final inner = e.error;
  if (inner is AppFailure) return inner;
  if (inner is FormatException) return const InvalidResponseFailure();

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const TimeoutFailure();
    case DioExceptionType.connectionError:
      return const NoConnectionFailure();
    case DioExceptionType.cancel:
      return const CancelledFailure();
    case DioExceptionType.badResponse:
      final status = e.response?.statusCode ?? 0;
      if (status >= 500) return ServerFailure(status);
      if (status >= 400) return ClientFailure(status);
      return UnexpectedFailure(e, e.stackTrace);
    case DioExceptionType.badCertificate:
    case DioExceptionType.transformTimeout:
    case DioExceptionType.unknown:
      // SocketException cai em `unknown` em algumas plataformas.
      if (inner.toString().contains('SocketException')) {
        return const NoConnectionFailure();
      }
      return UnexpectedFailure(inner ?? e, e.stackTrace);
  }
}
