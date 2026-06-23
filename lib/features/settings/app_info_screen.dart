import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({super.key});

  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  static const MethodChannel _manualChannel = MethodChannel(
    'mindrium/manual_pdf',
  );

  late final Future<PackageInfo> _packageInfoFuture =
      PackageInfo.fromPlatform();
  bool _isOpeningManual = false;

  Future<void> _openManual() async {
    if (_isOpeningManual) return;
    setState(() => _isOpeningManual = true);
    try {
      await _manualChannel.invokeMethod<bool>('openManual');
    } on PlatformException catch (e) {
      if (!mounted) return;
      final message =
          e.code == 'NO_VIEWER' ? 'PDF를 열 수 있는 앱이 필요해요.' : '매뉴얼을 열지 못했어요.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('매뉴얼을 열지 못했어요.')));
    } finally {
      if (mounted) setState(() => _isOpeningManual = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(
        title: '앱 정보',
        showHome: false,
        confirmOnBack: false,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/image/eduhome.png', fit: BoxFit.cover),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xAAFFFFFF), Color(0x66FFFFFF)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [_buildInfoCard()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFCFFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5EDF4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: FutureBuilder<PackageInfo>(
        future: _packageInfoFuture,
        builder: (context, snapshot) {
          final info = snapshot.data;
          final fallbackText = snapshot.hasError ? '확인 불가' : '확인 중';
          final version = info == null ? fallbackText : 'v${info.version}';
          final buildNumber =
              info == null
                  ? fallbackText
                  : (info.buildNumber.isEmpty ? '-' : info.buildNumber);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F7FB),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF2C4154),
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '마인드리움',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E2F3F),
                            fontFamily: 'Noto Sans KR',
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '8주 CBT 기반 불안 관리 앱',
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.45,
                            color: Color(0xFF8A97A3),
                            fontFamily: 'Noto Sans KR',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _InfoRow(label: '버전', value: version),
              _InfoRow(label: '빌드', value: buildNumber),
              const _InfoRow(label: '주요 기록', value: '걱정일기, 불안 점수, 이완 훈련'),
              const _InfoRow(label: '권한', value: '알림, 위치, 마이크(선택)'),
              const _InfoRow(
                label: '정책',
                value: '설정 > 약관 및 정책에서 확인',
                showDivider: false,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isOpeningManual ? null : _openManual,
                  icon:
                      _isOpeningManual
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(_isOpeningManual ? '여는 중' : '사용 매뉴얼 보기'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2C4154),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF9AA8B3),
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Noto Sans KR',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 78,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8A97A3),
                    fontFamily: 'Noto Sans KR',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C4154),
                    fontFamily: 'Noto Sans KR',
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: Color(0xFFE7EDF2)),
      ],
    );
  }
}
