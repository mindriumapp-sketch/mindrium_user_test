// 🔹 Mindrium: 걱정 일기 진행 분기 화면 (DiaryYesOrNo 개선 최종 버전)
// ‘아니오’ 클릭 시 로딩중 표시 + FastAPI 저장 + 위치 timeout 안전 처리

import 'dart:async';
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/contents/apply_flow/apply_flow_prompt_content.dart';
import 'package:gad_app_team/contents/apply_flow/apply_flow_route_data.dart';
import 'package:dio/dio.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/api/sud_api.dart';
import 'package:gad_app_team/data/apply_solve_provider.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_group_add_screen.dart';
import 'package:gad_app_team/widgets/inner_btn_card.dart';

class DiaryYesOrNo extends StatelessWidget {
  const DiaryYesOrNo({super.key});

  String? _resolveDiaryRoute(ApplyOrSolveFlow flow, String origin) {
    final route = flow.diaryRoute?.trim();
    if (route != null && route.isNotEmpty) {
      return route;
    }
    if (origin == 'daily') {
      return 'today_task';
    }
    if (origin == 'apply' || origin == 'solve') {
      return 'solve';
    }
    return null;
  }

  Future<void> _handleNo(
    BuildContext context,
    Map<String, dynamic> args,
    dynamic diary,
  ) async {
    final route = ApplyFlowRouteData.read(context, rawArgs: args);
    final flow = route.flow;
    final origin = route.origin;
    final tokens = TokenStorage();
    final access = await tokens.access;
    if (access == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다. 다시 로그인해 주세요.')),
        );
      }
      return;
    }

    final apiClient = ApiClient(tokens: tokens);
    final diariesApi = DiariesApi(apiClient);
    final sudApi = SudApi(apiClient);

    // 🔸 로딩 다이얼로그 표시
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.white, // 배경 흰색 유지
      builder:
          (_) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔹 로고 이미지 (노란 로딩 대신 표시)
                Image.asset(
                  'assets/image/logo.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),

                // 🔹 텍스트
                const Text(
                  '로딩 중입니다. 잠시만 기다려주세요...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Noto Sans KR',
                  ),
                ),
              ],
            ),
          ),
    );

    Position? pos;
    String? addressKo;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        // ⏱ 위치 요청 (5초 timeout 적용)
        try {
          pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
            ),
          ).timeout(const Duration(seconds: 5));
        } on TimeoutException {
          pos = null; // 시간 초과 시 null로 처리
        }
      }
    } catch (_) {
      // 위치 실패는 무시
      pos = null;
    }

    final resolvedPos = pos;
    if (resolvedPos != null) {
      try {
        await setLocaleIdentifier('ko_KR');
        final placemarks = await placemarkFromCoordinates(
          resolvedPos.latitude,
          resolvedPos.longitude,
        ).timeout(const Duration(seconds: 5));
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = <String>[
            if ((p.administrativeArea ?? '').trim().isNotEmpty)
              p.administrativeArea!.trim(),
            if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
            if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality!.trim(),
            if ((p.thoroughfare ?? '').trim().isNotEmpty)
              p.thoroughfare!.trim(),
            if ((p.subThoroughfare ?? '').trim().isNotEmpty)
              p.subThoroughfare!.trim(),
          ];
          if (parts.isNotEmpty) {
            addressKo = parts.join(' ');
          }
        }
      } catch (e) {
        debugPrint('주소 변환 실패: $e');
      }
    }

    final activationLabel = '자동 생성 일기 \n주소: ${addressKo ?? '확인되지 않음'}';
    final activationChip = diariesApi.makeDiaryChip(label: activationLabel);

    final beforeSud = route.beforeSud;
    flow.setBeforeSud(beforeSud);
    flow.setOrigin(origin);

    try {
      // 🔹 FastAPI + MongoDB에 빈 일기 생성
      final diaryRes = await diariesApi.createDiary(
        activation: activationChip,
        belief: const [],
        consequenceP: const [],
        consequenceE: const [],
        consequenceB: const [],
        alternativeThoughts: const [],
        route: _resolveDiaryRoute(flow, origin),
        latitude: pos?.latitude,
        longitude: pos?.longitude,
        addressName: addressKo,
      );
      final abcId = diaryRes['diary_id']?.toString();
      if (abcId == null || abcId.isEmpty) {
        throw Exception('생성된 일기 ID를 확인할 수 없습니다.');
      }
      flow.setDiaryId(abcId);

      Map<String, dynamic>? res;
      String? sudId;
      if (beforeSud != null) {
        try {
          res = await sudApi.createSudScore(
            diaryId: abcId,
            beforeScore: beforeSud,
          );
          sudId = res['sud_id'];
          flow.setSudId(sudId);
        } on DioException catch (e) {
          debugPrint('⚠️ SUD 저장 실패(Dio): ${e.message}');
        } catch (e) {
          debugPrint('⚠️ SUD 저장 실패: $e');
        }
      }

      if (context.mounted) {
        Navigator.pop(context); // ✅ 로딩창 닫기
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => AbcGroupAddScreen(
                  origin: origin,
                  diaryId: abcId,
                  beforeSud: beforeSud,
                  sudId: sudId,
                  diary: diary,
                ),
          ),
        );
      }
    } on DioException catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 로딩창 닫기
        final detail =
            e.response?.data is Map
                ? (e.response?.data['detail']?.toString() ??
                    e.response?.data.toString())
                : e.message;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('데이터 저장 중 오류가 발생했습니다: $detail')));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 로딩창 닫기
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('데이터 저장 중 오류가 발생했습니다: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = ApplyFlowRouteData.read(
      context,
      rawArgs: ModalRoute.of(context)?.settings.arguments,
    );
    final dynamic diary = route.diary;
    final String origin = route.origin;

    return InnerBtnCardScreen(
      appBarTitle: '걱정 일기 진행',
      title: '걱정 일기를 새로 \n작성하시겠어요?',
      primaryText: '예',
      onPrimary: () {
        Navigator.pushNamed(
          context,
          '/abc',
          arguments: route.mergedArgs(
            extra: {
              'origin': origin,
              'abcId': null,
              'beforeSud': route.beforeSud,
            },
            includeDiary: true,
          ),
        );
      },
      secondaryText: '아니오',
      onSecondary: () => _handleNo(context, route.args, diary),
      backgroundAsset: 'assets/image/eduhome.png',
      child: const ApplyFlowPromptContent(
        message: '예를 누르면 걱정 일기를 새로 작성해요.\n아니오를 누르면 걱정 그룹 추가로 넘어가요.',
      ),
    );
  }
}
