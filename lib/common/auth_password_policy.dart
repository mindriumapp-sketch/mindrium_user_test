/// 회원가입·비밀번호 재설정·변경 화면 공통 비밀번호 규칙.
abstract final class AuthPasswordPolicy {
  static final RegExp regex = RegExp(
    r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,20}$',
  );

  static const String message =
      '비밀번호는 8~20자이며, 영문자/숫자/특수문자를 각각 1자 이상 포함해야 합니다.';

  static String? validate(
    String password, {
    String emptyMessage = '비밀번호를 입력해주세요.',
  }) {
    final value = password.trim();
    if (value.isEmpty) return emptyMessage;
    if (!regex.hasMatch(value)) return message;
    return null;
  }

  static String? validateConfirm(
    String password,
    String confirmPassword, {
    String emptyMessage = '비밀번호 확인을 입력해주세요.',
    String mismatchMessage = '비밀번호가 일치하지 않습니다.',
  }) {
    final trimmedPassword = password.trim();
    final trimmedConfirm = confirmPassword.trim();
    if (trimmedConfirm.isEmpty) return emptyMessage;
    if (trimmedPassword != trimmedConfirm) return mismatchMessage;
    return null;
  }
}
