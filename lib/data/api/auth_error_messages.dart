import 'package:dio/dio.dart';

/// 인증 API 사용자 노출 메시지 (IA-06: 실패 원인 힌트 최소화).
abstract final class AuthErrorMessages {
  static const loginFailed = '이메일 또는 비밀번호가 올바르지 않습니다.';
  static const accountLocked = '잠시 후 다시 시도해주세요.';
  static const signupFailed = '회원가입에 실패했습니다. 입력 정보를 확인해주세요.';
  static const networkError = '네트워크 연결을 확인한 후 다시 시도해주세요.';
  /// 무료 호스팅 슬립·cold start 등으로 첫 연결이 오래 걸리거나 타임아웃될 때.
  static const hostedBackendUnreachable =
      '백엔드에 연결하지 못했습니다. 서버가 깨어나는 중이면 1~2분 뒤 다시 시도하거나, 로컬 실행 시 --dart-define=API_BASE_URL=… 로 주소를 지정해 주세요.';
  /// 로컬 API 주소(127.0.0.1 등)로 붙었는데 프로세스가 없거나 포트가 다를 때.
  static const localApiUnreachable =
      '로컬 API 서버에 연결하지 못했습니다. 터미널에서 백엔드를 실행했는지, 포트가 API_BASE_URL과 같은지 확인해 주세요. (예: uvicorn main:app --host 0.0.0.0 --port 8050)';
  static const serverError = '일시적인 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';

  static String fromDioException(DioException e, {required bool isSignup}) {
    final status = e.response?.statusCode;
    if (status == 423) return accountLocked;
    if (status == 401) return loginFailed;
    if (status == 409 && isSignup) {
      return _detailMessage(e) ?? '이미 등록된 이메일이거나 가입 정보가 올바르지 않습니다.';
    }
    if (status != null && status >= 500) return serverError;

    final detail = _detailMessage(e);
    if (detail != null && detail.isNotEmpty) {
      if (isSignup) return detail;
      // 로그인은 서버 detail이 있어도 통일 메시지 우선 (계정 존재 여부 비노출)
      if (status == 400 || status == 422) return loginFailed;
    }

    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      final host = e.requestOptions.uri.host;
      if (host == '127.0.0.1' || host == 'localhost') {
        return localApiUnreachable;
      }
      if (host.contains('onrender.com')) {
        return hostedBackendUnreachable;
      }
      return networkError;
    }

    return isSignup ? signupFailed : loginFailed;
  }

  static String? _detailMessage(DioException e) {
    final data = e.response?.data;
    if (data is! Map<String, dynamic>) return null;
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
