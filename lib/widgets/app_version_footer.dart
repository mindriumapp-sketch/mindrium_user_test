import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionFooter extends StatelessWidget {
  const AppVersionFooter({
    super.key,
    this.padding = const EdgeInsets.symmetric(vertical: 10),
    this.textColor = const Color(0xFF8A97A3),
  });

  final EdgeInsetsGeometry padding;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return _AppVersionFooterBody(padding: padding, textColor: textColor);
  }
}

class _AppVersionFooterBody extends StatefulWidget {
  const _AppVersionFooterBody({required this.padding, required this.textColor});

  final EdgeInsetsGeometry padding;
  final Color textColor;

  @override
  State<_AppVersionFooterBody> createState() => _AppVersionFooterBodyState();
}

class _AppVersionFooterBodyState extends State<_AppVersionFooterBody> {
  late final Future<PackageInfo> _packageInfoFuture =
      PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _packageInfoFuture,
      builder: (context, snapshot) {
        final info = snapshot.data;
        final versionText =
            info == null ? 'Mindrium 버전 확인 중' : 'Mindrium v${info.version}';

        return Padding(
          padding: widget.padding,
          child: Text(
            versionText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Noto Sans KR',
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: widget.textColor,
            ),
          ),
        );
      },
    );
  }
}
