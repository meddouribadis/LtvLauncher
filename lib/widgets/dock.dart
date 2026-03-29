import 'package:flutter/cupertino.dart';

import '../models/app.dart';
import '../models/category.dart';
import '../providers/apps_service.dart';
import 'category_clean_row.dart';

const _kDockPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 18);
const _kDockDecoration = BoxDecoration(
  color: Color(0x1AFFFFFF),
  borderRadius: BorderRadius.all(Radius.circular(32)),
  border: Border.fromBorderSide(
    BorderSide(color: Color(0x26FFFFFF), width: 1.5),
  ),
  boxShadow: [
    BoxShadow(
      color: Color(0x4D000000),
      blurRadius: 20,
      offset: Offset(0, 10),
    ),
  ],
);

class Dock extends StatelessWidget {
  final Category category;
  final List<App> apps;
  final AppsService appsService;

  const Dock({
    required this.category,
    required this.apps,
    required this.appsService,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: _kDockPadding,
        decoration: _kDockDecoration,
        child: CategoryCleanRow(
          category: category,
          applications: apps,
          isFirstSection: false,
          scrollAlignment: 1.0,
        ),
      ),
    );
  }
}