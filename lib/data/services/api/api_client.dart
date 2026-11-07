import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../config/env.dart';
import '../../../domain/errors/app_failure.dart';
import '../crash/error_reporter.dart';
import 'error_mapper.dart';

/// Cliente HTTP base. Todas as falhas são lançadas como [AppFailure]; as
/// inesperadas também são encaminhadas ao [ErrorReporter].
///
/// Use [CatalogApiClient] ou [GeminiApiClient], uma instância de cada,
/// injetadas via Provider.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.errorReporter,
    Map<String, String> headers = const {},
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 20),
    bool enableLogs = kDebugMode,
    HttpClientAdapter? httpClientAdapter,
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: connectTimeout,
           sendTimeout: connectTimeout,
           receiveTimeout: receiveTimeout,
           headers: {Headers.acceptHeader: Headers.jsonContentType, ...headers},
         ),
       ) {
    if (httpClientAdapter != null) _dio.httpClientAdapter = httpClientAdapter;
    // Headers ficam fora do log para não vazar chaves de API.
    if (enableLogs) {
      _dio.interceptors.add(
        LogInterceptor(
          requestHeader: false,
          requestBody: true,
          responseBody: true,
          logPrint: (o) => debugPrint(o.toString()),
        ),
      );
    }
  }

  final Dio _dio;
  final ErrorReporter errorReporter;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) => _request(
    () => _dio.get<T>(
      path,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
    ),
  );

  Future<T> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) => _request(
    () => _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
    ),
  );

  Future<T> _request<T>(Future<Response<T>> Function() send) async {
    try {
      final data = (await send()).data;
      if (data == null) {
        throw const InvalidResponseFailure.emptyBody();
      }
      return data;
    } on AppFailure catch (f) {
      await _reportIfUnexpected(f);
      rethrow;
    } on DioException catch (e) {
      final failure = mapDioException(e);
      await _reportIfUnexpected(failure);
      throw failure;
    } on Object catch (e, st) {
      final failure = UnexpectedFailure(e, st);
      await _reportIfUnexpected(failure);
      throw failure;
    }
  }

  Future<void> _reportIfUnexpected(AppFailure failure) async {
    if (failure is UnexpectedFailure) {
      try {
        await errorReporter.report(
          failure.cause ?? failure,
          failure.stackTrace,
        );
      } on Object {
        // A telemetria não pode substituir a falha da requisição.
      }
    }
  }

  void close() => _dio.close();
}

/// API do catálogo.
class CatalogApiClient extends ApiClient {
  CatalogApiClient(
    Env env,
    ErrorReporter reporter, {
    super.enableLogs,
    super.httpClientAdapter,
  }) : super(baseUrl: env.catalogBaseUrl, errorReporter: reporter);
}

/// API de IA (Gemini). A chave vai no header, nunca na URL.
class GeminiApiClient extends ApiClient {
  GeminiApiClient(Env env, ErrorReporter reporter)
    : super(
        baseUrl: env.geminiBaseUrl,
        errorReporter: reporter,
        headers: {'x-goog-api-key': env.geminiApiKey},
        receiveTimeout: const Duration(seconds: 60),
      );
}
