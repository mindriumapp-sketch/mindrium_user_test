import 'package:gad_app_team/utils/server_datetime.dart';

/// 현재 로그인한 사용자 정보를 나타내는 모델.
/// 백엔드의 UserMe 스키마와 1:1로 매칭되지만,
/// 이 모델은 "응답 전용(read only)" 용도로만 사용한다.
class UserMe {
  final String userId;
  final String email;
  final String name;
  final String? gender;
  final bool surveyCompleted;
  final bool emailVerified;
  final DateTime? createdAt; // 서버가 내려주는 값만 읽는다.
  final DateTime? updatedAt; // 서버가 내려주는 값만 읽는다.

  const UserMe({
    required this.userId,
    required this.email,
    required this.name,
    this.gender,
    required this.surveyCompleted,
    required this.emailVerified,
    this.createdAt,
    this.updatedAt,
  });

  /// 백엔드에서 내려주는 JSON → UserMe
  factory UserMe.fromJson(Map<String, dynamic> json) {
    return UserMe(
      userId: json['user_id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      gender: json['gender'] as String?,
      surveyCompleted: json['survey_completed'] as bool? ?? false,
      emailVerified: json['email_verified'] as bool? ?? false,
      createdAt: _parseNullableDateTime(json['created_at']),
      updatedAt: _parseNullableDateTime(json['updated_at']),
    );
  }

  /// copyWith는 UI에서 로컬 상태 업데이트용 (서버로 안 나감)
  UserMe copyWith({
    String? userId,
    String? email,
    String? name,
    String? gender,
    bool? surveyCompleted,
    bool? emailVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserMe(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      surveyCompleted: surveyCompleted ?? this.surveyCompleted,
      emailVerified: emailVerified ?? this.emailVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// null 허용 DateTime 파서
DateTime? _parseNullableDateTime(dynamic value) {
  return parseServerDateTime(value);
}
