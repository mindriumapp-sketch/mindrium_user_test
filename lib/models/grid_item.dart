import 'package:gad_app_team/utils/text_line_material.dart';

class GridItem {
  final IconData icon;
  final String label;
  final bool isAdd;

  const GridItem({required this.icon, required this.label, this.isAdd = false});
}
