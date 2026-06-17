import 'package:dio/dio.dart';

abstract final class ApiErrorMessages {
  static const networkError = '인터넷 연결을 확인한 후 다시 시도해주세요.';
  static const timeoutError = '서버 응답이 지연되고 있어요. 인터넷 연결을 확인한 뒤 다시 시도해주세요.';
  static const serverError = '일시적인 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
  static const unknownError = '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.';

  static bool isNetworkFailure(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout;
  }

  static String fromDioException(DioException e, {String? fallback}) {
    if (isNetworkFailure(e)) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return timeoutError;
      }
      return networkError;
    }

    final detail = _detailMessage(e);
    if (detail != null) return detail;

    final status = e.response?.statusCode;
    if (status != null && status >= 500) return serverError;

    return fallback ?? e.message ?? unknownError;
  }

  static String? _detailMessage(DioException e) {
    final data = e.response?.data;
    if (data is! Map) return null;
    final detail = data['detail'];
    if (detail is String && detail.trim().isNotEmpty) return detail.trim();
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map) {
        final msg = first['msg'];
        if (msg is String && msg.trim().isNotEmpty) return msg.trim();
      }
    }
    return null;
  }
}
